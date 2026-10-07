/-
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                         // rechaos // lean // oracle
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  rechaos — the output-tree oracle (Lean port of `Rechaos.Core.Oracle`).

  Models a build's outputs as a path-keyed tree, takes a deterministic `diff`
  between two trees, and renders a `Verdict` on whether two builds agreed. The
  Haskell reference keys its tree with a `Data.Map` iterated in ascending key
  order; here a `Tree` is a `List (String × Entry)` kept sorted by key, and the
  `diff` is a key-ordered merge. Two trees are `equivalent` exactly when their
  `diff` is empty, mirroring the reference null-diff criterion.

  Discipline: the Haskell reference LEADS. The concrete diff/verdict behaviour is
  checked against a reference-generated corpus by `native_decide` in
  `Rechaos.OracleCorpus`; the abstract equivalence-relation laws (`equivalent`
  reflexive/symmetric/transitive, and the empty-diff criterion) are proved here
  over core Lean, with no Mathlib and no `UInt64` arithmetic forced in the kernel.
  There is no `sorry`, no `admit`, and no new `axiom`.
-/

namespace Rechaos

set_option autoImplicit false

/-- A single node in a build-output tree. Mirrors the Haskell `Entry`:
    `file contentHash sizeBytes executable`, a `symlink` carrying its target
    path, or a `directory`. -/
inductive entry
  | /-- A regular file: content hash, size in bytes, and the executable bit. -/
    file (contentHash : String) (sizeBytes : Nat) (executable : Bool)
  | /-- A symlink carrying its target path. -/
    symlink (target : String)
  | /-- A directory node. -/
    directory
  deriving Repr, DecidableEq, Inhabited

/-- A build's outputs keyed by path, kept in strictly ascending path order. The
    Haskell reference uses a `Data.Map Text Entry`; a sorted association list is
    the core-Lean counterpart, and the key-ordered `diff` below matches the
    reference's ascending-key union exactly. -/
abbrev tree := List (String × entry)

/-- A per-path difference: `change path before after`, where `none` marks absence
    on that side (an addition or a deletion). Mirrors the Haskell `Change`. -/
structure change where
  path   : String
  before : Option entry
  after  : Option entry
  deriving Repr, DecidableEq, Inhabited

/-- The result of attempting a build. Mirrors the Haskell `BuildResult`. -/
inductive build_result
  | /-- The build succeeded, producing this output `Tree`. -/
    built (tree : tree)
  | /-- The build failed with the given message. -/
    buildFailed (message : String)
  | /-- The build did not finish within its deadline. -/
    buildTimedOut
  deriving Repr, Inhabited

/-- The oracle's judgement on a pair of builds. Mirrors the Haskell `Verdict`. -/
inductive verdict
  | /-- The builds produced identical outputs. -/
    equivalent
  | /-- The builds diverged; carries the canonical list of `Change`s. -/
    diverged (changes : List change)
  | /-- At least one build did not succeed, so no judgement is possible. -/
    inconclusive
  deriving Repr, DecidableEq, Inhabited

/-- The canonical difference between two sorted trees: one `Change` per path
    whose entries differ, emitted in strictly ascending key order. A key-ordered
    merge over the union of both trees' keys — the Lean counterpart of the
    Haskell comprehension over `keysSet a ∪ keysSet b` in ascending order. An
    empty result means the trees are identical. -/
def diff : tree → tree → List change
  | [], [] => []
  | [], (keyB, entryB) :: restB =>
      { path := keyB, before := none, after := some entryB } :: diff [] restB
  | (keyA, entryA) :: restA, [] =>
      { path := keyA, before := some entryA, after := none } :: diff restA []
  | (keyA, entryA) :: restA, (keyB, entryB) :: restB =>
      if keyA == keyB then
        let tailDiff := diff restA restB
        if entryA == entryB then tailDiff
        else { path := keyA, before := some entryA, after := some entryB } :: tailDiff
      else if keyA < keyB then
        { path := keyA, before := some entryA, after := none }
          :: diff restA ((keyB, entryB) :: restB)
      else
        { path := keyB, before := none, after := some entryB }
          :: diff ((keyA, entryA) :: restA) restB

/-- Whether two trees are equivalent, i.e. their `diff` is empty. Mirrors the
    Haskell `equivalent`. -/
def equivalent (treeA treeB : tree) : Bool :=
  diff treeA treeB == []

/-- Compare two build outcomes. Both must have `built` successfully to be judged;
    equal outputs yield `equivalent`, differing outputs `diverged`, and any
    non-success on either side `inconclusive`. Mirrors the Haskell
    `compareBuilds`. -/
def compare_builds : build_result → build_result → verdict
  | .built treeA, .built treeB =>
      match diff treeA treeB with
      | []      => .equivalent
      | changes => .diverged changes
  | _, _ => .inconclusive

-- ── empty-diff criterion (definitional) ──────────────────────────────────────

