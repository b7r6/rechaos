-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                  // rechaos // core // shrink
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   element-generic witness-preserving shrinking: candidates and acceptance
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | The shrinking algorithm with the element type abstracted away.

"Rechaos.Core.Minimize" instantiates this module at 'Rechaos.Core.Types.Decision'
(a gateway timeline); the shell's minimize driver instantiates it at an opaque
JSON step with the 'Rechaos.Shell.Steps' weakening, so a scheduler scenario (a
list of action submissions and control-plane faults) shrinks under exactly the
same candidate generator and acceptance rule as a fault timeline. The algorithm is Zeller-style delta debugging: chunk deletions
at halving sizes down to singletons, plus intensity reductions supplied by the
caller as a @weaker@ function that must follow a finite, strictly decreasing
measure.

n.b. A caller's @weaker@ is the only thing that can break termination. The
contract is: every element @weaker x@ returns is strictly smaller than @x@ under
some well-founded measure, and the chain reaches a floor. Deletion needs no such
promise; it is bounded by the list length.

This module is pure: no IO and no partial functions.
-}
module Rechaos.Core.Shrink (
  Verdict (..),
  ShrinkState (..),
  start,
  candidate,
  observe,
  candidates,
  descending,
) where

import Data.List (nub)

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

{- | The minimizer's state: the best (smallest) list known to trigger so far, and
  the queue of candidates still to try against it.
-}
data ShrinkState a = ShrinkState
  { best :: [a]
  -- ^ Smallest list confirmed to still 'Triggers' the failure.
  , pending :: [[a]]
  -- ^ Candidates yet to be offered, in order.
  }
  deriving (Eq, Show)

{- | Seed the state machine from a failing list: it becomes the initial 'best'
  and its 'candidates' (under @weaker@) are enqueued.
-}
start :: (Eq a) => (a -> [a]) -> [a] -> ShrinkState a
start weaker xs = ShrinkState xs (candidates weaker xs)

{- | The next candidate to test, or 'Nothing' when the queue is empty and
  shrinking has converged on 'best'.
-}
candidate :: ShrinkState a -> Maybe [a]
candidate (ShrinkState _ []) = Nothing
candidate (ShrinkState _ (next : _)) = Just next

{- | Fold the shell's 'Verdict' on the current candidate back into the state. On
  'Triggers' the candidate becomes the new 'best' and its own 'candidates' are
  enqueued (restarting the search from the smaller list); on 'DoesNotTrigger'
  or 'Unknown' the candidate is discarded and the next one is tried.
  Conservative: an 'Unknown' never advances 'best'.
-}
observe :: (Eq a) => (a -> [a]) -> Verdict -> ShrinkState a -> ShrinkState a
observe _ _ converged@(ShrinkState _ []) = converged
observe weaker Triggers (ShrinkState _ (accepted : _)) = ShrinkState accepted (candidates weaker accepted)
observe _ _ (ShrinkState bestSoFar (_ : rest)) = ShrinkState bestSoFar rest

{- | All shrink candidates derived from a list: chunk deletions at halving sizes
  down to singletons, then intensity reductions that replace one element with
  each of its @weaker@ forms. Deletion down to singletons is what makes a
  converged result deletion-1-minimal for a deterministic predicate. Candidates
  are offered in this order and deduplicated, so the sequence is a function of
  the input alone.
-}
candidates :: (Eq a) => (a -> [a]) -> [a] -> [[a]]
candidates weaker xs = nub (deletions ++ intensities)
 where
  n = length xs
  deletions = [take i xs ++ drop (i + k) xs | k <- descending n, i <- [0, k .. n - 1]]
  intensities =
    [ take i xs ++ [weakened] ++ drop (i + 1) xs
    | (i, element) <- zip [0 ..] xs
    , weakened <- weaker element
    ]

{- | The halving chunk sizes a deletion pass sweeps over: @n@, then @n \`div\` 2@,
  down to @1@; empty for a non-positive length.
-}
descending :: Int -> [Int]
descending k
  | k <= 0 = []
  | k == 1 = [1]
  | otherwise = k : descending (k `div` 2)
