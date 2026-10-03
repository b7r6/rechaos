-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                // rechaos // core // minimize
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   witness-preserving candidate generation and acceptance state machine
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

module Rechaos.Core.Minimize (Verdict (..), ShrinkState (..), start, candidate, observe, candidates) where

import Data.List (nub)
import Data.Maybe (isJust)
import Numeric.Natural (Natural)
import Rechaos.Core.Types

-- The shell must reproduce the SAME failure signature, not merely a nonzero
-- exit code. A flaky/timeout/infrastructure result must be Unknown.
data Verdict = Triggers | DoesNotTrigger | Unknown deriving (Eq, Show)
data ShrinkState = ShrinkState {best :: Timeline, pending :: [Timeline]}
  deriving (Eq, Show)

start :: Timeline -> ShrinkState
start xs =
  let faults = filter (isJust . injection) xs
   in ShrinkState faults (candidates faults)

candidate :: ShrinkState -> Maybe Timeline
candidate (ShrinkState _ []) = Nothing
candidate (ShrinkState _ (x : _)) = Just x

observe :: Verdict -> ShrinkState -> ShrinkState
observe _ s@(ShrinkState _ []) = s
observe Triggers (ShrinkState _ (x : _)) = ShrinkState x (candidates x)
observe _ (ShrinkState b (_ : xs)) = ShrinkState b xs

-- Chunk deletion down to singletons makes the result deletion-1-minimal for a
-- deterministic predicate. Intensity shrinking follows a finite, decreasing
-- measure; timing is explicit in the retained event identity and Delay value.
candidates :: Timeline -> [Timeline]
candidates xs = nub (deletions ++ intensities)
 where
  n = length xs
  sizes = descending n
  deletions = [take i xs ++ drop (i + k) xs | k <- sizes, i <- [0, k .. n - 1]]
  intensities =
    [ take i xs ++ [d{injection = Just f}] ++ drop (i + 1) xs
    | (i, d) <- zip [0 ..] xs
    , Just old <- [injection d]
    , f <- weaker (event d) old
    ]
  descending k
    | k <= 0 = []
    | k == 1 = [1]
    | otherwise = k : descending (k `div` 2)

weaker :: Event -> Fault -> [Fault]
weaker _ (Delay n) = [Delay (n `div` 2) | n > 0]
weaker e (Dribble rate chunk) =
  [Dribble (min cap (max 1 rate * 2)) chunk | rate < cap]
 where
  cap = max 1 (eMessageBytes e * 1000000)
weaker e (Truncate keep) =
  [Truncate (keep + max 1 ((cap - keep) `div` 2)) | keep < cap]
 where
  cap :: Natural
  cap = eMessageBytes e
weaker _ (Abort _) = []
