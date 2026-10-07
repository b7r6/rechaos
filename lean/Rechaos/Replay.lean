/-
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                         // rechaos // lean // replay
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  rechaos — the replay layer (Lean port of `Rechaos.Core.Scheduler`'s replay
  checks). This is the last piece of the determinism contract: a recorded
  timeline, re-observed live, must reproduce exactly the decisions it recorded.

  Mirrors the Haskell `validateTimeline` / `replayDecision` / `verifyReplay`
  faithfully over the Lean `Types`. The Haskell indexes a timeline by `EventKey`
  with a `Data.Map`; here an `EventTable` is a `List (EventKey × Decision)` built
  by `validateTimeline`, which fails (`none`) on a repeated event identity exactly
  as the reference `Data.Map`-insert guard does. `replayDecision` looks a live
  event up by key: a full recording (`sparse := false`) FAILS CLOSED on an event
  missing from the table, whereas a sparse fault timeline (`sparse := true`) passes
  unlisted traffic through with no injection; either way a present event must still
  match its recorded fingerprint (`sameEvent`) or replay fails. `verifyReplay` is
  the coverage check: every recorded event must have been observed with a matching
  fingerprint and an identical injection, so an incomplete replay (a recorded
  event that never arrived) is rejected even when nothing observed mismatched.

  Discipline: the Haskell reference LEADS. The concrete replay verdicts are checked
  against a reference-generated corpus by `native_decide` in `Rechaos.ReplayCorpus`;
  the abstract theorems — REPLAY IDENTITY (replaying `schedule p es` reproduces its
  own decisions), FAIL-CLOSED (a changed fingerprint is rejected), and COVERAGE (a
  missing recorded event is rejected) — are proved here by structural induction over
  core Lean, with no Mathlib and no `UInt64` arithmetic forced in the kernel. There
  is no `sorry`, no `admit`, and no new `axiom`.
-/

import Rechaos.Scheduler

namespace Rechaos

set_option autoImplicit false

/-- A timeline indexed by `EventKey`, the Lean counterpart of the Haskell
    `Data.Map EventKey Decision`. An association list in which `validateTimeline`
    guarantees every key occurs at most once; the association order is otherwise
    unspecified, exactly as a `Data.Map` imposes no insertion order. Both observable
    replay operations — key lookup and the coverage conjunction — are independent of
    that order once keys are unique, so the port is behaviourally faithful. -/
abbrev EventTable := List (EventKey × Decision)

/-- The outcome of a single-event replay lookup. Mirrors the Haskell
    `Either Text Decision`: `rejected` is the `Left` (replay fails closed), and
    `decided d` is the `Right d` (the decision to apply). -/
inductive ReplayOutcome
  | /-- Replay failed closed (unexpected or changed event). -/
    rejected
  | /-- Replay accepted, carrying the decision to apply. -/
    decided (decision : Decision)
  deriving Repr, DecidableEq, Inhabited

/-- Whether a membership key already appears in a partially-built table. The
    counterpart of the Haskell `M.member k acc` guard. -/
def tableMember (key : EventKey) : EventTable → Bool
  | [] => false
  | (k, _) :: rest => if k == key then true else tableMember key rest

/-- Look a key up in an `EventTable`, returning the first binding (there is at
    most one in a validated table). The counterpart of `M.lookup`. -/
def tableLookup (key : EventKey) : EventTable → Option Decision
  | [] => none
  | (k, dec) :: rest => if k == key then some dec else tableLookup key rest

/-- Index a timeline by `EventKey`, failing (`none`) if any event identity
    repeats. A well-formed timeline has at most one decision per event. The
    duplicate guard (`tableMember`) mirrors the reference `Data.Map`-insert check;
    the resulting association order is unspecified, as for a `Data.Map`. Faithful to
    the Haskell `validateTimeline`. -/
def validateTimeline (tl : Timeline) : Option EventTable :=
  go [] tl
