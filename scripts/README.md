# scripts

An index of the operational scripts in this directory: build/test wrappers,
protobuf tooling, the chaos monkey, the bounded smoke/stress harnesses, and the
standalone `repro-*.py` reproducers. Every script here speaks REAPI or drives
`cabal` / `protoc`; none edit server configuration or restart a server.

Reproducers cross-link to [`../docs/invariants.md`](../docs/invariants.md) by the
signature names used there.

## Build and toolchain

| Script | Purpose | Invocation |
|---|---|---|
| [`build.sh`](build.sh) | Build the library, executable, and test-suite through `cabal` (single source of truth is `rechaos.cabal`). | `bash scripts/build.sh` (inside `nix develop`) |
| [`test.sh`](test.sh) | Run the pure-core QuickCheck/HUnit suite (`cabal test core`), then compile the protos and run the Python gRPC wire-level peer. | `bash scripts/test.sh` (inside `nix develop`) |
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
