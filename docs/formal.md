# The Lean 4 verified core

rechaos keeps a small, machine-checked kernel in `lean/` that formalizes the one
load-bearing property the whole tool rests on: the fault scheduler's keystream is
deterministic, and it advances **exactly one SplitMix64 step per observed event**.
Everything in this document is derived from the actual sources
([`lean/Rechaos/Core.lean`](../lean/Rechaos/Core.lean),
[`src/Rechaos/Core/Scheduler.hs`](../src/Rechaos/Core/Scheduler.hs), and
[`test/CoreSpec.hs`](../test/CoreSpec.hs)); nothing here is aspirational.

The Lean core is deliberately tiny. It proves the **structure** of the keystream
abstractly, over any step function `f`, and then instantiates that structure with
the exact SplitMix64 step. Proving the shape abstractly is not just tidy — it is
what keeps the proofs tractable. `UInt64` in Lean is `Fin (2^64)`, so a theorem
that forces the kernel to *evaluate* SplitMix64 arithmetic would make the kernel
deep-recurse over a 64-bit numeral. The proofs below never do that: they are
structural inductions over the iteration count `n`, with the step function held
opaque.

## What is formalized

The Haskell production code (`Rechaos.Core.Scheduler`) and Lean model implement
the same intended algebra. Shared constants and finite conformance corpora check
agreement on committed cases; they are not a proof of equivalence for all inputs.
Structural Lean theorems apply to the Lean definitions. The IO shell, Python
drivers, and live server scheduling are outside those proofs.

### Definition map: Haskell → Lean

| Concept | Haskell (`src/Rechaos/Core/Scheduler.hs`) | Lean (`lean/Rechaos/Core.lean`) |
|---|---|---|
| One SplitMix64 step | `nextSeed :: Word64 -> (Word64, Word64)` | `next_seed (s : UInt64) : UInt64 × UInt64` |
| State-advance increment | `s + 0x9e3779b97f4a7c15` | `s + 0x9e3779b97f4a7c15` |
| Mixing constants | `0xbf58476d1ce4e5b9`, `0x94d049bb133111eb` | `0xbf58476d1ce4e5b9`, `0x94d049bb133111eb` |
| Final avalanche shift | `z2 \`xor\` (z2 \`shiftR\` 31)` | `z2 ^^^ (z2 >>> 31)` |
| Iterate a step `n` times | `iterate (fst . nextSeed) s !! n` (in `CoreSpec`) | `iter (f : UInt64 → UInt64) : Nat → UInt64 → UInt64` |
| The scheduler keystream | seed threaded through `step` / `schedule` once per event | `advance (n : Nat) (s : UInt64) : UInt64` |

A note on tuple order, because it matters when reading the two sources together:

- **Haskell** `nextSeed s = (s', output)` returns `(nextState, output)`, so the
  advanced state is `fst (nextSeed s)` and the draw is `snd (nextSeed s)`.
- **Lean** `next_seed s = (output, s')` returns `(output, nextState)`, so the
  advanced state is `(next_seed s).2` and the draw is `(next_seed s).1`.

Both expose the same two values; only the projection index differs. The Lean
keystream is defined on the state projection to match the Haskell keystream:

```lean
def advance (n : Nat) (s : UInt64) : UInt64 := iter (fun s => (next_seed s).2) n s
```

