/-
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                      // rechaos // lean // scheduler
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  rechaos — the scheduler layer (Lean port of `Rechaos.Core.Scheduler`).

  Mirrors the Haskell `matches` / `step` / `schedule` faithfully over the Lean
  `Types`: first-match targeting, one `nextSeed` draw per event, and the
  probability gate `draw % ppmDenominator < chancePpm`. The seed advances once
  per event whether or not any rule matched, exactly as in the reference.

  Discipline: the Haskell reference LEADS. The concrete probability-gate and
  decision behaviour is checked against reference-generated corpora by
  `native_decide` in `Rechaos.SchedulerCorpus`; the abstract first-match
  SELECTION law (`choose_first_match`, `choose_skips_nonmatching`, …) is proved
  here by structural induction, with no `UInt64` arithmetic forced in the kernel.
  There is no `sorry`, no `admit`, and no new `axiom`.
-/

import Rechaos.Core
import Rechaos.Types

namespace Rechaos

set_option autoImplicit false

/-- Whether a `Target` selects an `Event`. All constraints must hold (logical
    AND); absent optional fields match anything. Numeric bounds are inclusive,
    and a present blob bound never matches an event that carries no blob. Faithful
    to the Haskell `matches`: method and direction are exact, optional fields use
    the "default true" convention. -/
def matchesTarget (tgt : Target) (evt : Event) : Bool :=
  tgt.method == evt.method
    && tgt.direction == evt.direction
    && (match tgt.occurrence with | none => true | some occ => occ == evt.occurrence)
    && (match tgt.messageIndex with | none => true | some idx => idx == evt.messageIndex)
    && (match tgt.minBlobBytes with
        | none => true
        | some lo => (match evt.blobBytes with | none => false | some b => lo ≤ b))
    && (match tgt.maxBlobBytes with
        | none => true
        | some hi => (match evt.blobBytes with | none => false | some b => b ≤ hi))
    && (match tgt.afterMicros with | none => true | some af => af ≤ evt.elapsedMicros)
    && (match tgt.beforeMicros with | none => true | some bf => evt.elapsedMicros ≤ bf)

/-- The probability gate: a rule fires when the SplitMix64 draw modulo
    `ppmDenominator` is below the rule's `chancePpm`. The draw is the *output*
    half of `nextSeed` (`.1` in Lean, matching the Haskell `snd`). Kept total and
    concrete; its arithmetic is only ever forced under `native_decide`. -/
def fires (chancePpm : Nat) (draw : UInt64) : Bool :=
  draw.toNat % ppmDenominator < chancePpm

/-- First-match rule selection over a draw: walk the rules in priority order and
    return the first matching rule's fault when the gate fires, `none` otherwise.
    Structurally recursive on the rule list, so the SELECTION proofs below are
    tractable. Mirrors the Haskell `choose` nested in `step`. -/
def choose (rules : List Rule) (draw : UInt64) (evt : Event) : Option Fault :=
  match rules with
  | [] => none
  | rul :: rest =>
      if matchesTarget rul.target evt then
        if fires rul.chancePpm draw then some rul.fault else none
      else
        choose rest draw evt

/-- Make one scheduling decision. Advances the seed exactly once (via `nextSeed`,
    taking the state projection `.2`) and injects the first matching rule's fault
    when its gate fires. The seed advances whether or not any rule matched,
    keeping the stream aligned to event position. Returns `(nextState, decision)`
    to match the Haskell `step`'s `(Word64, Decision)`. -/
