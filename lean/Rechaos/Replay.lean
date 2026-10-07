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
abbrev event_table := List (EventKey × decision)

/-- The outcome of a single-event replay lookup. Mirrors the Haskell
    `Either Text Decision`: `rejected` is the `Left` (replay fails closed), and
    `decided d` is the `Right d` (the decision to apply). -/
inductive replay_outcome
  | /-- Replay failed closed (unexpected or changed event). -/ rejected
  | /-- Replay accepted, carrying the decision to apply. -/ decided (decision : decision)
  deriving Repr, DecidableEq, Inhabited

/-- Whether a membership key already appears in a partially-built table. The
    counterpart of the Haskell `M.member k acc` guard. -/
def table_member (key : EventKey) : event_table → Bool
  | []             => false
  | (k, _) :: rest => if k == key then true else table_member key rest

/-- Look a key up in an `EventTable`, returning the first binding (there is at
    most one in a validated table). The counterpart of `M.lookup`. -/
def table_lookup (key : EventKey) : event_table → Option decision
  | []               => none
  | (k, dec) :: rest => if k == key then some dec else table_lookup key rest

/-- Index a timeline by `EventKey`, failing (`none`) if any event identity
    repeats. A well-formed timeline has at most one decision per event. The
    duplicate guard (`tableMember`) mirrors the reference `Data.Map`-insert check;
    the resulting association order is unspecified, as for a `Data.Map`. Faithful to
    the Haskell `validateTimeline`. -/
def validate_timeline (tl : timeline) : Option event_table :=
  go [] tl
  where
    go (acc : event_table) : timeline → Option event_table
      | [] => some acc
      | dec :: rest =>
          let key := eventKey dec.event
          if table_member key acc then none
          else go ((key, dec) :: acc) rest

/-- Look up the decision for a live event against a recorded timeline table. The
    `sparse` flag selects the semantics: a full recording (`false`) fails closed
    on any event missing from the table, whereas a sparse fault timeline (`true`)
    passes unlisted traffic through with no injection. Either way, an event present
    in the table must still match its recorded fingerprint (via `sameEvent`), or
    replay is rejected. Faithful to the Haskell `replayDecision`. -/
def replay_decision (sparse : Bool) (table : event_table) (evt : Event) : replay_outcome :=
  match table_lookup (eventKey evt) table with
  | none => if sparse then .decided { event := evt, injection := none } else .rejected
  | some recorded =>
    if same_event recorded.event evt then
      .decided { event := evt, injection := recorded.injection }
    else
      .rejected

/-- Whether a single recorded decision was observed, unchanged, with an identical
    injection, in the observed table. The counterpart of the per-element `check`
    inside the Haskell `verifyReplay`: the recorded key must be present, carry a
    matching fingerprint (`sameEvent`), and inject exactly the recorded fault. -/
def observed_matches (observed : event_table) (recorded : decision) : Bool :=
  match table_lookup (eventKey recorded.event) observed with
  | none       => false
  | some found => same_event recorded.event found.event && recorded.injection == found.injection

/-- Check an observed timeline against an expected one (the forward inclusion).
    Succeeds (`true`) only when both timelines validate and every expected event
    occurred with a matching fingerprint and an identical injection. A replay is
    not complete merely because none of its observed events mismatched: every
    recorded event must also have happened — so an incomplete replay is rejected.
    Tolerates extra observed traffic not present in `expected`, the correct
    semantics for a sparse fault timeline. Faithful to the Haskell `verifyReplay`
    (modelled as a boolean verdict: `true` is `Right ()`, `false` is `Left _`). -/
def verify_replay (expected observed : timeline) : Bool :=
  match validate_timeline expected, validate_timeline observed with
  | some wanted, some actual => wanted.all (fun binding => observed_matches actual binding.2)
  | _, _ => false

-- ── structural facts about the table ─────────────────────────────────────────

