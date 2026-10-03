-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // shell // minimize
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   external checker driver with trial timeouts and retained evidence
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Rechaos.Shell.Minimize (minimizeTimeline) where

import Control.Exception (IOException, catch)
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (parseMaybe)
import qualified Data.ByteString.Lazy.Char8 as L
import Data.IORef
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Rechaos.Core.Minimize as M
import Rechaos.Core.Types
import Rechaos.Shell.Json
import System.Environment (getEnvironment)
import System.Exit
import System.FilePath ((</>))
import System.IO
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Signals (sigKILL, signalProcessGroup)
import System.Process
import qualified System.Timeout as Timeout

minimizeTimeline :: FilePath -> FilePath -> String -> Text -> Int -> Int -> Int -> IO ()
minimizeTimeline input output command signature repetitions timeoutSeconds maxTrials = do
  unless (repetitions > 0 && timeoutSeconds > 0 && timeoutSeconds <= 86400 && maxTrials > 0) $
    fail "repetitions, timeout, and max-trials must be positive; timeout <= 86400"
  original <- filter (isJust . injection) <$> readTimeline input
  env0 <- getEnvironment
  counter <- newIORef (0 :: Int)
  withFile (output ++ ".trials.jsonl") WriteMode $ \trials -> do
    hSetBuffering trials LineBuffering
    let test ds = do
          results <- mapM (const (once ds)) [1 .. repetitions]
          let verdict
                | all (== M.Triggers) results = M.Triggers
                | all (== M.DoesNotTrigger) results = M.DoesNotTrigger
                | otherwise = M.Unknown
          L.hPutStrLn
            trials
            (encode (object ["faults" .= length ds, "verdict" .= show verdict, "timeline" .= ds]))
          pure verdict
        once ds = withSystemTempDirectory "rechaos-trial" $ \dir -> do
          modifyIORef' counter (+ 1)
          let timeline = dir </> "timeline.jsonl"
              verdictFile = dir </> "verdict.json"
              env1 =
                ("RECHAOS_TIMELINE", timeline)
                  : ("RECHAOS_VERDICT", verdictFile)
                  : filter (\(k, _) -> k /= "RECHAOS_TIMELINE" && k /= "RECHAOS_VERDICT") env0
          writeTimeline timeline ds
          result <- withFile (dir </> "checker.log") WriteMode $ \logHandle ->
            withCreateProcess
              (shell command)
                { env = Just env1
                , create_group = True
                , std_out = UseHandle logHandle
                , std_err = UseHandle logHandle
                }
              $ \_ _ _ process -> do
                result <- Timeout.timeout (timeoutSeconds * 1000000) (waitForProcess process)
                case result of
                  Just code -> pure (Just code)
                  Nothing -> do
                    pid <- getPid process
                    maybe (pure ()) (\p -> signalProcessGroup sigKILL p `catch` ignoreIO) pid
                    _ <- waitForProcess process
                    pure Nothing
          if result /= Just ExitSuccess
            then pure M.Unknown
            else do
              bytes <- L.readFile verdictFile `catch` (\(_ :: IOException) -> pure "null")
              let parsed =
                    decode bytes
                      >>= parseMaybe (withObject "checker verdict" $ \o -> (,) <$> o .: "verdict" <*> o .:? "signature")
              pure $ case parsed of
                Just ("triggers" :: Text, Just found) | found == signature -> M.Triggers
                Just ("does-not-trigger", _) -> M.DoesNotTrigger
                _ -> M.Unknown
        loop n state
          | n >= maxTrials = pure (False, state)
          | otherwise = case M.candidate state of
              Nothing -> pure (True, state)
              Just ds -> test ds >>= \v -> loop (n + 1) (M.observe v state)
    baseline <- test original
    unless (baseline == M.Triggers) $
      fail "initial timeline did not repeatedly reproduce the requested signature"
    (finished, state) <- loop 0 (M.start original)
    final <- test (M.best state)
    unless (final == M.Triggers) $ fail "final witness did not reproduce; no minimized output written"
    writeTimeline output (M.best state)
    attempts <- readIORef counter
    L.putStrLn
      ( encode
          ( object
              [ "status" .= (if finished then "complete" else "trial-limit" :: Text)
              , "faults" .= length (M.best state)
              , "checkerRuns" .= attempts
              , "signature" .= signature
              ]
          )
      )
 where
  ignoreIO :: IOException -> IO ()
  ignoreIO _ = pure ()
