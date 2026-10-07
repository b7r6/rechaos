<!--
  // straylight // rechaos // house style
  Adapted from narsil's HOUSE_STYLE.md (b7r6/narsil) for this repo's GHC 9.10 /
  GHC2021 pin, two-space fourmolu, grapesy wire, pure-core/IO-shell split, Lean 4
  verified core, Python harnesses, and the nix-flake-check gate. Treat it as
  living: where we deviate from narsil, the deviation is documented here, not left
  implicit in the source. Where a rule is an aim rather than a mechanized gate,
  this document says so plainly.
-->

# `// straylight // rechaos`

> Based on **[narsil/HOUSE_STYLE.md](https://github.com/b7r6/narsil/blob/main/doc/HOUSE_STYLE.md)**.
> This is the house style for rechaos: a black-box chaos and determinism tool for
> the Bazel Remote Execution API, with a pure Haskell core, Python harnesses, and
> a Lean 4 verified core. The Haskell rules are primary; the Python and Lean
> sections note where the discipline differs.

## Why we do what we do

rechaos sits on the wire between a build client and an unmodified remote-execution
endpoint, injects faults, asserts invariants, and shrinks any violation to a
minimal witness. It is read far more often than it is written, and most of the
reading happens under pressure: an agent extending a subsystem it has never seen,
a human bisecting why a chaos campaign stopped reproducing. **Every ambiguity
compounds.** So we optimize relentlessly for *disambiguation* — the reader should
never have to hold more than one hypothesis about what a line means.

```haskell
-- costs 0.1s to write, 10 minutes to debug
step p e = if g e > 0 then go e else stop

-- costs 0.2s to write, saves the 10 minutes every time it's read
scheduleDecision :: Policy -> Event -> (Word64, Decision)
scheduleDecision policy event
  | chancePpm policy > 0 = applyFirstMatch policy event
  | otherwise = passThrough event
```

Beauty here is not cleverness. It is the property that a tired reader arrives at
the correct understanding on the first pass.

## The pure-core / IO-shell split (the load-bearing law)

This is rechaos's signature rule, and it is non-negotiable. **`Rechaos.Core.*` is
pure.** It imports no `IO`, no clock, no filesystem, no gRPC, and no
random-generator API, and it contains no partial indexing, `error`, or
`undefined`. All effects — the wire, the clock, the journal, the external
checker, the filesystem snapshot — live in `Rechaos.Shell.*`.

This is not aesthetic. It is why the scheduler is deterministic, why a recorded
timeline replays, why the oracle can be re-run, and why the core can be mirrored
and proved in Lean. A function that reaches for `IO` in the core is not a style
nit; it is a correctness regression that breaks replay and the verified core at
once. When you need an effect in core logic, thread the datum in as a value and
let the shell supply it.

## The binding law: guards and equations over `case`

This is the one rule that overrides taste, habit, and convenience, and it is
inherited directly from narsil. **If a `case` can be written another way, it is
written another way.**

> **Current state — honest.** Unlike narsil, rechaos has no `straylint`
> `case-ban` gate yet, and the hand-written tree still carries ~30 `case`
> expressions (concentrated in `Shell/Proxy.hs` and `Shell/Json.hs`). This rule
> is therefore the *direction*, enforced today by review and by an hlint config
> that already favors explicit forms — not a mechanized gate. Write new code as
> if the gate existed; treat existing `case`s as rewrite targets, not precedent.

`case` is demoted, not banned: nearly every `case` is a flatter construct wearing
a disguise.

1. **Function-clause equations** — when you `case` on an argument, match in the
   head instead (as `weaker`, `descending`, and `compareBuilds` already do).

   ```haskell
   -- NO
   classify x = case x of { Triggers -> ...; _ -> ... }
   -- YES
   classify :: Verdict -> Text
   classify Triggers = "triggers"
   classify _        = "other"
   ```

2. **Pattern guards** — when the scrutinee is a computed `Maybe`/`Either`/tuple,
   bind it in a guard and flatten the staircase.

3. **`maybe` / `either` / `fromMaybe`** — for two-armed cases, the eliminator
   names the intent better than `case` ever will.

`\case` (LambdaCase) is `case` with the scrutinee hidden — *more* opaque, not
less. It is **not enabled** in rechaos and should stay that way. The narrow
exception is a small, single-use, local match on a value produced mid-expression
where lifting it to a named `where`-helper costs more than it buys; mark such a
line **`CASE-OK`** with a reason so the survivors stay counted and few.

## Make invalid states unrepresentable

Push correctness into types so the wrong program does not compile. rechaos already
does this where it matters most:

```haskell
-- The shell's judgement is three-way on purpose: an inconclusive run must never
-- be mistaken for a reproduction.
data Verdict = Triggers | DoesNotTrigger | Unknown

-- A build outcome that cannot be "succeeded and also failed".
data BuildResult = Built Tree | BuildFailed Text | BuildTimedOut
```

The `Unknown` arm is load-bearing: the minimizer advances its witness only on
`Triggers`, so a flake or timeout can never be promoted to the minimal cause.
That conservatism is a *type* decision, not a runtime check. Newtypes guard units
and domain boundaries; explicit units (`micros`, `messageBytes`) never travel as
bare `Natural`s where a wrapper would catch a mix-up.

## Control flow: flat is a feature

A **small `do` for sequencing**, a **`where`-clause of guarded equations for
logic**. Note the two-space `where` aligned one stop under the body — that is what
our pinned fourmolu produces (`indent-wheres: false`); do not fight it by hand.

## Naming: the three-character rule

If an identifier is three characters or fewer it is probably too short for code
that outlives the function it sits in. Spell `configuration`, not `cfg`;
`connection`, not `conn`. **Sanctioned short names**, only in local scope where
the type removes all doubt: `xs`/`ys` (lists in pure folds), `m`/`n` (indices),
`k`/`v` (map key/value), `f`/`g` (higher-order functions).

**Acronyms keep their capitalization.** rechaos's terms of art — `REAPI`, `CAS`,
`AC` (ActionCache), `SHA256`, `gRPC`, `TLS`, `PPM` — are each one word and wear
their canonical casing wherever they appear. We do not title-case them to `Reapi`
/ `Cas` / `Json`.

## Comments: expository, almost literate

Code says *what*. Comments say *why*, and *why not the obvious alternative*.

- **Banner headers** orient a reader entering a module. The rechaos form (already
  in every core module) is a centered `// rechaos // path` between two heavy
  rules, then an indented one-line purpose:

  ```haskell
  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  --                                                       // rechaos // core // types
  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  --
  --   fault algebra, policy, events, and timeline values; explicit units
  --
  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ```

- **`n.b.` notes** carry the non-obvious: an invariant, a subtlety, the reason a
  tempting simplification is wrong. These are the highest-value comments in the
  tree.

- **Provenance markers** distinguish reasoning from convention. Domain knowledge
  an agent could not have inferred gets attributed (`-- human: …`); substantial
  AI-authored work is credited as a general matter, not per one-liner.

- **Haddock (`-- |`, `{- | … -}`)** on every exported binding. fourmolu is pinned
  to `haddock-style: multi-line`. The signature plus the Haddock should let a
  reader use the function without reading its body.

## Language extensions (GHC 9.10 / `GHC2021`)

Our `default-language` is `GHC2021`, which already folds in the former everyday
extensions (`ScopedTypeVariables`, `DeriveGeneric`, `BangPatterns`, `InstanceSigs`,
and friends). First-party `default-extensions` are deliberately tiny:
`OverloadedStrings` and `ScopedTypeVariables`. Reach past that list only with a
reason.

- **Green** — `OverloadedStrings` (Text everywhere), `RecordWildCards` /
  `NamedFieldPuns` (tasteful destructuring), `DerivingStrategies` (always say
  *how* you derive), `NumericUnderscores`.
- **Yellow** — `TypeApplications` (to disambiguate, not to show off),
  `GeneralizedNewtypeDeriving` (for newtype wrappers).
- **Red** — `LambdaCase` (it is `case` in a trenchcoat; see the binding law),
  `UndecidableInstances`, `ImplicitParams`, `NondecreasingIndentation`.

The generated `rechaos-proto` library is built with `-w` and carries the
proto-lens-required extensions (`DataKinds`, `TypeFamilies`, `AllowAmbiguousTypes`,
…). That is a vendored, machine-written boundary and is exempt from this document;
its extensions stay confined there and do not license their use in hand-written
code. `DataKinds` for type-level programming *of our own* is red.

## Effects are explicit; two output channels, never confused

`IO` vs pure is obvious from the signature (and enforced by the core split above).
Output discipline, already realized in `Shell/Oracle.hs` and `Shell/Runtime.hs`:

- **stdout is data.** Machine-readable verdicts and JSON, nothing else. A
  diagnostic must never reach stdout.
- **stderr is for humans.** Snapshot failures and operator messages go to stderr
  (`hPutStrLn stderr …`).

We do not hand-roll a logging framework; rechaos has no katip. Keep diagnostics
few, plain, and on the right channel.

## Compiler warnings and the real gates

First-party code builds under `-Wall -Wcompat`. We do **not** currently run
`-Werror` (an honest statement, not an aspiration dressed as one). The gates that
actually run — all through `nix flake check`, the single disciplined runner — are:

- **`format`** — fourmolu `--mode check` (hard gate).
- **`lint`** — hlint against `.hlint.yaml` (advisory in spirit, wired as a gate;
  its idiom hints never override this document).
- **`test`** — the cabal QuickCheck core properties (`CoreSpec`).
- **`cabalCheck` / `docs`** — sdist metadata and Haddock-rot.
- **`conformance` / `protos`** — corpus and generated-code drift.
- **`wire`** — the Python contract and wire suites (`test-python.sh`).
- **`lean`** — the Lean 4 verified core builds with zero proof holes
  (`check_lean.py` rejects `sorry`/`admit`/new `axiom`; `lake build` with
  `warningAsError=true`).

If a check is not wired into `nix flake check`, it atrophies; do not add a
parallel manual path.

## The Lean verified core

The core is mirrored and proved in `lean/`. The discipline is **reference-leads**:
the Haskell implementation is the authority, every conformance corpus is generated
by running the real Haskell, and both the Lean kernel (`native_decide`) and the
Haskell golden-snapshot tests re-verify it. The abstract theorems (determinism,
equivalence-relation laws, minimizer termination + witness preservation, replay
identity/fail-closed/coverage) are proved over core Lean — no Mathlib, no forced
`UInt64` evaluation. The **no-`sorry` policy** is absolute: zero `sorry`, zero
`admit`, no new `axiom`.

Because the Lean today *mirrors* Haskell, it uses Haskell's camelCase names on
purpose — the 1:1 correspondence is the point. The Straylight systems-Lean style
(snake_case, via `lean4fmt`) is deferred to the milestone where Lean becomes the
implementation rather than a shadow; at that point the mirror constraint
dissolves and we migrate naming with the identity-aware renamer.

## Python harnesses

The harnesses (`scripts/`, `test/`) are **contracts, not smoke**: real assertions
on values, not non-crashing. They enforce content-addressing integrity, the
consistency/linearizability model, and cross-endpoint observable equivalence.
stdout/exit-code discipline matches the Haskell side (data on stdout, a
machine-readable verdict, diagnostics on stderr). They require `grpc` and run
under `nix develop` / `test-python.sh`, not bare.

## Formatting

fourmolu is pinned by `fourmolu.yaml` (2-space indentation, 100-column limit,
trailing function-arrows, **leading** commas, diff-friendly import/export lists,
multi-line Haddock, `indent-wheres: false`) so style is explicit and stable across
fourmolu versions. `nix fmt` formats in place; the generated proto tree is
excluded. Commit subjects follow `// rechaos // imperative summary`.

## The vibe test

Good code here passes all of these:

- Could you debug it during an incident without a REPL?
- Could the next contributor — human or agent — extend it without breaking an
  invariant (determinism, the pure-core split, witness preservation)?
- Do the types prevent tomorrow's bug (is a flake forced to be `Unknown`)?
- Is every abbreviation worth the confusion it buys?
- Did you reach for `case` where an equation or a guard would have been clearer?
- Will it still make sense after a hundred hands have touched it?

## Required reading

- Zeller & Hildebrandt, *Simplifying and Isolating Failure-Inducing Input* (2002)
  — the delta-debugging basis of the minimizer.
- Claessen & Hughes, *QuickCheck* (2000) — the property-testing idiom the core
  leans on.
- The rechaos shrinker paper (`paper/rechaos.tex`) — termination and
  witness-preservation, proved.
- narsil's `HOUSE_STYLE.md` and `TYPOGRAPHY.md` — the parent conventions.

---

We are not the Haskell you learned in school. We are what happens when those ideas
have to hold up under a chaos campaign at 2am — and stay beautiful while they do.
