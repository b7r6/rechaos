-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                 // rechaos // shell // oracle
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   filesystem snapshot and SHA256 capture
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

{- | The differential oracle's shell: hash an output directory into a 'Tree' and
compare two such trees to decide whether a chaos build diverged from a clean one.

This module is in the IO shell. It walks the filesystem and computes digests
here, then hands the resulting pure 'Tree's to "Rechaos.Core.Oracle" for the
comparison. By convention human-facing chatter goes to stderr while the
scriptable JSON verdict is written to stdout.
-}
module Rechaos.Shell.Oracle (
  -- * Filesystem snapshot
  snapshot,

  -- * Comparison
  compareTrees,

  -- * JSON rendering
  oracleJSON,
  verdictJSON,
  putVerdict,
) where

import Control.Exception (evaluate)
import Control.Monad (forM, unless)
import Data.Aeson (Value, encode, object, (.=))
import Data.Bits ((.&.))
import Data.ByteString.Lazy qualified as L
import Data.ByteString.Lazy.Char8 qualified as LC
import Data.List (sort)
import Data.Map.Strict qualified as M
import Data.Text qualified as T
import Rechaos.Core.Oracle
import Rechaos.Shell.Protocol (sha256)
import System.Directory (listDirectory)
import System.FilePath ((</>))
import System.IO (IOMode (ReadMode), withBinaryFile)
import System.Posix.Files

{- | Walk an output directory and hash it into a pure 'Tree', recording each
regular file's digest, size, and executable bit, following no symlinks and
failing if any node changes while it is being read.
-}
snapshot :: FilePath -> IO Tree
snapshot root = do
  status <- getSymbolicLinkStatus root
  unless (isDirectory status) $ fail "oracle root must be an existing directory (not a symlink)"
  M.fromList <$> walk "" root
 where
  walk relative absolute = do
    before <- getSymbolicLinkStatus absolute
    entry <-
      if isSymbolicLink before
        then
          Symlink . T.pack <$> readSymbolicLink absolute
        else
          if isDirectory before
            then pure Directory
            else
              if isRegularFile before
                then withBinaryFile absolute ReadMode $ \h -> do
                  bytes <- L.hGetContents h
                  let digest = sha256 bytes
                  _ <- evaluate (T.length digest)
                  pure (File digest (fromIntegral (fileSize before)) (fileMode before .&. 0o111 /= 0))
                else fail ("unsupported output node: " ++ absolute)
    children <-
      if isDirectory before
        then do
          names <- sort <$> listDirectory absolute
          concat
            <$> forM names (\name -> walk (if null relative then name else relative </> name) (absolute </> name))
        else pure []
    after <- getSymbolicLinkStatus absolute
    unless (stable before after) $ fail ("output changed while hashing: " ++ absolute)
    pure ((T.pack relative, entry) : children)
  stable a b =
    fileID a == fileID b
      && deviceID a == deviceID b
      && fileSize a == fileSize b
      && fileMode a == fileMode b
      && modificationTimeHiRes a == modificationTimeHiRes b
      && statusChangeTimeHiRes a == statusChangeTimeHiRes b

{- | A one-line machine-readable verdict object carrying a single label, e.g.
@{"verdict":"valid"}@. Terminal subcommands emit this on stdout so results
stay scriptable while human chatter goes to stderr.
-}
verdictJSON :: T.Text -> Value
verdictJSON label = object ["verdict" .= label]

-- | Emit a 'verdictJSON' label as a single line on stdout.
putVerdict :: T.Text -> IO ()
putVerdict = LC.putStrLn . encode . verdictJSON

{- | Render an oracle 'Verdict' as a JSON object, listing per-path clean\/chaos
changes when the two trees diverged.
-}
oracleJSON :: Verdict -> Value
oracleJSON Equivalent = object ["verdict" .= ("equivalent" :: T.Text)]
oracleJSON Inconclusive = object ["verdict" .= ("inconclusive" :: T.Text)]
oracleJSON (Diverged changes) =
  object
    [ "verdict" .= ("diverged" :: T.Text)
    , "changes"
        .= [ object ["path" .= path, "clean" .= fmap show a, "chaos" .= fmap show b] | Change path a b <- changes
           ]
    ]

{- | Snapshot two output directories and compare them, yielding the oracle
'Verdict' for whether the second (chaos) build diverged from the first (clean).
-}
compareTrees :: FilePath -> FilePath -> IO Verdict
compareTrees a b = compareBuilds <$> (Built <$> snapshot a) <*> (Built <$> snapshot b)
