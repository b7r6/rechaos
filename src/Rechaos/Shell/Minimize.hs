-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // shell // minimize
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   external checker driver with trial timeouts and retained evidence
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{- | The shell driver for minimization: run a user-supplied checker against
candidates, under trial timeouts, until the pure core's delta-debugger converges
on a minimal witness that still reproduces a signature.

Two subjects share one driver. A fault timeline ('minimizeTimeline') shrinks its
injected faults and hands each candidate to the checker as @$RECHAOS_TIMELINE@;
a scenario step list ('minimizeSteps') shrinks opaque JSON steps and hands each
candidate over as @$RECHAOS_STEPS@. Both read the checker's verdict from
@$RECHAOS_VERDICT@.

This module is in the IO shell. It spawns checker subprocesses, enforces
per-trial timeouts and process-group kills, and persists trial evidence; the
search strategy itself lives in "Rechaos.Core.Shrink".
-}
module Rechaos.Shell.Minimize (
  -- * Shell driver
  minimizeTimeline,
  minimizeSteps,
  Subject (..),
  minimizeWith,
) where

import Control.Exception (IOException, catch)
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Key (Key)
import Data.Aeson.Types (parseMaybe)
import Data.ByteString.Lazy.Char8 qualified as L
import Data.IORef
import Data.Maybe (isJust)
import Data.Text (Text)
import Rechaos.Core.Minimize (weakerDecision)
import Rechaos.Core.Shrink qualified as Shrink
import Rechaos.Core.Types
import Rechaos.Shell.Json
import Rechaos.Shell.Steps
import System.Environment (getEnvironment)
import System.Exit
import System.FilePath ((</>))
import System.IO
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Signals (sigKILL, signalProcessGroup)
import System.Process
import System.Timeout qualified as Timeout

{- | What one kind of witness looks like to the driver: how to read and write
  it, how to weaken one element, which environment variable carries a
  candidate to the checker, and the noun used for elements in the evidence
  log and summary.
-}
data Subject a = Subject
  { subjectRead :: FilePath -> IO [a]
  -- ^ Read the failing input; may drop elements that can never shrink.
  , subjectWrite :: FilePath -> [a] -> IO ()
  -- ^ Write a candidate or the final witness.
  , subjectWeaker :: a -> [a]
  -- ^ Strictly weaker forms of one element, under a finite measure.
  , subjectVariable :: String
  -- ^ Environment variable naming the candidate file for the checker.
  , subjectNoun :: Key
  -- ^ JSON key for the element count: @faults@ or @steps@.
  }

-- | The fault-timeline subject: only injected faults are shrunk.
timelineSubject :: Subject Decision
timelineSubject =
  Subject
    { subjectRead = fmap (filter (isJust . injection)) . readTimeline
    , subjectWrite = writeTimeline
    , subjectWeaker = weakerDecision
    , subjectVariable = "RECHAOS_TIMELINE"
    , subjectNoun = "faults"
    }

-- | The scenario-steps subject: every step is a candidate for deletion.
stepsSubject :: Subject Step
stepsSubject =
  Subject
    { subjectRead = readSteps
    , subjectWrite = writeSteps
    , subjectWeaker = weakerStep
    , subjectVariable = "RECHAOS_STEPS"
    , subjectNoun = "steps"
    }

{- | Minimize the firing faults in @input@ down to a smallest reproducing subset,
writing the witness to @output@: it confirms the baseline reproduces, drives
the core delta-debugger by running @command@ (up to @maxTrials@ trials, each
repeated @repetitions@ times under a per-run @timeoutSeconds@ cap) until it
converges on faults still matching @signature@, retaining trial evidence.
-}
minimizeTimeline :: FilePath -> FilePath -> String -> Text -> Int -> Int -> Int -> IO ()
minimizeTimeline = minimizeWith timelineSubject

{- | Minimize a scenario step list exactly as 'minimizeTimeline' minimizes a
timeline: the checker receives each candidate as @$RECHAOS_STEPS@.
-}
minimizeSteps :: FilePath -> FilePath -> String -> Text -> Int -> Int -> Int -> IO ()
minimizeSteps = minimizeWith stepsSubject

