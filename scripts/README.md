# scripts

An index of the operational scripts in this directory: build/test wrappers,
protobuf tooling, the chaos monkey, the bounded smoke/stress harnesses, and the
standalone `repro-*.py` reproducers. Most scripts speak REAPI or drive local build tools. `process_chaos.py`
explicitly manages process lifecycles; its opt-in network operations and
authorization rules are documented in `docs/process-chaos.md`.

Reproducers cross-link to [`../docs/invariants.md`](../docs/invariants.md) by the
signature names used there.

## Build and toolchain

| Script | Purpose | Invocation |
|---|---|---|
| [`build.sh`](build.sh) | Build the library, executable, and test-suite through Cabal's `Setup.hs` driver against the pinned installed packages (`rechaos.cabal` remains the package definition). | `bash scripts/build.sh` (inside `nix develop`) |
| [`test.sh`](test.sh) | Build/select the executable and run the core suite, then the shared Python test runner. | `bash scripts/test.sh` (inside `nix develop`) |
| [`test-python.sh`](test-python.sh) | Generate Python bindings; discover contract and adapter tests; run consistency/process self-tests and the wire suite. Also used by the Nix wire gate. | `bash scripts/test-python.sh` (inside `nix develop`, with `RECHAOS_BIN` selecting a built executable) |
| [`generate-protos.sh`](generate-protos.sh) | Regenerate the Haskell `Proto.*` modules under `generated/` from `proto/` via `protoc` + `proto-lens-protoc`. | `bash scripts/generate-protos.sh` |
| [`fetch-protos.py`](fetch-protos.py) | Vendor the pinned public protocol definitions into `proto/` from the remote-apis and googleapis commits, following imports, without any server source dependency. | `python3 scripts/fetch-protos.py` |

## Chaos and fault campaigns

| Script | Purpose | Invocation |
|---|---|---|
| [`chaos-monkey.py`](chaos-monkey.py) | Continuous randomized REAPI fault campaigns against a live endpoint: each iteration draws a fresh seed and either drives traffic through the `rechaos serve` gateway with a randomized policy or runs a randomized hostile direct client, checks every result against the fixed invariant set, and freezes signature-deduplicated findings with reproducing evidence. | `nix develop --command python3 scripts/chaos-monkey.py --host 127.0.0.1 --port 50052` |
| [`fleet-stress.py`](fleet-stress.py) | Protocol-only NativeLink fault campaigns with byte and recovery oracles; each run saves its seed, identities, calls, policies, gateway timelines, metrics, and findings. Also the shared helper module (`Blob`, `Endpoint`, `measured`) imported by the reproducers below. | `nix develop --command python3 scripts/fleet-stress.py --host 127.0.0.1 --output runs/fleet-stress` |

## Smoke tests

| Script | Purpose | Invocation |
|---|---|---|
| [`fleet-smoke.py`](fleet-smoke.py) | Small bounded, protocol-only smoke test against an unmodified REAPI endpoint: direct write/read, a clean proxy read, a truncating fault compared through `rechaos oracle`, and a replay check. | `nix develop --command python3 scripts/fleet-smoke.py --host 127.0.0.1 --output runs/fleet` |
| [`bazel-smoke.py`](bazel-smoke.py) | Warm a small genrule cache target, then compare clean and faulted cache downloads through the gateway using unique output roots so no local action-cache hit can mask a divergence. | `nix develop --command python3 scripts/bazel-smoke.py --host 127.0.0.1 --output runs/bazel` |
| [`read-checker.py`](read-checker.py) | Read-only minimizer witness for the bounded fleet-smoke artifact: used as the `--check` command for `rechaos minimize`, it replays `RECHAOS_TIMELINE`, reads the blob, and writes a `triggers` / `does-not-trigger` verdict to `RECHAOS_VERDICT`. Demonstrates the `fleet-torn-read` signature. | `python3 scripts/read-checker.py --host 127.0.0.1` (invoked by `rechaos minimize --check`) |

