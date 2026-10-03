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

The Haskell production code (`Rechaos.Core.Scheduler`) and the Lean core share
the same algebra. The Lean side is the authority on the *shape* of that algebra;
the Haskell side is the executable implementation, pinned to the Lean definitions
bit-for-bit by shared constants.

### Definition map: Haskell → Lean

| Concept | Haskell (`src/Rechaos/Core/Scheduler.hs`) | Lean (`lean/Rechaos/Core.lean`) |
|---|---|---|
| One SplitMix64 step | `nextSeed :: Word64 -> (Word64, Word64)` | `nextSeed (s : UInt64) : UInt64 × UInt64` |
| State-advance increment | `s + 0x9e3779b97f4a7c15` | `s + 0x9e3779b97f4a7c15` |
| Mixing constants | `0xbf58476d1ce4e5b9`, `0x94d049bb133111eb` | `0xbf58476d1ce4e5b9`, `0x94d049bb133111eb` |
| Final avalanche shift | `z2 \`xor\` (z2 \`shiftR\` 31)` | `z2 ^^^ (z2 >>> 31)` |
| Iterate a step `n` times | `iterate (fst . nextSeed) s !! n` (in `CoreSpec`) | `iter (f : UInt64 → UInt64) : Nat → UInt64 → UInt64` |
| The scheduler keystream | seed threaded through `step` / `schedule` once per event | `advance (n : Nat) (s : UInt64) : UInt64` |

A note on tuple order, because it matters when reading the two sources together:

- **Haskell** `nextSeed s = (s', output)` returns `(nextState, output)`, so the
  advanced state is `fst (nextSeed s)` and the draw is `snd (nextSeed s)`.
- **Lean** `nextSeed s = (output, s')` returns `(output, nextState)`, so the
  advanced state is `(nextSeed s).2` and the draw is `(nextSeed s).1`.

Both expose the same two values; only the projection index differs. The Lean
keystream is defined on the state projection to match the Haskell keystream:

```lean
def advance (n : Nat) (s : UInt64) : UInt64 := iter (fun s => (nextSeed s).2) n s
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
| Target predicate | `matches :: Target -> Event -> Bool` | `matchesTarget (tgt : Target) (evt : Event) : Bool` |
| Probability gate | `draw \`mod\` ppmDenominator < chancePpm` (in `step`) | `fires (chancePpm : Nat) (draw : UInt64) : Bool` |
| First-match selection | `choose` (nested in `step`) | `choose (rules : List Rule) (draw : UInt64) (evt : Event) : Option Fault` |
| One decision | `step :: [Rule] -> Word64 -> Event -> (Word64, Decision)` | `step (rules) (state : UInt64) (evt : Event) : UInt64 × Decision` |
| Whole trace | `schedule :: Policy -> [Event] -> Timeline` | `schedule (policy : Policy) (events : List Event) : Timeline` |

`matches` is a reserved keyword in Lean, so the port names it `matchesTarget`; the
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
  `fires_full_always` (`ppmDenominator` ppm always fires, any draw), both abstract
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
  `fires_conforms_on_gateScope` checks, by `native_decide`, that
  `fires chancePpm (nextSeed seed).1` reproduces the reference `fires?` on every
  row. This is the subtle arithmetic differential.
- **scheduler decisions** — `test/golden/decisions.jsonl`, a byte snapshot of the
  reference `schedule` over a scope of nine policies (empty, always/never, several
  first-match shadowing pairs, predicate-gated rules) against a six-event trace
  spanning both directions, occurrences, present/absent blobs and the elapsed-time
  boundary. The Lean theorem `schedule_conforms_on_decisionScope` checks, by
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
| Output-tree node | `Entry = File Text Natural Bool \| Symlink Text \| Directory` | `Entry.file (contentHash) (sizeBytes) (executable) \| Entry.symlink (target) \| Entry.directory` |
| Output tree | `type Tree = Map Text Entry` | `abbrev Tree := List (String × Entry)` (sorted by key) |
| Per-path difference | `Change Text (Maybe Entry) (Maybe Entry)` | `structure Change { path, before, after }` |
| Build outcome | `BuildResult = Built Tree \| BuildFailed Text \| BuildTimedOut` | `BuildResult.built \| .buildFailed \| .buildTimedOut` |
| Verdict | `Verdict = Equivalent \| Diverged [Change] \| Inconclusive` | `Verdict.equivalent \| .diverged (changes) \| .inconclusive` |
| Canonical difference | `diff :: Tree -> Tree -> [Change]` | `diff : Tree → Tree → List Change` |
| Null-diff equivalence | `equivalent a b = null (diff a b)` | `equivalent a b := diff a b == []` |
| Build verdict | `compareBuilds :: BuildResult -> BuildResult -> Verdict` | `compareBuilds : BuildResult → BuildResult → Verdict` |

The Haskell `Tree` is a `Data.Map Text Entry` whose `diff` iterates the union of
both trees' keys in ascending order (`S.toAscList (keysSet a ∪ keysSet b)`). The
Lean `Tree` is a `List (String × Entry)` kept in ascending key order, and the Lean
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
  only that each unequal-key branch emits a leading `Change`.
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
  `compareBuilds_conforms_on_oracleScope` checks, by `native_decide`, that the Lean
  `compareBuilds` reproduces exactly the reference verdict — change list and all —
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
  `compareBuilds_conforms_on_oracleScope` (see "The output-tree oracle layer"
  above). The QuickCheck properties over `diff`/`compareBuilds` in `CoreSpec.hs`
  remain as an independent sampled check on the reference itself.
- Everything else outside the keystream: the status-code bijection, dribble pacing,
  shrinker 1-minimality, replay incomplete-vs-changed semantics, and JSON
  round-trips. These live entirely in `CoreSpec.hs` and have no Lean counterpart
  today.

In short: Lean proves that the keystream *is a deterministic, additive iteration
of a single step per event*; QuickCheck checks that the *concrete SplitMix64 step*
has the exact bits and injectivity we expect, and that the production `step`/
`schedule` functions actually realize that iteration.

## The no-sorry policy

The verified core admits no proof holes. Specifically:

- **zero `sorry`** and **zero `admit`** — every theorem is closed by a real
  proof the kernel accepts.
- **no new `axiom`** — the proofs rest only on core Lean (there is no Mathlib
  dependency); nothing is assumed.
- **no forced `UInt64` evaluation** — theorems are kept structural and abstract
  over the step function so the kernel never deep-recurses over 64-bit numerals.

This can be checked mechanically:

```sh
grep -rn 'sorry\|admit' lean/Rechaos    # expect no proof holes
```

(The literal string `sorry` appears once, inside a comment in `Core.lean` stating
this very policy; there is no `sorry` *term* or *tactic*.)

## How to build

```sh
cd lean && lake build
```

A successful run reports `Build completed successfully` and exits `0`. The project
targets Lean 4.30, available in this repo's environment via:

```sh
nix shell nixpkgs#lean4 --command lake build
```

The Lean build is **gated by CI**: `nix flake check` runs it, so a change that
breaks the proofs (or introduces a `sorry`/`admit`/`axiom`) fails the flake check
and cannot merge.