where
  go (acc : EventTable) : Timeline → Option EventTable
    | [] => some acc
    | dec :: rest =>
        let key := eventKey dec.event
        if tableMember key acc then none
        else go ((key, dec) :: acc) rest

/-- Look up the decision for a live event against a recorded timeline table. The
    `sparse` flag selects the semantics: a full recording (`false`) fails closed
    on any event missing from the table, whereas a sparse fault timeline (`true`)
    passes unlisted traffic through with no injection. Either way, an event present
    in the table must still match its recorded fingerprint (via `sameEvent`), or
    replay is rejected. Faithful to the Haskell `replayDecision`. -/
def replayDecision (sparse : Bool) (table : EventTable) (evt : Event) : ReplayOutcome :=
  match tableLookup (eventKey evt) table with
  | none => if sparse then .decided { event := evt, injection := none } else .rejected
  | some recorded =>
      if sameEvent recorded.event evt then
        .decided { event := evt, injection := recorded.injection }
      else
        .rejected

/-- Whether a single recorded decision was observed, unchanged, with an identical
    injection, in the observed table. The counterpart of the per-element `check`
    inside the Haskell `verifyReplay`: the recorded key must be present, carry a
    matching fingerprint (`sameEvent`), and inject exactly the recorded fault. -/
def observedMatches (observed : EventTable) (recorded : Decision) : Bool :=
  match tableLookup (eventKey recorded.event) observed with
  | none => false
  | some found =>
      sameEvent recorded.event found.event && recorded.injection == found.injection

/-- Check an observed timeline against an expected one (the forward inclusion).
    Succeeds (`true`) only when both timelines validate and every expected event
    occurred with a matching fingerprint and an identical injection. A replay is
    not complete merely because none of its observed events mismatched: every
    recorded event must also have happened — so an incomplete replay is rejected.
    Tolerates extra observed traffic not present in `expected`, the correct
    semantics for a sparse fault timeline. Faithful to the Haskell `verifyReplay`
    (modelled as a boolean verdict: `true` is `Right ()`, `false` is `Left _`). -/
def verifyReplay (expected observed : Timeline) : Bool :=
  match validateTimeline expected, validateTimeline observed with
  | some wanted, some actual => wanted.all (fun binding => observedMatches actual binding.2)
  | _, _ => false

-- ── structural facts about the table ─────────────────────────────────────────

/-- `tableLookup` finds a key just inserted at the head of a table. -/
theorem tableLookup_cons_self (key : EventKey) (dec : Decision) (rest : EventTable) :
    tableLookup key ((key, dec) :: rest) = some dec := by
  simp [tableLookup]

/-- `replayDecision` on an empty table passes a sparse event through and fails a
    full recording closed, for any event — the "missing event" dichotomy. -/
theorem replayDecision_nil (sparse : Bool) (evt : Event) :
    replayDecision sparse [] evt =
      (if sparse then .decided { event := evt, injection := none } else .rejected) := by
  simp [replayDecision, tableLookup]

/-- FAIL-CLOSED (single event): a live event whose key is recorded but whose
    fingerprint differs from the recording is rejected, under either semantics.
    This is the heart of the fail-closed contract — a changed payload can never
    be silently accepted. -/
theorem replayDecision_rejects_changed_fingerprint
    (sparse : Bool) (table : EventTable) (evt : Event) (recorded : Decision)
    (hkey : tableLookup (eventKey evt) table = some recorded)
    (hchanged : sameEvent recorded.event evt = false) :
    replayDecision sparse table evt = .rejected := by
  simp [replayDecision, hkey, hchanged]

/-- A recorded event re-observed with the SAME fingerprint replays its recorded
    injection — the positive counterpart of fail-closed. -/
theorem replayDecision_reuses_recorded_injection
    (sparse : Bool) (table : EventTable) (evt : Event) (recorded : Decision)
    (hkey : tableLookup (eventKey evt) table = some recorded)
    (hsame : sameEvent recorded.event evt = true) :
    replayDecision sparse table evt = .decided { event := evt, injection := recorded.injection } := by
  simp [replayDecision, hkey, hsame]

