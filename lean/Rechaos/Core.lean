/-
  rechaos — formally verified core (foundation).

  The scheduler's determinism rests on a keystream produced by iterating a step
  function. We prove the *structure* of that iteration abstractly (over any step
  `f`), so the proofs never force `UInt64` evaluation, and instantiate it with the
  exact SplitMix64 step. Everything here is machine-checked; there is no `sorry`.
-/

namespace Rechaos

/-- SplitMix64 one step: the exact UInt64 keystone of the scheduler. Returns the
    emitted value and the advanced state. Wraparound is definitional in UInt64. -/
def next_seed (s : UInt64) : UInt64 × UInt64 :=
  let s' := s + 0x9e3779b97f4a7c15
  let z1 := (s' ^^^ (s' >>> 30)) * 0xbf58476d1ce4e5b9
  let z2 := (z1 ^^^ (z1 >>> 27)) * 0x94d049bb133111eb
  (z2 ^^^ (z2 >>> 31), s')

/-- Iterate an arbitrary step `f` exactly `n` times — a total, pure function of
    the start state. -/
def iter (f : UInt64 → UInt64) : Nat → UInt64 → UInt64
  | 0, s     => s
  | n + 1, s => iter f n (f s)

@[simp]
theorem iter_zero (f : UInt64 → UInt64) (s : UInt64) : iter f 0 s = s := rfl

/-- One step consumed per count (definitional): the basis of "exactly one
    SplitMix64 step per observed event". -/
@[simp]
theorem iter_succ
        (f : UInt64 → UInt64)
        (n : Nat)
        (s : UInt64)
        : iter f (n + 1) s = iter f n (f s) :=
  rfl

/-- Determinism / additivity of consumption: iterating `m + n` times equals
    iterating `n` times after `m`. Proved by induction, step abstract. -/
theorem iter_add
        (f : UInt64 → UInt64)
        (m n : Nat)
        (s : UInt64)
        : iter f (m + n) s = iter f n (iter f m s) := by
  induction m generalizing s with
  | zero => simp
  | succ k ih => simp [Nat.succ_add, ih]

/-- The scheduler keystream: advance the SplitMix64 state `n` times. -/
def advance (n : Nat) (s : UInt64) : UInt64 := iter (fun s => (next_seed s).2) n s

/-- Determinism of the keystream, as a corollary of `iter_add`. -/
theorem advance_add (m n : Nat) (s : UInt64) : advance (m + n) s = advance n (advance m s) :=
  iter_add _ m n s

end Rechaos