{- | The shared driver behind 'minimizeTimeline' and 'minimizeSteps'. A trial
passes only when every repetition reports the exact @signature@; a checker
that exits non-zero, times out, or disagrees with itself is 'Shrink.Unknown'
and never advances the witness.
-}
minimizeWith ::
  forall a.
  (Eq a, ToJSON a) =>
  Subject a ->
  FilePath ->
  FilePath ->
  String ->
  Text ->
  Int ->
  Int ->
  Int ->
  IO ()
minimizeWith subject input output command signature repetitions timeoutSeconds maxTrials = do
  unless (repetitions > 0 && timeoutSeconds > 0 && timeoutSeconds <= 86400 && maxTrials > 0) $
    fail "repetitions, timeout, and max-trials must be positive; timeout <= 86400"
  original <- subjectRead subject input
  env0 <- getEnvironment
  counter <- newIORef (0 :: Int)
  withFile (output ++ ".trials.jsonl") WriteMode $ \trials -> do
    hSetBuffering trials LineBuffering
    let test :: [a] -> IO Shrink.Verdict
        test xs = do
          results <- mapM (const (once xs)) [1 .. repetitions]
          let verdict
                | all (== Shrink.Triggers) results = Shrink.Triggers
                | all (== Shrink.DoesNotTrigger) results = Shrink.DoesNotTrigger
                | otherwise = Shrink.Unknown
          L.hPutStrLn
            trials
            ( encode
                ( object
                    [ subjectNoun subject .= length xs
                    , "verdict" .= show verdict
                    , "candidate" .= xs
                    ]
                )
            )
          pure verdict
        once xs = withSystemTempDirectory "rechaos-trial" $ \dir -> do
          modifyIORef' counter (+ 1)
          let candidateFile = dir </> "candidate.jsonl"
              verdictFile = dir </> "verdict.json"
              variable = subjectVariable subject
              env1 =
                (variable, candidateFile)
                  : ("RECHAOS_VERDICT", verdictFile)
                  : filter (\(k, _) -> k /= variable && k /= "RECHAOS_VERDICT") env0
          subjectWrite subject candidateFile xs
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
                maybe (killGroup process) (pure . Just) result
          if result /= Just ExitSuccess
            then pure Shrink.Unknown
            else do
              bytes <- L.readFile verdictFile `catch` (\(_ :: IOException) -> pure "null")
              pure (verdictOf (decode bytes >>= parseMaybe verdictFields))
        verdictFields = withObject "checker verdict" $ \o -> (,) <$> o .: "verdict" <*> o .:? "signature"
        verdictOf (Just ("triggers" :: Text, Just found))
          | found == signature = Shrink.Triggers
        verdictOf (Just ("does-not-trigger", _)) = Shrink.DoesNotTrigger
        verdictOf _ = Shrink.Unknown
        -- The search ends in one of three ways: candidates exhausted with every
        -- rejection conclusive ("complete"), exhausted but with some Unknown
        -- rejections ("inconclusive"), or out of trial budget ("trial-limit").
        loop n uncertain state =
          maybe
            (pure (if uncertain then "inconclusive" else "complete", state))
            (tryCandidate n uncertain state)
            (Shrink.candidate state)
        tryCandidate n uncertain state xs
          | n >= maxTrials = pure ("trial-limit", state)
          | otherwise = do
              v <- test xs
              let uncertain' = v /= Shrink.Triggers && (uncertain || v == Shrink.Unknown)
              loop (n + 1) uncertain' (Shrink.observe (subjectWeaker subject) v state)
    baseline <- test original
    unless (baseline == Shrink.Triggers) $
      fail "initial input did not repeatedly reproduce the requested signature"
    (status, state) <- loop (0 :: Int) False (Shrink.start (subjectWeaker subject) original)
    final <- test (Shrink.best state)
    unless (final == Shrink.Triggers) $
      fail "final witness did not reproduce; no minimized output written"
    subjectWrite subject output (Shrink.best state)
    attempts <- readIORef counter
    L.putStrLn
      ( encode
          ( object
              [ "status" .= (status :: Text)
              , subjectNoun subject .= length (Shrink.best state)
              , "checkerRuns" .= attempts
              , "signature" .= signature
              ]
          )
      )
 where
  killGroup process = do
    pid <- getPid process
    maybe (pure ()) (\p -> signalProcessGroup sigKILL p `catch` ignoreIO) pid
    _ <- waitForProcess process
    pure Nothing
  ignoreIO :: IOException -> IO ()
  ignoreIO _ = pure ()