-- ── validated-table invariants (the engine of the abstract theorems) ─────────

/-- `tableMember` is the decidable negation of key membership in the table's key
    list: it reports `false` exactly when the key is absent. Bridges the duplicate
    guard in `validateTimeline` to the `Nodup` reasoning below. -/
theorem tableMember_false_iff (key : EventKey) (table : EventTable) :
    tableMember key table = false ↔ key ∉ table.map (·.1) := by
  induction table with
  | nil => simp [tableMember]
  | cons head rest ih =>
      obtain ⟨k, dec⟩ := head
      simp only [tableMember, List.map_cons, List.mem_cons]
      by_cases hk : k = key
      · subst hk; simp
      · have hbeq : (k == key) = false := by simpa using hk
        simp only [hbeq, if_false, Bool.false_eq_true, if_false]
        rw [ih]
        constructor
        · intro hnotin hcontra
          rcases hcontra with h | h
          · exact hk h.symm
          · exact hnotin h
        · intro hcontra hmem
          exact hcontra (Or.inr hmem)

/-- In a table whose keys are distinct (`Nodup`), every binding looks itself up:
    `tableLookup b.1 table = some b.2`. The association-list counterpart of "a
    `Data.Map` returns the value stored under each key". -/
theorem lookup_of_mem_nodup :
    ∀ (table : EventTable), (table.map (·.1)).Nodup →
      ∀ binding ∈ table, tableLookup binding.1 table = some binding.2 := by
  intro table
  induction table with
  | nil => intro _ binding hbind; cases hbind
  | cons head rest ih =>
      intro hnodup binding hbind
      obtain ⟨k, dec⟩ := head
      simp only [List.map_cons, List.nodup_cons] at hnodup
      obtain ⟨hnotin, hrest⟩ := hnodup
      rw [List.mem_cons] at hbind
      rcases hbind with heq | hmem
      · subst heq; simp [tableLookup]
      · have hblk : binding.1 ≠ k := by
          intro hcontra
          apply hnotin
          rw [← hcontra]
          exact List.mem_map_of_mem hmem
        simp only [tableLookup]
        rw [if_neg (by simp only [beq_iff_eq]; exact fun h => hblk h.symm)]
        exact ih hrest binding hmem

/-- `validateTimeline.go` preserves key-distinctness: starting from a `Nodup`
    accumulator, a successful validation yields a table whose keys are still
    `Nodup`. The duplicate guard refuses to insert any key already present. -/
theorem go_nodup :
    ∀ (decisions : Timeline) (acc table : EventTable),
      (acc.map (·.1)).Nodup → validateTimeline.go acc decisions = some table →
      (table.map (·.1)).Nodup := by
  intro decisions
  induction decisions with
  | nil =>
      intro acc table hacc hgo
      simp only [validateTimeline.go, Option.some.injEq] at hgo
      subst hgo; exact hacc
  | cons dec rest ih =>
      intro acc table hacc hgo
      simp only [validateTimeline.go] at hgo
      by_cases hmem : tableMember (eventKey dec.event) acc = true
      · simp [hmem] at hgo
      · have hmemf : tableMember (eventKey dec.event) acc = false := by simpa using hmem
        rw [if_neg (by simp [hmemf])] at hgo
        apply ih ((eventKey dec.event, dec) :: acc) table _ hgo
        simp only [List.map_cons, List.nodup_cons]
        exact ⟨(tableMember_false_iff _ _).mp hmemf, hacc⟩

/-- `validateTimeline.go` preserves the key-agreement invariant: every binding it
    stores has `binding.1 = eventKey binding.2.event`, because it only ever inserts
    `(eventKey decision.event, decision)`. -/
