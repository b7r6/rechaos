/-
  rechaos — conformance anchors for the verified core.

  Core/Determinism proves the keystream laws abstractly (quantified over the
  step), so the kernel never evaluates UInt64. These anchors tie the *concrete*
  SplitMix64 step to independently-computed golden values, checked by native
  evaluation over a finite scope — the "verified reference as oracle" discipline:
  completeness is inherited from the scope the theorem ranges over. No `sorry`.
-/
import Rechaos.Core

namespace Rechaos

set_option autoImplicit false

/-- A fixed scope of `(seed, expected-output, expected-next-state)` for the
    SplitMix64 step, computed independently of this definition. -/
def splitmixScope : List (UInt64 × UInt64 × UInt64) :=
  [ (0, 0xe220a8397b1dcdaf, 0x9e3779b97f4a7c15)
  , (1, 0x910a2dec89025cc1, 0x9e3779b97f4a7c16)
  , (0x9e3779b97f4a7c15, 0x6e789e6aa1b965f4, 0x3c6ef372fe94f82a)
  , (0xdeadbeefcafef00d, 0x901d4f652fb472cb, 0x7ce538a94a496c22) ]

/-- `nextSeed` reproduces every golden vector in `splitmixScope`. Checked by
    native evaluation (no kernel UInt64 reduction). -/
theorem nextSeed_conforms_on_scope :
    splitmixScope.all (fun entry => nextSeed entry.1 == entry.2) = true := by
  native_decide

end Rechaos
