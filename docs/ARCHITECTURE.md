# Architecture and design rationale

This document explains *why* rechaos is built the way it is. It expands the
module table in the top-level [README](../README.md) into a design-rationale
reference: the pure-core / IO-shell split, the determinism model, the targeting
and replay semantics, how the shell maps wire traffic onto the core algebra, and
how the oracle defines build equivalence. Claims here are cited against the Core
module haddocks and the shell boundary; where a precise field-level contract
matters it is stated at reference precision.

Companion references:

- [`fault-dsl.md`](fault-dsl.md) — the policy grammar, fields, constraints, the
  fault-eligibility matrix, and the exact decoder error strings.
- [`timeline-format.md`](timeline-format.md) — the on-disk decision timeline and
  outcomes sidecar schema, and the replay distinction described below.
- [`invariants.md`](invariants.md) — the correctness/liveness invariants the
  chaos monkey asserts against a live endpoint.

## The pure core / IO shell split

rechaos is deliberately split into two layers.

- **`Rechaos.Core.*` is a pure decision engine.** It imports no `IO`, no clock,
  no filesystem, no gRPC, and no random-generator API, and it contains no
  partial indexing, `error`, or `undefined`. This is stated explicitly in each
  module's haddock: `Core.Types` is "pure: no IO, no clock, no filesystem, no
  randomness, and no partial functions"; `Core.Scheduler` is "pure: no IO, no
  clock, no randomness beyond the explicit seed, and no partial functions";
  `Core.Oracle` is "pure: no IO, no filesystem access, and no partial
  functions"; `Core.Minimize` is "pure: no IO and no partial functions."
- **`Rechaos.Shell.*` is the effectful boundary.** Everything that touches the
  outside world — reading the wall clock, allocating occurrence counters,
  speaking gRPC over grapesy, pacing bytes, snapshotting the filesystem,
  spawning an external checker — lives in the shell.

Why bother with the discipline? Three reasons.

1. **Testability and reproducibility.** Because scheduling, replay, output-tree
   comparison, and shrinking are pure functions of their inputs, they are
   property-tested with QuickCheck and reproduce bit-for-bit. A recorded
   timeline plus a policy is a total specification of what the core will decide.
2. **Auditability.** The heart of what rechaos *asserts* — determinism,
   first-match targeting, equivalence as a null diff, deletion-1-minimality —
   is concentrated in four small, side-effect-free modules you can read end to
   end.
3. **Lean portability.** The no-`IO`/no-partiality rule, plus the explicit
   `Word64` arithmetic in the generator (below), is what lets the core be
   transliterated to a proof assistant (Lean) without dragging in an effect
   model. The core is written as if it already were a specification.

The no-partial-functions rule shows up concretely even in corner cases:
`Core.Scheduler.dribbleMicros` returns `Maybe` and yields `Nothing` for a zero
rate rather than dividing by zero, "keeping the function total even for an
invalid `Dribble` supplied by another Haskell caller."

## Determinism: SplitMix64, one step per event

The central invariant of the scheduler is reproducibility:

> same policy + seed + event trace ⇒ same decisions.

This rests on two deliberate choices in `Core.Scheduler`.

### SplitMix64 with fixed constants and `Word64` wraparound

The generator is a single SplitMix64 step (`nextSeed :: Word64 -> (Word64,
Word64)`) using the fixed golden-ratio increment `0x9e3779b97f4a7c15` and the
two mixing constants `0xbf58476d1ce4e5b9` and `0x94d049bb133111eb`, relying on
`Word64` wraparound arithmetic. The haddock states the motive: the constants and
the wraparound reliance are "deliberate so the generator is portable
bit-for-bit to Lean's `UInt64`." A chaos finding reproduced in Haskell is
therefore reproducible in a future Lean model of the same scheduler.

### One RNG step per event, regardless of match

`step` advances the seed exactly once per observed event — *including events no
rule targets* — and only then consults the rules:

```haskell
step rs s e = (s', Decision e (choose rs))
 where
  (s', draw) = nextSeed s
  ...
```

The haddock is explicit that the seed "advances whether or not any rule matched,
keeping the stream aligned to event position." This is the load-bearing design
decision behind replay stability: the decision stream is a function of **event
position**, not of which rules happened to fire. Adding, removing, or re-ordering
a rule that does not match a given event does not shift the draws seen by later
events, because every event consumes exactly one step. `schedule` threads the
seed left to right with `mapAccumL` from the policy's initial `seed`, so the
whole timeline is a pure fold over the event trace.

A rule fires when `draw mod 1000000 < chancePpm`. Even a `chancePpm` of `0` rule
still owns a matched event (blocking later rules) and still consumes its step —
the step is consumed per *event*, not per *fired fault*.

