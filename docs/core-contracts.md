# Core contracts

This is the citable catalog of the invariants the **pure core** (`src/Rechaos/Core`)
asserts about itself — the fault algebra, the SplitMix64 scheduler, the oracle,
and the shrinker. Where [`invariants.md`](invariants.md) names what rechaos
asserts about a *live REAPI endpoint*, this page names what the core asserts
about *its own values and functions*: the propositions that make the executable core
reliable. See `formal.md` for the separate Lean models and proof boundaries.

Each proposition below gives: the exact statement, the Core function it is a
property of, the `CoreSpec` check-site name that exercises it (the string passed
to `check`), and whether it is **tested as property** (a QuickCheck property or a
pinned vector in [`test/CoreSpec.hs`](../test/CoreSpec.hs)) or **not yet a
theorem** (asserted by construction / documented but awaiting a machine-checked
proof in the Lean port).

Everything in the core is pure, total, and nonnegative: no IO, no clock, no
filesystem, no randomness beyond the explicit seed, and no partial functions. A
proposition marked *tested as property* is checked over generated inputs with
`maxSuccess = 500`; a boundary proposition is additionally pinned at its
endpoints.

## Determinism

### C1. SplitMix64 matches published vectors

- **Statement.** `nextSeed` is the reference SplitMix64 mixer: its output on the
  zero seed is `0xe220a8397b1dcdaf` and on `0x9e3779b97f4a7c15` is
  `0x6e789e6aa1b965f4`, and its state advance is exactly the golden-ratio
  increment independent of the output.
- **Core function.** `Rechaos.Core.Scheduler.nextSeed`.
- **Check-site.** `"SplitMix64 published zero-seed vector"`,
  `"SplitMix64 published nonzero-seed vector"`,
  `"state advance is exactly the golden-ratio increment, independent of output"`,
  `"the advance step is injective over a sampled seed range"`.
- **Status.** Tested as property (plus pinned vectors).

### C2. One generator step per event

- **Statement.** Folding `step` over an event trace advances the seed exactly
  once per event — whether or not any rule matched — so decisions depend only on
  event position, not on which rules fired. `schedule` is deterministic, and a
  trace split and rejoined yields the identical timeline.
- **Core function.** `Rechaos.Core.Scheduler.step`,
  `Rechaos.Core.Scheduler.schedule`.
- **Check-site.**
  `"folding step advances the seed exactly once per event, whatever matched"`,
  `"a nonmatching or absent rule advances the seed identically to a match"`,
  `"scheduler agrees with incremental execution across trace splits"`,
  `"schedule is deterministic for an arbitrary policy and event stream"`,
  `"trace-split agreement generalizes to an arbitrary policy"`,
  `"seed advances exactly once per event for an arbitrary policy"`.
- **Status.** Tested as property (the arbitrary-`Policy` variants generalize the
  single-rule helper to the full `Arbitrary Policy` instance).

### C3. The ppm firing test is exact at its endpoints

- **Statement.** The firing test draws against `ppmDenominator` (= `maxPpm` =
  `1_000_000`): a rule with `chancePpm == 0` never fires and a rule with
  `chancePpm == maxPpm` always fires, over any event stream; and the empirical
  fire fraction tracks `chancePpm / ppmDenominator`.
- **Core function.** `Rechaos.Core.Scheduler.step` (the
  `< fromIntegral ppmDenominator` comparison), `Rechaos.Core.Types.ppmDenominator`.
- **Check-site.** `"probability endpoints"`,
  `"chancePpm == 0 never fires over a generated event stream"`,
  `"chancePpm == maxPpm always fires over a generated event stream"`,
  `"empirical injection frequency tracks chancePpm within tolerance"`.
- **Status.** Tested as property (endpoints over generated traces, interior statistically
  within tolerance).

## Fault algebra

### C4. `statusCode` / `statusFromCode` bijection

- **Statement.** `statusFromCode` is the total inverse of `statusCode` on the
  nine codes rechaos synthesizes, and the deliberately excluded standard codes
  decode to `Nothing`.
- **Core function.** `Rechaos.Core.Types.statusCode`,
  `Rechaos.Core.Types.statusFromCode`.
- **Check-site.** `"statusFromCode inverts statusCode for every Status"`,
  `"the nine documented gRPC codes are pinned exactly"`,
  `"excluded gRPC codes decode to Nothing"`.
- **Status.** Tested as property (plus a pinned code table).

### C5. `dribbleMicros` ceiling-minimality

- **Statement.** `dribbleMicros rate bytes` is the *minimal* microsecond count
  that does not under-deliver: it rounds up (never under-delivers the requested
  bytes), one microsecond less would under-deliver, zero rate is `Nothing`, and
  when `rate` divides `bytes * microsPerSecond` evenly the result is the exact
  floor with no spurious `+1`. `bytes == 0` gives `Just 0`.
- **Core function.** `Rechaos.Core.Scheduler.dribbleMicros`,
  `Rechaos.Core.Types.microsPerSecond`.
- **Check-site.**
  `"dribble zero rate is total; rounding never exceeds requested rate"`,
  `"dribble micros are ceiling-minimal: one microsecond less under-delivers"`,
  `"dribbleMicros is the exact floor when rate divides evenly, and zero bytes give zero"`,
  `"dribbleMicros divides exactly with no spurious +1 on an aligned product"`.
- **Status.** Tested as property.

