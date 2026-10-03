-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                             // rechaos // cli
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   command-line entry: argument parsing and subcommand dispatch
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Concurrent (threadDelay)
import Control.Exception
import Control.Monad (unless, when)
import Data.Aeson (encode)
import qualified Data.ByteString.Lazy.Char8 as L
import Data.Maybe (isJust, isNothing)
import qualified Data.Text as T
import qualified Network.GRPC.Client as C
import Network.GRPC.Common (SslKeyLog (..), def)
import Network.GRPC.Server.Run
import Options.Applicative
import qualified Rechaos.Core.Oracle as O
import Rechaos.Core.Scheduler (schedule, verifyReplay)
import Rechaos.Core.Types
import Rechaos.Shell.Json
import Rechaos.Shell.Minimize
import Rechaos.Shell.Oracle
import Rechaos.Shell.Proxy
import Rechaos.Shell.Runtime
import System.Directory (canonicalizePath, createDirectoryIfMissing)
import System.Exit
import System.FilePath (takeDirectory)
import System.IO
import System.IO.Error (ioeGetErrorString)

data ServeOptions = ServeOptions
  { host :: String
  , port :: Int
  , upstreamHost :: String
  , upstreamPort :: Int
  , tlsUpstream :: Bool
  , ca :: Maybe FilePath
  , certificate :: Maybe FilePath
  , key :: Maybe FilePath
  , policyFile :: Maybe FilePath
  , replayFile :: Maybe FilePath
  , sparse :: Bool
  , record :: FilePath
  , maxSeconds :: Int
  }
data Command
  = Serve ServeOptions
  | Oracle FilePath FilePath
  | Schedule FilePath FilePath FilePath
  | Validate FilePath
  | Minimize FilePath FilePath String String Int Int Int
  | VerifyReplay FilePath FilePath

-- Keep this literal in sync with the version in flake.nix / the cabal metadata.
-- It is hardcoded here deliberately to avoid reading flake.nix at build time.
versionString :: String
versionString = "rechaos 0.1.0"

optionString :: String -> String -> Parser String
optionString name helpText = strOption (long name <> metavar "VALUE" <> help helpText)

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command'
        "serve"
        (Serve <$> serveOptions)
        ( "Run the REAPI chaos gateway. "
            <> "Banners go to stderr. "
            <> "Exit codes: 0 ok, 2 usage/IO error."
        )
        <> command'
          "oracle"
          (Oracle <$> strArgument (metavar "CLEAN_TREE") <*> strArgument (metavar "CHAOS_TREE"))
          ( "Compare completed build output trees. "
              <> "stdout: JSON verdict; stderr: chatter. "
              <> "Exit codes: 0 equivalent, 1 divergence, 2 usage/IO error."
          )
        <> command'
          "schedule"
          ( Schedule
              <$> optionString "policy" "Policy JSON"
              <*> optionString "trace" "Recorded JSONL events"
              <*> optionString "output" "Recomputed timeline JSONL"
          )
          ( "Recompute decisions from a recorded event trace. "
              <> "Exit codes: 0 ok, 2 usage/IO error."
          )
        <> command'
          "validate"
          (Validate <$> strArgument (metavar "POLICY"))
          ( "Validate a policy. "
              <> "stdout: JSON verdict; stderr: chatter. "
              <> "Exit codes: 0 valid, 2 invalid/IO error."
          )
        <> command'
          "verify-replay"
          ( VerifyReplay
              <$> strArgument (metavar "EXPECTED_TIMELINE")
              <*> strArgument (metavar "OBSERVED_TIMELINE")
          )
          ( "Check that all replay events were observed with matching fingerprints and faults. "
              <> "stdout: JSON verdict; stderr: chatter. "
              <> "Exit codes: 0 covered, 2 uncovered/IO error."
          )
        <> command'
          "minimize"
          ( Minimize
              <$> optionString "timeline" "Recorded fault timeline"
              <*> optionString "output" "Minimized JSONL timeline"
              <*> optionString "check" "Shell command that reads RECHAOS_TIMELINE and writes RECHAOS_VERDICT"
              <*> optionString "signature" "Exact failure signature to preserve"
              <*> option auto (long "repetitions" <> metavar "N" <> value 2 <> showDefault)
              <*> option auto (long "trial-timeout" <> metavar "SECONDS" <> value 30 <> showDefault)
              <*> option auto (long "max-trials" <> metavar "N" <> value 1000 <> showDefault)
          )
          ( "Shrink only on repeatedly confirmed matching failure signatures. "
              <> "Exit codes: 0 ok, 2 usage/IO error."
          )
    )
 where
  command' name parser desc = Options.Applicative.command name (info parser (progDesc desc))