## Targeting: first-match

`Core.Scheduler.step` uses **first-match** targeting: it walks the rule list in
order and the first rule whose `Target` `matches` the event decides that event's
fate; no later rule is consulted. `matches` is a conjunction (logical AND) over
the target fields — method and direction by exact equality, and the optional
`occurrence`, `messageIndex`, inclusive `minBlobBytes`/`maxBlobBytes`, and
inclusive `afterMicros`/`beforeMicros` bounds, each matching anything when
absent. A present blob bound never matches an event that carries no blob
(`eBlobBytes == Nothing`).

First-match (rather than, say, highest-priority or all-match) keeps the decision
for an event a simple, order-dependent lookup: put specific rules first, general
rules last. Combined with one-step-per-event, the entire scheduling function is
easy to specify and to replay.

## Replay: incomplete vs. changed

Replay distinguishes two failure modes, and this distinction is intentional (see
`Core.Scheduler` haddock: the checks "distinguish an incomplete replay (a
required event never occurred) from a changed one").

- **Incomplete** — a required event never occurred. In a full recording,
  `replayDecision False` fails closed on a missing event with `event missing
  from replay timeline`. `verifyReplay` fails for any expected event that was
  never observed.
- **Changed** — an event occurred but its fingerprint differs. `replayDecision`
  returns `replay fingerprint mismatch`; `verifyReplay` folds both cases into
  `replay incomplete or changed: <identity>`.

The fingerprint is defined by `sameEvent`, which is equality **modulo arrival
time**: `eElapsedMicros` is carved out (it may legitimately vary on a live
replay), while identity, blob size, message size, and payload hash must all
agree exactly. Mechanically:

```haskell
sameEvent a b = a{eElapsedMicros = 0} == b{eElapsedMicros = 0}
```

The event identity used for lookup is the `EventKey` tuple
`(method, occurrence, direction, messageIndex)`, which must be unique across a
well-formed timeline (`validateTimeline` rejects duplicates with `duplicate
event identity in timeline`).

A replay is **not** considered complete merely because nothing it observed
mismatched: `verifyReplay`'s haddock states that "every required event must also
have happened." Replay reports divergence instead of guessing. The sparse
variant (`replayDecision True`, surfaced as `serve --sparse`) permits unlisted
traffic through unfaulted but still checks every listed event's fingerprint. See
[`timeline-format.md`](timeline-format.md#replay-and-verification) for the
command-level view and exact on-disk schema.

## The shell: mapping wire traffic onto the core algebra

The core speaks in `Event`/`Decision` values; the shell's job is to turn
observed gRPC/ByteStream traffic into those values and to carry out the chosen
`Fault`.

- **`Shell/Wire`** is the grapesy transport glue: the gRPC server that accepts
  the build client and the client transport to the unmodified upstream.
- **`Shell/Protocol`** inspects proto-lens messages and performs stream edits:
  it computes the logical blob size (`blobSize`), the serialized message size
  (`messageSize`), the payload fingerprint (`sha256`), and performs the
  payload-level rewrites (`payloadChunks` for dribble re-chunking,
  `truncatePayload` for truncation). It also names the ByteStream/CAS methods
  the proxy special-cases.
- **`Shell/Runtime`** is where each observed message becomes an `Event`: it
  allocates 1-based occurrence indices per method and message indices per
  direction, reads the monotonic clock to fill `eElapsedMicros` (the one field
  the core excuses from the fingerprint), calls `Core.Scheduler` (`decide`) to
  obtain a `Decision`, journals the decision timeline, and writes the outcomes
  sidecar. Under `--replay` it consults the recorded timeline instead of the
  policy.
- **`Shell/Proxy`** is the faulting gateway proper: it enacts the chosen fault —
  pacing (dribble), stream edits (truncate), deadlines (delay via
  `sleepMicros`), gRPC status synthesis (abort) — and manages metadata and
  cancellation. The proxy does not retry RPCs; it reconnects its upstream
  transport for subsequent calls after a disconnect.
- **`Shell/Oracle`** snapshots an output directory into a `Core.Oracle.Tree`
  (relative paths, SHA-256 content hash and size, executable bit, symlink
  targets, directories; timestamps ignored) and renders verdicts.
- **`Shell/Minimize`** drives an external checker with trial timeouts and
  retained evidence, feeding each run's `Verdict` back into
  `Core.Minimize`'s pure acceptance state machine.
- **`Shell/Json`** is the strict, versioned decoder/encoder for policies and
  timelines (unknown fields are errors; `version` must equal `1`). It is the
  single source of truth for the fault-eligibility matrix (see
  [`fault-dsl.md`](fault-dsl.md)): `validFault`/`supportedMethods` decide which
  method/direction/fault combinations are legal, checked once on the whole
  policy at decode time and again per decision on replay.

The symmetry is the point: the shell is the only place that reads a clock,
touches the network, or touches disk; the core receives a fully-formed `Event`
and returns a `Decision`, and never learns where the event came from.

## The oracle: build equivalence as a null diff

`Core.Oracle` models a successful build's outputs as a `Tree` (a `Map` from
relative path to `Entry`, where an `Entry` is a `File contentHash sizeBytes
executable`, a `Symlink target`, or a `Directory`). Equivalence is defined
precisely:

> two trees are `equivalent` exactly when `diff` between them is empty.

`diff` iterates the union of both trees' paths in ascending key order and emits
one `Change path before after` per path whose entries differ (`Nothing` on a
side marks an addition or deletion), so its output is a stable, canonical,
order-independent list. `compareBuilds` only renders a judgement when *both*
sides `Built` successfully: equal outputs yield `Equivalent`, differing outputs
`Diverged changes`, and any non-success on either side (`BuildFailed`,
`BuildTimedOut`) is `Inconclusive` rather than divergent — a failed or timed-out
build is not evidence that the server corrupted an output.

This definition is what the `rechaos oracle` command exposes: it compares two
completed output trees and exits `1` on divergence, `2` on error, ignoring
timestamps and comparing content digests, sizes, executable bits, symlink
targets, and directories.

## Shrinking: deletion-1-minimality

`Core.Minimize` shrinks a failing timeline to a small reproducer via a
candidate/observe state machine (`ShrinkState`). `start` seeds it from a failing
timeline keeping only its injected faults; `candidate` offers the next timeline;
`observe` folds the shell's `Verdict` back in, accepting a candidate only when it
still `Triggers` the original failure signature. Candidates include chunk
deletions at halving sizes down to singletons, so a fully explored result is
**deletion-1-minimal** for a deterministic predicate: no single retained fault
can be dropped without losing the failure. Intensity shrinking follows a
separate, strictly decreasing measure (`Delay` halves toward zero, `Dribble`
doubles its rate toward the message's full-speed cap, `Truncate` raises its
kept-byte count toward the full message size; `Abort` has no weaker form).

The `Triggers` / `DoesNotTrigger` / `Unknown` distinction is load-bearing: only
a reproduction of the *same* failure signature counts; a flake, timeout, or
infrastructure error is `Unknown` and never advances `best`. The shrinker thus
never mistakes noise for a successful shrink.

## Module-by-module map

### Core (pure)

| Module | Responsibility |
|---|---|
| [`Core/Types`](../src/Rechaos/Core/Types.hs) | Fault algebra (`Fault`, `Status`, `Direction`), `Target`/`Rule`/`Policy`, `Event`/`Decision`/`Timeline`, the `EventKey` identity and the `sameEvent` fingerprint; explicit nonnegative units |
| [`Core/Scheduler`](../src/Rechaos/Core/Scheduler.hs) | SplitMix64 `nextSeed`, one-step-per-event `step`/`schedule`, first-match `matches`, `replayDecision`/`verifyReplay`/`validateTimeline`, `dribbleMicros` |
| [`Core/Oracle`](../src/Rechaos/Core/Oracle.hs) | Output-tree `Tree`/`Entry`, canonical `diff`, `equivalent`, `compareBuilds` verdicts |
| [`Core/Minimize`](../src/Rechaos/Core/Minimize.hs) | `ShrinkState` candidate/observe machine, `candidates`, intensity `weaker` measure, `Verdict` |

### Shell (IO boundary)

| Module | Responsibility |
|---|---|
| [`Shell/Json`](../src/Rechaos/Shell/Json.hs) | Strict, versioned policy/timeline decode+encode; `validatePolicy`/`validFault`/`supportedMethods` eligibility |
| [`Shell/Protocol`](../src/Rechaos/Shell/Protocol.hs) | proto-lens message inspection, blob/message sizing, SHA-256, dribble re-chunking, truncation |
| [`Shell/Proxy`](../src/Rechaos/Shell/Proxy.hs) | Faulting gateway: pacing, stream edits, deadlines, metadata, cancellation, gRPC status synthesis |
| [`Shell/Runtime`](../src/Rechaos/Shell/Runtime.hs) | Monotonic observation, occurrence/message-index allocation, `decide`, decision journal + outcomes sidecar |
| [`Shell/Wire`](../src/Rechaos/Shell/Wire.hs) | grapesy server/client transport glue |
| [`Shell/Oracle`](../src/Rechaos/Shell/Oracle.hs) | Filesystem snapshot + SHA-256 into a `Tree`; verdict rendering |
| [`Shell/Minimize`](../src/Rechaos/Shell/Minimize.hs) | External checker driver with trial timeouts and retained evidence |
