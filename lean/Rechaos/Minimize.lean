/-
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                       // rechaos // lean // minimize
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  rechaos — the witness-preserving minimizer (Lean port of `Rechaos.Core.Minimize`).

  Shrinks a failing `Timeline` down to a small reproducer through a candidate /
  observe state machine (`ShrinkState`): `start` seeds it from a failing timeline,
  `candidate` offers the next timeline to try, and `observe` folds the shell's
  `Verdict` back in — accepting a candidate only on a `triggers` verdict. The
  candidate generator (`candidates`) offers chunk deletions at halving sizes down
  to singletons plus intensity reductions (`weaker`) that replace one injected
  fault with a strictly weaker one.

  Discipline: the Haskell reference LEADS. The concrete candidate set and one
  acceptance-driven shrink trajectory are checked against a reference-generated
  corpus by `native_decide` in `Rechaos.MinimizeCorpus`; the abstract theorems
  (candidate TERMINATION under a `(length, summed-intensity)` measure, and
  acceptance WITNESS PRESERVATION) are proved here over core Lean, with no
  Mathlib and no `UInt64` arithmetic forced in the kernel. There is no `sorry`,
  no `admit`, and no new `axiom`.
-/

import Rechaos.Types

namespace Rechaos

set_option autoImplicit false

/-- The shell's judgement on a shrink candidate. The shell must reproduce the
    SAME failure signature, not merely a nonzero exit code: a flaky, timeout, or
    infrastructure result is `unknown` and is treated conservatively (the
    candidate is discarded, not accepted). Mirrors the Haskell `Verdict`. -/
inductive MinimizeVerdict
  | /-- The candidate reproduced the original failure signature. -/
    triggers
  | /-- The candidate ran but did not reproduce the failure. -/
    doesNotTrigger
  | /-- The run was inconclusive (flake, timeout, infrastructure error). -/
    unknown
  deriving Repr, DecidableEq, Inhabited

/-- The minimizer's state: the best (smallest) timeline known to trigger so far,
    and the queue of candidates still to try against it. Mirrors the Haskell
    `ShrinkState`. -/
structure ShrinkState where
  best    : Timeline
  pending : List Timeline
  deriving Repr, DecidableEq, Inhabited

/-- Strictly weaker variants of a fault, if any, used for intensity shrinking.
    Each step moves along a finite, decreasing measure toward the event's natural
    bound: `delay` halves toward zero, `dribble` doubles its rate toward the
    message's full-speed cap (`messageBytes * microsPerSecond`, the rate that
    delivers the whole message in one microsecond), `truncate` raises its
    kept-byte count toward the full message size, and `corrupt` halves its
    corrupted-byte count toward one. `abort` has no weaker form.
    Mirrors the Haskell `weaker`. -/
def weaker (anchor : Event) : Fault → List Fault
  | .delay micros => if micros > 0 then [.delay (micros / 2)] else []
  | .dribble rate chunk =>
      let cap := Nat.max 1 (anchor.messageBytes * microsPerSecond)
      if rate < cap then [.dribble (Nat.min cap (Nat.max 1 rate * 2)) chunk] else []
  | .truncate keep =>
      let cap := anchor.messageBytes
      if keep < cap then [.truncate (keep + Nat.max 1 ((cap - keep) / 2))] else []
  | .corrupt n => if n > 1 then [.corrupt (n / 2)] else []
  | .abort _ => []

/-- The halving chunk sizes a deletion pass sweeps over: `n`, then `n/2`, …, down
    to `1`. Structurally recursive on an explicit fuel equal to the list length,
    so Lean accepts it without a termination proof over `n / 2`. Mirrors the
    Haskell `descending`. -/
def descending : Nat → Nat → List Nat
  | 0, _ => []
  | _, 0 => []
  | _ + 1, 1 => [1]
  | fuel + 1, size => size :: descending fuel (size / 2)

/-- The offsets `0, step, 2*step, …` strictly below `limit`. A structurally
    recursive enumeration on fuel (the list length is an ample bound), mirroring
    the Haskell comprehension `[0, k .. n - 1]`. -/
