# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- REAPI chaos gateway (`rechaos serve`): delay / abort / dribble / truncate faults
  over a strict, versioned policy DSL, with deterministic replay.
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
