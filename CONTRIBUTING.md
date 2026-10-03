# Contributing to rechaos

Thanks for your interest. rechaos is a black-box REAPI chaos and determinism tool:
the scheduler, replay checks, output-tree oracle, and shrinking decisions are
**pure Haskell** (`src/Rechaos/Core`); everything with `IO`, the clock, the
filesystem, gRPC, or randomness lives in the shell (`src/Rechaos/Shell`). Please
preserve that boundary — the core imports no `IO`, clock, filesystem, gRPC, or
random-generator API, contains no partial indexing / `error` / `undefined`, and
represents the zero-rate case explicitly.

## Build and test

```sh
nix build              # builds the gateway and runs the pure core checks
nix develop            # dev shell: ghc, cabal, fourmolu, hlint, python+grpc, protobuf
bash scripts/test.sh   # generates the Python bindings and runs the wire-level checks
```

Tests are the pure-core QuickCheck/HUnit suite (`test/CoreSpec.hs`, run by
`nix build`) plus an independent Python gRPC peer (`test/integration.py`) that
exercises forwarding, metadata, all faults, deadlines, replay, and shrinking.

### Reproducible cabal builds

A committed `cabal.project` pins the Hackage `index-state:` so a plain cabal
build resolves a stable plan over time. Inside `nix develop`, `cabal build all`
and `cabal test core` work directly (they back `scripts/build.sh` and
`scripts/test.sh`). The nix flake remains the authoritative, byte-reproducible
build; cabal resolves its own plan and may differ from the nix pin.

### Editor / IDE

The committed `hie.yaml` is an explicit multi-component cradle, so HLS is
zero-config: open the repo and every component (`rechaos-proto`, `rechaos`, the
`rechaos` executable, and the `core` test-suite) resolves without touching
implicit-cradle discovery.

## Style

- Format with the committed config before sending a change:
  `fourmolu --mode inplace $(git ls-files '*.hs')`
- Code is `GHC2021` + `-Wall`; keep it warning-clean.
- Match the surrounding code: explicit units, no partial functions in the core,
  comment density and naming consistent with the module you are touching.
- Unknown JSON fields in the policy/timeline formats are errors — keep decoders
  strict and versioned.

## Pull requests

Keep changes focused. For anything touching the fault DSL, scheduler
determinism, or the oracle, add or extend a core property in `test/CoreSpec.hs`.
The determinism contract is **same policy + seed + event trace ⇒ same decisions**;
don't weaken it.

By contributing you agree your contributions are licensed under the MIT License.