def strideOffsets (fuel : Nat) (step : Nat) (start : Nat) (limit : Nat) : List Nat :=
  match fuel with
  | 0 => []
  | fuel + 1 =>
      if start < limit then start :: strideOffsets fuel step (start + Nat.max 1 step) limit
      else []

/-- Deduplicate a list of timelines, preserving first-seen order. The reference
    uses `Data.List.nub`; here equality is `DecidableEq` on `Timeline`. -/
def nubTimelines : List Timeline → List Timeline
  | [] => []
  | tl :: rest => tl :: nubTimelines (rest.filter (fun other => other != tl))
  termination_by timelines => timelines.length
  decreasing_by
    simp_wf
    exact Nat.lt_succ_of_le (List.length_filter_le _ rest)

/-- All shrink candidates derived from a timeline: chunk deletions at halving
    sizes down to singletons, plus intensity reductions that replace one injected
    fault with a strictly weaker one. Deletion down to singletons is what makes a
    converged result deletion-1-minimal for a deterministic predicate; the
    intensity candidates follow a finite, decreasing measure (see `weaker`), and
    timing stays explicit in the retained event identity and `delay` value.
    Mirrors the Haskell `candidates`. -/
def candidates (timeline : Timeline) : List Timeline :=
  let len := timeline.length
  let sizes := descending len len
  let deletions :=
    sizes.flatMap (fun chunk =>
      (strideOffsets (len + 1) chunk 0 len).map (fun offset =>
        timeline.take offset ++ timeline.drop (offset + chunk)))
  let intensities :=
    timeline.zipIdx.flatMap (fun pair =>
      let decision := pair.1
      let offset := pair.2
      match decision.injection with
      | none => []
      | some old =>
          (weaker decision.event old).map (fun replacement =>
            timeline.take offset
              ++ [{ decision with injection := some replacement }]
              ++ timeline.drop (offset + 1)))
  nubTimelines (deletions ++ intensities)

/-- Seed the state machine from a failing timeline. Keeps only its injected
    faults as the initial `best` and enqueues their `candidates`. Mirrors the
    Haskell `start`. -/
def start (timeline : Timeline) : ShrinkState :=
  let faults := timeline.filter (fun decision => decision.injection.isSome)
  { best := faults, pending := candidates faults }

/-- The next candidate timeline to test, or `none` when the queue is empty and
    shrinking has converged on `best`. Mirrors the Haskell `candidate`. -/
def candidate : ShrinkState → Option Timeline
  | { pending := [], .. } => none
  | { pending := next :: _, .. } => some next

/-- Fold the shell's `Verdict` on the current candidate back into the state. On
    `triggers` the candidate becomes the new `best` and its own `candidates` are
    enqueued (restarting the search from the smaller timeline); on
    `doesNotTrigger` or `unknown` the candidate is discarded and the next one is
    tried. Conservative: an `unknown` never advances `best`. Mirrors the Haskell
    `observe`. -/
def observe (verdict : MinimizeVerdict) (state : ShrinkState) : ShrinkState :=
  match state.pending with
  | [] => state
  | next :: rest =>
      match verdict with
      | .triggers => { best := next, pending := candidates next }
      | _ => { best := state.best, pending := rest }

-- ── termination measure ───────────────────────────────────────────────────────

/-- Severity of an injected fault at its anchoring event: the Haskell
    `(length, summed-severity)` measure's intensity component, decreasing exactly
    when `weaker` fires. `delay` is its own micros; `truncate` is how many bytes
    it drops below the full message; `dribble` is how far its rate sits below the
    full-speed cap; `corrupt` is its corrupted-byte count; `abort` has no
    intensity. -/
def severity (anchor : Event) : Fault → Nat
  | .delay micros => micros
  | .abort _ => 0
  | .truncate keep => anchor.messageBytes - Nat.min anchor.messageBytes keep
  | .corrupt n => n
  | .dribble rate _ =>
      let cap := Nat.max 1 (anchor.messageBytes * microsPerSecond)
      cap - Nat.min cap rate

/-- The summed intensity of every injected fault in a timeline. The second
    component of the well-founded shrink measure. -/
def summedIntensity : Timeline → Nat
  | [] => 0
  | decision :: rest =>
      (match decision.injection with
       | none => 0
       | some fault => severity decision.event fault)
      + summedIntensity rest