theorem go_key_agree :
    ∀ (decisions : Timeline) (acc table : EventTable),
      (∀ binding ∈ acc, binding.1 = eventKey binding.2.event) →
      validateTimeline.go acc decisions = some table →
      (∀ binding ∈ table, binding.1 = eventKey binding.2.event) := by
  intro decisions
  induction decisions with
  | nil =>
      intro acc table hacc hgo
      simp only [validateTimeline.go, Option.some.injEq] at hgo
      subst hgo; exact hacc
  | cons dec rest ih =>
      intro acc table hacc hgo
      simp only [validateTimeline.go] at hgo
      by_cases hmem : tableMember (eventKey dec.event) acc = true
      · simp [hmem] at hgo
      · have hmemf : tableMember (eventKey dec.event) acc = false := by simpa using hmem
        rw [if_neg (by simp [hmemf])] at hgo
        apply ih _ table _ hgo
        intro binding hbind
        rw [List.mem_cons] at hbind
        rcases hbind with heq | hmem'
        · subst heq; rfl
        · exact hacc binding hmem'

/-- A validated table has distinct keys. The top-level corollary of `go_nodup`. -/
theorem validateTimeline_nodup (tl : Timeline) (table : EventTable)
    (hval : validateTimeline tl = some table) : (table.map (·.1)).Nodup :=
  go_nodup tl [] table (by simp) hval

/-- Every binding of a validated table is keyed by its own event's `eventKey`. The
    top-level corollary of `go_key_agree`. -/
theorem validateTimeline_key_agree (tl : Timeline) (table : EventTable)
    (hval : validateTimeline tl = some table) :
    ∀ binding ∈ table, binding.1 = eventKey binding.2.event :=
  go_key_agree tl [] table (by simp) hval

/-- Each binding of a validated table matches itself under `observedMatches`: the
    key is found, the fingerprint agrees (reflexively), and the injection is
    identical. The per-binding core of self-coverage. -/
theorem observedMatches_self (tl : Timeline) (table : EventTable)
    (hval : validateTimeline tl = some table)
    (binding : EventKey × Decision) (hbind : binding ∈ table) :
    observedMatches table binding.2 = true := by
  have hnodup := validateTimeline_nodup tl table hval
  have hagree := validateTimeline_key_agree tl table hval binding hbind
  have hlook : tableLookup binding.1 table = some binding.2 :=
    lookup_of_mem_nodup table hnodup binding hbind
  unfold observedMatches
  rw [← hagree, hlook]
  simp [sameEvent_refl]

/-- A helper for rejection: if any element of a list fails the predicate, the
    boolean `all` over that list is `false`. The engine of the coverage and
    fail-closed rejection theorems below. -/
theorem all_false_of_mem_false {α : Type} (elems : List α) (pred : α → Bool)
    (elem : α) (hmem : elem ∈ elems) (hpred : pred elem = false) :
    elems.all pred = false := by
  induction elems with
  | nil => cases hmem
  | cons head tail ih =>
      rw [List.mem_cons] at hmem
      simp only [List.all_cons]
      rcases hmem with heq | hm
      · subst heq; rw [hpred]; simp
      · rw [ih hm]; simp

-- ── REPLAY IDENTITY (the prize), FAIL-CLOSED, and COVERAGE ───────────────────

/-- A recorded decision, replayed against its own validated table under either
    semantics, reproduces exactly its recorded decision — same event, same
    injection. This is REPLAY IDENTITY at the single-decision level: replaying a
    recording returns the recording. Proved from the validated-table invariants
    (distinct keys ⇒ self-lookup) and `sameEvent` reflexivity. -/
theorem replayDecision_recorded_identity
    (sparse : Bool) (tl : Timeline) (table : EventTable)
    (hval : validateTimeline tl = some table)
    (binding : EventKey × Decision) (hbind : binding ∈ table) :
    replayDecision sparse table binding.2.event
      = .decided { event := binding.2.event, injection := binding.2.injection } := by
  have hnodup := validateTimeline_nodup tl table hval
  have hagree := validateTimeline_key_agree tl table hval binding hbind
  have hlook : tableLookup binding.1 table = some binding.2 :=
    lookup_of_mem_nodup table hnodup binding hbind
  apply replayDecision_reuses_recorded_injection
  · rw [← hagree]; exact hlook
  · simp [sameEvent_refl]

