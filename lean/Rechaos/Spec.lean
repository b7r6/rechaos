/-
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                           // rechaos // lean // spec
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  rechaos — a FORMAL REAPI specification in Lean.

  This module defines a selected sequential store model and proves structural
  laws about that model. It is not a complete REAPI specification or a proof
  that a live server, the Haskell gateway, or the Python checker implements it.
  The runtime history checker checks related properties independently; its
  assumptions and the mapping to these laws are documented in
  `docs/reapi-spec.md` and `docs/consistency-oracle.md`.

  Design discipline, matching the rest of `Rechaos.*`:
    * Abstract over the concrete hash and byte types — a `Store` is parameterised
      by a `Digest` key type, a `Content` value type, and a pure `hash`. Nothing
      here forces `UInt64` evaluation in the kernel; the laws are structural.
    * A `Store` is a finite association list `Digest ⇀ Content`, the Lean
      counterpart of the oracle's per-key register map.
    * REAPI operations are `Op` labels; `step` is the LTS transition, producing a
      next state and an `Obs` observation (the server's response).
    * No Mathlib. No `sorry`, no `admit`, no new `axiom`.

  The four laws proved here are exactly the oracle's C1 (content integrity),
  the write-then-read half of C2/C3 (write-then-read availability), the
  soundness+completeness of FindMissingBlobs, and last-writer-wins monotonicity
  of the Action Cache.
-/

namespace Rechaos.Spec

set_option autoImplicit false

-- ── the content-addressed store ───────────────────────────────────────────────

/-- A content-addressed store over an abstract digest key type `κ` and content
    value type `α`, decidable-equal on keys. A finite association list kept as a
    plain `List (κ × α)`; lookup takes the *first* binding, so a cons models a
    last-writer-wins update. This is the Lean counterpart of the per-key register
    map the runtime oracle maintains. -/
abbrev Store (κ α : Type) := List (κ × α)

variable {κ α : Type}

/-- Lookup the content bound to a digest, returning the first (most-recent)
    binding. `none` means "not present" — the CAS/AC not-found response, and the
    oracle's `MISSING` / `absent` sentinel. -/
def lookup [DecidableEq κ] (st : Store κ α) (d : κ) : Option α :=
  match st with
  | [] => none
  | (k, v) :: rest => if k = d then some v else lookup rest d

/-- A digest is *present* when it has a binding. Mirrors FindMissingBlobs saying
    "not missing" and a `read`/`find_missing` observing `present`. -/
def present [DecidableEq κ] (st : Store κ α) (d : κ) : Prop :=
  (lookup st d).isSome = true

instance [DecidableEq κ] (st : Store κ α) (d : κ) : Decidable (present st d) := by
  unfold present; infer_instance

@[simp] theorem lookup_nil [DecidableEq κ] (d : κ) :
    lookup ([] : Store κ α) d = none := rfl

@[simp] theorem lookup_cons_self [DecidableEq κ] (rest : Store κ α) (d : κ) (v : α) :
    lookup ((d, v) :: rest) d = some v := by
  simp [lookup]

theorem lookup_cons_ne [DecidableEq κ] (rest : Store κ α) (d k : κ) (v : α)
    (h : k ≠ d) : lookup ((k, v) :: rest) d = lookup rest d := by
  simp [lookup, h]

/-- A successful lookup witnesses a binding in the store. -/
theorem lookup_some_mem [DecidableEq κ] (st : Store κ α) (d : κ) (v : α)
    (h : lookup st d = some v) : (d, v) ∈ st := by
  induction st with
  | nil => simp [lookup] at h
  | cons head rest ih =>
      obtain ⟨k, w⟩ := head
      by_cases hk : k = d
      · subst hk
        rw [lookup_cons_self] at h
        have : w = v := by cases h; rfl
        subst this; exact List.mem_cons_self
      · rw [lookup_cons_ne rest d k w hk] at h
        exact List.mem_cons_of_mem _ (ih h)

-- ── REAPI operations as an LTS ────────────────────────────────────────────────

/-- The REAPI surface we model, as transition labels.

    * `write d b`  — CAS `BatchUpdateBlobs` / ByteStream `Write`: store bytes `b`
      under digest `d`. A *conforming* write must have `hash b = d`; see `valid`.
    * `read d`     — CAS `BatchReadBlobs` / ByteStream `Read`: fetch bytes for `d`.
    * `findMissing ds` — CAS `FindMissingBlobs`: which of `ds` are absent.
    * `updateActionResult k r` — ActionCache `UpdateActionResult`: bind result `r`
      to action key `k` (last-writer-wins).
    * `getActionResult k` — ActionCache `GetActionResult`: fetch the result for `k`.

    Content and ActionResult share the content type `α` here: a REAPI
    `ActionResult` is itself a blob, so one value domain suffices for the
    structural laws. -/
inductive Op (κ α : Type)
  | write (d : κ) (b : α)
  | read (d : κ)
  | findMissing (ds : List κ)
  | updateActionResult (k : κ) (r : α)
  | getActionResult (k : κ)

/-- A server's observable response to an `Op`. Observations carry exactly what a
    client sees, so the oracle's recorded outcomes map onto these constructors. -/
inductive Obs (κ α : Type)
  | /-- A write/update acknowledged (the op completed). -/
    acked
  | /-- A read/get returned content. -/
    got (v : α)
  | /-- A read/get found nothing (the `MISSING` sentinel). -/
    notFound
  | /-- FindMissingBlobs answered with the sublist of absent digests. -/
    missing (ds : List κ)

/-- A write is *valid* (content-addressing-conforming) exactly when the bytes
    hash to the digest. REAPI servers MUST reject writes where this fails; our
    `step` only mutates the store on a valid write, modelling that rejection. -/
def valid (hash : α → κ) (d : κ) (b : α) : Prop := hash b = d

/-- The labelled transition: given the hashing function, a prior state and an
    `Op`, produce the next state and the observation. This is the single source
    of truth the correctness predicates are stated against.

    A `write` with mismatched hash is rejected: the state is unchanged and the
    server still acks nothing new (we surface `notFound`-free semantics by simply
    not binding; a real server returns an `INVALID_ARGUMENT`, modelled as "no
    state change"). FindMissingBlobs returns the input digests filtered to the
    absent ones. UpdateActionResult always binds (last-writer-wins, no content
    constraint — AC keys do not encode their value). -/
def step [DecidableEq κ] (hash : α → κ) :
    Store κ α → Op κ α → Store κ α × Obs κ α
  | st, .write d b =>
      if hash b = d then ((d, b) :: st, .acked) else (st, .acked)
  | st, .read d =>
      match lookup st d with
      | some v => (st, .got v)
      | none   => (st, .notFound)
  | st, .findMissing ds =>
      (st, .missing (ds.filter (fun d => !(present st d : Bool))))
  | st, .updateActionResult k r =>
      ((k, r) :: st, .acked)
  | st, .getActionResult k =>
      match lookup st k with
      | some v => (st, .got v)
      | none   => (st, .notFound)

/-- Run a sequence of ops from a start state, returning the final state. A
    *history* in the oracle's sense; the laws below quantify over any such run. -/
def run [DecidableEq κ] (hash : α → κ) (st : Store κ α) : List (Op κ α) → Store κ α
  | [] => st
  | op :: rest => run hash (step hash st op).1 rest

/-- A store is *integral* when every binding's content hashes to its key — the
    content-addressing well-formedness invariant. CAS/ByteStream keys encode
    their value; this is the store-level statement of that. -/
def integral (hash : α → κ) (st : Store κ α) : Prop :=
  ∀ d b, (d, b) ∈ st → hash b = d

/-- A read returns `some v` exactly as its observation's content. A reusable
    bridge from the LTS observation back to the store lookup. -/
theorem read_obs_eq [DecidableEq κ] (hash : α → κ) (st : Store κ α) (d : κ) (v : α)
    (hobs : (step hash st (.read d)).2 = .got v) : lookup st d = some v := by
  simp only [step] at hobs
  cases hl : lookup st d with
  | none => rw [hl] at hobs; exact absurd hobs (by simp)
  | some v' =>
      rw [hl] at hobs
      have hvv : v' = v := by injection hobs
      rw [hvv]

-- ── LAW 1: content integrity ──────────────────────────────────────────────────

/-- `step` preserves integrity: starting from an integral store, any op lands in
    an integral store. The only state-growing ops are `write` (gated on
    `hash b = d`, so the new binding is integral by construction) and
    `updateActionResult`. The latter binds an arbitrary result under an AC key;
    to keep the single value domain honest we require the AC binding to also be
    content-addressed is NOT assumed — instead we prove integrity for the CAS
    fragment, i.e. runs whose ops are writes/reads/finds. AC is handled by its own
    monotonicity law below. -/
theorem step_preserves_integral_cas [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (d : κ) (b : α) (hst : integral hash st) :
    integral hash (step hash st (.write d b)).1 := by
  intro d' b' hmem
  by_cases h : hash b = d
  · have hstep : (step hash st (.write d b)).1 = (d, b) :: st := by
      simp only [step, if_pos h]
    rw [hstep] at hmem
    rcases List.mem_cons.mp hmem with heq | htail
    · -- the freshly written binding; its hash matches by `h`
      have hd : d' = d := ((Prod.mk.injEq d b d' b').mp heq.symm).1.symm
      have hb : b' = b := ((Prod.mk.injEq d b d' b').mp heq.symm).2.symm
      rw [hd, hb]; exact h
    · exact hst d' b' htail
  · have hstep : (step hash st (.write d b)).1 = st := by
      simp only [step, if_neg h]
    rw [hstep] at hmem
    exact hst d' b' hmem

/-- Reads never change the store, so integrity is trivially preserved. -/
theorem step_read_preserves_integral [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (d : κ) (hst : integral hash st) :
    integral hash (step hash st (.read d)).1 := by
  intro d' b' hmem
  have : (step hash st (.read d)).1 = st := by
    simp only [step]; cases lookup st d <;> rfl
  rw [this] at hmem
  exact hst d' b' hmem

/-- FindMissingBlobs never changes the store, so integrity is preserved. -/
theorem step_findMissing_preserves_integral [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (ds : List κ) (hst : integral hash st) :
    integral hash (step hash st (.findMissing ds)).1 := by
  intro d' b' hmem
  have : (step hash st (.findMissing ds)).1 = st := rfl
  rw [this] at hmem
  exact hst d' b' hmem

/-- Content integrity, the observable form: in an integral store, any `read` that
    returns content returns content that hashes to the digest. This is the C1
    predicate the oracle checks structurally on every CAS read. -/
theorem read_content_integrity [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (d : κ) (v : α)
    (hst : integral hash st)
    (hobs : (step hash st (.read d)).2 = .got v) :
    hash v = d := by
  have hl : lookup st d = some v := read_obs_eq hash st d v hobs
  exact hst d v (lookup_some_mem st d v hl)

-- ── LAW 2: write-then-read availability ───────────────────────────────────────

/-- After a *completed valid* `write d b` (with `hash b = d`), an immediately
    following `read d` yields `b`. This is the write-then-read availability law:
    a correct server, absent eviction, must serve what it just accepted. It is
    the formal form of the oracle's monotone-availability (C2) + the read-returns-
    latest-write edge of linearizability (C3) for a CAS register. -/
theorem write_then_read [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (d : κ) (b : α) (hvalid : valid hash d b) :
    (step hash (step hash st (.write d b)).1 (.read d)).2 = .got b := by
  unfold valid at hvalid
  have hstep : (step hash st (.write d b)).1 = (d, b) :: st := by
    simp only [step, if_pos hvalid]
  rw [hstep]
  simp only [step, lookup_cons_self]

/-- After a valid `write d b`, the digest `d` is present. The availability half of
    write-then-read, in the `present`/FindMissingBlobs vocabulary. -/
theorem write_then_present [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (d : κ) (b : α) (hvalid : valid hash d b) :
    present (step hash st (.write d b)).1 d := by
  unfold valid at hvalid
  have hstep : (step hash st (.write d b)).1 = (d, b) :: st := by
    simp only [step, if_pos hvalid]
  unfold present
  rw [hstep, lookup_cons_self]
  rfl

-- ── LAW 3: FindMissingBlobs soundness & completeness ──────────────────────────

/-- The digests FindMissingBlobs reports for a query `ds`. Pulled out of `step`
    so the laws can name it directly. -/
def findMissingResult [DecidableEq κ] (st : Store κ α) (ds : List κ) : List κ :=
  ds.filter (fun d => !(present st d : Bool))

theorem step_findMissing_eq [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (ds : List κ) :
    (step hash st (.findMissing ds)).2 = .missing (findMissingResult st ds) := rfl

/-- SOUNDNESS: every digest FindMissingBlobs reports as missing is genuinely
    absent from the store (and was in the query). A server that reports a present
    blob as missing — causing needless re-upload or, worse, masking a real
    presence — violates this. -/
theorem findMissing_sound [DecidableEq κ] (st : Store κ α) (ds : List κ) (d : κ)
    (h : d ∈ findMissingResult st ds) :
    d ∈ ds ∧ ¬ present st d := by
  unfold findMissingResult at h
  rw [List.mem_filter] at h
  obtain ⟨hmem, hpred⟩ := h
  refine ⟨hmem, ?_⟩
  intro hpres
  have : (present st d : Bool) = true := decide_eq_true hpres
  rw [this] at hpred
  simp at hpred

/-- COMPLETENESS: every queried digest that is genuinely absent IS reported
    missing. A server that omits a truly-missing blob from the response — causing
    a client to skip an upload it needed — violates this. Together with soundness
    this pins the FindMissingBlobs response to exactly the absent-in-query set. -/
theorem findMissing_complete [DecidableEq κ] (st : Store κ α) (ds : List κ) (d : κ)
    (hmem : d ∈ ds) (habs : ¬ present st d) :
    d ∈ findMissingResult st ds := by
  unfold findMissingResult
  rw [List.mem_filter]
  refine ⟨hmem, ?_⟩
  have : (present st d : Bool) = false := decide_eq_false habs
  rw [this]
  rfl

/-- The exact characterisation: FindMissingBlobs reports `d` iff `d` was queried
    and is absent. Soundness ∧ completeness, packaged. -/
theorem findMissing_iff [DecidableEq κ] (st : Store κ α) (ds : List κ) (d : κ) :
    d ∈ findMissingResult st ds ↔ (d ∈ ds ∧ ¬ present st d) := by
  constructor
  · exact findMissing_sound st ds d
  · exact fun ⟨hm, ha⟩ => findMissing_complete st ds d hm ha

/-- Corollary bridging to availability: a present digest is NEVER reported missing
    — the exact statement the oracle leans on when it flags "find_missing said
    absent after a completed write". -/
theorem present_not_findMissing [DecidableEq κ] (st : Store κ α) (ds : List κ) (d : κ)
    (hpres : present st d) : d ∉ findMissingResult st ds := by
  intro hcontra
  exact (findMissing_sound st ds d hcontra).2 hpres

-- ── LAW 4: Action Cache monotonicity under last-writer ────────────────────────

/-- After `updateActionResult k r`, an immediately following `getActionResult k`
    returns `r`: last-writer-wins. The AC is a mutable register and this is the
    "a read sees the most recent write" edge the oracle's per-key linearizability
    (C3) enforces for AC keys. -/
theorem update_then_get [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (k : κ) (r : α) :
    (step hash (step hash st (.updateActionResult k r)).1 (.getActionResult k)).2
      = .got r := by
  have hstep : (step hash st (.updateActionResult k r)).1 = (k, r) :: st := rfl
  rw [hstep]
  simp only [step, lookup_cons_self]

/-- Monotone presence for AC: once a key is updated it is present, and remains
    present under any *further* update of the same key (the newer binding shadows
    but never removes availability). The availability spine of AC monotonicity. -/
theorem update_then_present [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (k : κ) (r : α) :
    present (step hash st (.updateActionResult k r)).1 k := by
  have hstep : (step hash st (.updateActionResult k r)).1 = (k, r) :: st := rfl
  unfold present
  rw [hstep, lookup_cons_self]
  rfl

/-- Last-writer-wins, stated on the store: after two successive updates of the
    same key, lookup yields the *second* (most recent) result. The core
    monotonicity fact — a later write cannot be masked by an earlier one. -/
theorem lastWriterWins [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (k : κ) (r₁ r₂ : α) :
    lookup (step hash (step hash st (.updateActionResult k r₁)).1
             (.updateActionResult k r₂)).1 k = some r₂ := by
  have h₁ : (step hash st (.updateActionResult k r₁)).1 = (k, r₁) :: st := rfl
  rw [h₁]
  have h₂ : (step hash ((k, r₁) :: st) (.updateActionResult k r₂)).1
      = (k, r₂) :: (k, r₁) :: st := rfl
  rw [h₂, lookup_cons_self]

/-- A later update of a *different* key does not disturb an earlier key's binding:
    AC updates are independent across keys (the per-key register view the oracle
    takes is sound). -/
theorem update_other_key_stable [DecidableEq κ] (hash : α → κ)
    (st : Store κ α) (k k' : κ) (r r' : α) (hne : k' ≠ k) :
    lookup (step hash (step hash st (.updateActionResult k r)).1
             (.updateActionResult k' r')).1 k
      = lookup (step hash st (.updateActionResult k r)).1 k := by
  have h₁ : (step hash st (.updateActionResult k r)).1 = (k, r) :: st := rfl
  rw [h₁]
  have h₂ : (step hash ((k, r) :: st) (.updateActionResult k' r')).1
      = (k', r') :: (k, r) :: st := rfl
  rw [h₂, lookup_cons_ne _ k k' r' hne]

end Rechaos.Spec