which is exactly the Lean rendering of the Haskell `iterate (fst . nextSeed) s`
that `CoreSpec` folds over (`CoreSpec.hs`, invariants (G): "folding step advances
the seed exactly once per event" and "seed advances exactly once per event for an
arbitrary policy"). The scheduler's `step` advances the seed once per event
*whether or not any rule matched* (`CoreSpec.hs` (G): "a nonmatching or absent
rule advances the seed identically to a match"), which is what makes
position-indexed iteration — i.e. `advance n` — the correct model of the
keystream.

## The proved theorems and what they mean

All four statements below are proved in `lean/Rechaos/Core.lean` with real proofs
(`rfl` or structural induction), checked by the Lean kernel. There is no `sorry`,
no `admit`, and no new `axiom`.

### `iter_zero` — zero events consume zero keystream

```lean
theorem iter_zero (f : UInt64 → UInt64) (s : UInt64) : iter f 0 s = s := rfl
```

Operationally: running the scheduler over an empty event trace returns the
initial seed untouched. No event, no step.

### `iter_succ` — exactly one step per observed event

```lean
theorem iter_succ (f : UInt64 → UInt64) (n : Nat) (s : UInt64) :
    iter f (n + 1) s = iter f n (f s) := rfl
```

Operationally: processing `n + 1` events is processing one step (`f s`) and then
the remaining `n`. This is the formal statement of "the SplitMix64 generator is
advanced exactly once per event." It holds definitionally — it is the recursion
equation of `iter` — which is why it can be a `simp` lemma that drives the other
proofs. This is the Lean counterpart of the Haskell invariant that the seed
advances once per event regardless of which rule fired.

### `iter_add` — consumption is additive (and so deterministic)

```lean
theorem iter_add (f : UInt64 → UInt64) (m n : Nat) (s : UInt64) :
    iter f (m + n) s = iter f n (iter f m s) := by
  induction m generalizing s with
  | zero => simp
  | succ k ih => simp [Nat.succ_add, ih]
```

Operationally: iterating `m + n` times equals iterating `m` times and then `n`
more times from wherever that landed. Splitting an event trace in two and
processing the halves in sequence lands on the same state as processing the whole
trace at once. The keystream depends only on *how many* steps have been taken,
never on how the trace was chunked. This is proved by induction on `m` with the
step function `f` kept abstract — no `UInt64` arithmetic is ever forced.

### `advance_add` — keystream determinism

```lean
theorem advance_add (m n : Nat) (s : UInt64) :
    advance (m + n) s = advance n (advance m s) := iter_add _ m n s
```

Operationally: this is `iter_add` specialized to the real SplitMix64
state-advance step. Two runs that process the same number of events from the same
seed reach the same keystream state, and a run can be resumed from a checkpoint
mid-trace without drift. This is the determinism guarantee that replay and the
chaos oracle depend on: same policy + same seed + same event trace ⇒ same
decisions. It is a one-line corollary of `iter_add`, so determinism of the
concrete keystream follows for free from the abstract additivity lemma.

## The scheduler layer

On top of the keystream, the verified core now models the whole scheduler:
targeting (`matches`), the probability gate, first-match selection (`choose`), the
single-event `step`, and the trace-level `schedule`. The Lean port lives in
[`lean/Rechaos/Scheduler.lean`](../lean/Rechaos/Scheduler.lean) over the type port
in [`lean/Rechaos/Types.lean`](../lean/Rechaos/Types.lean), and is faithful to the
Haskell reference [`src/Rechaos/Core/Scheduler.hs`](../src/Rechaos/Core/Scheduler.hs).

The same discipline as the keystream holds: **the Haskell reference leads**. All
concrete behaviour (the exact probability-gate arithmetic and the full
first-match decisions) is pinned to the reference by corpora that
`scripts/gen-conformance.hs` generates *by running the real Haskell functions*,
and that both sides re-verify. The abstract first-match *selection law* is proved
in Lean by structural induction, needing no corpus.

### Definition map: Haskell → Lean (scheduler)

| Concept | Haskell (`Rechaos.Core.Scheduler`) | Lean (`Rechaos.Scheduler`) |
|---|---|---|
| Target predicate | `matches :: Target -> Event -> Bool` | `matches_target (tgt : Target) (evt : Event) : Bool` |
| Probability gate | `draw \`mod\` ppmDenominator < chancePpm` (in `step`) | `fires (chance_ppm : Nat) (draw : UInt64) : Bool` |
| First-match selection | `choose` (nested in `step`) | `choose (rules : List rule) (draw : UInt64) (evt : Event) : Option Fault` |
| One decision | `step :: [Rule] -> Word64 -> Event -> (Word64, Decision)` | `step (rules) (state : UInt64) (evt : Event) : UInt64 × decision` |
| Whole trace | `schedule :: Policy -> [Event] -> Timeline` | `schedule (policy : policy) (events : List Event) : timeline` |

`matches` is a reserved keyword in Lean, so the port names it `matches_target`; the
behaviour is identical. The draw is the SplitMix64 *output* half — Haskell `snd`,
Lean `.1` — and the seed advances by the *state* half (`fst` / `.2`) exactly once
per event, whether or not any rule matched.

### Proved in Lean (abstract, no corpus)

These are in `lean/Rechaos/Scheduler.lean`, proved by structural induction with no
`UInt64` arithmetic forced in the kernel:

- **first-match SELECTION** — the heart of the layer:
  - `choose_nil` — no rules ⇒ no injection.
  - `choose_skips_nonmatching` — a leading rule whose target misses is transparent;
    selection continues with the tail.
  - `choose_first_match` — when the leading rule's target matches, the outcome is
    decided entirely by that rule's gate; the tail is never consulted.
  - `choose_first_match_fires` / `choose_first_match_shut` — the sharp corollaries:
    a matching head that fires injects *its* fault; a matching head that stays shut
    passes through (and still does not fall through to the tail).
  - `choose_head_owns_independent_of_tail` — "the first matching rule owns the
    event": if the head matches, swapping the entire tail leaves the decision
    unchanged. This rules out accidental fallthrough to a lower-priority rule.
- **gate endpoints** — `fires_zero_never` (0 ppm never fires, any draw) and
  `fires_full_always` (`ppm_denominator` ppm always fires, any draw), both abstract
  over the draw.
- **step / schedule structure** — `step_advances_once` (one state-advance per
  event, regardless of match), `step_preserves_event`, `step_injection_eq_choose`,
  `step_nil_passthrough`, `schedule_length` / `scheduleFrom_length` (exactly one
  decision per event), and `schedule_events` / `scheduleFrom_events` (decisions are
  made for exactly the input trace, in order).

### Reference-leads differential (corpus, `native_decide`)

`scripts/gen-conformance.hs` runs the real Haskell `step` / `schedule` and emits
two corpora, each as a JSON golden *and* as Lean terms in
[`lean/Rechaos/SchedulerCorpus.lean`](../lean/Rechaos/SchedulerCorpus.lean):

- **probability gate** — `test/golden/gate.jsonl` rows `[seed, chancePpm, fires?]`
  over every keystream seed × a ppm ladder that straddles the midpoint (so the
  strict `<` is exercised on both sides). The Lean theorem
  `fires_conforms_on_gate_scope` checks, by `native_decide`, that
  `fires chance_ppm (next_seed seed).1` reproduces the reference `fires?` on every
  row. This is the subtle arithmetic differential.
- **scheduler decisions** — `test/golden/decisions.jsonl`, a byte snapshot of the
  reference `schedule` over a scope of nine policies (empty, always/never, several
  first-match shadowing pairs, predicate-gated rules) against a six-event trace
  spanning both directions, occurrences, present/absent blobs and the elapsed-time
  boundary. The Lean theorem `schedule_conforms_on_decision_scope` checks, by
  `native_decide`, that the Lean `schedule` produces exactly the reference's
  injected-fault list for every case.

On the Haskell side, `CoreSpec.hs`'s golden-snapshot block re-derives both corpora
from the reference and fails if the committed bytes/rows do not reproduce (the gate
corpus row-by-row through `step`; the decisions corpus byte-for-byte through
`schedule`). The goldens are listed in `rechaos.cabal`'s `extra-source-files` so an
unpacked `cabal sdist` can read them. Both goldens are regenerated — alongside the
SplitMix64 corpus and the Lean files — by `scripts/gen-conformance.hs`.

The Lean scheduler is therefore **differentially conformant to the reference** on
both the probability gate and the full first-match decisions over the committed
scope, and the first-match selection semantics is additionally proved abstractly
for all rule lists, draws, and events.

## The output-tree oracle layer

On top of the scheduler, the verified core now also models the **equivalence
oracle**: the judgement that decides whether two builds produced the same outputs.
The Lean port lives in [`lean/Rechaos/Oracle.lean`](../lean/Rechaos/Oracle.lean)
and is faithful to the Haskell reference
[`src/Rechaos/Core/Oracle.hs`](../src/Rechaos/Core/Oracle.hs).

The same discipline holds: **the Haskell reference leads**. The concrete
diff/verdict behaviour is pinned to the reference by a corpus that
`scripts/gen-conformance.hs` generates *by running the real Haskell
`compareBuilds`*; the equivalence-relation algebra is proved in Lean abstractly,
needing no corpus.

### Definition map: Haskell → Lean (oracle)

| Concept | Haskell (`Rechaos.Core.Oracle`) | Lean (`Rechaos.Oracle`) |
|---|---|---|
| Output-tree node | `Entry = File Text Natural Bool \| Symlink Text \| Directory` | `entry.file (contentHash) (sizeBytes) (executable) \| entry.symlink (target) \| entry.directory` |
| Output tree | `type Tree = Map Text Entry` | `abbrev tree := List (String × entry)` (sorted by key) |
| Per-path difference | `Change Text (Maybe Entry) (Maybe Entry)` | `structure change { path, before, after }` |
| Build outcome | `BuildResult = Built Tree \| BuildFailed Text \| BuildTimedOut` | `build_result.built \| .buildFailed \| .buildTimedOut` |
| Verdict | `Verdict = Equivalent \| Diverged [Change] \| Inconclusive` | `verdict.equivalent \| .diverged (changes) \| .inconclusive` |
| Canonical difference | `diff :: Tree -> Tree -> [Change]` | `diff : tree → tree → List change` |
| Null-diff equivalence | `equivalent a b = null (diff a b)` | `equivalent a b := diff a b == []` |
| Build verdict | `compareBuilds :: BuildResult -> BuildResult -> Verdict` | `compare_builds : build_result → build_result → verdict` |

The Haskell `Tree` is a `Data.Map Text Entry` whose `diff` iterates the union of
both trees' keys in ascending order (`S.toAscList (keysSet a ∪ keysSet b)`). The
Lean `tree` is a `List (String × entry)` kept in ascending key order, and the Lean
`diff` is the matching key-ordered merge: on equal keys it compares entries, and on
unequal keys it emits the lesser-keyed side first. Over a sorted assoc list this
produces exactly the reference's canonical, ascending, one-`Change`-per-path output.
Equivalence is the null-diff criterion on both sides, and `compareBuilds` renders
`Equivalent` / `Diverged` on two successful builds and `Inconclusive` whenever
either build did not succeed — identical to the reference.

### Proved in Lean (abstract, no corpus)

These are in `lean/Rechaos/Oracle.lean`, proved over core Lean (no Mathlib, no
`UInt64` arithmetic) by structural induction — establishing that `equivalent` is a
genuine **equivalence relation** together with the empty-diff criterion:

- `diff_nil_iff_equivalent` — **the empty-diff criterion**: `diff a b = []` iff
  `equivalent a b`. Holds definitionally, since `equivalent` *is* the null-diff test.
- `diff_self_nil` / `equivalent_refl` — **reflexivity**: a tree never differs from
  itself, so every tree is equivalent to itself.
- `diff_nil_imp_eq` — the structural crux: a null diff forces the two argument
  lists to coincide (the merge returns `[]` only when it consumed both inputs in
  lockstep on equal keys with equal entries). This needs no key-ordering lemmas,
  only that each unequal-key branch emits a leading `change`.
- `equivalent_symm` — **symmetry**: `equivalent a b = equivalent b a`, routed
  entirely through `diff_nil_imp_eq` and `diff_self_nil` (no antisymmetry of the key
  order is required).
- `equivalent_trans` — **transitivity**: `a ≡ b` and `b ≡ c` give `a ≡ c`, because
  a null diff collapses to list equality, which composes.

### Reference-leads differential (corpus, `native_decide`)

`scripts/gen-conformance.hs` runs the real Haskell `compareBuilds` and emits the
oracle corpus as a JSON golden *and* as Lean terms in
[`lean/Rechaos/OracleCorpus.lean`](../lean/Rechaos/OracleCorpus.lean):

- **output-tree oracle** — `test/golden/oracle.jsonl`, one row per `(treeA, treeB)`
  over a scope spanning identity, additions, deletions, content-hash/size/
  executable-bit changes, symlink-target changes, kind changes (file ↔ directory ↔
  symlink), empty-vs-nonempty, disjoint key sets, and multi-path diffs whose changes
  must land in ascending key order. Each row carries the reference `Verdict`
  (equivalence, or divergence with the full canonical change list). The Lean theorem
  `compare_builds_conforms_on_oracle_scope` checks, by `native_decide`, that the Lean
  `compare_builds` reproduces exactly the reference verdict — change list and all —
  on every case.

On the Haskell side, `CoreSpec.hs`'s golden-snapshot block re-derives the oracle
corpus from the reference and fails if the committed bytes do not reproduce
(byte-for-byte through `compareBuilds`). The golden is listed in `rechaos.cabal`'s
`extra-source-files` so an unpacked `cabal sdist` can read it, and it is regenerated
— alongside the SplitMix64, gate, and decisions corpora and the Lean files — by
`scripts/gen-conformance.hs`.

The Lean oracle is therefore **differentially conformant to the reference** on the
full diff/verdict behaviour over the committed scope, and the equivalence-relation
laws (reflexivity, symmetry, transitivity) plus the empty-diff criterion are
additionally proved abstractly for all trees.

## The minimizer layer

On top of the oracle, the verified core now also models the **minimizer**
(shrinker): the witness-preserving search that reduces a failing `Timeline` to a
small reproducer. The Lean port lives in
[`lean/Rechaos/Minimize.lean`](../lean/Rechaos/Minimize.lean) and is faithful to
the Haskell reference
[`src/Rechaos/Core/Minimize.hs`](../src/Rechaos/Core/Minimize.hs).

The same discipline holds: **the Haskell reference leads**. The concrete candidate
set and one acceptance-driven shrink trajectory are pinned to the reference by a
corpus that `scripts/gen-conformance.hs` generates *by running the real Haskell
`candidates`/`start`/`observe`*; the two load-bearing properties — candidate
**termination** and acceptance **witness preservation** — are proved in Lean
abstractly, needing no corpus.

### Definition map: Haskell → Lean (minimizer)

| Concept | Haskell (`Rechaos.Core.Minimize`) | Lean (`Rechaos.Minimize`) |
|---|---|---|
| Shell verdict | `Verdict = Triggers \| DoesNotTrigger \| Unknown` | `minimize_verdict.triggers \| .doesNotTrigger \| .unknown` |
| Minimizer state | `ShrinkState { best :: Timeline, pending :: [Timeline] }` | `structure shrink_state { best, pending }` |
| Seed from a failure | `start :: Timeline -> ShrinkState` | `start : timeline → shrink_state` |
| Next candidate | `candidate :: ShrinkState -> Maybe Timeline` | `candidate : shrink_state → Option timeline` |
| Fold a verdict in | `observe :: Verdict -> ShrinkState -> ShrinkState` | `observe : minimize_verdict → shrink_state → shrink_state` |
| Candidate set | `candidates :: Timeline -> [Timeline]` | `candidates : timeline → List timeline` |
| Strictly-weaker fault | `weaker :: Event -> Fault -> [Fault]` | `weaker : Event → Fault → List Fault` |

`candidates` offers chunk deletions at halving sizes down to singletons (making a
converged result deletion-1-minimal for a deterministic predicate) plus intensity
reductions that replace one injected fault with a strictly weaker one. The Lean
port reproduces the reference `nub (deletions ++ intensities)` set exactly: the
halving `descending` sweep and the `[0, k .. n-1]` stride are rendered as
fuel-bounded structural recursions (`descending`, `stride_offsets`), and `weaker`
matches branch-for-branch — `delay` halves toward zero, `dribble` doubles its rate
toward the full-speed cap `messageBytes * microsPerSecond`, `truncate` raises its
kept-byte count toward the message size, and `abort` has no weaker form. `observe`
accepts a candidate — advancing `best` and re-seeding `pending` from the smaller
timeline — **only** on `triggers`; `doesNotTrigger` and `unknown` both discard it,
so a flake/timeout is never mistaken for a reproduction.

### Proved in Lean (abstract, no corpus)

These are in `lean/Rechaos/Minimize.lean`, proved over core Lean (no Mathlib, no
`UInt64` arithmetic — every intensity quantity is `Nat`):

- `weaker_severity_lt` — **the termination engine**: every fault `weaker` emits is
  strictly weaker at its anchoring event under the `severity` measure (`delay`
  micros, bytes dropped below the message for `truncate`, rate below the cap for
  `dribble`). Proved by cases on the fault with each branch's numeric
  side-condition.
- `summed_intensity_append` / `summed_intensity_singleton` — additivity of the
  summed-intensity measure over the `take ++ [replacement] ++ drop` splice the
  intensity candidates perform.
- `deletion_length_lt` — a nonempty contiguous deletion strictly shrinks the
  length, hence the measure. Together with `weaker_severity_lt` this is
  **TERMINATION**: every generated candidate is strictly smaller than its input
  under the well-founded `(length, summed-intensity)` measure (`measure` /
  `measure_lt`), so the shrink loop terminates.
- `observe_best_triggers` — **WITNESS PRESERVATION**: `observe` advances `best` to
  a new timeline only on a `triggers` verdict, and the new `best` is exactly the
  candidate the external checker reported `triggers` on. Given a truthful checker,
  every accepted `best` is a confirmed reproduction.
- `observe_unknown_preserves_best` / `observe_unknown_eq_does_not_trigger` — the
  **conservative** half: an `unknown` verdict never advances `best` and is
  observationally identical to `doesNotTrigger`.

### Reference-leads differential (corpus, `native_decide`)

`scripts/gen-conformance.hs` runs the real Haskell minimizer and emits the corpus
as a JSON golden *and* as Lean terms in
[`lean/Rechaos/MinimizeCorpus.lean`](../lean/Rechaos/MinimizeCorpus.lean):

- **candidate generation** — `test/golden/minimize.jsonl` (first block), one row
  per input `Timeline` over a scope spanning the empty timeline, single faults of
  every intensity-bearing constructor at interior and boundary (cap) values,
  `abort` (no weaker form), passthrough (`Nothing`) decisions, and multi-fault
  timelines. Each row carries the reference `candidates` set. The Lean theorem
  `candidates_conforms_on_candidate_scope` checks, by `native_decide`, that the Lean
  `candidates` reproduces that set exactly on every case.
- **acceptance trajectory** — `test/golden/minimize.jsonl` (second block), one row
  per `(timeline, threshold)` seed driven to convergence by `start`/`candidate`/
  `observe` under a deterministic oracle (a candidate triggers iff it retains a
  `delay` of at least `threshold` micros). Each row carries the converged `best`.
  The Lean theorem `run_shrink_conforms_on_trajectory_scope` ports the same
  deterministic oracle and fuel-bounded driver and checks, by `native_decide`, that
  the Lean minimizer shrinks to exactly the reference `best`.

On the Haskell side, `CoreSpec.hs`'s golden-snapshot block re-derives both corpus
blocks from the reference and fails if the committed bytes do not reproduce. The
golden is listed in `rechaos.cabal`'s `extra-source-files`, and it is regenerated —
alongside the other corpora and Lean files — by `scripts/gen-conformance.hs`.

The Lean minimizer is therefore **differentially conformant to the reference** on
both candidate generation and the acceptance state machine over the committed
scope, and termination plus witness preservation are additionally proved abstractly
for all timelines.

## The replay layer

On top of the minimizer, the verified core now also models the **replay** checks —
the last piece of the determinism contract. Replay is what turns a recorded
timeline into a reproducible witness: re-observing the same events must reproduce
exactly the decisions that were recorded. The Lean port lives in
[`lean/Rechaos/Replay.lean`](../lean/Rechaos/Replay.lean) and is faithful to the
Haskell reference `validateTimeline` / `replayDecision` / `verifyReplay` in
[`src/Rechaos/Core/Scheduler.hs`](../src/Rechaos/Core/Scheduler.hs).

The same discipline holds: **the Haskell reference leads**. The concrete replay
verdicts and per-event outcomes are pinned to the reference by a corpus that
`scripts/gen-conformance.hs` generates *by running the real Haskell
`verifyReplay`/`replayDecision`*; the three load-bearing properties — replay
**identity** (round-trip), **fail-closed** (a changed fingerprint rejects), and
**coverage** (a missing recorded event rejects) — are proved in Lean abstractly,
needing no corpus.

### Definition map: Haskell → Lean (replay)

| Concept | Haskell (`Rechaos.Core.Scheduler`) | Lean (`Rechaos.Replay`) |
|---|---|---|
| Indexed timeline | `Data.Map EventKey Decision` | `abbrev event_table := List (EventKey × decision)` (distinct keys) |
| Build / validate | `validateTimeline :: Timeline -> Either Text (Map EventKey Decision)` | `validate_timeline : timeline → Option event_table` |
| Single-event replay | `replayDecision :: Bool -> Map … -> Event -> Either Text Decision` | `replay_decision (sparse) (table) (evt) : replay_outcome` |
| Replay outcome | `Either Text Decision` (`Left`=reject, `Right`=apply) | `replay_outcome.rejected \| .decided (decision)` |
| Coverage check | `verifyReplay :: Timeline -> Timeline -> Either Text ()` | `verify_replay (expected observed) : Bool` |
| Elapsed-agnostic equality | `sameEvent` (via `fingerprint`) | `sameEvent` (via `fingerprint`, in `Types.lean`) |

The Haskell indexes a timeline with a `Data.Map`, whose insert guard rejects a
repeated event identity; the Lean `validate_timeline` builds an association list and
rejects a repeated key with the matching `tableMember` guard, so it fails on exactly
the same ill-formed timelines. Because both observable replay operations — key
lookup and the coverage conjunction — are independent of association order once keys
are unique, the association-list port is behaviourally faithful to the map. The
`sparse` flag selects the same semantics as the reference: a full recording
(`false`) fails closed on any event missing from the table, a sparse fault timeline
(`true`) passes unlisted traffic through, and either way a present event must still
match its recorded `fingerprint` (via `sameEvent`, which ignores only arrival time)
or replay is rejected. `verifyReplay` is the forward-inclusion coverage check:
every recorded event must have been observed, unchanged, with an identical
injection, so an incomplete replay is rejected even when nothing observed
mismatched. The `Either Text ()` verdict is modelled as a `Bool` (`true` = `Right
()`, `false` = `Left _`); since success is a conjunction over all recorded events
and failure is any single miss, the boolean verdict is order-independent and
faithful.

### Proved in Lean (abstract, no corpus)

These are in `lean/Rechaos/Replay.lean`, proved over core Lean (no Mathlib, no
`UInt64` arithmetic) by structural induction over the table:

- `validate_timeline_nodup` / `validate_timeline_key_agree` — the **validated-table
  invariants**: a validated table has distinct keys, and every binding is keyed by
  its own event's `eventKey`. Proved by threading each invariant through the
  `validate_timeline.go` accumulator (the duplicate guard `tableMember` never inserts
  a key already present). `lookup_of_mem_nodup` then shows that in a distinct-key
  table every binding looks itself up.
- `verify_replay_identity` — **REPLAY IDENTITY** (the prize): any timeline that
  validates verifies against itself (`verify_replay t t = true`). Replaying a
  recording against the very events it recorded always succeeds — every recorded
  event is observed, unchanged, with its recorded injection.
  `replay_decision_recorded_identity` is the single-decision form (a recorded
  decision replays to exactly itself), and `verify_replay_schedule_identity`
  specializes the trace-level result to `schedule policy events`: when the scheduled
  timeline validates (its events carry distinct identities), replaying it against
  itself reproduces exactly those decisions. This is the round-trip that closes the
  determinism contract.
- `replay_decision_rejects_changed_fingerprint` / `verify_replay_changed_rejected` —
  **FAIL-CLOSED**: a recorded event re-observed with a *different* payload
  fingerprint is rejected, both at the single-event level and through the
  trace-level coverage check. A changed recording is never silently accepted.
  `replay_decision_reuses_recorded_injection` is the positive counterpart: a matching
  fingerprint (even with a fresh arrival time) reuses the recorded injection.
- `verify_replay_missing_rejected` / `verify_replay_empty_observed_rejected` —
  **COVERAGE**: a recorded event that never arrived rejects the replay — the general
  form (any recorded key absent from the observed table) and the sharp form (a
  nonempty recording replayed against an empty observed timeline).

### Reference-leads differential (corpus, `native_decide`)

`scripts/gen-conformance.hs` runs the real Haskell `verifyReplay`/`replayDecision`
and emits the replay corpus as a JSON golden *and* as Lean terms in
[`lean/Rechaos/ReplayCorpus.lean`](../lean/Rechaos/ReplayCorpus.lean):

- **coverage verdicts** — `test/golden/replay.jsonl` (first block), one row per
  `(expected, observed)` pair over a scope spanning an exact match, an
  arrival-time-only perturbation (must still verify, since `sameEvent` ignores
  elapsed time), a changed-fingerprint case (must be **rejected**), a missing-event
  case (coverage must **reject**), an extra observed pass-through (tolerated by the
  forward check), and a changed-injection case (must be **rejected**). Each row
  carries the reference `verifyReplay` verdict. The Lean theorem
  `verify_replay_conforms_on_replay_scope` checks, by `native_decide`, that the Lean
  `verify_replay` reproduces every verdict.
- **per-event replay outcomes** — `test/golden/replay.jsonl` (second block), one row
  per `(sparse?, event)` probe of `replayDecision` against the recorded
  `replayExpected` table, under both the full and sparse semantics, over a recorded
  pass-through (new arrival time), a recorded injection (new arrival time), a changed
  fingerprint, and an unrecorded event. Each row carries the reference outcome
  (`rejected`, or `decided` with the reused injection). The Lean theorem
  `replay_decision_conforms_on_replay_probe_scope` checks, by `native_decide`, that the
  Lean `replay_decision` reproduces every outcome — reusing the recorded injection on
  a matching fingerprint, failing closed on a changed one, and splitting the
  missing-event case by `sparse` (full rejects, sparse passes through).

On the Haskell side, `CoreSpec.hs`'s golden-snapshot block re-derives both corpus
blocks from the reference and fails if the committed bytes do not reproduce
(byte-for-byte through `verifyReplay`/`replayDecision`). The golden is listed in
`rechaos.cabal`'s `extra-source-files`, and it is regenerated — alongside the other
corpora and Lean files — by `scripts/gen-conformance.hs`.

The Lean replay layer is therefore **differentially conformant to the reference** on
both the coverage verdicts and the per-event replay outcomes over the committed
scope, and replay identity, fail-closed, and coverage are additionally proved
abstractly for all validatable timelines.

## Machine-checked in Lean vs. QuickCheck-only in Haskell

It is important to be precise about the boundary between what the Lean kernel has
*proved* and what the Haskell test suite only *samples*.

**Machine-checked in Lean** (`lean/Rechaos/Core.lean`): the structural keystream
laws — `iter_zero`, `iter_succ`, `iter_add`, and `advance_add`. These are
universally quantified over all iteration counts and all seeds and are verified by
the kernel, not by examples.

**Only a QuickCheck property in `test/CoreSpec.hs`** (not yet a Lean theorem):

- The SplitMix64 golden test vectors — `snd (nextSeed 0) == 0xe220a8397b1dcdaf`
  and `snd (nextSeed 0x9e3779b97f4a7c15) == 0x6e789e6aa1b965f4` (invariants (D)).
  These pin the *concrete output bits*, which the Lean proofs deliberately avoid
  evaluating.
- "state advance is exactly the golden-ratio increment, independent of output"
  (`fst (nextSeed s) == s + 0x9e3779b97f4a7c15`) — checked on sampled seeds only.
- Injectivity of the advance step over a sampled seed range (invariant (D)) —
  a bounded sample, not a universal proof.
- The seed-advance invariants (G): that `foldl` over `step` equals
  `iterate (fst . nextSeed) s !! n`, and that a nonmatching/absent rule advances
  the seed identically to a match. The Lean `iter`/`advance` model *captures the
  abstract shape* of this claim; the Lean `Scheduler` port now additionally
  proves the single-step `step_advances_once` and the `schedule_length` /
  `schedule_events` structure, and pins the concrete first-match decisions to the
  reference via the `native_decide` corpora (see "The scheduler layer" above). The
  exact bit-level tie between `iterate (fst . nextSeed)` and the production fold is
  still exercised by QuickCheck.
- The output-tree oracle's equivalence/transitivity are **now also proved in Lean**
  (`lean/Rechaos/Oracle.lean`: `equivalent_refl` / `equivalent_symm` /
  `equivalent_trans` / `diff_nil_iff_equivalent`), and the concrete diff/verdict
  behaviour is pinned to the reference by the `native_decide` corpus
  `compare_builds_conforms_on_oracle_scope` (see "The output-tree oracle layer"
  above). The QuickCheck properties over `diff`/`compareBuilds` in `CoreSpec.hs`
  remain as an independent sampled check on the reference itself.
- The minimizer's candidate generation and acceptance state machine are **now also
  proved/pinned in Lean** (`lean/Rechaos/Minimize.lean`): termination under the
  `(length, summed-intensity)` measure (`weaker_severity_lt` / `deletion_length_lt`)
  and witness preservation (`observe_best_triggers`, with the conservative
  `observe_unknown_*` lemmas) are proved abstractly, and the concrete candidate
  set + one shrink trajectory are pinned to the reference by the `native_decide`
  corpora `candidates_conforms_on_candidate_scope` and
  `run_shrink_conforms_on_trajectory_scope` (see "The minimizer layer" above). The
  QuickCheck properties over `candidates`/`observe` in `CoreSpec.hs` (including
  deletion-1-minimality of a converged result) remain as an independent sampled
  check on the reference itself.
- The replay checks — `validateTimeline` / `replayDecision` / `verifyReplay` — are
  **now also proved/pinned in Lean** (`lean/Rechaos/Replay.lean`): replay identity
  (`verify_replay_identity`, with `verify_replay_schedule_identity` and the
  single-decision `replay_decision_recorded_identity`), fail-closed
  (`replay_decision_rejects_changed_fingerprint` / `verify_replay_changed_rejected`),
  and coverage (`verify_replay_missing_rejected` /
  `verify_replay_empty_observed_rejected`) are proved abstractly, and the concrete
  verdicts + per-event outcomes are pinned to the reference by the `native_decide`
  corpora `verify_replay_conforms_on_replay_scope` and
  `replay_decision_conforms_on_replay_probe_scope` (see "The replay layer" above). The
  QuickCheck properties over replay's incomplete-vs-changed semantics in
  `CoreSpec.hs` remain as an independent sampled check on the reference itself.
- Everything else outside the keystream: the status-code bijection, dribble pacing,
  and JSON round-trips. These live entirely in `CoreSpec.hs` and have no Lean
  counterpart today.

In short: Lean proves that the keystream *is a deterministic, additive iteration
of a single step per event*; QuickCheck checks that the *concrete SplitMix64 step*
has the exact bits and injectivity we expect, and that the production `step`/
`schedule` functions actually realize that iteration.

**Every pure-core layer is now machine-checked with the reference generating each
corpus.** The five layers of the verified core — the SplitMix64 **keystream**
(`Core.lean`), the **scheduler** (`Scheduler.lean`), the output-tree **oracle**
(`Oracle.lean`), the **minimizer** (`Minimize.lean`), and now the **replay** checks
(`Replay.lean`) — each ship a faithful Lean port, a set of abstract theorems proved
by the kernel, and a `native_decide` conformance theorem against a corpus that
`scripts/gen-conformance.hs` generates *by running the real Haskell reference*. The
same reference-leads discipline runs end to end: the Haskell implementation is the
authority, every corpus is generated from it, and both the Lean kernel and the
Haskell `CoreSpec` golden-snapshot block re-verify it. The Lean structural laws are proved, while correspondence with Haskell is
checked on finite corpora and sampled properties. Neither those checks nor
shared constants prove end-to-end equivalence of the Haskell implementation,
IO shell, and Lean models. `native_decide` corpus checks also trust Lean's native
evaluation machinery. A fixed seed does not fix a live server's event trace.

## The no-sorry policy

The verified core admits no proof holes. Specifically:

- **zero `sorry`** and **zero `admit`** — every theorem is closed by a real
  proof the kernel accepts.
- **no new `axiom`** — the proofs rest only on core Lean (there is no Mathlib
  dependency). Corpus checks using `native_decide` have the trust boundary
  described above; this policy forbids adding project-specific assumptions.
- **no forced `UInt64` evaluation** — theorems are kept structural and abstract
  over the step function so the kernel never deep-recurses over 64-bit numerals.

This can be checked mechanically:

```sh
python3 scripts/check_lean.py lean    # rejects proof-hole tokens and new axioms
```

The guard ignores line comments, nested block comments, and string literals,
so documentation mentions are allowed. It rejects `sorry`, `admit`, and `axiom`
tokens in source code; `lake build` separately checks elaboration and proofs
with `warningAsError=true`, so elaborator warnings about proof holes fail too.

## How to build

```sh
cd lean && lake build
```

A successful run reports `Build completed successfully` and exits `0`. The project
targets Lean 4.31, available in this repo's environment via:

```sh
nix shell nixpkgs#lean4 --command lake build
```

The Lean build is **gated by CI**: `nix flake check` runs it, so a change that
breaks the proofs (or introduces a `sorry`/`admit`/`axiom`) fails the flake check
and cannot merge.
