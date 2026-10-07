-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                // rechaos // shell // runtime
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   monotonic observation, occurrence allocation, and journal writes
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

{- | The mutable per-process state that backs the proxy: the active policy (or
replay timeline), monotonic-clock observation, per-method occurrence counters,
and the decision and outcome journals.

This module is in the IO shell. It reads the clock, allocates occurrence
indices, and writes journal lines; the actual scheduling and replay choices are
made by the pure core, which this module merely feeds observed 'Event's and
records the resulting 'Decision's.
-}
module Rechaos.Shell.Runtime (
  -- * Runtime handle
  Runtime,
  newRuntime,

  -- * Per-call lifecycle
  beginCall,
  decide,
  logOutcome,

  -- * Replay accounting
  remainingReplay,

  -- * Interruptible sleep
  sleepMicros,
) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy.Char8 qualified as L
import Data.Map.Strict qualified as M
import Data.Set qualified as S
import Data.Text (Text)
import Data.Text qualified as T
import Data.Word (Word64)
import GHC.Clock (getMonotonicTimeNSec)
import Numeric.Natural (Natural)
import Rechaos.Core.Scheduler
import Rechaos.Core.Types
import Rechaos.Shell.Json ()
import Rechaos.Shell.Protocol (messageSize, sha256)
import System.IO

data RuntimeState = RuntimeState Word64 (M.Map Text Natural) (S.Set EventKey)

{- | Opaque proxy state: policy, optional replay table, mutable counters, and the
decision and outcome journal handles. Construct one with 'newRuntime'.
-}
data Runtime
  = Runtime
      Policy
      (Maybe (Bool, M.Map EventKey Decision))
      (MVar RuntimeState)
      Handle
      Handle

{- | Build a 'Runtime' from a policy and optional replay timeline, validating the
replay table and setting both journal handles to line buffering.
-}
newRuntime :: Policy -> Maybe (Bool, Timeline) -> Handle -> Handle -> IO Runtime
newRuntime p replay journal outcomes = do
  table <- traverse (\(s, ds) -> either (fail . T.unpack) (pure . (,) s) (validateTimeline ds)) replay
  state <- newMVar (RuntimeState (seed p) M.empty S.empty)
  hSetBuffering journal LineBuffering
  hSetBuffering outcomes LineBuffering
  pure (Runtime p table state journal outcomes)

{- | Open a new call for @method@: allocate its 1-based occurrence index and take
the monotonic start time the call's events will be measured against.
-}
beginCall :: Runtime -> Text -> IO (Natural, Word64)
beginCall (Runtime _ _ state _ _) method = do
  n <- modifyMVar state $ \(RuntimeState s calls seen) -> do
    -- n.b. occurrence is 1-based: the first call to a method gets 1, not 0, so
    -- the index the core sees in an 'Event' matches the policy's 1-based rules.
    let n = M.findWithDefault 0 method calls + 1
    pure (RuntimeState s (M.insert method n calls) seen, n)
  now <- getMonotonicTimeNSec
  pure (n, now)

{- | Observe one message as an 'Event', consult the policy (or replay table) for
the fault to inject, journal the 'Decision' before any effect, and return it.
-}
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
        chosen = maybe (Right d) (\(sparse, table) -> replayDecision sparse table e) replay
    -- CASE-OK: two asymmetric effectful arms on a local Either; the Right arm
    -- journals and returns, so an `either` eliminator would not read clearer.
    case chosen of
      Left err -> pure (old, Left (err <> ": " <> T.pack (show (eventKey e))))
      Right decision -> do
        L.hPutStrLn journal (encode decision)
        hFlush journal -- record the decision BEFORE the effect
        pure (RuntimeState s' calls (S.insert (eventKey e) seen), Right (injection decision))

{- | Append a one-line outcome record for a finished call -- its method,
occurrence, result label, and elapsed microseconds -- to the outcome journal.
-}
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

{- | List replay events that were expected but never observed; empty when not
replaying or when every scheduled event was seen.
-}
remainingReplay :: Runtime -> IO [EventKey]
remainingReplay (Runtime _ replay state _ _) = withMVar state $ \(RuntimeState _ _ seen) ->
  pure (maybe [] (\(_, table) -> S.toList (M.keysSet table S.\\ seen)) replay)

{- | Sleep for the given number of microseconds in bounded chunks, avoiding 'Int'
overflow and staying interruptible even for very long delays.
-}
sleepMicros :: Natural -> IO ()
sleepMicros 0 = pure ()
sleepMicros n = do
  let piece = min n 1000000
  threadDelay (fromIntegral piece)
  sleepMicros (n - piece)
