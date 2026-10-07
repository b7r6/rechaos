/-
  rechaos — core types (Lean port of `Rechaos.Core.Types`).

  Mirrors the Haskell fault algebra, policy, events, and timeline values. All
  explicit-unit nonnegative quantities (micros, bytes, ppm) are `Nat`; the
  SplitMix64 seed is `UInt64`, matching `Rechaos.Core`. This module is pure and
  carries no `sorry`: the few lemmas are structural `rfl`/`decide` facts that do
  not force `UInt64` arithmetic in the kernel.
-/

import Rechaos.Core

namespace Rechaos

/-- Which half of an RPC an observation or target refers to. -/
inductive Direction
  | request
  | response
  deriving Repr, DecidableEq, Inhabited

/-- gRPC status codes an `abort` fault can inject. -/
inductive status
  | cancelled
  | invalidArgument
  | deadlineExceeded
  | notFound
  | resourceExhausted
  | failedPrecondition
  | internal
  | unavailable
  | dataLoss
  deriving Repr, DecidableEq, Inhabited

/-- The canonical gRPC integer code for a `Status`. Total. -/
def status_code : status → Nat
  | .cancelled          => 1
  | .invalidArgument    => 3
  | .deadlineExceeded   => 4
  | .notFound           => 5
  | .resourceExhausted  => 8
  | .failedPrecondition => 9
  | .internal           => 13
  | .unavailable        => 14
  | .dataLoss           => 15

/-- Total inverse of `statusCode`: recover a `Status` from a gRPC code, or
    `none` when the code is not one rechaos synthesizes. -/
def status_from_code : Nat → Option status
  | 1  => some .cancelled
  | 3  => some .invalidArgument
  | 4  => some .deadlineExceeded
  | 5  => some .notFound
  | 8  => some .resourceExhausted
  | 9  => some .failedPrecondition
  | 13 => some .internal
  | 14 => some .unavailable
  | 15 => some .dataLoss
  | _  => none

/-- The algebra of faults rechaos can inject at a matched event. -/
inductive Fault
  | /-- Delay delivery by the given number of microseconds. -/
    delay (micros : Nat)
  | /-- Abort the RPC with the given gRPC `Status`. -/
    abort (status : status)
  | /-- Deliver slowly: `dribble bytesPerSecond chunkBytes`. -/
    dribble (bytesPerSecond : Nat) (chunkBytes : Nat)
  | /-- Truncate the payload, keeping only the leading `keepBytes` bytes. -/
    truncate (keepBytes : Nat)
  | /-- Corrupt the payload in place, flipping the low bit of each of the leading
        `bytes` payload bytes. Length-preserving, unlike `truncate`. -/
    corrupt (bytes : Nat)
  deriving Repr, DecidableEq, Inhabited

/-- A predicate over `Event`s selecting where a `Rule` applies. Absent optional
    fields default to "any"; present fields must all hold. Bounds are inclusive. -/
structure Target where
  method       : String
  direction    : Direction
  occurrence   : Option Nat := none
  message_index : Option Nat := none
  min_blob_bytes : Option Nat := none
  max_blob_bytes : Option Nat := none
  after_micros  : Option Nat := none
  before_micros : Option Nat := none
  deriving Repr, DecidableEq, Inhabited

/-- A policy rule: inject `fault` at events matching `target` with probability
    `chancePpm` parts per million. -/
structure rule where
  target    : Target
  chance_ppm : Nat
  fault     : Fault
  deriving Repr, DecidableEq, Inhabited

/-- Inclusive upper bound on a firing probability in parts per million:
    `1_000_000` ppm = certainty. -/
def max_ppm : Nat := 1000000

/-- The parts-per-million scale the scheduler draws against. Equal to `maxPpm`
    to keep a single ppm source of truth. -/
def ppm_denominator : Nat := max_ppm

/-- Microseconds per second: the dribble timing unit. Numerically equal to
    `ppmDenominator` but a distinct physical quantity. -/
def micros_per_second : Nat := 1000000

/-- Validated builder for a `Rule`: `none` when `chancePpm` exceeds `maxPpm`. -/
def mk_rule (t : Target) (c : Nat) (f : Fault) : Option rule :=
  if c > max_ppm then none else some { target := t, chance_ppm := c, fault := f }