/-- `tableLookup` finds a key just inserted at the head of a table. -/
theorem table_lookup_cons_self
        (key : EventKey)
        (dec : decision)
        (rest : event_table)
        : table_lookup key ((key, dec) :: rest) = some dec := by simp [table_lookup]

/-- `replayDecision` on an empty table passes a sparse event through and fails a
    full recording closed, for any event — the "missing event" dichotomy. -/
theorem replay_decision_nil
        (sparse : Bool)
        (evt : Event)
        : replay_decision sparse [] evt
            = (if sparse then .decided { event := evt, injection := none } else .rejected) := by
  simp [replay_decision, table_lookup]

/-- FAIL-CLOSED (single event): a live event whose key is recorded but whose
    fingerprint differs from the recording is rejected, under either semantics.
    This is the heart of the fail-closed contract — a changed payload can never
    be silently accepted. -/
theorem replay_decision_rejects_changed_fingerprint
        (sparse : Bool)
        (table : event_table)
        (evt : Event)
        (recorded : decision)
        (hkey : table_lookup (eventKey evt) table = some recorded)
        (hchanged : same_event recorded.event evt = false)
        : replay_decision sparse table evt = .rejected := by simp [replay_decision, hkey, hchanged]

/-- A recorded event re-observed with the SAME fingerprint replays its recorded
    injection — the positive counterpart of fail-closed. -/
theorem replay_decision_reuses_recorded_injection
        (sparse : Bool)
        (table : event_table)
        (evt : Event)
        (recorded : decision)
        (hkey : table_lookup (eventKey evt) table = some recorded)
        (hsame : same_event recorded.event evt = true)
        : replay_decision sparse table evt
            = .decided { event := evt, injection := recorded.injection } := by
  simp [replay_decision, hkey, hsame]

-- ── validated-table invariants (the engine of the abstract theorems) ─────────

/-- `tableMember` is the decidable negation of key membership in the table's key
    list: it reports `false` exactly when the key is absent. Bridges the duplicate
    guard in `validateTimeline` to the `Nodup` reasoning below. -/
theorem table_member_false_iff
        (key : EventKey)
        (table : event_table)
        : table_member key table = false ↔ key ∉ table.map (·.1) := by
  induction table with
  | nil => simp [table_member]
  | cons head rest ih =>
    obtain ⟨k, dec⟩ := head
    simp only [table_member, List.map_cons, List.mem_cons]
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
theorem lookup_of_mem_nodup
        : ∀ (table : event_table),
            (table.map (·.1)).Nodup
                → ∀ binding ∈ table, table_lookup binding.1 table = some binding.2 := by
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
    · subst heq; simp [table_lookup]
    · have hblk : binding.1 ≠ k := by
        intro hcontra
        apply hnotin
        rw [← hcontra]
        exact List.mem_map_of_mem hmem
      simp only [table_lookup]
      rw [if_neg (by simp only [beq_iff_eq]; exact fun h => hblk h.symm)]
      exact ih hrest binding hmem

/-- `validateTimeline.go` preserves key-distinctness: starting from a `Nodup`
    accumulator, a successful validation yields a table whose keys are still
    `Nodup`. The duplicate guard refuses to insert any key already present. -/
theorem go_nodup
        : ∀ (decisions : timeline) (acc table : event_table),
            (acc.map (·.1)).Nodup
                → validate_timeline.go acc decisions = some table
                → (table.map (·.1)).Nodup := by
  intro decisions
  induction decisions with
  | nil =>
    intro acc table hacc hgo
    simp only [validate_timeline.go, Option.some.injEq] at hgo
    subst hgo; exact hacc
  | cons dec rest ih =>
    intro acc table hacc hgo
    simp only [validate_timeline.go] at hgo
    by_cases hmem : table_member (eventKey dec.event) acc = true
    · simp [hmem] at hgo
    · have hmemf : table_member (eventKey dec.event) acc = false := by simpa using hmem
      rw [if_neg (by simp [hmemf])] at hgo
      apply ih ((eventKey dec.event, dec) :: acc) table _ hgo
      simp only [List.map_cons, List.nodup_cons]
      exact ⟨(table_member_false_iff _ _).mp hmemf, hacc⟩

