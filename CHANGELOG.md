# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Scheduler chaos: `scripts/fleet_rig.py` starts an isolated local NativeLink
  fleet (scheduler + N workers, optionally Redis-backed with the RediSearch
  module resolved automatically); `scripts/scheduler_steps.py` replays a JSONL
  scenario (actions with `cpu_count`/`memory_kb`/inputs/timing, detached
  clients, `store-full`/`store-pause`/`worker-pause` faults) and evaluates
  invariants 8-13 (`queue-starvation`, `dispatch-stall`, `stuck-executing`,
  `input-evicted-failure`) as a pure function; the chaos monkey's `--rig` mode
  composes such scenarios cold and freezes each finding with a `minimize.sh`.
- `Rechaos.Core.Scenario`: the scheduler and object-store invariants (8-13)
  as a pure core function, exposed as `rechaos evaluate observations.json`,
  with a differential contract against the Python engine's evaluator; and
  `rechaos validate-steps`.
- `scripts/dhall_bench.py` and `docs/dhall-cost.md`: what the reference Dhall
  implementation costs per operation and input size, where it sits in each
  loop, and the `--compare` protocol for a replacement. `vendor/dhall-cpp/`: a
  C++ evaluator measured under that protocol (`nix build .#dhall-cpp`, gated by
  `checks.dhall-cpp` for agreement on scenario inputs); 33 to 35x faster on
  literal witnesses, equal as parsed JSON on scenarios, no type checker,
  non-standard union normal form, arena memory never freed. MIT, like its
  upstream. Not the gate's implementation.
- `dhall/`: typed scenario steps, fleet parameters, NativeLink configs, and
  limits that render to the wire JSON with `dhall-to-json`; the `dhall` flake
  check type-checks them offline, validates the example scenarios, and requires
  the rendered fleet configs to equal `scripts/fleet_rig.py config`.
- Object-store dialects as an explicit fault category: `s3_fault_proxy.py
  --dialect s3|azure|gcs` answers throttles in each hyperscaler's exact shape
  (Azure `503 ServerBusy` + `x-ms-error-code` + "Egress is over the account
  limit.", S3 `SlowDown`, GCS JSON `backendError`/`rateLimitExceeded`, all
  with `Retry-After`) and gains a control endpoint (`--control`: sustained
  throttle on/off, per-key request counts). The fleet rig's `--cas-backend
  azure|s3` puts NativeLink's own cloud client behind it over Azurite or
  MinIO; the `store-throttle` scenario step and invariants 12-13
  (`store-throttle-giveup`, `store-throttle-redispatch`) catch a client that
  gives up inside the worker's download budget or re-dispatches the action.
- `rechaos minimize --steps`: the delta-debugger over an opaque JSONL step list
  (deletion plus declared `weaker` halving), handed to the checker as
  `$RECHAOS_STEPS`. `Rechaos.Core.Shrink` is the element-generic core that
  `Rechaos.Core.Minimize` now instantiates; its timeline candidates are unchanged
  (conformance corpora identical).
- REAPI chaos gateway (`rechaos serve`): delay / abort / dribble / truncate /
  corrupt faults over a strict, versioned policy DSL, with deterministic replay.
- `corrupt` fault (`{"kind":"corrupt","bytes":N}`): a length-preserving
  payload-rewriting fault that flips the low bit of the first N bytes of a
  ByteStream Read response or Write request, forcing the server to re-hash the
  content to detect tampering (a strictly harder integrity test than `truncate`).
  Mirrored into the Lean model and the Haskell<->Lean differential corpora.
- Pure Haskell core: SplitMix64 scheduler, first-match targeting, replay
  identity/fingerprint/coverage checks, output-tree oracle, witness-preserving
  minimizer.
- `verify-replay`, `schedule`, `oracle`, `minimize`, and `validate` subcommands.
- Continuous chaos monkey (`scripts/chaos-monkey.py`): randomized fault policies
  and adversarial direct clients over CAS / ByteStream / FindMissingBlobs, with
  always-on CAS-integrity and liveness invariants, signature dedup, and frozen
  replayable reproducers.
- Execution/scheduler stress mode and an awaited-action queue-GC leak detector.
- Independent Python wire-level test peer (`test/integration.py`).
- Cabal packaging (`rechaos.cabal`, cabal-version 3.0): library, `rechaos`
  executable, and `core` test-suite, with the generated proto-lens modules
  isolated in an internal library so `-Wall` stays meaningful. The nix flake now
  builds this single package via `callCabal2nix` and exposes distinct checks —
  `test` (cabal test-suite), `format` (fourmolu `--mode check`), and `lint`
  (hlint) — instead of aliasing the build derivation. `scripts/build.sh` and
  `scripts/test.sh` delegate to `cabal`, and the dev shell gains fourmolu and
  hlint.

[Unreleased]: https://github.com/b7r6/rechaos
