-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                   // rechaos // core // types
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   fault algebra, policy, events, and timeline values; explicit units
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | Values at the heart of rechaos: the fault algebra, the policy that decides
when faults fire, the events the shell observes, and the timelines those
decisions form.

All quantities are expressed in explicit units and are nonnegative ('Natural' or
'Word64'); there is no implicit scaling. Validation at the shell boundary (not
here) rejects zero rates and chunk sizes and any unsupported
method\/direction\/fault combination. This module is pure: no IO, no clock, no
filesystem, no randomness, and no partial functions.
-}
module Rechaos.Core.Types (
  -- * Fault algebra
  Direction (..),
  Status (..),
  Fault (..),

  -- * Targeting and policy
  Target (..),
  Rule (..),
  Policy (..),

  -- * Events and timelines
  Event (..),
  Decision (..),
  Timeline,
  EventKey,
  eventKey,
  sameEvent,
) where

import Data.Text (Text)
import Data.Word (Word64)
import Numeric.Natural (Natural)

-- Units are explicit and nonnegative. Validation at the shell boundary rejects
-- zero rates/chunks and unsupported method/direction/fault combinations.

-- | Which half of an RPC an observation or target refers to.
data Direction
  = -- | Client-to-server message flow.
    Request
  | -- | Server-to-client message flow.
    Response
  deriving (Eq, Ord, Show)

{- | gRPC status codes that an 'Abort' fault can inject. The set is the subset of
  the standard codes rechaos knows how to synthesize.
-}
data Status
  = Cancelled
  | InvalidArgument
  | DeadlineExceeded
  | NotFound
  | ResourceExhausted
  | FailedPrecondition
  | Internal
  | Unavailable
  | DataLoss
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | The algebra of faults rechaos can inject at a matched event.
data Fault
  = -- | Delay delivery by the given number of microseconds.
    Delay Natural
  | -- | Abort the RPC with the given gRPC 'Status'.
    Abort Status
  | {- | Deliver slowly: @Dribble bytesPerSecond chunkBytes@. The first field is
    the sustained throughput in bytes per second, the second the size of
    each delivered chunk in bytes.
    -}
    Dribble Natural Natural
  | -- | Truncate the payload, keeping only the leading @keepBytes@ bytes.
    Truncate Natural
  deriving (Eq, Show)

{- | A predicate over 'Event's selecting where a 'Rule' applies. All optional
  fields default to \"any\" when absent; present fields must all hold (logical
  AND). Numeric bounds are inclusive.
-}
data Target = Target
  { tMethod :: Text
  -- ^ Fully-qualified method name; matched by exact equality.
  , tDirection :: Direction
  -- ^ Which direction the event must be on.
  , tOccurrence :: Maybe Natural
  -- ^ 1-based occurrence index of the method on this stream, if constrained.
  , tMessageIndex :: Maybe Natural
  -- ^ 1-based message index within the matched direction, if constrained.
  , tMinBlobBytes :: Maybe Natural
  {- ^ Inclusive lower bound on the event's blob size in bytes, if constrained.
  Events without a blob never satisfy a present bound.
  -}
  , tMaxBlobBytes :: Maybe Natural
  {- ^ Inclusive upper bound on the event's blob size in bytes, if constrained.
  Events without a blob never satisfy a present bound.
  -}
  , tAfterMicros :: Maybe Natural
  -- ^ Inclusive lower bound on elapsed time in microseconds, if constrained.
  , tBeforeMicros :: Maybe Natural
  -- ^ Inclusive upper bound on elapsed time in microseconds, if constrained.
  }
  deriving (Eq, Show)

{- | A policy rule: inject @fault@ at events matching @target@ with probability
  @chancePpm@ parts per million.
-}
data Rule = Rule
  { target :: Target
  -- ^ The matching predicate for this rule.
  , chancePpm :: Natural
  -- ^ Firing probability in parts per million (0..1_000_000).
  , fault :: Fault
  -- ^ The fault injected when the rule fires.
  }
  deriving (Eq, Show)

{- | A complete policy: a scheduling seed and an ordered list of rules. Rule order
  is significant; targeting uses first-match (see "Rechaos.Core.Scheduler").
-}
data Policy = Policy
  { seed :: Word64
  -- ^ Initial SplitMix64 state; advanced exactly once per event.
  , rules :: [Rule]
  -- ^ Rules in priority order; the first matching rule wins.
  }
  deriving (Eq, Show)

-- An event is an observation supplied by the shell, never a clock read.
-- Occurrences are 1-based per method; message indices are 1-based per direction.

{- | A single observation handed to the core by the shell. It is never a clock
  read taken here; every field is reported from the outside world.
-}
data Event = Event
  { eMethod :: Text
  -- ^ Fully-qualified method name.
  , eOccurrence :: Natural
  -- ^ 1-based occurrence index of this method on the stream.
  , eDirection :: Direction
  -- ^ Which direction this message is on.
  , eMessageIndex :: Natural
  -- ^ 1-based message index within the direction.
  , eBlobBytes :: Maybe Natural
  -- ^ Size of the attached blob in bytes, if any.
  , eElapsedMicros :: Natural
  {- ^ Elapsed time at observation, in microseconds. This is the one field that
  may legitimately differ between a recording and a live replay of the same
  event (see 'sameEvent').
  -}
  , eMessageBytes :: Natural
  -- ^ Size of the message payload in bytes.
  , ePayloadHash :: Text
  -- ^ Fingerprint of the payload, used to detect changed traffic.
  }
  deriving (Eq, Show)

{- | A scheduling outcome: the observed 'Event' paired with the fault to inject,
  or 'Nothing' when no rule fired.
-}
data Decision = Decision
  { event :: Event
  -- ^ The event this decision was made for.
  , injection :: Maybe Fault
  -- ^ The fault to inject, or 'Nothing' to pass the event through untouched.
  }
  deriving (Eq, Show)

-- | An ordered sequence of scheduling decisions.
type Timeline = [Decision]

{- | The identity of an event: @(method, occurrence, direction, messageIndex)@.
  Unique within a well-formed timeline.
-}
type EventKey = (Text, Natural, Direction, Natural)

{- | Project an 'Event' onto its identity 'EventKey'. Ignores payload and timing;
  two events with the same key are \"the same event\" positionally.
-}
eventKey :: Event -> EventKey
eventKey e = (eMethod e, eOccurrence e, eDirection e, eMessageIndex e)

-- Arrival time may vary during live replay. All other observations must agree.

{- | Equality modulo arrival time. 'eElapsedMicros' is carved out because it may
  legitimately vary during live replay; every other field (identity, blob and
  message sizes, payload hash) must agree exactly.
-}
sameEvent :: Event -> Event -> Bool
sameEvent a b = a{eElapsedMicros = 0} == b{eElapsedMicros = 0}
