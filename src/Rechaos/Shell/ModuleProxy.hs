-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                           // rechaos // shell // module-proxy
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   a GOPROXY over HTTP/2 and TLS that can reset a response stream mid-body
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | A Go module proxy that serves a directory in the GOPROXY layout (what a
module cache keeps under @cache/download@) over HTTP/2 and TLS, and, under a
'Rule', cuts chosen responses part-way through the body with
@RST_STREAM(INTERNAL_ERROR)@: the fault a build sees as
@stream error: stream ID n; INTERNAL_ERROR; received from peer@ when a module
proxy or an edge in front of it drops a transfer.

The reset is the HTTP/2 library's own cancel path: the response headers and the
bytes pushed so far are on the wire, then the stream is reset, so the client
cannot tell this from an upstream that failed for real. A clean response
carries a @content-length@; a reset one does too, since the upstream that
drops a stream had already promised a length.

HTTP/2 and TLS are what the fault needs, not decoration: a plain-text proxy
would get HTTP/1.1 from a Go client, where the nearest fault is a truncated
body and the message differs. Each request is logged as one JSON line to
stderr (and to a file when asked) so a run can be checked against what the
client reported. The proxy runs until interrupted.
-}
module Rechaos.Shell.ModuleProxy (
  ModuleProxyOptions (..),
  serveModuleProxy,
) where

import Control.Concurrent.MVar (newMVar, withMVar)
import Control.Exception (ErrorCall (..), toException)
import Data.Aeson (encode, object, (.=))
import Data.Aeson.Types (Pair)
import Data.ByteString qualified as B
import Data.ByteString.Builder (byteString)
import Data.ByteString.Char8 qualified as BC
import Data.ByteString.Lazy.Char8 qualified as L
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Data.Text qualified as T
import Network.HTTP.Types (hContentLength, hContentType, status200, status404)
import Network.HTTP2.Server (
  OutBodyIface (..),
  Server,
  requestPath,
  responseNoBody,
  responseStreamingIface,
 )
import Network.HTTP2.TLS.Server qualified as TLS
import Network.TLS (Credentials (..), credentialLoadX509)
import Numeric.Natural (Natural)
import Rechaos.Core.ModuleProxy
import System.Directory (doesFileExist)
import System.FilePath (joinPath, splitDirectories, (</>))
import System.IO

-- | How to serve and what to break.
data ModuleProxyOptions = ModuleProxyOptions
  { proxyRoot :: FilePath
  -- ^ Directory in GOPROXY layout.
  , proxyHost :: String
  -- ^ Listen address.
  , proxyPort :: Int
  -- ^ Listen port.
  , proxyCertificate :: FilePath
  -- ^ TLS certificate PEM; the client must trust it (Go honours @SSL_CERT_FILE@).
  , proxyKey :: FilePath
  -- ^ TLS key PEM.
  , proxyRule :: Maybe Rule
  -- ^ The reset rule, or 'Nothing' to serve everything whole.
  , proxyLog :: Maybe FilePath
  -- ^ Append the per-request JSON lines here as well as to stderr.
  }

-- | Serve until interrupted. Fails (exit 2 through the CLI) when the credentials do not load.
serveModuleProxy :: ModuleProxyOptions -> IO ()
serveModuleProxy options = do
  credential <-
    credentialLoadX509 (proxyCertificate options) (proxyKey options)
      >>= either (fail . ("certificate: " ++)) pure
  logFile <- traverse (`openFile` AppendMode) (proxyLog options)
  logLock <- newMVar ()
  requests <- newIORef 0
  matched <- newIORef 0
  hPutStrLn stderr $
    "module proxy: https://"
      ++ proxyHost options
      ++ ":"
      ++ show (proxyPort options)
      ++ " serving "
      ++ proxyRoot options
      ++ maybe "" describe (proxyRule options)
  let emit fields = withMVar logLock $ \_ -> do
        let line = encode (object fields)
        L.hPutStrLn stderr line
        mapM_ (\handle -> L.hPutStrLn handle line >> hFlush handle) logFile
  TLS.run
    TLS.defaultSettings
    (Credentials [credential])
    (proxyHost options)
    (fromIntegral (proxyPort options))
    (server options requests matched emit)
 where
  describe rule =
    ", resetting the first "
      ++ show (ruleCount rule)
      ++ " response(s) whose path contains "
      ++ show (ruleNeedle rule)
      ++ " after "
      ++ show (ruleAfterBytes rule)
      ++ " bytes"

-- | One request: resolve the path under the root, then serve it whole or cut it.
server :: ModuleProxyOptions -> IORef Natural -> IORef Natural -> ([Pair] -> IO ()) -> Server
server options requests matched emit request _ respond = do
  number <- atomicModifyIORef' requests (\n -> (n + 1, n + 1))
  let path = maybe "" BC.unpack (requestPath request)
      record :: String -> Natural -> IO ()
      record outcome sent =
        emit ["request" .= number, "path" .= path, "bytes" .= sent, "outcome" .= outcome]
      missing outcome = record outcome 0 >> respond (responseNoBody status404 []) []
  case relativePath path of
    Nothing -> missing "rejected"
    Just relative -> do
      let file = proxyRoot options </> relative
      exists <- doesFileExist file
      if not exists
        then missing "missing"
        else do
          contents <- B.readFile file
          plan <- case proxyRule options of
            Just rule
              | matches rule (T.pack path) ->
                  decide rule <$> atomicModifyIORef' matched (\n -> (n + 1, n))
            _ -> pure Nothing
          let headers =
                [ (hContentLength, BC.pack (show (B.length contents)))
                , (hContentType, "application/octet-stream")
                ]
          respond (responseStreamingIface status200 headers (stream plan contents record)) []

{- | Push the body in chunks; under a plan, stop at the planned byte and cancel
  the stream, which the library sends as @RST_STREAM(INTERNAL_ERROR)@ after
  the data already queued.
-}
stream :: Maybe Natural -> B.ByteString -> (String -> Natural -> IO ()) -> OutBodyIface -> IO ()
stream plan contents record iface = go 0 contents
 where
  chunk = 16384 :: Natural
  go sent rest
    | Just limit <- plan
    , sent >= limit = do
        outBodyCancel iface (Just (toException (ErrorCall "rechaos: injected stream reset")))
        record "reset" sent
    | B.null rest = record "complete" sent
    | otherwise = do
        let allowed = maybe chunk (\limit -> min chunk (limit - sent)) plan
            (piece, remaining) = B.splitAt (fromIntegral allowed) rest
        outBodyPush iface (byteString piece)
        outBodyFlush iface
        go (sent + fromIntegral (B.length piece)) remaining

{- | The request path as a path under the root: query string dropped, leading
  slashes dropped, and refused outright if any component would leave the root.
-}
relativePath :: String -> Maybe FilePath
relativePath raw
  | null parts || any escapes parts = Nothing
  | otherwise = Just (joinPath parts)
 where
  parts = filter (/= "/") (splitDirectories (dropWhile (== '/') (takeWhile (/= '?') raw)))
  escapes part = part == ".." || part == "."
