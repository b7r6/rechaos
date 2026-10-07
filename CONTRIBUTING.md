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
nix flake check       # complete validation gate, also used by CI
nix build              # builds the gateway and runs the pure core checks
nix develop            # dev shell: ghc, cabal, fourmolu, hlint, python+grpc, protobuf
bash scripts/test.sh   # focused core, Python, adapter, and wire tests while developing
```

`nix flake check` is the complete repository gate on the current system:

| Check | Coverage |
|---|---|
| `test` | Build the source tarball and run the core QuickCheck properties and goldens. |
| `devBuild` | Run the documented `scripts/build.sh` workflow and core suite against the pinned installed packages. |
| `wire` | Generate Python bindings; run all `test/*_contracts.py` regressions, consistency and process self-tests, and the independent gRPC integration suite. Includes HTTP/2 and S3 loopback peers and a bounded concurrent load test. |
| `syntax` | Compile every Python script and test; parse every shell script. |
| `conformance` | Regenerate the Haskell/Lean corpora and reject differences from the committed files. |
| `protos` | Regenerate all Haskell protobuf modules and reject differences. |
| `format` / `lint` | Check all handwritten Haskell, including `Setup.hs` and the corpus generator. |
| `docs` | Build the package's Haddock documentation. |
| `cabalCheck` | Check package metadata and create the source tarball consumed by `test` and `docs`. |
| `lean` | Reject proof holes and added axioms; compile every Lean module with warnings as errors. |

All runtime tests use owned local fixtures. Campaigns against external REAPI,
execution, or object-store services remain explicit operational runs; passing
this gate establishes the tested tool behavior, not a live server's correctness.
New Python contract files matching `*_contracts.py` are discovered automatically.

### Reproducible cabal builds

A committed `cabal.project` pins the Hackage index for separate cabal-install
builds. Inside `nix develop`, use `scripts/build.sh` and `scripts/test.sh`:
they run Cabal's `Setup.hs` driver against the installed Nix package set. This
avoids the solver conflict between the intentionally coexisting random 1.2 and
1.3 dependency closures. The package definition remains `rechaos.cabal`.
`RECHAOS_BUILD_DIR` can move build artifacts from `.build/cabal` to another
directory. The Nix flake remains the authoritative packaged build.

### Editor / IDE

The committed `hie.yaml` is an explicit multi-component cradle, so HLS is
zero-config: open the repo and every component (`rechaos-proto`, `rechaos`, the
`rechaos` executable, and the `core` test-suite) resolves without touching
implicit-cradle discovery.

## Style

- Format with the committed config before sending a change:
  `nix fmt`
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