def step (rules : List Rule) (state : UInt64) (evt : Event) : UInt64 × Decision :=
  let draw := (nextSeed state).1
  let state' := (nextSeed state).2
  (state', { event := evt, injection := choose rules draw evt })

/-- Thread the seed left-to-right across an event trace, collecting decisions.
    Structurally recursive on the trace; mirrors the Haskell `mapAccumL` in
    `schedule`. Returns the final state paired with the timeline. -/
def scheduleFrom (rules : List Rule) : UInt64 → List Event → UInt64 × Timeline
  | state, [] => (state, [])
  | state, evt :: rest =>
      let (state', dec) := step rules state evt
      let (stateFinal, tl) := scheduleFrom rules state' rest
      (stateFinal, dec :: tl)

/-- Run the scheduler over a whole event trace, threading the seed from the
    policy's initial `seed`. Same policy + seed + trace always produce the same
    `Timeline`. Faithful to the Haskell `schedule`. -/
def schedule (pol : Policy) (events : List Event) : Timeline :=
  (scheduleFrom pol.rules pol.seed events).2

-- ── probability-gate lemmas (abstract over the draw) ────────────────────────

/-- A zero-chance rule never fires, for any draw: `0 ppm` is certainty of a
    pass-through. The modulus is irrelevant because nothing is `< 0`. -/
theorem fires_zero_never (draw : UInt64) : fires 0 draw = false := by
  simp [fires]

/-- A rule at the full `ppmDenominator` chance always fires, for any draw: the
    draw modulo the denominator is strictly below the denominator, so the gate is
    always open. This is the Lean counterpart of the Haskell "chancePpm == maxPpm
    always fires" invariant, proved abstractly over the draw. -/
theorem fires_full_always (draw : UInt64) : fires ppmDenominator draw = true := by
  simp only [fires, decide_eq_true_eq]
  exact Nat.mod_lt _ (by decide)

-- ── first-match SELECTION law (abstract, structural induction) ───────────────

/-- SELECTION, empty: with no rules, nothing is ever injected. -/
theorem choose_nil (draw : UInt64) (evt : Event) : choose [] draw evt = none := rfl

/-- SELECTION, skip: a leading rule whose target does NOT match the event is
    transparent — selection continues with the remaining rules exactly as if the
    nonmatching rule were absent. This is the "only matching rules participate"
    half of first-match. -/
theorem choose_skips_nonmatching
    (rul : Rule) (rest : List Rule) (draw : UInt64) (evt : Event)
    (hmiss : matchesTarget rul.target evt = false) :
    choose (rul :: rest) draw evt = choose rest draw evt := by
  simp [choose, hmiss]

/-- SELECTION, ownership: the FIRST matching rule owns the event. When the
    leading rule's target matches, the outcome is decided entirely by that rule's
    gate — the remaining rules are never consulted. Injects that rule's fault iff
    its gate fires. This is the core first-match semantics. -/
theorem choose_first_match
    (rul : Rule) (rest : List Rule) (draw : UInt64) (evt : Event)
    (hhit : matchesTarget rul.target evt = true) :
    choose (rul :: rest) draw evt =
      (if fires rul.chancePpm draw then some rul.fault else none) := by
  simp [choose, hhit]

/-- SELECTION corollary: once the first matching rule is found, no later rule can
    inject in its place. If the head matches, the decision is independent of the
    tail `rest` — swapping the tail leaves the decision unchanged. This rules out
    accidental fallthrough to a lower-priority rule. -/
theorem choose_head_owns_independent_of_tail
    (rul : Rule) (rest other : List Rule) (draw : UInt64) (evt : Event)
    (hhit : matchesTarget rul.target evt = true) :
    choose (rul :: rest) draw evt = choose (rul :: other) draw evt := by
  rw [choose_first_match rul rest draw evt hhit,
      choose_first_match rul other draw evt hhit]

/-- SELECTION, first-match pins to the firing gate: if the head matches AND its
    gate fires, `choose` injects exactly that head rule's fault, independent of
    everything downstream. The sharpest ownership statement. -/
theorem choose_first_match_fires
    (rul : Rule) (rest : List Rule) (draw : UInt64) (evt : Event)
    (hhit : matchesTarget rul.target evt = true)
    (hfire : fires rul.chancePpm draw = true) :
    choose (rul :: rest) draw evt = some rul.fault := by
  rw [choose_first_match rul rest draw evt hhit, if_pos hfire]

/-- SELECTION, a matching-but-shut head still owns (as a pass-through): if the head
    matchesTarget but its gate does NOT fire, `choose` is `none` — the event is NOT
    offered to the tail. First-match ownership includes the decision to pass
    through. -/
theorem choose_first_match_shut
    (rul : Rule) (rest : List Rule) (draw : UInt64) (evt : Event)
    (hhit : matchesTarget rul.target evt = true)
    (hshut : fires rul.chancePpm draw = false) :
    choose (rul :: rest) draw evt = none := by
  rw [choose_first_match rul rest draw evt hhit, if_neg (by simp [hshut])]

-- ── step / schedule structural facts ────────────────────────────────────────

/-- `step` advances the seed by exactly the `nextSeed` state projection, whatever
    the rules or event — the "one draw per event, regardless of match" invariant
    at the single-step level. -/
theorem step_advances_once (rules : List Rule) (state : UInt64) (evt : Event) :
    (step rules state evt).1 = (nextSeed state).2 := rfl

/-- `step` never alters the event it decides on: the decision's event is the
    input event. -/
theorem step_preserves_event (rules : List Rule) (state : UInt64) (evt : Event) :
    (step rules state evt).2.event = evt := rfl

/-- `step`'s injection is exactly `choose` over the draw: the decision's fault is
    the first-match selection, linking `step` to the SELECTION law above. -/
theorem step_injection_eq_choose (rules : List Rule) (state : UInt64) (evt : Event) :
    (step rules state evt).2.injection = choose rules (nextSeed state).1 evt := rfl

/-- With no rules, `step` always passes the event through (no injection), for any
    seed. The empty policy is a no-op scheduler. -/
theorem step_nil_passthrough (state : UInt64) (evt : Event) :
    (step [] state evt).2.injection = none := rfl

/-- `schedule` over an empty trace is the empty timeline. No event, no decision. -/
theorem schedule_nil (pol : Policy) : schedule pol [] = [] := rfl

/-- The timeline has exactly one decision per event: `scheduleFrom` preserves the
    trace length. Proved by induction on the trace, abstract over the seed. -/
theorem scheduleFrom_length (rules : List Rule) :
    ∀ (state : UInt64) (events : List Event),
      (scheduleFrom rules state events).2.length = events.length := by
  intro state events
  induction events generalizing state with
  | nil => rfl
  | cons _ rest ih =>
      simp only [scheduleFrom, List.length_cons]
      exact congrArg (· + 1) (ih _)

/-- `schedule` emits exactly one decision per observed event. A corollary of
    `scheduleFrom_length`. -/
theorem schedule_length (pol : Policy) (events : List Event) :
    (schedule pol events).length = events.length :=
  scheduleFrom_length pol.rules pol.seed events

/-- Each decision in a `scheduleFrom` run is made for the event at the same
    position: the decisions' events are exactly the input trace. Proved by
    induction on the trace. -/
theorem scheduleFrom_events (rules : List Rule) :
    ∀ (state : UInt64) (events : List Event),
      (scheduleFrom rules state events).2.map (·.event) = events := by
  intro state events
  induction events generalizing state with
  | nil => rfl
  | cons evt rest ih =>
      simp only [scheduleFrom, List.map_cons, step_preserves_event]
      exact congrArg (evt :: ·) (ih _)

/-- `schedule` decides on exactly the input events, in order. A corollary of
    `scheduleFrom_events`. -/
theorem schedule_events (pol : Policy) (events : List Event) :
    (schedule pol events).map (·.event) = events :=
  scheduleFrom_events pol.rules pol.seed events

end Rechaos