/-- `validateTimeline.go` preserves the key-agreement invariant: every binding it
    stores has `binding.1 = eventKey binding.2.event`, because it only ever inserts
    `(eventKey decision.event, decision)`. -/
theorem go_key_agree
        : ∀ (decisions : timeline) (acc table : event_table),
            (∀ binding ∈ acc, binding.1 = eventKey binding.2.event)
                → validate_timeline.go acc decisions = some table
                → (∀ binding ∈ table, binding.1 = eventKey binding.2.event) := by
  intro decisions
  induction decisions with
  | nil =>
    intro acc table hacc hgo
    simp only [validate_timeline.go, Option.some.injEq] at hgo
    subst hgo; exact hacc
  | cons dec rest ih =>
    intro acc table hacc hgo
    simp only [validate_timeline.go] at hgo
    by_cases hmem : table_member (eventKey dec.event) acc = true
    · simp [hmem] at hgo
    · have hmemf : table_member (eventKey dec.event) acc = false := by simpa using hmem
      rw [if_neg (by simp [hmemf])] at hgo
      apply ih _ table _ hgo
      intro binding hbind
      rw [List.mem_cons] at hbind
      rcases hbind with heq | hmem'
      · subst heq; rfl
      · exact hacc binding hmem'

/-- A validated table has distinct keys. The top-level corollary of `go_nodup`. -/
theorem validate_timeline_nodup
        (tl : timeline)
        (table : event_table)
        (hval : validate_timeline tl = some table)
        : (table.map (·.1)).Nodup :=
  go_nodup tl [] table (by simp) hval

/-- Every binding of a validated table is keyed by its own event's `eventKey`. The
    top-level corollary of `go_key_agree`. -/
theorem validate_timeline_key_agree
        (tl : timeline)
        (table : event_table)
        (hval : validate_timeline tl = some table)
        : ∀ binding ∈ table, binding.1 = eventKey binding.2.event :=
  go_key_agree tl [] table (by simp) hval

/-- Each binding of a validated table matches itself under `observedMatches`: the
    key is found, the fingerprint agrees (reflexively), and the injection is
    identical. The per-binding core of self-coverage. -/
theorem observed_matches_self
        (tl : timeline)
        (table : event_table)
        (hval : validate_timeline tl = some table)
        (binding : EventKey × decision)
        (hbind : binding ∈ table)
        : observed_matches table binding.2 = true := by
  have hnodup := validate_timeline_nodup tl table hval
  have hagree := validate_timeline_key_agree tl table hval binding hbind
  have hlook : table_lookup binding.1 table = some binding.2 :=
    lookup_of_mem_nodup table hnodup binding hbind
  unfold observed_matches
  rw [← hagree, hlook]
  simp [same_event_refl]

/-- A helper for rejection: if any element of a list fails the predicate, the
    boolean `all` over that list is `false`. The engine of the coverage and
    fail-closed rejection theorems below. -/
theorem all_false_of_mem_false
        {α : Type}
        (elems : List α)
        (pred : α → Bool)
        (elem : α)
        (hmem : elem ∈ elems)
        (hpred : pred elem = false)
        : elems.all pred = false := by
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
theorem replay_decision_recorded_identity
        (sparse : Bool)
        (tl : timeline)
        (table : event_table)
        (hval : validate_timeline tl = some table)
        (binding : EventKey × decision)
        (hbind : binding ∈ table)
        : replay_decision sparse table binding.2.event
            = .decided { event := binding.2.event, injection := binding.2.injection } := by
  have hnodup := validate_timeline_nodup tl table hval
  have hagree := validate_timeline_key_agree tl table hval binding hbind
  have hlook : table_lookup binding.1 table = some binding.2 :=
    lookup_of_mem_nodup table hnodup binding hbind
  apply replay_decision_reuses_recorded_injection
  · rw [← hagree]; exact hlook
  · simp [same_event_refl]

