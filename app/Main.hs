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

optionString :: String -> String -> Parser String
optionString name helpText = strOption (long name <> metavar "VALUE" <> help helpText)

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command' "serve" (Serve <$> serveOptions) "Run the REAPI chaos gateway"
        <> command'
          "oracle"
          (Oracle <$> strArgument (metavar "CLEAN_TREE") <*> strArgument (metavar "CHAOS_TREE"))
          "Compare completed build output trees (exit 1 = divergence, 2 = error)"
        <> command'
          "schedule"
          ( Schedule
              <$> optionString "policy" "Policy JSON"
              <*> optionString "trace" "Recorded JSONL events"
              <*> optionString "output" "Recomputed timeline JSONL"
          )
          "Recompute decisions from a recorded event trace"
        <> command' "validate" (Validate <$> strArgument (metavar "POLICY")) "Validate a policy"
        <> command'
          "verify-replay"
          ( VerifyReplay
              <$> strArgument (metavar "EXPECTED_TIMELINE")
              <*> strArgument (metavar "OBSERVED_TIMELINE")
          )
          "Check that all replay events were observed with matching fingerprints and faults"
        <> command'
          "minimize"
          ( Minimize
              <$> optionString "timeline" "Recorded fault timeline"
              <*> optionString "output" "Minimized JSONL timeline"
              <*> optionString "check" "Shell command that reads RECHAOS_TIMELINE and writes RECHAOS_VERDICT"
              <*> optionString "signature" "Exact failure signature to preserve"
              <*> option auto (long "repetitions" <> value 2 <> showDefault)
              <*> option auto (long "trial-timeout" <> value 30 <> showDefault)
              <*> option auto (long "max-trials" <> value 1000 <> showDefault)
          )
          "Shrink only on repeatedly confirmed matching failure signatures"
    )
 where
  command' name parser desc = Options.Applicative.command name (info (parser <**> helper) (progDesc desc))

serveOptions :: Parser ServeOptions
serveOptions =
  ServeOptions
    <$> strOption (long "host" <> value "127.0.0.1" <> showDefault)
    <*> option auto (long "port" <> value 50070 <> showDefault)
    <*> optionString "upstream-host" "Upstream REAPI hostname"
    <*> option auto (long "upstream-port" <> value 50051 <> showDefault)
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

main :: IO ()
main =
  ( execParser
      ( info
          (commandParser <**> helper)
          (fullDesc <> progDesc "rechaos: black-box REAPI chaos and determinism checking")
      )
      >>= run
  )
    `catch` \e -> case fromException e :: Maybe ExitCode of
      Just code -> exitWith code
      Nothing -> hPutStrLn stderr (displayException (e :: SomeException)) >> exitWith (ExitFailure 2)

run :: Command -> IO ()
run (Validate path) = readPolicy path >> putStrLn "policy valid"
run (VerifyReplay expected observed) = do
  a <- readTimeline expected
  b <- readTimeline observed
  either (fail . T.unpack) (const (putStrLn "replay coverage verified")) (verifyReplay a b)
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
  p <- readPolicy policy
  ds <- readTimeline trace
  writeTimeline output (schedule p (map event ds))
run (Serve opts) = do
  unless (all (\n -> n > 0 && n <= 65535) [port opts, upstreamPort opts]) $
    fail "ports must be in 1..65535"
  unless (maxSeconds opts > 0 && maxSeconds opts <= 86400) $
    fail "max-call-seconds must be in 1..86400"
  when (sparse opts && replayFile opts == Nothing) $ fail "--sparse requires --replay"
  when (ca opts /= Nothing && not (tlsUpstream opts)) $ fail "--ca requires --upstream-tls"
  when (policyFile opts /= Nothing && replayFile opts /= Nothing) $ fail "choose --policy or --replay"
  p <- maybe (pure (Policy 0 [])) readPolicy (policyFile opts)
  replay <-
    traverse
      ( \file -> do
          a <- canonicalizePath file
          b <- canonicalizePath (record opts)
          when (a == b) $ fail "record path must differ from replay path"
          ds <- readTimeline file
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