/-- REPLAY IDENTITY (trace level): any timeline that validates verifies against
    itself. Replaying a recording against the very events it recorded always
    succeeds — every recorded event is observed, unchanged, with its recorded
    injection. The headline round-trip of the replay layer. -/
theorem verifyReplay_identity (tl : Timeline) (table : EventTable)
    (hval : validateTimeline tl = some table) :
    verifyReplay tl tl = true := by
  unfold verifyReplay
  rw [hval]
  simp only
  rw [List.all_eq_true]
  intro binding hbind
  exact observedMatches_self tl table hval binding hbind

/-- REPLAY IDENTITY specialized to the scheduler: when the timeline produced by
    `schedule policy events` validates (its events carry distinct identities),
    replaying it against itself reproduces exactly those decisions. This is the
    round-trip that closes the determinism contract — the decisions `schedule`
    emits are precisely the decisions a replay of them recovers. -/
theorem verifyReplay_schedule_identity
    (pol : Policy) (events : List Event) (table : EventTable)
    (hval : validateTimeline (schedule pol events) = some table) :
    verifyReplay (schedule pol events) (schedule pol events) = true :=
  verifyReplay_identity (schedule pol events) table hval

/-- COVERAGE: a recorded event that never arrived rejects the replay. If a binding
    of the validated expected table has no counterpart in the observed table
    (`tableLookup … = none`), `verifyReplay` fails — an incomplete replay is never
    accepted, even when nothing observed mismatched. -/
theorem verifyReplay_missing_rejected
    (expected observed : Timeline) (wanted actual : EventTable)
    (hexp : validateTimeline expected = some wanted)
    (hobs : validateTimeline observed = some actual)
    (binding : EventKey × Decision) (hbind : binding ∈ wanted)
    (hmiss : tableLookup (eventKey binding.2.event) actual = none) :
    verifyReplay expected observed = false := by
  unfold verifyReplay
  rw [hexp, hobs]
  apply all_false_of_mem_false wanted _ binding hbind
  unfold observedMatches
  rw [hmiss]

/-- COVERAGE (sharp form): a nonempty recording replayed against an empty observed
    timeline is always rejected — nothing arrived, so no recorded event is covered. -/
theorem verifyReplay_empty_observed_rejected (expected : Timeline) (table : EventTable)
    (hval : validateTimeline expected = some table) (hne : table ≠ []) :
    verifyReplay expected [] = false := by
  unfold verifyReplay
  rw [hval]
  simp only [validateTimeline, validateTimeline.go]
  cases table with
  | nil => exact absurd rfl hne
  | cons binding rest =>
      simp only [List.all_cons]
      have hmiss : observedMatches [] binding.2 = false := by
        unfold observedMatches; simp [tableLookup]
      rw [hmiss]; simp

/-- FAIL-CLOSED (trace level): a recorded event observed with a CHANGED payload
    fingerprint rejects the replay. If the observed table binds the recorded key to
    a decision whose event fingerprint differs (`sameEvent … = false`),
    `verifyReplay` fails — a changed recording is never silently accepted. -/
theorem verifyReplay_changed_rejected
    (expected observed : Timeline) (wanted actual : EventTable)
    (hexp : validateTimeline expected = some wanted)
    (hobs : validateTimeline observed = some actual)
    (binding : EventKey × Decision) (hbind : binding ∈ wanted) (found : Decision)
    (hfound : tableLookup (eventKey binding.2.event) actual = some found)
    (hchanged : sameEvent binding.2.event found.event = false) :
    verifyReplay expected observed = false := by
  unfold verifyReplay
  rw [hexp, hobs]
  apply all_false_of_mem_false wanted _ binding hbind
  unfold observedMatches
  rw [hfound]
  simp only [hchanged, Bool.false_and]

end Rechaos