/-- Inclusive upper bound on a `dribble` chunk size in bytes: `4_194_304`
    (4 MiB). -/
def max_dribble_chunk_bytes : Nat := 4194304

/-- Total predicate capturing the intended numeric invariant of a `Fault`:
    `dribble` requires a positive rate and a chunk size in
    `1 .. maxDribbleChunkBytes`; every other fault is unconstrained. -/
def valid_fault_bounds : Fault → Bool
  | .dribble rate chunkBytes =>
      rate > 0 && chunkBytes >= 1 && chunkBytes <= max_dribble_chunk_bytes
  | _ => true

/-- A complete policy: a scheduling seed and an ordered list of rules. Rule
    order is significant; targeting uses first-match. -/
structure policy where
  seed  : UInt64
  rules : List rule
  deriving Repr, Inhabited

/-- A single observation handed to the core by the shell. Occurrences are
    1-based per method; message indices are 1-based per direction. -/
structure Event where
  method        : String
  occurrence    : Nat
  direction     : Direction
  message_index  : Nat
  blob_bytes     : Option Nat := none
  elapsed_micros : Nat
  message_bytes  : Nat
  payload_hash   : String
  deriving Repr, DecidableEq, Inhabited

/-- A scheduling outcome: the observed `Event` paired with the fault to inject,
    or `none` when no rule fired. -/
structure decision where
  event     : Event
  injection : Option Fault := none
  deriving Repr, DecidableEq, Inhabited

/-- An ordered sequence of scheduling decisions. -/
abbrev timeline := List decision

/-- The identity of an event: `(method, occurrence, direction, messageIndex)`. -/
abbrev EventKey := String × Nat × Direction × Nat

/-- Project an `Event` onto its identity `EventKey`. Ignores payload and timing. -/
def eventKey (e : Event) : EventKey :=
  (e.method, e.occurrence, e.direction, e.message_index)

/-- The identity-significant projection of an `Event`: every field except
    `elapsedMicros`, which may vary between a recording and a live replay. -/
structure Fingerprint where
  method       : String
  occurrence   : Nat
  direction    : Direction
  message_index : Nat
  blob_bytes    : Option Nat
  message_bytes : Nat
  payload_hash  : String
  deriving Repr, DecidableEq, Inhabited

/-- Project an `Event` onto its `Fingerprint`, excluding `elapsedMicros`. -/
def fingerprint (e : Event) : Fingerprint :=
  { method := e.method
  , occurrence := e.occurrence
  , direction := e.direction
  , message_index := e.message_index
  , blob_bytes := e.blob_bytes
  , message_bytes := e.message_bytes
  , payload_hash := e.payload_hash }

/-- Equality modulo arrival time: `elapsedMicros` is carved out, every other
    field must agree. Defined as `Fingerprint` equality. -/
def same_event (a b : Event) : Bool :=
  fingerprint a == fingerprint b

-- ── structural lemmas ──────────────────────────────────────────────────────

/-- `statusFromCode` is a left inverse of `statusCode` on every `Status`. -/
theorem status_from_code_status_code : ∀ s : status, status_from_code (status_code s) = some s := by
  intro s; cases s <;> rfl

/-- `ppmDenominator` is the ppm source of truth: equal to `maxPpm`. -/
theorem ppm_denominator_eq_max_ppm : ppm_denominator = max_ppm := rfl

/-- `eventKey` depends only on the identity fields, not on timing or payload:
    two events agreeing on them share an `eventKey`. -/
theorem event_key_congr (e : Event) (t : Nat) :
    eventKey { e with elapsed_micros := t } = eventKey e := rfl

/-- `fingerprint` ignores `elapsedMicros`: overwriting it leaves the fingerprint
    (and hence `sameEvent`) unchanged. -/
theorem fingerprint_elapsed_irrelevant (e : Event) (t : Nat) :
    fingerprint { e with elapsed_micros := t } = fingerprint e := rfl

/-- `sameEvent` is reflexive. -/
theorem same_event_refl (e : Event) : same_event e e = true := by
  simp [same_event]

/-- `validFaultBounds` accepts every non-dribble fault unconditionally. -/
theorem valid_fault_bounds_delay (m : Nat) : valid_fault_bounds (.delay m) = true := rfl

end Rechaos