serveOptions :: Parser ServeOptions
serveOptions =
  ServeOptions
    <$> strOption
      ( long "host"
          <> metavar "HOST"
          <> value "127.0.0.1"
          <> showDefault
          <> help "Downstream listen address"
      )
    <*> option
      auto
      ( long "port"
          <> metavar "PORT"
          <> value 50070
          <> showDefault
          <> help "Downstream listen port"
      )
    <*> optionString "upstream-host" "Upstream REAPI hostname"
    <*> option
      auto
      ( long "upstream-port"
          <> metavar "PORT"
          <> value 50051
          <> showDefault
          <> help "Upstream REAPI port"
      )
    <*> switch (long "upstream-tls" <> help "Verify upstream TLS using system trust or --ca")
    <*> optional (optionString "ca" "Upstream CA PEM file")
    <*> optional (optionString "certificate" "Downstream TLS certificate PEM")
    <*> optional (optionString "key" "Downstream TLS key PEM")
    <*> optional (optionString "policy" "Fault policy JSON (default: no faults)")
    <*> optional (optionString "replay" "Replay a recorded JSONL timeline")
    <*> switch (long "sparse" <> help "Replay only listed events; check fingerprints for all listed events")
    <*> strOption
      ( long "record"
          <> value "runs/timeline.jsonl"
          <> showDefault
          <> help "New decision log; outcomes go to PATH.outcomes.jsonl"
      )
    <*> option
      auto
      ( long "max-call-seconds"
          <> value 60
          <> showDefault
          <> help "Bound every RPC, including one without a client deadline"
      )

versioner :: Parser (a -> a)
versioner =
  infoOption
    versionString
    (long "version" <> help "Show version and exit")

main :: IO ()
main = (execParser opts >>= run) `catches` [Handler onExit, Handler onIO, Handler onError]
 where
  opts =
    info
      (commandParser <**> versioner <**> helper)
      (fullDesc <> progDesc "rechaos: black-box REAPI chaos and determinism checking")
  -- Let optparse-applicative's own exits (usage, --help, --version) pass through,
  -- and preserve any ExitCode a subcommand raised (e.g. divergence = exit 1).
  onExit :: ExitCode -> IO a
  onExit = exitWith
  -- IOExceptions (missing/unreadable files, bad ports) must never surface a
  -- HasCallStack backtrace; print a clean one-liner and exit 2.
  onIO :: IOException -> IO a
  onIO = die' . ioeGetErrorString
  -- A stray 'error'/'errorWithoutStackTrace' lands here; strip the backtrace.
  onError :: ErrorCall -> IO a
  onError e = die' (errorCallMessage e)
  errorCallMessage (ErrorCallWithLocation msg _) = msg
  die' :: String -> IO a
  die' msg = hPutStrLn stderr ("rechaos: " ++ msg) >> exitWith (ExitFailure 2)

-- Read a JSON input, qualifying any failure with the file path (and, where a
-- command reads several inputs, the argument name) so diagnostics say exactly
-- which file failed and why. Missing/unreadable files and strict-decode
-- failures both arrive as IOExceptions (the latter via 'fail'); an 'error'
-- would arrive as ErrorCall. Either becomes a single clean
-- 'rechaos: <path>: <reason>' line through the top-level handler.
withPath :: FilePath -> IO a -> IO a
withPath path act = act `catches` [Handler rioe, Handler rerr]
 where
  rioe :: IOException -> IO a
  rioe e = fail (path ++ ": " ++ ioeGetErrorString e)
  rerr :: ErrorCall -> IO a
  rerr e = fail (path ++ ": " ++ show e)

run :: Command -> IO ()
run (Validate path) = do
  _ <- withPath path (readPolicy path)
  hPutStrLn stderr "policy valid"
  putVerdict "valid"
