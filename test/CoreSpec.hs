-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                    // rechaos // test // core
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   pure-core property and unit tests
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (decode, eitherDecode, encode)
import Data.ByteString.Lazy qualified as L
import Data.ByteString.Lazy.Char8 qualified as LC
import Data.List (sort)
import Data.Map.Strict qualified as M
import Data.Text qualified as T
import Data.Word (Word64)
import Numeric.Natural (Natural)
import Rechaos.Core.Minimize qualified as Min
import Rechaos.Core.Oracle qualified as O
import Rechaos.Core.Scheduler
import Rechaos.Core.Types
import Rechaos.Shell.Json ()
import System.Environment (lookupEnv)
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

-- | A Natural drawn from the nonnegative Int range, for JSON round-trip generators.
natural :: Gen Natural
natural = fromIntegral . getNonNegative <$> (arbitrary :: Gen (NonNegative Int))

-- The full fault-eligible method surface, mirrored from Rechaos.Shell.Json's
-- supportedMethods so generated Policies round-trip through validFault.
supportedMethods :: [T.Text]
supportedMethods =
  [ "google.bytestream.ByteStream/Read"
  , "google.bytestream.ByteStream/Write"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchUpdateBlobs"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchReadBlobs"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/GetTree"
  , "build.bazel.remote.execution.v2.ActionCache/GetActionResult"
  , "build.bazel.remote.execution.v2.ActionCache/UpdateActionResult"
  , "build.bazel.remote.execution.v2.Capabilities/GetCapabilities"
  ]

-- | A stream-payload target (Read response or Write request) that Truncate accepts.
streamPayloadTarget :: Gen (T.Text, Direction)
streamPayloadTarget =
  elements
    [ ("google.bytestream.ByteStream/Read", Response)
    , ("google.bytestream.ByteStream/Write", Request)
    ]

instance Arbitrary Direction where
  arbitrary = elements [Request, Response]

instance Arbitrary Status where
  arbitrary = arbitraryBoundedEnum

-- Only JSON-valid faults are generated so validPolicy/validFault accept the Rule.
instance Arbitrary Fault where
  arbitrary =
    oneof
      [ Delay <$> natural
      , Abort <$> arbitrary
      , Dribble
          <$> (fromIntegral . getPositive <$> (arbitrary :: Gen (Positive Int)))
          <*> (fromIntegral <$> chooseInt (1, 4194304))
      , Truncate <$> natural
      ]

-- A fault paired with a target method/direction on which validFault accepts it.
-- Truncate is only emitted against a stream-payload target.
arbitraryFaultAndTarget :: Gen (Fault, T.Text, Direction)
arbitraryFaultAndTarget =
  oneof
    [ do
        f <- oneof [Delay <$> natural, Abort <$> arbitrary, dribbleGen]
        m <- elements supportedMethods
        d <- arbitrary
        pure (f, m, d)
    , do
        keep <- natural
        (m, d) <- streamPayloadTarget
        pure (Truncate keep, m, d)
    ]
 where
  dribbleGen =
    Dribble
      <$> (fromIntegral . getPositive <$> (arbitrary :: Gen (Positive Int)))
      <*> (fromIntegral <$> chooseInt (1, 4194304))

-- | A Target carrying the given method and direction with JSON-valid optional fields.
arbitraryTargetFor :: T.Text -> Direction -> Gen Target
arbitraryTargetFor m d = do
  occ <- positiveMaybe
  mi <- positiveMaybe
  (lo, hi) <- orderedMaybe
  (af, bf) <- orderedMaybe
  pure (Target m d occ mi lo hi af bf)
 where
  positiveMaybe =
    oneof [pure Nothing, Just . fromIntegral . getPositive <$> (arbitrary :: Gen (Positive Int))]
  orderedMaybe =
    oneof
      [ pure (Nothing, Nothing)
      , do a <- natural; pure (Just a, Nothing)
      , do b <- natural; pure (Nothing, Just b)
      , do a <- natural; c <- natural; pure (Just (min a c), Just (max a c))
      ]

instance Arbitrary Target where
  arbitrary = do
    m <- elements supportedMethods
    d <- arbitrary
    arbitraryTargetFor m d

