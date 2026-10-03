-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                    // rechaos // test // core
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   pure-core property and unit tests
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (decode, eitherDecode, encode)
import qualified Data.ByteString.Lazy as L
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Data.Word (Word64)
import Numeric.Natural (Natural)
import qualified Rechaos.Core.Minimize as Min
import qualified Rechaos.Core.Oracle as O
import Rechaos.Core.Scheduler
import Rechaos.Core.Types
import Rechaos.Shell.Json ()
import System.Exit (exitFailure)
import Test.QuickCheck

method :: T.Text
method = "google.bytestream.ByteStream/Read"
targetAll :: Target
targetAll = Target method Response Nothing Nothing Nothing Nothing Nothing Nothing
eventAt :: Natural -> Event
eventAt n = Event method n Response 1 (Just 100) 500 100 "abc"
policy :: Word64 -> Policy
policy s = Policy s [Rule targetAll 500000 (Delay 100)]

check :: (Testable p) => String -> p -> IO ()
check name prop = do
  putStrLn name
  result <- quickCheckWithResult stdArgs{maxSuccess = 500} prop
  unless (isSuccess result) exitFailure

main :: IO ()
main = do
  check "SplitMix64 published zero-seed vector" $ snd (nextSeed 0) == 0xe220a8397b1dcdaf
  check "scheduler agrees with incremental execution across trace splits" $ \s (NonNegative count) ->
    let es = map (eventAt . fromIntegral) [1 .. (count `mod` 100 + 1 :: Int)]
        (a, b) = splitAt (count `mod` 30) es
        advance (seed0, ds) e = let (seed1, d) = step (rules (policy s)) seed0 e in (seed1, ds ++ [d])
        (next, da) = foldl advance (s, []) a
        (_, db) = foldl advance (next, []) b
     in schedule (policy s) es == da ++ db
  check "random choices vary across seeds" $
    let es = map eventAt [1 .. 64]
     in schedule (policy 1) es /= schedule (policy 2) es
  check "probability endpoints" $ \s ->
    injection (snd (step [Rule targetAll 0 (Delay 1)] s (eventAt 1))) == Nothing
      && injection (snd (step [Rule targetAll 1000000 (Delay 1)] s (eventAt 1))) == Just (Delay 1)
  check "unknown blob size never satisfies a size predicate" $
    not (matches (targetAll{tMinBlobBytes = Just 0}) ((eventAt 1){eBlobBytes = Nothing}))
  check "first matching rule owns probability, no accidental fallthrough" $ \s ->
    injection
      (snd (step [Rule targetAll 0 (Delay 1), Rule targetAll 1000000 (Abort Internal)] s (eventAt 1)))
      == Nothing
  check "timeline JSON round trip" $ \s ->
    let ds = schedule (policy s) (map eventAt [1 .. 20])
     in decode (encode ds) == Just ds
  check "replay tolerates arrival-time variation and rejects changed content" $ \s ->
    let ds = schedule (policy s) [eventAt 1]
     in case validateTimeline ds of
          Left _ -> False
          Right table ->
            isRight (replayDecision False table ((eventAt 1){eElapsedMicros = 9}))
              && not (isRight (replayDecision False table ((eventAt 1){ePayloadHash = "changed"})))
              && not (isRight (replayDecision False table (eventAt 2)))
  check "duplicate timeline identities rejected" $
    not
      (isRight (validateTimeline [Decision (eventAt 1) Nothing, Decision (eventAt 1) (Just (Delay 1))]))
  check "replay coverage rejects a missing tail even without observed mismatches" $
    let ds = [Decision (eventAt 1) Nothing, Decision (eventAt 2) (Just (Delay 1))]
     in isRight (verifyReplay ds ds) && not (isRight (verifyReplay ds (take 1 ds)))
  check "dribble zero rate is total; rounding never exceeds requested rate" $ \(Positive r) (NonNegative b) ->
    let rate = fromIntegral (r :: Int); bytes = fromIntegral (b :: Int)
     in dribbleMicros 0 bytes == Nothing
          && maybe False (\us -> us * rate >= bytes * 1000000) (dribbleMicros rate bytes)
  check "oracle equivalence is reflexive and symmetric" $ \(ns :: [Int]) (ms :: [Int]) ->
    let a = tree ns; b = tree ms
     in O.equivalent a a && O.equivalent a b == O.equivalent b a
  check "oracle detects paths, executable bits, empty directories and symlink targets" $
    all
      (not . O.equivalent (M.singleton "a" (O.File "hash" 1 False)))
      [ M.empty
      , M.singleton "b" (O.File "hash" 1 False)
      , M.singleton "a" (O.File "hash" 1 True)
      , M.singleton "a" O.Directory
      , M.singleton "a" (O.Symlink "x")
      ]
  check "unsuccessful builds are never correctness findings" $
    O.compareBuilds (O.BuildFailed "1") (O.Built M.empty) == O.Inconclusive
      && O.compareBuilds O.BuildTimedOut O.BuildTimedOut == O.Inconclusive
  check "minimizer only accepts confirmed reproductions" $ \(NonNegative n) ->
    let s = Min.start [Decision (eventAt 1) (Just (Delay (fromIntegral (n :: Int))))]
     in Min.best (Min.observe Min.Unknown s) == Min.best s
          && Min.best (Min.observe Min.DoesNotTrigger s) == Min.best s
  check "minimizer removes irrelevant faults and shrinks to the failing threshold" $
    let ds = [Decision (eventAt n) (Just (Delay 128)) | n <- [1 .. 4]]
        triggers =
          any (\d -> eOccurrence (event d) == 3 && case injection d of Just (Delay n) -> n >= 4; _ -> False)
        result = minimize triggers 200 (Min.start ds)
     in triggers result && length result == 1 && all (not . triggers) (Min.candidates result)
  check "negative values, zero dribble rate and unsupported fault targets rejected" $
    all
      (not . isRight . (eitherDecode :: L.ByteString -> Either String Policy))
      [ "{\"version\":1,\"seed\":0,\"rules\":[{\"target\":{\"method\":\"google.bytestream.ByteStream/Read\",\"direction\":\"response\"},\"fault\":{\"kind\":\"delay\",\"micros\":-1}}]}"
      , "{\"version\":1,\"seed\":0,\"rules\":[{\"target\":{\"method\":\"google.bytestream.ByteStream/Read\",\"direction\":\"response\"},\"fault\":{\"kind\":\"dribble\",\"bytesPerSecond\":0,\"chunkBytes\":1}}]}"
      , "{\"version\":1,\"seed\":0,\"rules\":[{\"target\":{\"method\":\"unknown\",\"direction\":\"response\"},\"fault\":{\"kind\":\"delay\",\"micros\":1}}]}"
      ]
 where
  isRight (Right _) = True
  isRight _ = False
  tree ns =
    M.fromList [(T.pack (show i), O.File (T.pack (show n)) 1 False) | (i, n) <- zip [(0 :: Int) ..] ns]
  minimize :: (Timeline -> Bool) -> Int -> Min.ShrinkState -> Timeline
  minimize _ 0 state = Min.best state
  minimize predicate fuel state = case Min.candidate state of
    Nothing -> Min.best state
    Just ds ->
      minimize
        predicate
        (fuel - 1)
        (Min.observe (if predicate ds then Min.Triggers else Min.DoesNotTrigger) state)