## Reproducers

Each `repro-*.py` is a standalone, deterministic reproduction of one finding.
Fresh deterministic content prevents a prior cache entry from satisfying a case.

| Script | Invariant / signature | What it demonstrates | Invocation |
|---|---|---|---|
| [`repro-cold-read.py`](repro-cold-read.py) | invariant 1, `torn-read` | Cold CAS downloads with paused/cancelled readers and independent peers: upload to one node, wait for a second node to find it, then read on the second node over independent connections. | `nix develop --command python3 scripts/repro-cold-read.py --source 127.0.0.1:50052 --target 127.0.0.1:50053 --output runs/cold-read` |
| [`repro-partial-write.py`](repro-partial-write.py) | invariant 2, `wrong-committed-size` | A rejected short upload becoming a successful, incomplete CAS read; speaks directly to NativeLink with no proxy. | `nix develop --command python3 scripts/repro-partial-write.py --endpoint 127.0.0.1:50051 --output runs/partial-write` |
| [`repro-scheduler-leak.py`](repro-scheduler-leak.py) | invariant 7, `scheduler-queue-leak` | The scheduler queue-GC leak: completed actions stay in the awaited-action store past `retain_completed_for_s`; a final "touch" shows eviction is access-triggered with no background timer. Standalone, no fuzzer. Exit 0 = leak reproduced, exit 1 = store drained. | `nix develop --command python3 scripts/repro-scheduler-leak.py` |
| [`repro-upload-wait.py`](repro-upload-wait.py) | invariant 5, `query-overcount` | How unfinished uploads affect CAS lookups and replacement uploads: `QueryWriteStatus` acknowledges the prefix, the upload is cancelled / half-closed / timed out, then observers (each on its own connection) and a full replacement upload measure recovery. | `nix develop --command python3 scripts/repro-upload-wait.py --endpoint 127.0.0.1:50051 --output runs/upload-wait` |
| [`repro-write-status.py`](repro-write-status.py) | invariant 5, `query-false-complete` | `QueryWriteStatus` over complete, verified artifact uploads across a range of sizes, checking that it neither over-reports committed bytes nor falsely claims completion. | `nix develop --command python3 scripts/repro-write-status.py --endpoint 127.0.0.1:50052 --output runs/write-status` |

## Additional contract checks and workload tools

| Script | Purpose | Reference |
|---|---|---|
| `reapi_differential.py` | Compare recorded observations from independently probed endpoints | [Differential testing](../docs/differential.md) |
| `consistency_oracle.py` | Check complete histories against a register model | [Consistency oracle](../docs/consistency-oracle.md) |
| `build_trace.py` | Generate cache workloads, record complete graph descriptors, and verify replay | [Build traces](../docs/build-trace.md) |
| `conformance_report.py` | Report a finite protocol-probe scorecard | [Conformance](../docs/conformance.md) |
| `load_gen.py` | Measure load and compare performance baselines | [Load/performance](../docs/load-perf.md) |
| `s3_fault_proxy.py`, `h2_fault_proxy.py` | Inject object-store and HTTP/2 faults | [S3](../docs/s3-faults.md), [HTTP/2](../docs/h2-faults.md) |
| `process_chaos.py` | Exercise owned process lifecycle and explicit network faults | [Process chaos](../docs/process-chaos.md) |
| `check_lean.py` | Reject proof-hole tokens and new axioms outside comments/strings | [Formal checks](../docs/formal.md) |

Python gateway helpers use `RECHAOS_BIN` when set, otherwise `result/bin/rechaos`,
the legacy `bin/rechaos`, or `rechaos` on PATH. `scripts/test.sh` selects the
executable from its Cabal build directory; the Nix wire gate selects its built package.
The complete validation entry point is `nix flake check`; `scripts/test.sh` is
the focused runtime subset. Set `RECHAOS_TEST_OUTPUT` to change the integration
artifact directory from `runs/integration`.
