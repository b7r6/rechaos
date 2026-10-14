-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                // rechaos // core // scenario
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   scheduler and object-store liveness invariants over observed scenario actions
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

{- | The scheduler and object-store invariants (catalog entries 8 through 13 in
@docs/invariants.md@) as a pure function of what a scenario run observed.

The step engine records, per action, when it was submitted, first seen
@QUEUED@ and @EXECUTING@, when it finished, its final status and message, and
every time it fell from @EXECUTING@ back to @QUEUED@; plus the start and end of
each control-plane fault window. 'evaluate' turns those observations and the
scenario's 'Limits' into 'Finding's named by stable signatures. It is total and
deterministic: the same observations and limits always give the same findings
in the same order, which is what lets a frozen witness re-evaluate identically
during shrinking.

n.b. Time inside any control window is discounted from the queue-age and
executing bounds: a fault's direct effect (nothing dispatches while the store
is paused; every slot is held by a retrying fetch while the store throttles) is
not a scheduler decision. The throttle invariants look inside a
@store-throttle@ window on purpose, because giving up or re-dispatching while
the store says \"retry later\" is the behavior under test.
-}
module Rechaos.Core.Scenario (
  -- * Observations
  Action (..),
  Control (..),
  Observations (..),
  Limits (..),

  -- * Findings
  Finding (..),
  Evidence (..),
  evaluate,
  signatures,

  -- * Constants
  overtakeMarginMs,
  throttleTailMs,
  clientSideStatuses,
  controlSteps,
) where

