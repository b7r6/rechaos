-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // core // scheduler
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   deterministic SplitMix64 scheduling, targeting, and replay checks
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | Deterministic fault scheduling, targeting, and replay checking.

The central invariant is reproducibility: the same policy, the same seed, and the
same event trace always yield the same decisions. Determinism rests on a
SplitMix64 generator ('nextSeed') advanced exactly once per event — including
events no rule targets — and on first-match targeting, where the first rule whose
'Target' 'matches' an event decides its fate. A rule fires when the generator's
draw falls below the rule's parts-per-million chance.

The replay checks ('replayDecision', 'verifyReplay') distinguish an incomplete
replay (a required event never occurred) from a changed one (an event occurred
but its fingerprint differs). This module is pure: no IO, no clock, no
randomness beyond the explicit seed, and no partial functions.
-}
module Rechaos.Core.Scheduler (
  step,
  schedule,
  nextSeed,
  matches,
  replayDecision,
  validateTimeline,
  dribbleMicros,
  verifyReplay,
) where

import Data.Bits (shiftR, xor)
import Data.List (mapAccumL)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word64)
import Numeric.Natural (Natural)
import Rechaos.Core.Types

-- SplitMix64: fixed constants and Word64 wraparound, portable to Lean UInt64.
-- Advance exactly once per event, including events with no applicable rule.

{- | One SplitMix64 step: the determinism keystone. Given the current state it
  returns @(nextState, output)@. The fixed golden-ratio and mixing constants
  and the reliance on 'Word64' wraparound arithmetic are deliberate so the
  generator is portable bit-for-bit to Lean's @UInt64@. Advanced exactly once
  per event, so decisions depend only on event position, not on which rules
  matched.
-}
nextSeed :: Word64 -> (Word64, Word64)
nextSeed s = (s', z2 `xor` (z2 `shiftR` 31))
 where
  s' = s + 0x9e3779b97f4a7c15
  z1 = (s' `xor` (s' `shiftR` 30)) * 0xbf58476d1ce4e5b9
  z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb

{- | Whether a 'Target' selects an 'Event'. All constraints must hold (logical
  AND); absent optional fields match anything. Numeric bounds are inclusive,
  and a present blob bound never matches an event that carries no blob. Used
  under first-match semantics: the first rule whose target matches wins.
-}
matches :: Target -> Event -> Bool
matches t e =
  tMethod t == eMethod e
    && tDirection t == eDirection e
    && maybe True (== eOccurrence e) (tOccurrence t)
    && maybe True (== eMessageIndex e) (tMessageIndex t)
    && maybe True (\lo -> maybe False (>= lo) (eBlobBytes e)) (tMinBlobBytes t)
    && maybe True (\hi -> maybe False (<= hi) (eBlobBytes e)) (tMaxBlobBytes t)
    && maybe True (<= eElapsedMicros e) (tAfterMicros t)
    && maybe True (>= eElapsedMicros e) (tBeforeMicros t)

{- | Make one scheduling decision. Advances the seed exactly once (via 'nextSeed')
  and then, using first-match targeting, injects the first matching rule's
  fault when the draw modulo one million is below that rule's 'chancePpm'. The
  seed advances whether or not any rule matched, keeping the stream aligned to
  event position.
-}
step :: [Rule] -> Word64 -> Event -> (Word64, Decision)
step rs s e = (s', Decision e (choose rs))
 where
  (s', draw) = nextSeed s
  choose [] = Nothing
  choose (r : rest)
    | matches (target r) e =
        if fromIntegral (draw `mod` 1000000) < chancePpm r
          then Just (fault r)
          else Nothing
    | otherwise = choose rest

{- | Run the scheduler over a whole event trace, threading the seed left to right
  from the policy's initial 'seed'. Same policy + seed + event trace always
  produces the same 'Timeline'.
-}
schedule :: Policy -> [Event] -> Timeline
schedule p = snd . mapAccumL (step (rules p)) (seed p)

{- | Index a timeline by 'EventKey', failing if any event identity repeats. A
  well-formed timeline has at most one decision per event.
-}
validateTimeline :: Timeline -> Either Text (M.Map EventKey Decision)
validateTimeline = go M.empty
 where
  go acc [] = Right acc
  go acc (d : ds)
    | M.member k acc = Left (T.pack "duplicate event identity in timeline")
    | otherwise = go (M.insert k d acc) ds
   where
    k = eventKey (event d)

-- Full recordings fail closed on unexpected or changed messages. Sparse fault
-- timelines permit unlisted traffic, but still check every targeted fingerprint.

{- | Look up the decision for a live event against a recorded timeline. The
  @sparse@ flag selects the semantics: a full recording (@False@) fails closed
  on any event missing from the timeline, whereas a sparse fault timeline
  (@True@) passes unlisted traffic through with no injection. Either way, an
  event present in the timeline must still match its recorded fingerprint
  (via 'sameEvent'), or replay fails.
-}
replayDecision :: Bool -> M.Map EventKey Decision -> Event -> Either Text Decision
replayDecision sparse timeline e = case M.lookup (eventKey e) timeline of
  Nothing
    | sparse -> Right (Decision e Nothing)
    | otherwise -> Left (T.pack "event missing from replay timeline")
  Just d
    | sameEvent (event d) e -> Right (Decision e (injection d))
    | otherwise -> Left (T.pack "replay fingerprint mismatch")

-- Total even for an invalid constructor supplied by another Haskell caller.

{- | Microseconds needed to deliver @bytes@ at @rate@ bytes per second. Rounds up
  (ceiling division) so the computed duration never under-delivers the
  requested bytes. A zero rate is rejected with 'Nothing', keeping the function
  total even for an invalid 'Dribble' supplied by another Haskell caller.
-}
dribbleMicros :: Natural -> Natural -> Maybe Natural
dribbleMicros 0 _ = Nothing
dribbleMicros rate bytes = Just ((bytes * 1000000 + rate - 1) `div` rate)

-- A replay run is not complete merely because none of its observed events
-- mismatched: every required event must also have occurred.

{- | Check an observed timeline against an expected one. Succeeds only when every
  expected event occurred (incomplete replays fail) with a matching fingerprint
  and identical injection (changed replays fail). A replay is not complete
  merely because none of its observed events mismatched: every required event
  must also have happened.
-}
verifyReplay :: Timeline -> Timeline -> Either Text ()
verifyReplay expected observed = do
  wanted <- validateTimeline expected
  actual <- validateTimeline observed
  mapM_ (check actual) (M.elems wanted)
 where
  check actual d = case M.lookup (eventKey (event d)) actual of
    Just found | sameEvent (event d) (event found) && injection d == injection found -> Right ()
    _ -> Left (T.pack "replay incomplete or changed: " <> T.pack (show (eventKey (event d))))