/-- The well-founded shrink measure: `(length, summed-intensity)`, ordered
    lexicographically. Every generated candidate is strictly smaller under it, so
    the shrink loop terminates. -/
def measure (timeline : Timeline) : Nat × Nat :=
  (timeline.length, summedIntensity timeline)

/-- Lexicographic strictly-less on the `(length, summed-intensity)` measure:
    shorter wins outright; on a length tie, lower summed intensity wins. -/
def measureLt (left right : Nat × Nat) : Prop :=
  left.1 < right.1 ∨ (left.1 = right.1 ∧ left.2 < right.2)

-- ── abstract theorem: candidate TERMINATION ───────────────────────────────────

/-- A single `weaker` result is strictly weaker at its anchoring event: its
    `severity` drops. The engine of the summed-intensity decrease, proved by
    cases on the fault with the numeric side-conditions of each `weaker` branch.
    No `UInt64` arithmetic: every quantity here is `Nat`. -/
theorem weaker_severity_lt
    (anchor : Event) (old new : Fault) (hmem : new ∈ weaker anchor old) :
    severity anchor new < severity anchor old := by
  cases old with
  | delay micros =>
      simp only [weaker] at hmem
      by_cases hpos : micros > 0
      · simp only [hpos, if_true, List.mem_singleton] at hmem
        subst hmem
        simp only [severity]
        omega
      · simp only [hpos, if_false, List.not_mem_nil] at hmem
  | abort status =>
      simp only [weaker, List.not_mem_nil] at hmem
  | truncate keep =>
      simp only [weaker] at hmem
      by_cases hlt : keep < anchor.messageBytes
      · simp only [hlt, if_true, List.mem_singleton] at hmem
        subst hmem
        simp only [severity]
        -- The new keep count is `keep + bump` with `bump = max 1 ((mb-keep)/2)`.
        -- `1 ≤ bump ≤ mb - keep`, so the new keep strictly increases yet stays
        -- within the message, and both `min`s resolve to their right argument.
        have hbump_lo : (1 : Nat) ≤ Nat.max 1 ((anchor.messageBytes - keep) / 2) :=
          Nat.le_max_left 1 _
        have hbump_hi : Nat.max 1 ((anchor.messageBytes - keep) / 2)
            ≤ anchor.messageBytes - keep := by
          apply Nat.max_le.mpr
          refine ⟨by omega, ?_⟩
          exact Nat.le_trans (Nat.div_le_self _ 2) (Nat.le_refl _)
        have hkeep : Nat.min anchor.messageBytes keep = keep :=
          Nat.min_eq_right (Nat.le_of_lt hlt)
        have hnew : Nat.min anchor.messageBytes
            (keep + Nat.max 1 ((anchor.messageBytes - keep) / 2))
            = keep + Nat.max 1 ((anchor.messageBytes - keep) / 2) :=
          Nat.min_eq_right (by omega)
        rw [hkeep, hnew]
        omega
      · simp only [hlt, if_false, List.not_mem_nil] at hmem
  | corrupt n =>
      simp only [weaker] at hmem
      by_cases hgt : n > 1
      · simp only [hgt, if_true, List.mem_singleton] at hmem
        subst hmem
        simp only [severity]
        omega
      · simp only [hgt, if_false, List.not_mem_nil] at hmem
  | dribble rate chunk =>
      simp only [weaker] at hmem
      by_cases hlt : rate < Nat.max 1 (anchor.messageBytes * microsPerSecond)
      · simp only [hlt, if_true, List.mem_singleton] at hmem
        subst hmem
        simp only [severity]
        -- Abbreviate the cap as `cap`; the new rate is `min cap (max 1 rate * 2)`,
        -- which is strictly greater than `rate` yet still at most `cap`. Resolve
        -- every `min` to a plain term, then the subtraction inequality is linear.
        generalize hc : Nat.max 1 (anchor.messageBytes * microsPerSecond) = cap at *
        have hnewle : Nat.min cap (Nat.max 1 rate * 2) ≤ cap := Nat.min_le_left _ _
        have hgt : rate < Nat.max 1 rate * 2 := by
          have hup : rate ≤ Nat.max 1 rate := Nat.le_max_right 1 rate
          have hpos : (1 : Nat) ≤ Nat.max 1 rate := Nat.le_max_left 1 rate
          omega
        have hge : rate < Nat.min cap (Nat.max 1 rate * 2) :=
          Nat.lt_min.mpr ⟨hlt, hgt⟩
        have hinner : Nat.min cap (Nat.min cap (Nat.max 1 rate * 2))
            = Nat.min cap (Nat.max 1 rate * 2) := Nat.min_eq_right hnewle
        have hrate : Nat.min cap rate = rate := Nat.min_eq_right (Nat.le_of_lt hlt)
        rw [hinner, hrate]
        -- Goal: `cap - min cap (max 1 rate*2) < cap - rate`, with `rate < that min
        -- ≤ cap`. `Nat.sub_lt_sub_left` turns it into exactly `rate < min …`.
        exact Nat.sub_lt_sub_left (Nat.lt_of_lt_of_le hge hnewle) hge
      · simp only [hlt, if_false, List.not_mem_nil] at hmem