import Control.Applicative ((<|>))
import Data.List (nub, sort, sortOn)
import Data.Maybe (fromMaybe, isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as T

{- | One action as the engine observed it. Times are milliseconds from the
scenario's start.
-}
data Action = Action
  { aId :: Text
  , aSubmitMs :: Maybe Integer
  , aExecutingMs :: Maybe Integer
  , aDoneMs :: Maybe Integer
  , aLastMs :: Maybe Integer
  , aLastStage :: Maybe Text
  , aStatus :: Maybe Text
  -- ^ @OK@, a gRPC status name, or @CLIENT_CANCELLED@.
  , aMessage :: Text
  , aExitCode :: Maybe Integer
  , aOperation :: Maybe Text
  , aDetached :: Bool
  , aProbes :: Integer
  -- ^ How many re-attach probes were made.
  , aInputsPresent :: Maybe Bool
  , aRequeues :: [Integer]
  -- ^ Times at which @EXECUTING@ fell back to @QUEUED@.
  , aCpu :: Integer
  , aMemoryKb :: Integer
  }
  deriving (Eq, Show)

-- | One control-plane fault window, as it actually ran.
data Control = Control
  { cStep :: Text
  , cStartMs :: Integer
  , cEndMs :: Integer
  }
  deriving (Eq, Show)

-- | Everything one scenario run observed.
data Observations = Observations
  { oActions :: [Action]
  , oControls :: [Control]
  }
  deriving (Eq, Show)

-- | The bounds the invariants are evaluated against.
data Limits = Limits
  { queueAgeMs :: Integer
  , executingMs :: Integer
  , workers :: Integer
  , slots :: Integer
  , memoryKb :: Integer
  , downloadBudgetMs :: Integer
  }
  deriving (Eq, Show)

{- | A value in a finding's evidence: enough structure to render as JSON
without the core depending on a JSON library.
-}
data Evidence
  = EInt Integer
  | EText Text
  | EBool Bool
  | ENull
  | EList [Evidence]
  | EObject [(Text, Evidence)]
  deriving (Eq, Show)

-- | One invariant violation.
data Finding = Finding
  { fSignature :: Text
  , fAction :: Text
  , fKind :: Text
  , fEvidence :: [(Text, Evidence)]
  }
  deriving (Eq, Show)

{- | A later submission counts as overtaking only when it was dispatched at
least this far ahead: sub-second ordering among actions that all waited for
the same slot is a wobble, not starvation.
-}
overtakeMarginMs :: Integer
overtakeMarginMs = 1000

-- | A throttle's effects are attributed up to this long after it ends.
throttleTailMs :: Integer
throttleTailMs = 5000

-- | Statuses the client caused, never attributed to the server.
clientSideStatuses :: [Text]
clientSideStatuses = ["CANCELLED", "DEADLINE_EXCEEDED", "CLIENT_CANCELLED", "UNAVAILABLE"]

-- | The control-step kinds whose windows discount the bounds.
controlSteps :: [Text]
controlSteps = ["store-full", "store-pause", "worker-pause", "store-throttle"]

{- | Every finding for one run, sorted by signature then action. Actions are
  considered in submission order (ties by id); an action never submitted
  produces nothing.
-}
evaluate :: Limits -> Observations -> [Finding]
evaluate limits (Observations actions controls) =
  sortOn (\finding -> (fSignature finding, fAction finding)) (concatMap perAction submitted)
 where
  ordered = sortOn (\action -> (fromMaybe maxTime (aSubmitMs action), aId action)) actions
  submitted = filter (isJust . aSubmitMs) ordered
  perAction action =
    queueFindings limits controls ordered action
      ++ executingFindings limits controls action
      ++ failureFindings controls action
      ++ throttleFindings limits controls action
  maxTime = 2 ^ (60 :: Int)

-- | The distinct signatures among findings, sorted.
signatures :: [Finding] -> [Text]
signatures = sort . nub . map fSignature

-- Milliseconds of [start, end) inside any control window.
faultedMs :: Integer -> Integer -> [Control] -> Integer
faultedMs start end = sum . map overlap . filter ((`elem` controlSteps) . cStep)
 where
  overlap control =
    let lo = max start (cStartMs control)
        hi = min end (cEndMs control)
     in if hi > lo then hi - lo else 0

throttleWindows :: [Control] -> [Control]
throttleWindows = filter ((== "store-throttle") . cStep)

inWindow :: Integer -> Integer -> [Control] -> Bool
inWindow tailMs ms = any (\window -> cStartMs window <= ms && ms <= cEndMs window + tailMs)

-- The wait from submission to dispatch (or to the last observation), minus
-- fault windows; Nothing when nothing was observed after submission.
waitMs :: [Control] -> Action -> Maybe Integer
waitMs controls action = do
  submit <- aSubmitMs action
  end <- aExecutingMs action <|> aLastMs action
  pure (end - submit - faultedMs submit end controls)

-- Invariants 8 (queue-starvation) and 9 (dispatch-stall).
queueFindings :: Limits -> [Control] -> [Action] -> Action -> [Finding]
queueFindings limits controls actions action
  | Just wait <- waitMs controls action
  , Just submit <- aSubmitMs action
  , wait > queueAgeMs limits =
      starvedOrStalled wait submit
  | otherwise = []
 where
  starvedOrStalled wait submit
    | not (null overtakenBy) =
        [ Finding
            "queue-starvation"
            (aId action)
            "an action waited past the bound while later submissions were dispatched ahead of it"
            ( evidence wait
                ++ [ ("overtaken_by", EList (map EText (take 12 overtakenBy)))
                   , ("overtaken_count", EInt (fromIntegral (length overtakenBy)))
                   ]
            )
        ]
    | fits =
        [ Finding
            "dispatch-stall"
            (aId action)
            "an action waited past the bound although the fleet had room for everything in flight"
            ( evidence wait
                ++ [ ("inflight", EInt (fromIntegral (length inflight)))
                   , ("capacity_slots", EInt (workers limits * slots limits))
                   ]
            )
        ]
    | otherwise = []
   where
    at = submit + queueAgeMs limits
    inflight =
      [ other
      | other <- actions
      , Just otherSubmit <- [aSubmitMs other]
      , otherSubmit <= at
      , maybe True (> at) (aDoneMs other)
      ]
    fits =
      sum (map aCpu inflight) <= workers limits * slots limits
        && all ((<= memoryKb limits) . aMemoryKb) inflight
        && sum (map aMemoryKb inflight) <= workers limits * memoryKb limits
  overtakenBy =
    [ aId other
    | other <- actions
    , aId other /= aId action
    , Just otherSubmit <- [aSubmitMs other]
    , Just submit <- [aSubmitMs action]
    , otherSubmit > submit
    , Just otherExecuting <- [aExecutingMs other]
    , maybe True (\executing -> otherExecuting + overtakeMarginMs < executing) (aExecutingMs action)
    ]
  evidence wait =
    [ ("wait_ms", EInt wait)
    , ("bound_ms", EInt (queueAgeMs limits))
    , ("dispatched", EBool (isJust (aExecutingMs action)))
    , ("cpu", EInt (aCpu action))
    , ("memory_kb", EInt (aMemoryKb action))
    ]

-- Invariant 10 (stuck-executing).
executingFindings :: Limits -> [Control] -> Action -> [Finding]
executingFindings limits controls action
  | Just started <- aExecutingMs action
  , isNothing (aDoneMs action)
  , Just lastSeen <- aLastMs action
  , aLastStage action == Just "EXECUTING"
  , let executing = lastSeen - started - faultedMs started lastSeen controls
  , executing >= executingMs limits =
      [ Finding
          "stuck-executing"
          (aId action)
          "an operation stayed EXECUTING past the scheduler's executing timeout with no client attached"
          [ ("executing_ms", EInt started)
          , ("last_seen_ms", EInt lastSeen)
          , ("executing_outside_faults_ms", EInt executing)
          , ("bound_ms", EInt (executingMs limits))
          , ("operation", maybe ENull EText (aOperation action))
          , ("detached", EBool (aDetached action))
          , ("probes", EInt (aProbes action))
          ]
      ]
  | otherwise = []

-- A server-side failure: a status that is neither OK nor the client's doing.
serverFailure :: Action -> Maybe Text
serverFailure action
  | Just status <- aStatus action
  , status /= "OK"
  , status `notElem` clientSideStatuses =
      Just status
  | otherwise = Nothing

failedAtMs :: Action -> Maybe Integer
failedAtMs action = aDoneMs action <|> aLastMs action

containsAny :: [Text] -> Text -> Bool
containsAny needles haystack = any (`T.isInfixOf` T.toLower haystack) needles

evictionText :: Text -> Bool
evictionText = containsAny ["evict", "hardlink", "hard link"]

storeFetchText :: Text -> Bool
storeFetchText =
  containsAny
    [ "download"
    , "fetch"
    , "serverbusy"
    , "slowdown"
    , "ratelimit"
    , "throttl"
    , "on attempt"
    , "failed to start"
    , "error reading from"
    ]

-- Invariant 11 (input-evicted-failure, action-failed-inputs-present).
failureFindings :: [Control] -> Action -> [Finding]
failureFindings controls action
  | Just status <- serverFailure action
  , aInputsPresent action == Just True =
      classify status
  | otherwise = []
 where
  classify status
    | evictionText (aMessage action) =
        [ Finding
            "input-evicted-failure"
            (aId action)
            "an action failed on a worker-local eviction while every input was present in the CAS"
            (evidence status)
        ]
    | Just failed <- failedAtMs action
    , faultedMs failed (failed + 1) controls > 0 =
        []
    | Just failed <- failedAtMs action
    , storeFetchText (aMessage action)
    , inWindow throttleTailMs failed (throttleWindows controls) =
        []
    | otherwise =
        [ Finding
            ("action-failed-inputs-present:" <> status)
            (aId action)
            "an action failed server-side while every input was present in the CAS"
            (evidence status)
        ]
  evidence status =
    [ ("status", EText status)
    , ("message", EText (T.take 300 (aMessage action)))
    , ("exit_code", maybe ENull EInt (aExitCode action))
    ]

-- Invariants 12 (store-throttle-giveup) and 13 (store-throttle-redispatch).
throttleFindings :: Limits -> [Control] -> Action -> [Finding]
throttleFindings limits controls action
  | null windows = []
  -- n.b. Unknown presence counts as absent here: a failed action whose inputs
  -- were never confirmed present is not attributed to the throttle.
  | aInputsPresent action /= Just True && failedStatus = []
  | otherwise = giveUp ++ redispatch
 where
  windows =
    filter
      (\window -> cEndMs window - cStartMs window < downloadBudgetMs limits)
      (throttleWindows controls)
  failedStatus = maybe False (/= "OK") (aStatus action)
  windowEvidence =
    EList
      [ EObject [("start_ms", EInt (cStartMs window)), ("end_ms", EInt (cEndMs window))] | window <- windows
      ]
  giveUp
    | Just status <- serverFailure action
    , aInputsPresent action == Just True
    , Just failed <- failedAtMs action
    , storeFetchText (aMessage action)
    , inWindow throttleTailMs failed windows =
        [ Finding
            "store-throttle-giveup"
            (aId action)
            "an input fetch failed during an object-store throttle shorter than the worker's download budget"
            [ ("status", EText status)
            , ("message", EText (T.take 300 (aMessage action)))
            , ("failed_at_ms", EInt failed)
            , ("throttle", windowEvidence)
            , ("download_budget_ms", EInt (downloadBudgetMs limits))
            ]
        ]
    | otherwise = []
  bounced = filter (\requeue -> inWindow throttleTailMs requeue windows) (aRequeues action)
  redispatch
    | null bounced = []
    | otherwise =
        [ Finding
            "store-throttle-redispatch"
            (aId action)
            "an action was requeued to another worker because of an object-store throttle instead of being retried in place"
            [ ("requeues_ms", EList (map EInt (take 12 bounced)))
            , ("requeue_count", EInt (fromIntegral (length bounced)))
            , ("final_status", maybe ENull EText (aStatus action))
            , ("throttle", windowEvidence)
            ]
        ]