-- A rule whose fault and target are jointly generated to satisfy validFault.
instance Arbitrary Rule where
  arbitrary = do
    (f, m, d) <- arbitraryFaultAndTarget
    t <- arbitraryTargetFor m d
    ppm <- fromIntegral <$> chooseInt (0, 1000000)
    pure (Rule t ppm f)

instance Arbitrary Policy where
  arbitrary = Policy <$> (fromIntegral <$> chooseInt (0, maxBound)) <*> listOf arbitrary

-- Oracle entries exercising all three constructors, with varying size and exec bit.
instance Arbitrary O.Entry where
  arbitrary =
    oneof
      [ O.File
          <$> (T.pack . show <$> chooseInt (0, 4))
          <*> natural
          <*> arbitrary
      , pure O.Directory
      , O.Symlink . T.pack . show <$> chooseInt (0, 4)
      ]

-- | A build-output tree over a small key space, exercising every 'O.Entry' kind.
richTree :: Gen O.Tree
richTree = do
  keys <- sublistOf (map (T.pack . show) [0 .. 5 :: Int])
  entries <- vectorOf (length keys) arbitrary
  pure (M.fromList (zip keys entries))

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
  -- (A) matches coverage ------------------------------------------------------
  check "a self-valued target still matches and any one-off predicate kills it" $ \(NonNegative n) ->
    let e = eventAt (fromIntegral (n :: Int))
        selfTarget =
          targetAll
            { tOccurrence = Just (eOccurrence e)
            , tMessageIndex = Just (eMessageIndex e)
            , tMinBlobBytes = eBlobBytes e
            , tMaxBlobBytes = eBlobBytes e
            , tAfterMicros = Just (eElapsedMicros e)
            , tBeforeMicros = Just (eElapsedMicros e)
            }
        kills =
          [ selfTarget{tOccurrence = Just (eOccurrence e + 1)}
          , selfTarget{tMessageIndex = Just (eMessageIndex e + 1)}
          , selfTarget{tMinBlobBytes = Just (maybe 1 (+ 1) (eBlobBytes e))}
          , selfTarget{tMaxBlobBytes = Just 0}
          , selfTarget{tAfterMicros = Just (eElapsedMicros e + 1)}
          , selfTarget{tBeforeMicros = if eElapsedMicros e == 0 then Just 0 else Just (eElapsedMicros e - 1)}
          ]
     in matches selfTarget e
          && all (\t -> not (matches t e)) kills
  check "after and before micros are both inclusive at the elapsed boundary" $ \(NonNegative n) (NonNegative k) ->
    let e = (eventAt (fromIntegral (n :: Int))){eElapsedMicros = fromIntegral (k :: Int)}
     in matches (targetAll{tAfterMicros = Just (eElapsedMicros e)}) e
          && matches (targetAll{tBeforeMicros = Just (eElapsedMicros e)}) e
  check "an upper blob bound never matches an unknown blob size" $ \(NonNegative hi) ->
    not
      ( matches
          (targetAll{tMaxBlobBytes = Just (fromIntegral (hi :: Int))})
          ((eventAt 1){eBlobBytes = Nothing})
      )
  check "occurrence and message-index predicates gate exactly" $ \(Positive occ) (Positive mi) ->
    let e = (eventAt (fromIntegral (occ :: Int))){eMessageIndex = fromIntegral (mi :: Int)}
     in matches (targetAll{tOccurrence = Just (eOccurrence e)}) e
          && not (matches (targetAll{tOccurrence = Just (eOccurrence e + 1)}) e)
          && matches (targetAll{tMessageIndex = Just (eMessageIndex e)}) e
          && not (matches (targetAll{tMessageIndex = Just (eMessageIndex e + 1)}) e)
  check "an all-Nothing target matches on method and direction alone" $ \(NonNegative n) ->
    matches targetAll (eventAt (fromIntegral (n :: Int)))
      && not (matches targetAll{tMethod = "other"} (eventAt (fromIntegral (n :: Int))))
      && not (matches targetAll{tDirection = Request} (eventAt (fromIntegral (n :: Int))))
  -- (B) minimizer -------------------------------------------------------------
  check "every generated candidate is strictly smaller under the termination measure" $ \(fs :: [Int]) ->
    let xs = faultTimeline fs
        m = measure xs
     in all (\c -> measure c < m) (Min.candidates xs)
  check "Unknown and DoesNotTrigger are observationally identical on multi-element lists" $ \(fs :: [Int]) ->
    let xs = faultTimeline (0 : 1 : 2 : fs)
        s = Min.start xs
     in Min.observe Min.Unknown s == Min.observe Min.DoesNotTrigger s
  check "Truncate minimization shrinks toward the failing threshold" $
    let ds = [Decision (eventAt 1) (Just (Truncate 0))]
        triggers = any (\d -> case injection d of Just (Truncate keep) -> keep < 60; _ -> False)
        result = minimize triggers 200 (Min.start ds)
     in triggers result && all (not . triggers) (Min.candidates result)
  check "Dribble minimization shrinks toward the failing threshold" $
    let ds = [Decision (eventAt 1) (Just (Dribble 1 16))]
        triggers = any (\d -> case injection d of Just (Dribble rate _) -> rate < 1000; _ -> False)
        result = minimize triggers 200 (Min.start ds)
     in triggers result && all (not . triggers) (Min.candidates result)
  check "candidate generation produces no intensity variant at the Truncate and Dribble caps" $
    let e = eventAt 1
        atCapTrunc = [Decision e (Just (Truncate (eMessageBytes e)))]
        atCapDrib = [Decision e (Just (Dribble (eMessageBytes e * 1000000) 16))]
        noSameLength base = all ((< length base) . length) (Min.candidates base)
     in noSameLength atCapTrunc && noSameLength atCapDrib
  check "a capped two-element timeline yields only deletions, never a weaker fault" $
    let e1 = eventAt 1
        e2 = eventAt 2
        capped =
          [ Decision e1 (Just (Truncate (eMessageBytes e1)))
          , Decision e2 (Just (Dribble (eMessageBytes e2 * 1000000) 16))
          ]
     in all ((< length capped) . length) (Min.candidates capped)
  -- (C) ppm statistics --------------------------------------------------------
  check "empirical injection frequency tracks chancePpm within tolerance" $
    all withinBand [250000, 500000, 750000]
  -- (D) SplitMix64 ------------------------------------------------------------
  check "SplitMix64 published nonzero-seed vector" $
    snd (nextSeed 0x9e3779b97f4a7c15) == 0x6e789e6aa1b965f4
  check "state advance is exactly the golden-ratio increment, independent of output" $ \s ->
    fst (nextSeed s) == s + 0x9e3779b97f4a7c15
  check "nextSeed is referentially transparent" $ \s ->
    nextSeed s == nextSeed s
  check "the advance step is injective over a sampled seed range" $ \s ->
    let seeds = [s + fromIntegral i | i <- [0 .. 255 :: Int]]
        advanced = map (fst . nextSeed) seeds
     in length (nubWord advanced) == length advanced
  -- (E) replay ----------------------------------------------------------------
  check "sparse replay admits a missing event but still checks present fingerprints" $ \s ->
    let ds = schedule (policy s) [eventAt 1]
     in case validateTimeline ds of
          Left _ -> False
          Right table ->
            replayDecision True table (eventAt 2) == Right (Decision (eventAt 2) Nothing)
              && not (isRight (replayDecision True table ((eventAt 1){ePayloadHash = "changed"})))
              && isRight (replayDecision True table ((eventAt 1){eElapsedMicros = 9}))
  check "perturbing any non-elapsed field makes sameEvent false" $ \(NonNegative n) ->
    let e = eventAt (fromIntegral (n :: Int))
        perturbed =
          [ e{eMethod = eMethod e <> "x"}
          , e{eOccurrence = eOccurrence e + 1}
          , e{eDirection = if eDirection e == Response then Request else Response}
          , e{eMessageIndex = eMessageIndex e + 1}
          , e{eBlobBytes = Just (maybe 0 (+ 1) (eBlobBytes e))}
          , e{eMessageBytes = eMessageBytes e + 1}
          , e{ePayloadHash = ePayloadHash e <> "x"}
          ]
     in sameEvent e e
          && sameEvent e e{eElapsedMicros = eElapsedMicros e + 1}
          && all (not . sameEvent e) perturbed
  -- (F) oracle ----------------------------------------------------------------
  check "compareBuilds reports Diverged with the underlying changes" $ \(ns :: [Int]) (ms :: [Int]) ->
    let a = tree ns; b = tree ms
     in case O.compareBuilds (O.Built a) (O.Built b) of
          O.Diverged changes -> changes == O.diff a b && not (null changes)
          O.Equivalent -> O.diff a b == []
          O.Inconclusive -> False
  check "diff is empty iff equivalent iff structurally equal" $ \(ns :: [Int]) (ms :: [Int]) ->
    let a = tree ns; b = tree ms
     in (O.diff a b == []) == O.equivalent a b
          && O.equivalent a b == (a == b)
  check "diff reports each key once in ascending order" $ \(ns :: [Int]) (ms :: [Int]) ->
    let a = tree ns
        b = tree ms
        keys = [k | O.Change k _ _ <- O.diff a b]
     in keys == sort keys && nubText keys == keys
  check "oracle equivalence is transitive" $ \(ns :: [Int]) (ms :: [Int]) (ks :: [Int]) ->
    let a = tree ns; b = tree ms; c = tree ks
     in not (O.equivalent a b && O.equivalent b c) || O.equivalent a c
  -- (G) seed-advance invariant ------------------------------------------------
  check "folding step advances the seed exactly once per event, whatever matched" $ \s (NonNegative count) ->
    let n = count `mod` 100 :: Int
        es = map (eventAt . fromIntegral) [1 .. n]
        advance (seed0, ds) e = let (seed1, d) = step (rules (policy s)) seed0 e in (seed1, ds ++ [d])
        (final, _) = foldl advance (s, []) es
     in final == iterate (fst . nextSeed) s !! n
  check "a nonmatching or absent rule advances the seed identically to a match" $ \s ->
    fst (step [] s (eventAt 1)) == fst (nextSeed s)
      && fst (step [Rule targetAll{tMethod = "nomatch"} 1000000 (Delay 1)] s (eventAt 1))
        == fst (nextSeed s)
  -- (H) full policy JSON round trip -------------------------------------------
  check "a fully valid policy round trips through JSON" $ \(p :: Policy) ->
    decode (encode p) == Just p
  check "a single-rule policy exercising every fault path round trips through JSON" $ \(r :: Rule) ->
    let p = Policy 42 [r]
     in decode (encode p) == Just p
  -- (I) abort coverage --------------------------------------------------------
  check "an abort-only timeline yields only deletions, never a weaker fault" $ \(Positive k) ->
    let ds = [Decision (eventAt (fromIntegral (n :: Int))) (Just (Abort Internal)) | n <- [1 .. k]]
     in all ((< length ds) . length) (Min.candidates (Min.best (Min.start ds)))
  check "an abort rule round trips through JSON for every status" $
    all
      (\st -> let p = Policy 0 [Rule targetAll 1000 (Abort st)] in decode (encode p) == Just p)
      [minBound .. maxBound]
  -- (J) richer oracle algebra -------------------------------------------------
  check "oracle equivalence is reflexive and symmetric over all entry kinds" $
    forAll richTree $ \a -> forAll richTree $ \b ->
      O.equivalent a a && O.equivalent a b == O.equivalent b a
  check "compareBuilds reports Diverged with the underlying changes over all entry kinds" $
    forAll richTree $ \a -> forAll richTree $ \b ->
      case O.compareBuilds (O.Built a) (O.Built b) of
        O.Diverged changes -> changes == O.diff a b && not (null changes)
        O.Equivalent -> O.diff a b == []
        O.Inconclusive -> False
  check "oracle equivalence is transitive over all entry kinds" $
    forAll richTree $ \a -> forAll richTree $ \b -> forAll richTree $ \c ->
      not (O.equivalent a b && O.equivalent b c) || O.equivalent a c
  check "an exec-bit-only change is reported as a change" $
    O.diff
      (M.singleton "a" (O.File "h" 1 False))
      (M.singleton "a" (O.File "h" 1 True))
      == [O.Change "a" (Just (O.File "h" 1 False)) (Just (O.File "h" 1 True))]
  check "a symlink-target-only change is reported as a change" $
    O.diff
      (M.singleton "a" (O.Symlink "x"))
      (M.singleton "a" (O.Symlink "y"))
      == [O.Change "a" (Just (O.Symlink "x")) (Just (O.Symlink "y"))]
  -- (K) replay mismatch and dribble minimality --------------------------------
  check "replay fails when the observed event carries a different injected fault" $
    let ds = [Decision (eventAt 1) (Just (Delay 1))]
        observed = [Decision (eventAt 1) (Just (Delay 2))]
     in not (isRight (verifyReplay ds observed))
  check "dribble micros are ceiling-minimal: one microsecond less under-delivers" $ \(Positive r) (Positive b) ->
    let rate = fromIntegral (r :: Int); bytes = fromIntegral (b :: Int)
     in maybe False (\us -> us == 0 || (us - 1) * rate < bytes * 1000000) (dribbleMicros rate bytes)
  -- (L) golden snapshots ------------------------------------------------------
  goldenSnapshots
 where
  goldenSnapshots :: IO ()
  goldenSnapshots = do
    regen <- lookupEnv "RECHAOS_REGEN_GOLDEN"
    let scheduleBytes = LC.unlines (map encode (schedule (policy 1) (map eventAt [1 .. 5])))
        faultBytes = encode goldenFaultRules
    case regen of
      Just _ -> do
        L.writeFile "test/golden/schedule.jsonl" scheduleBytes
        L.writeFile "test/golden/faults.json" faultBytes
        putStrLn "golden snapshots regenerated"
      Nothing -> do
        putStrLn "golden schedule snapshot matches committed bytes"
        onDiskSchedule <- L.readFile "test/golden/schedule.jsonl"
        unless (onDiskSchedule == scheduleBytes) exitFailure
        putStrLn "golden faults snapshot matches committed bytes"
        onDiskFaults <- L.readFile "test/golden/faults.json"
        unless (onDiskFaults == faultBytes) exitFailure
  -- One representative Rule per Fault constructor, plus an Abort carrying a Status.
  goldenFaultRules :: [Rule]
  goldenFaultRules =
    [ Rule targetAll 500000 (Delay 100)
    , Rule targetAll 250000 (Abort Internal)
    , Rule targetAll 100000 (Dribble 1024 16)
    , Rule targetAll 750000 (Truncate 64)
    ]
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
  -- A timeline whose faults all have weaker variants, exercising intensity shrinking.
  faultTimeline :: [Int] -> Timeline
  faultTimeline fs =
    [ Decision (eventAt (fromIntegral i)) (Just (faultFrom x))
    | (i, x) <- zip [1 :: Int ..] fs
    ]
  faultFrom :: Int -> Fault
  faultFrom x = case (abs x `mod` 3, fromIntegral (abs x `mod` 90) :: Natural) of
    (0, n) -> Delay n
    (1, n) -> Truncate n
    (_, n) -> Dribble (n + 1) 16
  -- Termination measure: length first, then summed severity. Every weaker variant
  -- lowers severity, so Min.candidates must be strictly smaller in this order.
  measure :: Timeline -> (Int, Natural)
  measure xs = (length xs, sum [severity (event d) f | d <- xs, Just f <- [injection d]])
  severity :: Event -> Fault -> Natural
  severity _ (Delay n) = n
  severity _ (Abort _) = 0
  severity e (Truncate keep) = eMessageBytes e - min (eMessageBytes e) keep
  severity e (Dribble rate _) =
    let cap = max 1 (eMessageBytes e * 1000000) in cap - min cap rate
  -- (C) deterministic ppm band: the observed fire fraction over a fixed stream.
  withinBand :: Natural -> Bool
  withinBand rate =
    let total = 20000 :: Int
        p = Policy 12345 [Rule targetAll rate (Delay 1)]
        fired = length [() | d <- schedule p (map (eventAt . fromIntegral) [1 .. total]), injection d /= Nothing]
        observed = fromIntegral fired / fromIntegral total :: Double
        expected = fromIntegral rate / 1000000 :: Double
     in abs (observed - expected) <= 0.03
  nubWord :: [Word64] -> [Word64]
  nubWord = go []
   where
    go seen [] = reverse seen
    go seen (x : xs)
      | x `elem` seen = go seen xs
      | otherwise = go (x : seen) xs
  nubText :: [T.Text] -> [T.Text]
  nubText = go []
   where
    go seen [] = reverse seen
    go seen (x : xs)
      | x `elem` seen = go seen xs
      | otherwise = go (x : seen) xs