/-- REPLAY IDENTITY (trace level): any timeline that validates verifies against
    itself. Replaying a recording against the very events it recorded always
    succeeds — every recorded event is observed, unchanged, with its recorded
    injection. The headline round-trip of the replay layer. -/
theorem verify_replay_identity
        (tl : timeline)
        (table : event_table)
        (hval : validate_timeline tl = some table)
        : verify_replay tl tl = true := by
  unfold verify_replay
  rw [hval]
  simp only
  rw [List.all_eq_true]
  intro binding hbind
  exact observed_matches_self tl table hval binding hbind

/-- REPLAY IDENTITY specialized to the scheduler: when the timeline produced by
    `schedule policy events` validates (its events carry distinct identities),
    replaying it against itself reproduces exactly those decisions. This is the
    round-trip that closes the determinism contract — the decisions `schedule`
    emits are precisely the decisions a replay of them recovers. -/
theorem verify_replay_schedule_identity
        (pol : policy)
        (events : List Event)
        (table : event_table)
        (hval : validate_timeline (schedule pol events) = some table)
        : verify_replay (schedule pol events) (schedule pol events) = true :=
  verify_replay_identity (schedule pol events) table hval

/-- COVERAGE: a recorded event that never arrived rejects the replay. If a binding
    of the validated expected table has no counterpart in the observed table
    (`tableLookup … = none`), `verifyReplay` fails — an incomplete replay is never
    accepted, even when nothing observed mismatched. -/
theorem verify_replay_missing_rejected
        (expected observed : timeline)
        (wanted actual : event_table)
        (hexp : validate_timeline expected = some wanted)
        (hobs : validate_timeline observed = some actual)
        (binding : EventKey × decision)
        (hbind : binding ∈ wanted)
        (hmiss : table_lookup (eventKey binding.2.event) actual = none)
        : verify_replay expected observed = false := by
  unfold verify_replay
  rw [hexp, hobs]
  apply all_false_of_mem_false wanted _ binding hbind
  unfold observed_matches
  rw [hmiss]

/-- COVERAGE (sharp form): a nonempty recording replayed against an empty observed
    timeline is always rejected — nothing arrived, so no recorded event is covered. -/
theorem verify_replay_empty_observed_rejected
        (expected : timeline)
        (table : event_table)
        (hval : validate_timeline expected = some table)
        (hne : table ≠ [])
        : verify_replay expected [] = false := by
  unfold verify_replay
  rw [hval]
  simp only [validate_timeline, validate_timeline.go]
  cases table with
  | nil => exact absurd rfl hne
  | cons binding rest =>
    simp only [List.all_cons]
    have hmiss : observed_matches [] binding.2 = false := by
      unfold observed_matches; simp [table_lookup]
    rw [hmiss]; simp

/-- FAIL-CLOSED (trace level): a recorded event observed with a CHANGED payload
    fingerprint rejects the replay. If the observed table binds the recorded key to
    a decision whose event fingerprint differs (`sameEvent … = false`),
    `verifyReplay` fails — a changed recording is never silently accepted. -/
theorem verify_replay_changed_rejected
        (expected observed : timeline)
        (wanted actual : event_table)
        (hexp : validate_timeline expected = some wanted)
        (hobs : validate_timeline observed = some actual)
        (binding : EventKey × decision)
        (hbind : binding ∈ wanted)
        (found : decision)
        (hfound : table_lookup (eventKey binding.2.event) actual = some found)
        (hchanged : same_event binding.2.event found.event = false)
        : verify_replay expected observed = false := by
  unfold verify_replay
  rw [hexp, hobs]
  apply all_false_of_mem_false wanted _ binding hbind
  unfold observed_matches
  rw [hfound]
  simp only [hchanged, Bool.false_and]

end Rechaos