### C6. `dribbleSchedule` offset-preservation and time-agreement

- **Statement.** `dribbleSchedule rate chunkBytes totalBytes` is the Core model
  of the shell's chunk pacing. It is `Nothing` iff `rate == 0` or
  `chunkBytes == 0`. Otherwise the first components sum to `totalBytes` (offset
  preservation), the schedule is non-empty, every chunk size is `chunkBytes`
  except possibly the last (the remainder), and the final cumulative time equals
  `dribbleMicros rate totalBytes`. The empty payload yields the singleton
  `[(0, 0)]`.
- **Core function.** `Rechaos.Core.Scheduler.dribbleSchedule`.
- **Check-site.** `"dribbleSchedule is Nothing iff rate or chunk is zero"`,
  `"dribbleSchedule preserves the total offset and agrees with dribbleMicros"`,
  `"dribbleSchedule chunk sizes are all chunkBytes except possibly the last"`,
  `"dribbleSchedule on an empty payload is the singleton (0,0)"`.
- **Status.** Tested as property.

## Shrinker

### C7. Deletion-1-minimality of the shrinker

- **Statement.** Because the candidate generator includes chunk deletions down
  to singletons, a fully explored shrink is deletion-1-minimal for a
  deterministic predicate: no single retained fault can be dropped without losing
  the failure. Every generated candidate is strictly smaller under the
  termination measure (length, then summed severity), and an `Unknown` verdict
  never advances `best`.
- **Core function.** `Rechaos.Core.Minimize.candidates`,
  `Rechaos.Core.Minimize.observe`, `Rechaos.Core.Minimize.weaker`.
- **Check-site.**
  `"minimizer removes irrelevant faults and shrinks to the failing threshold"`,
  `"every generated candidate is strictly smaller under the termination measure"`,
  `"minimizer only accepts confirmed reproductions"`,
  `"candidate generation produces no intensity variant at the Truncate and Dribble caps"`.
- **Status.** Tested as property (deletion-1-minimality is established for the
  tested predicates; the general theorem is not yet machine-checked — a Lean-port
  target).

## Oracle

### C8. Oracle equivalence is a congruence

- **Statement.** Build-output equivalence (`O.equivalent`) is reflexive,
  symmetric, and transitive, and coincides with structural equality and with an
  empty `diff`; `diff` reports each key once in ascending order; unsuccessful
  builds are never correctness findings (`Inconclusive`).
- **Core function.** `Rechaos.Core.Oracle.equivalent`,
  `Rechaos.Core.Oracle.diff`, `Rechaos.Core.Oracle.compareBuilds`.
- **Check-site.** `"oracle equivalence is reflexive and symmetric"`,
  `"oracle equivalence is transitive"`,
  `"diff is empty iff equivalent iff structurally equal"`,
  `"diff reports each key once in ascending order"`,
  `"unsuccessful builds are never correctness findings"` (and the
  `"... over all entry kinds"` variants).
- **Status.** Tested as property.

## Replay

### C9. Expected-event coverage and rejection of extra injected decisions

- **Statement.** `verifyReplay expected observed` is the forward inclusion: every
  expected event must have occurred, unchanged (same fingerprint modulo arrival
  time) and with an identical injection; it tolerates extra observed traffic, the
  correct semantics for a sparse fault timeline. `verifyReplayExact` runs that
  forward check *and* the reverse inclusion, failing closed on any observed
  decision whose injection is `Just` but whose `eventKey` is absent from
  `expected`. `verifyReplayExact` certifies expected-event coverage and agreement on the
  injected decisions, while permitting extra non-injected observed events.
  It does not require equality of the entire event sets.
- **Core function.** `Rechaos.Core.Scheduler.verifyReplay`,
  `Rechaos.Core.Scheduler.verifyReplayExact`,
  `Rechaos.Core.Scheduler.replayDecision`.
- **Check-site.**
  `"replay coverage rejects a missing tail even without observed mismatches"`,
  `"replay fails when the observed event carries a different injected fault"`,
  `"verifyReplayExact rejects an extra injected decision that verifyReplay tolerates"`,
  `"verifyReplayExact tolerates an extra non-injected (pass-through) observed event"`,
  `"both verifyReplay and verifyReplayExact accept an exact match"`,
  `"verifyReplayExact still fails closed on a missing expected event"`.
- **Status.** Tested as property.

## Numeric invariants

### C10. One ppm source of truth; ppm and microseconds are distinct quantities

- **Statement.** `ppmDenominator == maxPpm` (a single ppm source of truth) and
  `microsPerSecond` is numerically equal to both (`1_000_000`) yet a distinct
  physical quantity: a dimensionless parts-per-million scale versus
  microseconds-per-second. The scheduler's firing test draws against
  `ppmDenominator`; `dribbleMicros` / `dribbleSchedule` convert using
  `microsPerSecond`.
- **Core function.** `Rechaos.Core.Types.maxPpm`,
  `Rechaos.Core.Types.ppmDenominator`, `Rechaos.Core.Types.microsPerSecond`.
- **Check-site.** Covered indirectly by C3 (ppm endpoints) and C5/C6 (dribble
  timing); the equality is a definitional fact, not a separate property.
- **Status.** Not yet a theorem (held by definition — `ppmDenominator = maxPpm`;
  the physical-quantity distinction is a documentation invariant a Lean port
  would make a type-level fact).
