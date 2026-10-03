-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                // rechaos // shell // runtime
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   monotonic observation, occurrence allocation, and journal writes
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

module Rechaos.Shell.Runtime (Runtime, newRuntime, beginCall, decide, logOutcome, remainingReplay, sleepMicros) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy.Char8 as L
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word64)
import GHC.Clock (getMonotonicTimeNSec)
import Numeric.Natural (Natural)
import Rechaos.Core.Scheduler
import Rechaos.Core.Types
import Rechaos.Shell.Json ()
import Rechaos.Shell.Protocol (messageSize, sha256)
import System.IO

data RuntimeState = RuntimeState Word64 (M.Map Text Natural) (S.Set EventKey)
data Runtime
  = Runtime
      Policy
      (Maybe (Bool, M.Map EventKey Decision))
      (MVar RuntimeState)
      Handle
      Handle

newRuntime :: Policy -> Maybe (Bool, Timeline) -> Handle -> Handle -> IO Runtime
newRuntime p replay journal outcomes = do
  table <- traverse (\(s, ds) -> either (fail . T.unpack) (pure . (,) s) (validateTimeline ds)) replay
  state <- newMVar (RuntimeState (seed p) M.empty S.empty)
  hSetBuffering journal LineBuffering
  hSetBuffering outcomes LineBuffering
  pure (Runtime p table state journal outcomes)

beginCall :: Runtime -> Text -> IO (Natural, Word64)
beginCall (Runtime _ _ state _ _) method = do
  n <- modifyMVar state $ \(RuntimeState s calls seen) -> do
    let n = M.findWithDefault 0 method calls + 1
    pure (RuntimeState s (M.insert method n calls) seen, n)
  now <- getMonotonicTimeNSec
  pure (n, now)

decide ::
  Runtime ->
  Text ->
  Natural ->
  Word64 ->
  Direction ->
  Natural ->
  Maybe Natural ->
  L.ByteString ->
  IO (Either Text (Maybe Fault))
decide (Runtime p replay state journal _) method occurrence started direction index size bytes = do
  now <- getMonotonicTimeNSec
  let e =
        Event
          method
          occurrence
          direction
          index
          size
          (fromIntegral ((now - started) `div` 1000))
          (messageSize method direction bytes)
          (sha256 bytes)
  modifyMVar state $ \old@(RuntimeState s calls seen) -> do
    let (s', d) = step (rules p) s e
        chosen = case replay of
          Nothing -> Right d
          Just (sparse, table) -> replayDecision sparse table e
    case chosen of
      Left err -> pure (old, Left (err <> ": " <> T.pack (show (eventKey e))))
      Right decision -> do
        L.hPutStrLn journal (encode decision)
        hFlush journal -- record the decision BEFORE the effect
        pure (RuntimeState s' calls (S.insert (eventKey e) seen), Right (injection decision))

logOutcome :: Runtime -> Text -> Natural -> Word64 -> Text -> IO ()
logOutcome (Runtime _ _ state _ out) method occurrence started result = do
  now <- getMonotonicTimeNSec
  withMVar state $ \_ ->
    L.hPutStrLn
      out
      ( encode
          ( object
              [ "method" .= method
              , "occurrence" .= occurrence
              , "result" .= result
              , "elapsedMicros" .= ((now - started) `div` 1000)
              ]
          )
      )

remainingReplay :: Runtime -> IO [EventKey]
remainingReplay (Runtime _ replay state _ _) = withMVar state $ \(RuntimeState _ _ seen) ->
  pure (case replay of Nothing -> []; Just (_, table) -> S.toList (M.keysSet table S.\\ seen))

-- Avoid Int overflow and remain interruptible even for very long policies.
sleepMicros :: Natural -> IO ()
sleepMicros 0 = pure ()
sleepMicros n = do
  let piece = min n 1000000
  threadDelay (fromIntegral piece)
  sleepMicros (n - piece)