/-- `summedIntensity` is additive over list append. Needed to reason about the
    `take _ ++ [replacement] ++ drop _` splice in the intensity candidates. -/
theorem summedIntensity_append (left right : Timeline) :
    summedIntensity (left ++ right) = summedIntensity left + summedIntensity right := by
  induction left with
  | nil => simp [summedIntensity]
  | cons head tail ih =>
      simp only [List.cons_append, summedIntensity, ih]
      omega

/-- `summedIntensity` of a singleton is the severity of its (optional) injection. -/
theorem summedIntensity_singleton (decision : Decision) :
    summedIntensity [decision]
      = (match decision.injection with
         | none => 0
         | some fault => severity decision.event fault) := by
  simp [summedIntensity]

/-- Deleting a nonempty contiguous chunk strictly shrinks the length, hence the
    measure. The deletion candidates are `take offset ++ drop (offset + chunk)`
    with `chunk ≥ 1`; their length is `len - chunk < len` whenever the offset lies
    within the timeline. (Stated for the shape the generator produces.) -/
theorem deletion_length_lt
    (timeline : Timeline) (offset chunk : Nat)
    (hchunk : chunk ≥ 1) (hoffset : offset < timeline.length) :
    (timeline.take offset ++ timeline.drop (offset + chunk)).length < timeline.length := by
  rw [List.length_append, List.length_take, List.length_drop]
  omega

-- ── abstract theorem: acceptance WITNESS PRESERVATION ─────────────────────────

/-- WITNESS PRESERVATION: `observe` advances `best` to a new timeline only on a
    `triggers` verdict. Contrapositively, if the best changed, the verdict was
    `triggers` and the new best is the head of the pending queue — the candidate
    the external checker reported `triggers` on. Given a truthful checker, every
    accepted `best` is therefore a confirmed reproduction. -/
theorem observe_best_triggers
    (verdict : MinimizeVerdict) (state : ShrinkState)
    (hchanged : (observe verdict state).best ≠ state.best) :
    verdict = .triggers
      ∧ ∃ next rest, state.pending = next :: rest ∧ (observe verdict state).best = next := by
  obtain ⟨sbest, spending⟩ := state
  cases spending with
  | nil => simp [observe] at hchanged
  | cons next rest =>
      cases verdict with
      | triggers => exact ⟨rfl, next, rest, rfl, rfl⟩
      | doesNotTrigger => simp [observe] at hchanged
      | unknown => simp [observe] at hchanged

/-- An `unknown` verdict is conservative: it never advances `best`, exactly like
    `doesNotTrigger`. A flake, timeout, or infrastructure error is never mistaken
    for a reproduction. -/
theorem observe_unknown_preserves_best (state : ShrinkState) :
    (observe .unknown state).best = state.best := by
  unfold observe
  cases state.pending with
  | nil => rfl
  | cons next rest => rfl

/-- `unknown` and `doesNotTrigger` are observationally identical: both discard the
    current candidate and leave `best` untouched. -/
theorem observe_unknown_eq_doesNotTrigger (state : ShrinkState) :
    observe .unknown state = observe .doesNotTrigger state := by
  unfold observe
  cases state.pending with
  | nil => rfl
  | cons next rest => rfl

end Rechaos
