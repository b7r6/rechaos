-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // core // scheduler
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   deterministic SplitMix64 scheduling, targeting, and replay checks
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
nextSeed :: Word64 -> (Word64, Word64)
nextSeed s = (s', z2 `xor` (z2 `shiftR` 31))
 where
  s' = s + 0x9e3779b97f4a7c15
  z1 = (s' `xor` (s' `shiftR` 30)) * 0xbf58476d1ce4e5b9
  z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb

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

schedule :: Policy -> [Event] -> Timeline
schedule p = snd . mapAccumL (step (rules p)) (seed p)

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
replayDecision :: Bool -> M.Map EventKey Decision -> Event -> Either Text Decision
replayDecision sparse timeline e = case M.lookup (eventKey e) timeline of
  Nothing
    | sparse -> Right (Decision e Nothing)
    | otherwise -> Left (T.pack "event missing from replay timeline")
  Just d
    | sameEvent (event d) e -> Right (Decision e (injection d))
    | otherwise -> Left (T.pack "replay fingerprint mismatch")

-- Total even for an invalid constructor supplied by another Haskell caller.
dribbleMicros :: Natural -> Natural -> Maybe Natural
dribbleMicros 0 _ = Nothing
dribbleMicros rate bytes = Just ((bytes * 1000000 + rate - 1) `div` rate)

-- A replay run is not complete merely because none of its observed events
-- mismatched: every required event must also have occurred.
verifyReplay :: Timeline -> Timeline -> Either Text ()
verifyReplay expected observed = do
  wanted <- validateTimeline expected
  actual <- validateTimeline observed
  mapM_ (check actual) (M.elems wanted)
 where
  check actual d = case M.lookup (eventKey (event d)) actual of
    Just found | sameEvent (event d) (event found) && injection d == injection found -> Right ()
    _ -> Left (T.pack "replay incomplete or changed: " <> T.pack (show (eventKey (event d))))
