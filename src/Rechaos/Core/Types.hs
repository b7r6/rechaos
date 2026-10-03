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

  -- * Status <-> gRPC code
  statusCode,
  statusFromCode,

  -- * Targeting and policy
  Target (..),
  Rule (..),
  Policy (..),

  -- * Numeric invariants
  maxPpm,
  mkRule,
  maxDribbleChunkBytes,
  validFaultBounds,

  -- * Events and timelines
  Event (..),
  Decision (..),
  Timeline,
  EventKey,
  eventKey,
  Fingerprint (..),
  fingerprint,
  sameEvent,
) where

import Data.Text (Text)
import Data.Word (Word64, Word8)
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
  the standard codes rechaos knows how to synthesize. See 'statusCode' for the
  canonical integer each constructor maps to.

  The omitted standard codes are excluded deliberately:

      * @OK@ (0) is excluded because 'Abort' must /fail/ the RPC; injecting a
        success would be a no-op fault.
      * @Unknown@ (2) is excluded because it carries no actionable meaning for a
        chaos injection; its absence keeps every injected status specific.
      * @AlreadyExists@ (6) and @OutOfRange@ (11) are excluded as
        resource\/argument conditions that rechaos never synthesizes, overlapping
        'InvalidArgument' and 'FailedPrecondition' for injection purposes.
      * @PermissionDenied@ (7) and @Unauthenticated@ (16) are excluded because
        auth outcomes depend on credentials the proxy does not manipulate.
      * @Aborted@ (10) is excluded because it signals a concurrency\/transaction
        conflict rechaos has no model of; 'FailedPrecondition' covers the
        precondition case.
      * @Unimplemented@ (12) is excluded because rechaos targets existing
        methods; faking \"not implemented\" would misrepresent the surface.
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

{- | The canonical gRPC integer code for a 'Status'. Total: every constructor has
  a fixed code, matching the canonical @grpc-status@ registry.

      * 'Cancelled' = 1
      * 'InvalidArgument' = 3
      * 'DeadlineExceeded' = 4
      * 'NotFound' = 5
      * 'ResourceExhausted' = 8
      * 'FailedPrecondition' = 9
      * 'Internal' = 13
      * 'Unavailable' = 14
      * 'DataLoss' = 15
-}
statusCode :: Status -> Word8
statusCode Cancelled = 1
statusCode InvalidArgument = 3
statusCode DeadlineExceeded = 4
statusCode NotFound = 5
statusCode ResourceExhausted = 8
statusCode FailedPrecondition = 9
statusCode Internal = 13
statusCode Unavailable = 14
statusCode DataLoss = 15

{- | The total inverse of 'statusCode': recover the 'Status' from a gRPC integer
  code, or 'Nothing' when the code is not one rechaos synthesizes (including the
  deliberately excluded standard codes documented on 'Status').
-}
statusFromCode :: Word8 -> Maybe Status
statusFromCode 1 = Just Cancelled
statusFromCode 3 = Just InvalidArgument
statusFromCode 4 = Just DeadlineExceeded
statusFromCode 5 = Just NotFound
statusFromCode 8 = Just ResourceExhausted
statusFromCode 9 = Just FailedPrecondition
statusFromCode 13 = Just Internal
statusFromCode 14 = Just Unavailable
statusFromCode 15 = Just DataLoss
statusFromCode _ = Nothing

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

{- | The inclusive upper bound on a firing probability expressed in parts per
  million: @1_000_000@ ppm = certainty. A 'Rule' with @chancePpm == maxPpm@
  always fires; a value above it is out of range. @Rechaos.Shell.Json.validatePolicy@
  enforces this bound at the decoder boundary via this constant.
-}
maxPpm :: Natural
maxPpm = 1_000_000

{- | Validated entry point for building a 'Rule': returns 'Nothing' when
  @chancePpm@ exceeds 'maxPpm', and @'Just' rule@ otherwise. The raw 'Rule'
  constructor remains public (the scheduler and decoders pattern-match it), but
  'mkRule' is the correct-by-construction path that cannot produce an
  out-of-range firing probability.
-}
mkRule :: Target -> Natural -> Fault -> Maybe Rule
mkRule t c f
  | c > maxPpm = Nothing
  | otherwise = Just (Rule{target = t, chancePpm = c, fault = f})

{- | The inclusive upper bound on a 'Dribble' chunk size in bytes: @4_194_304@
  (4 MiB). @Rechaos.Shell.Json.validatePolicy@ enforces
  @1 <= chunkBytes <= maxDribbleChunkBytes@ via 'validFaultBounds', so the bound
  is a named Core fact rather than a magic literal in the decoder.
-}
maxDribbleChunkBytes :: Natural
maxDribbleChunkBytes = 4_194_304

{- | Total predicate capturing the intended numeric invariant of a 'Fault',
  suitable as the basis for a future Lean lemma:

      * 'Dribble' requires a positive @bytesPerSecond@ rate and a chunk size in
        @1 .. 'maxDribbleChunkBytes'@ inclusive.
      * every other fault is unconstrained here (always 'True').

  @Rechaos.Shell.Json.validatePolicy@ gates 'Dribble' acceptance on this
  predicate at the decoder boundary, so the invariant is enforced here in Core
  rather than duplicated as literals in the shell.
-}
validFaultBounds :: Fault -> Bool
validFaultBounds (Dribble rate chunkBytes) =
  rate > 0 && chunkBytes >= 1 && chunkBytes <= maxDribbleChunkBytes
validFaultBounds _ = True

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

{- | The identity-significant projection of an 'Event' used by 'sameEvent':
  every field /except/ 'eElapsedMicros', in the tuple shape
  @(method, occurrence, direction, messageIndex, blobBytes, messageBytes,
  payloadHash)@. Two events are \"the same\" when their fingerprints are equal.

  Naming this value makes the comparison contract explicit rather than an
  emergent property of zeroing 'eElapsedMicros' before a record equality check.
-}
newtype Fingerprint = Fingerprint (Text, Natural, Direction, Natural, Maybe Natural, Natural, Text)
  deriving (Eq, Show)

{- | Project an 'Event' onto its 'Fingerprint', capturing exactly the
  identity-significant fields. 'eElapsedMicros' is deliberately excluded because
  it may legitimately vary between a recording and a live replay of the same
  event.
-}
fingerprint :: Event -> Fingerprint
fingerprint e =
  Fingerprint
    ( eMethod e
    , eOccurrence e
    , eDirection e
    , eMessageIndex e
    , eBlobBytes e
    , eMessageBytes e
    , ePayloadHash e
    )

{- | Equality modulo arrival time. 'eElapsedMicros' is carved out because it may
  legitimately vary during live replay; every other field (identity, blob and
  message sizes, payload hash) must agree exactly. Defined as 'Fingerprint'
  equality so the compared field set is a single named value.
-}
sameEvent :: Event -> Event -> Bool
sameEvent a b = fingerprint a == fingerprint b
