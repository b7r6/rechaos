/-
  rechaos — determinism of the keystream (foundation, part two).

  Building on `Rechaos.Core`, we prove further *structural* facts about the
  iteration that backs the scheduler keystream. As in `Core.lean`, every lemma
  is kept abstract over the step function `f`, so the kernel never forces any
  `UInt64` arithmetic — the proofs are definitional or by induction on `Nat`.
  There is no `sorry`, no `admit`, and no new `axiom`.
-/

import Rechaos.Core

namespace Rechaos

/-- Zero advancement is the identity on the state. Together with `advance_add`
    this makes `advance` a monoid action of `(Nat, +, 0)` on the seed. -/
@[simp]
theorem advance_zero (s : UInt64) : advance 0 s = s := rfl

/-- Determinism restatement: two runs that advance the state by the *same* count
    from the *same* start produce the *same* keystream state. This is what
    "deterministic scheduling" means operationally — the result is a pure
    function of `(n, s)`, so equal inputs give equal outputs. -/
theorem advance_deterministic (n : Nat) (s t : UInt64) (h : s = t) : advance n s = advance n t := by
  rw [h]

/-- Another determinism restatement, phrased via `iter`: iterating the same step
    the same number of times from equal states yields equal results. -/
theorem iter_deterministic
        (f : UInt64 → UInt64)
        (n : Nat)
        (s t : UInt64)
        (h : s = t)
        : iter f n s = iter f n t := by rw [h]

/-- Pulling one step out on the *right*: iterating `n + 1` times equals applying
    `f` once to the `n`-fold iterate. Complements the definitional `iter_succ`
    (which peels a step off the left) and is proved from `iter_add`. -/
theorem iter_succ_right
        (f : UInt64 → UInt64)
        (n : Nat)
        (s : UInt64)
        : iter f (n + 1) s = f (iter f n s) := by
  have h := iter_add f n 1 s
  simpa using h

/-- A list-driven fold: advance the seed one keystream step per event in `xs`.
    The event payloads are irrelevant to *how many* steps are consumed — exactly
    one per element — which is the property we verify below. Abstract over the
    event type `α` and the step `f`. -/
def fold_steps (f : UInt64 → UInt64) : List α → UInt64 → UInt64
  | [], s      => s
  | _ :: xs, s => fold_steps f xs (f s)

@[simp]
theorem fold_steps_nil (f : UInt64 → UInt64) (s : UInt64) : fold_steps (α := α) f [] s = s := rfl

@[simp]
theorem fold_steps_cons
        (f : UInt64 → UInt64)
        (x : α)
        (xs : List α)
        (s : UInt64)
        : fold_steps f (x :: xs) s = fold_steps f xs (f s) :=
  rfl

/-- The key accounting lemma: folding the step across a list consumes *exactly*
    `xs.length` steps — i.e. it coincides with iterating `xs.length` times. The
    event payloads drop out entirely; only the length matters. Proved by
    induction on the list, with the step `f` abstract (no `UInt64` evaluation). -/
theorem fold_steps_eq_iter
        (f : UInt64 → UInt64)
        (xs : List α)
        (s : UInt64)
        : fold_steps f xs s = iter f xs.length s := by
  induction xs generalizing s with
  | nil => simp
  | cons x xs ih => simp [ih]

/-- Specialised to the real keystream step: consuming a list of events advances
    the SplitMix64 state by exactly `xs.length`. This directly justifies the
    "one step per observed event" invariant of the scheduler. -/
theorem fold_steps_advance
        (xs : List α)
        (s : UInt64)
        : fold_steps (fun s => (next_seed s).2) xs s = advance xs.length s :=
  fold_steps_eq_iter _ xs s

/-- Determinism of the fold: equal start states give equal folded results,
    regardless of the (identical) event list. -/
theorem fold_steps_deterministic
        (f : UInt64 → UInt64)
        (xs : List α)
        (s t : UInt64)
        (h : s = t)
        : fold_steps f xs s = fold_steps f xs t := by rw [h]

/-- Concatenating event lists sums their step consumption: folding over `xs ++ ys`
    is folding over `ys` after folding over `xs`. The combination of this with
    `foldSteps_eq_iter` re-derives `iter_add`-style additivity at the list level. -/
theorem fold_steps_append
        (f : UInt64 → UInt64)
        (xs ys : List α)
        (s : UInt64)
        : fold_steps f (xs ++ ys) s = fold_steps f ys (fold_steps f xs s) := by
  induction xs generalizing s with
  | nil => simp
  | cons x xs ih => simp [ih]

end Rechaos
