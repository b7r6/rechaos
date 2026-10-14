-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                // rechaos // core // minimize
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   witness-preserving candidate generation and acceptance state machine
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | Witness-preserving shrinking of a failing 'Timeline' down to a small
reproducer.

This is "Rechaos.Core.Shrink" instantiated at 'Decision': the candidate
generator and acceptance state machine are shared, and this module supplies the
timeline-specific pieces, namely that only injected faults are shrunk and the
'weaker' intensity order for each 'Fault'. 'start' seeds the machine from a
failing timeline, 'candidate' offers the next timeline to try, and 'observe'
folds the shell's 'Verdict' back in, accepting a candidate only when it still
'Triggers' the failure. Because candidates include chunk deletions down to
singletons, a fully explored result is deletion-1-minimal for a deterministic
predicate: no single retained fault can be dropped without losing the failure.
Intensity shrinking follows a separate, strictly decreasing (weaker) measure.

The 'Triggers' \/ 'Unknown' distinction is load-bearing: only a reproduction of the
SAME failure signature counts as triggering; a flake, timeout, or infrastructure
error is 'Unknown' and must never be treated as a successful shrink. This module
is pure: no IO and no partial functions.
-}
module Rechaos.Core.Minimize (
  Verdict (..),
  ShrinkState (..),
  start,
  candidate,
  observe,
  candidates,
  weaker,
  weakerDecision,
) where

import Data.Maybe (isJust)
import Numeric.Natural (Natural)
import Rechaos.Core.Shrink (ShrinkState (..), Verdict (..), candidate)
import Rechaos.Core.Shrink qualified as Shrink
import Rechaos.Core.Types

{- | Seed the state machine from a failing timeline. Keeps only its injected
  faults as the initial 'best' and enqueues their 'candidates'.
-}
start :: Timeline -> ShrinkState Decision
start = Shrink.start weakerDecision . filter (isJust . injection)

{- | Fold the shell's 'Verdict' on the current candidate back into the state. On
  'Triggers' the candidate becomes the new 'best' and its own 'candidates' are
  enqueued (restarting the search from the smaller timeline); on
  'DoesNotTrigger' or 'Unknown' the candidate is discarded and the next one is
  tried. Conservative: an 'Unknown' never advances 'best'.
-}
observe :: Verdict -> ShrinkState Decision -> ShrinkState Decision
observe = Shrink.observe weakerDecision

{- | All shrink candidates derived from a timeline: chunk deletions at halving
  sizes down to singletons, plus intensity reductions that replace one injected
  fault with a strictly weaker one. Deletion down to singletons is what makes a
  converged result deletion-1-minimal for a deterministic predicate; the
  intensity candidates follow a finite, decreasing measure (see 'weaker'), and
  timing stays explicit in the retained event identity and 'Delay' value.
-}
candidates :: Timeline -> [Timeline]
candidates = Shrink.candidates weakerDecision

{- | The strictly weaker forms of one decision: the same event carrying each
  'weaker' variant of its injected fault. A passthrough decision has none.
-}
weakerDecision :: Decision -> [Decision]
weakerDecision d = [d{injection = Just f} | Just old <- [injection d], f <- weaker (event d) old]

{- | Strictly weaker variants of a fault, if any, used for intensity shrinking.
  Each step moves along a finite, decreasing measure toward the event's natural
  bound: 'Delay' halves toward zero, 'Dribble' doubles its rate toward the
  message's full-speed cap (@messageBytes * 'microsPerSecond'@, the rate that
  delivers the whole message in one microsecond), 'Truncate' raises its
  kept-byte count toward the full message size, and 'Corrupt' halves its
  corrupted-byte count toward one. 'Abort' has no weaker form.
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
weaker _ (Corrupt n) = [Corrupt (n `div` 2) | n > 1]
weaker _ (Abort _) = []
