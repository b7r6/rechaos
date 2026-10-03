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
  abstract shape* of this claim, but the specific tie between the Haskell `step`
  function, first-match targeting, and `iter` is exercised only by QuickCheck.
- Everything outside the keystream: the status-code bijection, dribble pacing,
  shrinker 1-minimality, oracle equivalence/transitivity, replay
  incomplete-vs-changed semantics, and JSON round-trips. These live entirely in
  `CoreSpec.hs` and have no Lean counterpart today.

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
