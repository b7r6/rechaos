# rechaos

[![ci](https://github.com/b7r6/rechaos/actions/workflows/ci.yml/badge.svg)](https://github.com/b7r6/rechaos/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A black-box chaos and determinism tool for the [Bazel Remote Execution API][reapi]
(REAPI) and compatible endpoints such as [NativeLink][nativelink]. rechaos sits
as a gateway between a build client and an **unmodified** remote endpoint,
injects faults into the wire traffic, and checks correctness and liveness
invariants — then deterministically replays, compares, and **shrinks** any
failure to a minimal witness.

The scheduler, replay checks, output-tree comparison, and shrinking decisions are
**pure Haskell**. [grapesy][grapesy] handles the wire. A continuous **chaos
monkey** drives randomized fault policies and adversarial clients and freezes
every finding as a replayable reproducer.

## Why

Remote-execution and remote-cache servers are concurrent, content-addressed, and
on the critical path of every build. The interesting bugs — torn reads, partial
uploads served as complete, dishonest commit sizes, queue entries that never get
collected — surface only under adversarial timing and malformed-but-legal wire
traffic. rechaos produces exactly that traffic, asserts the invariants a correct
CAS/scheduler must hold, and makes any violation reproducible to a single fault.

## Install

```sh
nix build
./result/bin/rechaos --help
```

## Run the gateway

```sh
# No faults unless --policy or --replay is supplied.
./result/bin/rechaos serve \
  --upstream-host cache.example.com --upstream-port 50051 \
  --port 50070 --record runs/clean.jsonl

# Stop the first proxy, then run a fault policy.
./result/bin/rechaos serve \
  --upstream-host cache.example.com --upstream-port 50051 \
  --port 50070 --policy examples/fault-policy.json \
  --record runs/chaos.jsonl
```

Point the build client at the gateway: Bazel with
`--remote_cache=grpc://127.0.0.1:50070` and/or
`--remote_executor=grpc://127.0.0.1:50070`, using the upstream's instance name
(`--remote_instance_name=main`). Buck2 can use the same gateway address in its RE
client configuration.

The default listener is `127.0.0.1:50070`. `--max-call-seconds` defaults to 60;
increase it for long remote executions. Each run writes decisions to `--record`
and RPC outcomes to `RECORD.outcomes.jsonl`. The proxy does not retry RPCs; it
reconnects its upstream transport for subsequent calls after a disconnect.

## Fault policy

[`examples/fault-policy.json`](examples/fault-policy.json) is the complete
one-file example. `version` and an explicit 64-bit `seed` are required. Targets
use full `service/Method` names without a leading slash. Unknown JSON fields are
errors.

The authoritative references are [`docs/fault-dsl.md`](docs/fault-dsl.md) for the
policy grammar, every field and constraint, and the exact decoder error strings,
and [`docs/timeline-format.md`](docs/timeline-format.md) for the recorded
timeline and `.outcomes.jsonl` on-disk schema.

| Fault | Effect |
|---|---|
| `{"kind":"delay","micros":100000}` | Hold the selected message for 100 ms. |
| `{"kind":"abort","status":"Unavailable"}` | End the selected RPC with that gRPC error. |
| `{"kind":"dribble","bytesPerSecond":65536,"chunkBytes":4096}` | Pace ByteStream payload chunks while preserving valid protobuf messages and Write offsets. |
| `{"kind":"truncate","keepBytes":7}` | Keep N bytes of a Read response and end the stream with `OK`, or shorten a Write message and `finish_write`. |

`truncate` applies only to ByteStream `Read` responses and `Write` requests
(shortening a unary message would produce an invalid proto). `dribble`, `delay`,
and `abort` apply to every supported method and direction — `dribble` paces a
unary message as a single whole-message chunk. The supported-method allow-list in
`validFault` covers nine REAPI methods (ByteStream `Read`/`Write`; CAS
`FindMissingBlobs`/`BatchUpdateBlobs`/`BatchReadBlobs`/`GetTree`; ActionCache
`GetActionResult`/`UpdateActionResult`; `Capabilities/GetCapabilities`); see
[`docs/fault-dsl.md`](docs/fault-dsl.md) for the exact set. Methods outside it
pass through. Targets
can constrain `direction`, `occurrence`, `messageIndex`, `minBlobBytes`,
`maxBlobBytes`, `afterMicros`, and `beforeMicros`. The first matching rule owns
the event; its `chancePpm` defaults to 1,000,000. Exactly one SplitMix64 step is
consumed per observed message.

## Replay, comparison, shrinking

```sh
# Replay a recorded timeline, then verify coverage.
./result/bin/rechaos serve --upstream-host cache.example.com \
  --replay runs/chaos.jsonl --record runs/replayed.jsonl
./result/bin/rechaos verify-replay runs/chaos.jsonl runs/replayed.jsonl

# Recompute the scheduler from exactly the recorded observations.
./result/bin/rechaos schedule --policy examples/fault-policy.json \
  --trace runs/chaos.jsonl --output runs/recomputed.jsonl

# Compare output directories from two successful builds (exit 0 equivalent,
# 1 diverged, 2 inconclusive when an input is not a completed Built tree).
./result/bin/rechaos oracle runs/clean-output runs/chaos-output

# Shrink a failure to a minimal witness that still triggers your checker.
./result/bin/rechaos minimize \
  --timeline runs/chaos.jsonl --output runs/minimal.jsonl \
  --signature my-repro --check 'python3 my_checker.py'
```

The JSONL timeline is self-contained for replay: each row stores the observed
event and its selected fault (including `null` for no fault). The determinism
contract is **same policy + seed + event trace ⇒ same decisions**. Replay reports
divergence instead of guessing. The oracle compares relative paths, SHA256 file
digests and sizes, executable bits, symlink targets, and directories, ignoring
timestamps. It reports `equivalent` (exit 0), `diverged` (exit 1), or
`inconclusive` (exit 2); `inconclusive` means an input was not a completed
`Built` tree, so `compareBuilds` had nothing to judge. The shrinker is deletion-1-minimal for a repeatable checker under the
stated intensity steps.

## Commands

| Command | Purpose | Key flags |
|---|---|---|
| `serve` | Run the REAPI chaos gateway | `--upstream-host`, `--upstream-port`, `--host`, `--port`, `--policy`, `--replay`, `--sparse`, `--record`, `--max-call-seconds`, `--upstream-tls`, `--ca`, `--certificate`, `--key` |
| `oracle` | Compare completed build output trees (exit 0 equivalent, 1 diverged, 2 inconclusive) | `CLEAN_TREE`, `CHAOS_TREE` |
| `schedule` | Recompute decisions from a recorded event trace | `--policy`, `--trace`, `--output` |
| `validate` | Validate a policy JSON file | `POLICY` |
| `verify-replay` | Check every expected event was observed with matching fingerprints and faults | `EXPECTED_TIMELINE`, `OBSERVED_TIMELINE` |
| `minimize` | Shrink a failure to a minimal witness under a repeatable checker | `--timeline`, `--output`, `--check`, `--signature`, `--repetitions`, `--trial-timeout`, `--max-trials` |

## Chaos monkey

[`scripts/chaos-monkey.py`](scripts/chaos-monkey.py) runs continuously against a
live endpoint. Each iteration draws a seed and either drives a randomized fault
policy through the gateway or runs a randomized adversarial direct client, then
checks a fixed set of invariants, deduplicates findings by signature, and freezes
replayable reproducers.

```sh
nix develop --command python3 scripts/chaos-monkey.py --host 127.0.0.1 --port 50070
nix develop --command python3 scripts/chaos-monkey.py --only-direct --stop-on-finding
nix develop --command python3 scripts/chaos-monkey.py --execution   # + scheduler stress
```

The invariants are catalogued, with their REAPI basis and check sites, in
[`docs/invariants.md`](docs/invariants.md). In brief: an `OK` Read must return bytes matching the requested digest;
a partial/aborted upload must not become a readable blob whose content mismatches
its digest; a successful Write's `committed_size` must equal the advertised size;
`FindMissingBlobs` must be consistent; `QueryWriteStatus` must not over-report;
known-good traffic must recover after each fault. With `--execution`, it also
stresses the Execution/scheduler path and detects awaited-action queue-GC leaks
(store occupancy that never drains after completion).

## Architecture

The core imports no `IO`, clock, filesystem, gRPC, or random-generator API, and
contains no partial indexing, `error`, or `undefined`. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design rationale
behind the pure-core / IO-shell split, the determinism model, and replay.

| Module | Responsibility |
|---|---|
| `Core/Types` | Fault algebra, policy, event and timeline values; explicit units |
| `Core/Scheduler` | SplitMix64 step, first-match targeting, probability, replay checks |
| `Core/Oracle` | Output-tree maps, difference, equivalence, build verdicts |
| `Core/Minimize` | Candidate generation and acceptance state machine |
| `Shell/Json` | Versioned policy/timeline decoding and validation |
| `Shell/Runtime` | Monotonic observations, occurrence allocation, journal writes |
| `Shell/Wire`, `Protocol`, `Proxy` | grapesy server/client, pacing, stream edits, deadlines |
| `Shell/Oracle`, `Shell/Minimize` | Filesystem snapshot + SHA256; external checker driver |

## Repository layout

| Path | Contents |
|---|---|
| `examples/` | `fault-policy.json`, the complete one-file policy example; `examples/chaos/*.json5`, NativeLink server configs for isolated local endpoints used in reproductions |
| `scripts/` | `chaos-monkey.py`, build/test wrappers, protobuf fetch/generate helpers, and standalone `repro-*.py` reproducers |
| `reports/` | Dated investigation write-ups and their captured evidence under `reports/evidence/` |
| `proto/` | Vendored `remote-apis` and `googleapis` protocol definitions with their licenses |
| `docs/` | Reference docs, indexed by [`docs/README.md`](docs/README.md): [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) (design rationale), [`invariants.md`](docs/invariants.md) (invariants catalog), [`fault-dsl.md`](docs/fault-dsl.md) (policy DSL), and [`timeline-format.md`](docs/timeline-format.md) (on-disk timeline/outcomes schema) |

## Develop

```sh
nix develop
bash scripts/build.sh
bash scripts/test.sh
```

Protocol definitions are vendored from pinned, public `bazelbuild/remote-apis` and
`googleapis/googleapis` commits; generated Haskell is included. Tests use an
independent Python gRPC peer plus QuickCheck properties for the core.

## License

[MIT](LICENSE).

[reapi]: https://github.com/bazelbuild/remote-apis
[nativelink]: https://github.com/TraceMachina/nativelink
[grapesy]: https://github.com/well-typed/grapesy