/-- The empty-diff criterion: a diff is empty exactly when the trees are
    equivalent. Holds definitionally — `equivalent` is defined as the null-diff
    boolean test — so the two sides are the same fact. -/
theorem diff_nil_iff_equivalent (treeA treeB : tree) :
    diff treeA treeB = [] ↔ equivalent treeA treeB = true := by
  unfold equivalent
  constructor
  · intro hnil; simp [hnil]
  · intro hbeq; exact beq_iff_eq.mp hbeq

-- ── reflexivity: a tree never differs from itself ─────────────────────────────

/-- `diff` of a tree against itself is empty, for any tree. By structural
    induction: matched heads carry equal entries and drop through to the tail,
    which is empty by the induction hypothesis. The engine of `equivalent_refl`. -/
theorem diff_self_nil (tr : tree) : diff tr tr = [] := by
  induction tr with
  | nil => simp [diff]
  | cons head rest ih =>
      obtain ⟨key, ent⟩ := head
      simp [diff, ih]

/-- `equivalent` is reflexive: every tree is equivalent to itself. -/
theorem equivalent_refl (tr : tree) : equivalent tr tr = true := by
  unfold equivalent
  rw [diff_self_nil]
  rfl

-- ── a null diff pins the two trees to one another ──────────────────────────────

/-- A null diff forces the two trees to be the same list. The merge returns the
    empty list only when it consumed both inputs in lockstep on equal keys with
    equal entries: on unequal heads (either `keyA < keyB` or not) it always emits
    a leading `Change`, so a null result rules those branches out. The structural
    crux of both symmetry and transitivity — and it needs no ordering lemmas, only
    that the two unequal-key branches each produce a cons. -/
theorem diff_nil_imp_eq : ∀ (treeA treeB : tree), diff treeA treeB = [] → treeA = treeB := by
  intro treeA
  induction treeA with
  | nil =>
      intro treeB hdiff
      cases treeB with
      | nil => rfl
      | cons headB restB =>
          obtain ⟨keyB, entryB⟩ := headB
          simp [diff] at hdiff
  | cons headA restA ihA =>
      obtain ⟨keyA, entryA⟩ := headA
      intro treeB hdiff
      cases treeB with
      | nil => simp [diff] at hdiff
      | cons headB restB =>
          obtain ⟨keyB, entryB⟩ := headB
          by_cases hkey : keyA = keyB
          · subst hkey
            by_cases hentry : entryA = entryB
            · subst hentry
              simp only [diff, beq_self_eq_true, if_true] at hdiff
              rw [ihA restB hdiff]
            · exfalso
              have hne : (entryA == entryB) = false := beq_eq_false_iff_ne.mpr hentry
              simp [diff, hne] at hdiff
          · exfalso
            have hkeyAB : (keyA == keyB) = false := beq_eq_false_iff_ne.mpr hkey
            by_cases hlt : keyA < keyB
            · simp [diff, hkeyAB, hlt] at hdiff
            · simp [diff, hkeyAB, hlt] at hdiff

/-- `equivalent` is symmetric: `equivalent a b = equivalent b a`. A null diff
    pins both trees to the same list (`diff_nil_imp_eq`), and a tree never differs
    from itself (`diff_self_nil`), so a null diff one way is a null diff the other.
    Needs no key-ordering antisymmetry — it routes entirely through list equality. -/
theorem equivalent_symm (treeA treeB : tree) :
    equivalent treeA treeB = equivalent treeB treeA := by
  unfold equivalent
  by_cases h : diff treeA treeB = []
  · have heq : treeA = treeB := diff_nil_imp_eq treeA treeB h
    rw [h, heq, diff_self_nil]
  · have h2 : diff treeB treeA ≠ [] := by
      intro hcontra
      exact h (by rw [diff_nil_imp_eq treeB treeA hcontra, diff_self_nil])
    rw [beq_eq_false_iff_ne.mpr h, beq_eq_false_iff_ne.mpr h2]

-- ── transitivity ───────────────────────────────────────────────────────────────

/-- `equivalent` is transitive. Via `diff_nil_imp_eq`, equivalence collapses to
    list equality, which composes; `diff_self_nil` then turns the equality back
    into an empty diff. No sortedness hypothesis is needed because a null diff
    already forces the two argument lists to coincide. -/
theorem equivalent_trans
    (treeA treeB treeC : tree)
    (hab : equivalent treeA treeB = true)
    (hbc : equivalent treeB treeC = true) :
    equivalent treeA treeC = true := by
  unfold equivalent at *
  have hab' : diff treeA treeB = [] := beq_iff_eq.mp hab
  have hbc' : diff treeB treeC = [] := beq_iff_eq.mp hbc
  have heqAB : treeA = treeB := diff_nil_imp_eq treeA treeB hab'
  have heqBC : treeB = treeC := diff_nil_imp_eq treeB treeC hbc'
  have heqAC : treeA = treeC := heqAB.trans heqBC
  rw [heqAC, diff_self_nil]
  rfl

end Rechaos
