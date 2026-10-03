-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                // rechaos // core // minimize
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   witness-preserving candidate generation and acceptance state machine
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | Witness-preserving shrinking of a failing 'Timeline' down to a small
reproducer.

Minimization is a candidate\/observe state machine ('ShrinkState'): 'start' seeds
it from a failing timeline, 'candidate' offers the next timeline to try, and
'observe' folds the shell's 'Verdict' back in — accepting a candidate only when it
still 'Triggers' the failure. Because candidates include chunk deletions down to
singletons, a fully explored result is deletion-1-minimal for a deterministic
predicate: no single retained fault can be dropped without losing the failure.
Intensity shrinking follows a separate, strictly decreasing (weaker) measure.

The 'Triggers' \/ 'Unknown' distinction is load-bearing: only a reproduction of the
SAME failure signature counts as triggering; a flake, timeout, or infrastructure
error is 'Unknown' and must never be treated as a successful shrink. This module
is pure: no IO and no partial functions.
-}
module Rechaos.Core.Minimize (Verdict (..), ShrinkState (..), start, candidate, observe, candidates) where

import Data.List (nub)
import Data.Maybe (isJust)
import Numeric.Natural (Natural)
import Rechaos.Core.Types

-- The shell must reproduce the SAME failure signature, not merely a nonzero
-- exit code. A flaky/timeout/infrastructure result must be Unknown.

{- | The shell's judgement on a shrink candidate. The shell must reproduce the
  SAME failure signature, not merely a nonzero exit code: a flaky, timeout, or
  infrastructure result is 'Unknown' and is treated conservatively (the
  candidate is discarded, not accepted).
-}
data Verdict
  = -- | The candidate reproduced the original failure signature.
    Triggers
  | -- | The candidate ran but did not reproduce the failure.
    DoesNotTrigger
  | -- | The run was inconclusive (flake, timeout, infrastructure error).
    Unknown
  deriving (Eq, Show)

{- | The minimizer's state: the best (smallest) timeline known to trigger so far,
  and the queue of candidates still to try against it.
-}
data ShrinkState = ShrinkState
  { best :: Timeline
  -- ^ Smallest timeline confirmed to still 'Triggers' the failure.
  , pending :: [Timeline]
  -- ^ Candidates yet to be offered, in order.
  }
  deriving (Eq, Show)

{- | Seed the state machine from a failing timeline. Keeps only its injected
  faults as the initial 'best' and enqueues their 'candidates'.
-}
start :: Timeline -> ShrinkState
start xs =
  let faults = filter (isJust . injection) xs
   in ShrinkState faults (candidates faults)

{- | The next candidate timeline to test, or 'Nothing' when the queue is empty and
  shrinking has converged on 'best'.
-}
candidate :: ShrinkState -> Maybe Timeline
candidate (ShrinkState _ []) = Nothing
candidate (ShrinkState _ (x : _)) = Just x

{- | Fold the shell's 'Verdict' on the current candidate back into the state. On
  'Triggers' the candidate becomes the new 'best' and its own 'candidates' are
  enqueued (restarting the search from the smaller timeline); on
  'DoesNotTrigger' or 'Unknown' the candidate is discarded and the next one is
  tried. Conservative: an 'Unknown' never advances 'best'.
-}
observe :: Verdict -> ShrinkState -> ShrinkState
observe _ s@(ShrinkState _ []) = s
observe Triggers (ShrinkState _ (x : _)) = ShrinkState x (candidates x)
observe _ (ShrinkState b (_ : xs)) = ShrinkState b xs

-- Chunk deletion down to singletons makes the result deletion-1-minimal for a
-- deterministic predicate. Intensity shrinking follows a finite, decreasing
-- measure; timing is explicit in the retained event identity and Delay value.

{- | All shrink candidates derived from a timeline: chunk deletions at halving
  sizes down to singletons, plus intensity reductions that replace one injected
  fault with a strictly weaker one. Deletion down to singletons is what makes a
  converged result deletion-1-minimal for a deterministic predicate; the
  intensity candidates follow a finite, decreasing measure (see 'weaker'), and
  timing stays explicit in the retained event identity and 'Delay' value.
-}
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

{- | Strictly weaker variants of a fault, if any, used for intensity shrinking.
  Each step moves along a finite, decreasing measure toward the event's natural
  bound: 'Delay' halves toward zero, 'Dribble' doubles its rate toward the
  message's full-speed cap (@messageBytes * 'microsPerSecond'@, the rate that
  delivers the whole message in one microsecond), and 'Truncate' raises its
  kept-byte count toward the full message size. 'Abort' has no weaker form.
-}
weaker :: Event -> Fault -> [Fault]
weaker _ (Delay n) = [Delay (n `div` 2) | n > 0]
weaker e (Dribble rate chunk) =
  [Dribble (min cap (max 1 rate * 2)) chunk | rate < cap]
 where
  cap = max 1 (eMessageBytes e * microsPerSecond)
weaker e (Truncate keep) =
  [Truncate (keep + max 1 ((cap - keep) `div` 2)) | keep < cap]
 where
  cap :: Natural
  cap = eMessageBytes e
weaker _ (Abort _) = []