run (VerifyReplay expected observed) = do
  a <- withPath ("expected timeline " ++ expected) (readTimeline expected)
  b <- withPath ("observed timeline " ++ observed) (readTimeline observed)
  case verifyReplay a b of
    Left err -> fail (T.unpack err)
    Right () -> do
      hPutStrLn stderr "replay coverage verified"
      putVerdict "covered"
run (Minimize input output checker signature repetitions seconds trials) =
  minimizeTimeline input output checker (T.pack signature) repetitions seconds trials
run (Oracle clean chaos) = do
  result <- compareTrees clean chaos
  L.putStrLn (encode (oracleJSON result))
  case result of
    O.Equivalent -> pure ()
    O.Diverged _ -> exitWith (ExitFailure 1)
    O.Inconclusive -> exitWith (ExitFailure 2)
run (Schedule policy trace output) = do
  p <- withPath ("policy " ++ policy) (readPolicy policy)
  ds <- withPath ("trace " ++ trace) (readTimeline trace)
  writeTimeline output (schedule p (map event ds))
run (Serve opts) = do
  unless (all (\n -> n > 0 && n <= 65535) [port opts, upstreamPort opts]) $
    fail "ports must be in 1..65535"
  unless (maxSeconds opts > 0 && maxSeconds opts <= 86400) $
    fail "max-call-seconds must be in 1..86400"
  when (sparse opts && isNothing (replayFile opts)) $ fail "--sparse requires --replay"
  when (isJust (ca opts) && not (tlsUpstream opts)) $ fail "--ca requires --upstream-tls"
  when (isJust (policyFile opts) && isJust (replayFile opts)) $ fail "choose --policy or --replay"
  p <- maybe (pure (Policy 0 [])) (\f -> withPath ("policy " ++ f) (readPolicy f)) (policyFile opts)
  replay <-
    traverse
      ( \file -> do
          a <- canonicalizePath file
          b <- canonicalizePath (record opts)
          when (a == b) $ fail "record path must differ from replay path"
          ds <- withPath ("replay " ++ file) (readTimeline file)
          pure (sparse opts, ds)
      )
      (replayFile opts)
  config <- case (certificate opts, key opts) of
    (Nothing, Nothing) ->
      pure (ServerConfig (Just (InsecureConfig (Just (host opts)) (fromIntegral (port opts)))) Nothing)
    (Just cert, Just privateKey) ->
      pure
        ( ServerConfig
            Nothing
            (Just (SecureConfig (host opts) (fromIntegral (port opts)) cert [] privateKey SslKeyLogNone))
        )
    _ -> fail "downstream TLS requires both --certificate and --key"
  let trust = maybe C.certStoreFromSystem C.certStoreFromPath (ca opts)
      address = C.Address (upstreamHost opts) (fromIntegral (upstreamPort opts)) Nothing
      server =
        if tlsUpstream opts
          then C.ServerSecure (C.ValidateServer trust) SslKeyLogNone address
          else C.ServerInsecure address
  createDirectoryIfMissing True (takeDirectory (record opts))
  withFile (record opts) WriteMode $ \journal ->
    withFile (record opts ++ ".outcomes.jsonl") WriteMode $ \outcomes -> do
      runtime <- newRuntime p replay journal outcomes
      let finish = do
            remaining <- remainingReplay runtime
            unless (null remaining) $
              hPutStrLn
                stderr
                ("replay incomplete: " ++ show (length remaining) ++ " recorded events were not observed")
      -- Reconnect transport for future calls; never retry a failed RPC. A fixed
      -- interval avoids introducing hidden random choices into the shell.
      let reconnect = C.ReconnectPolicy $ do
            threadDelay 250000
            pure (C.DoReconnect (C.Reconnect C.ReconnectToOriginal Nothing reconnect))
      flip finally finish $ C.withConnection def{C.connReconnectPolicy = reconnect} server $ \connection -> do
        hPutStrLn stderr ("rechaos listening on " ++ host opts ++ ":" ++ show (port opts))
        hPutStrLn stderr ("decision log: " ++ record opts)
        runServerWithHandlers def config (handlers runtime connection (maxSeconds opts))
