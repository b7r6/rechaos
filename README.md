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

| Fault | Effect |
|---|---|
| `{"kind":"delay","micros":100000}` | Hold the selected message for 100 ms. |
| `{"kind":"abort","status":"Unavailable"}` | End the selected RPC with that gRPC error. |
| `{"kind":"dribble","bytesPerSecond":65536,"chunkBytes":4096}` | Pace ByteStream payload chunks while preserving valid protobuf messages and Write offsets. |
| `{"kind":"truncate","keepBytes":7}` | Keep N bytes of a Read response and end the stream with `OK`, or shorten a Write message and `finish_write`. |

Fault selection is implemented for `FindMissingBlobs`, ByteStream `Read`, and
ByteStream `Write`; the other REAPI methods pass through. Targets can constrain
`direction`, `occurrence`, `messageIndex`, `minBlobBytes`, `maxBlobBytes`,
`afterMicros`, and `beforeMicros`. The first matching rule owns the event; its
`chancePpm` defaults to 1,000,000. Exactly one SplitMix64 step is consumed per
observed message.

## Replay, comparison, shrinking

```sh
# Replay a recorded timeline, then verify coverage.
./result/bin/rechaos serve --upstream-host cache.example.com \
  --replay runs/chaos.jsonl --record runs/replayed.jsonl
./result/bin/rechaos verify-replay runs/chaos.jsonl runs/replayed.jsonl

# Recompute the scheduler from exactly the recorded observations.
./result/bin/rechaos schedule --policy examples/fault-policy.json \
  --trace runs/chaos.jsonl --output runs/recomputed.jsonl

# Compare output directories from two successful builds (exit 1 = divergence).
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
timestamps. The shrinker is deletion-1-minimal for a repeatable checker under the
stated intensity steps.

## Chaos monkey

[`scripts/chaos-monkey.py`](scripts/chaos-monkey.py) runs continuously against a
live endpoint. Each iteration draws a seed and either drives a randomized fault
policy through the gateway or runs a randomized adversarial direct client, then
checks a fixed set of invariants, deduplicates findings by signature, and freezes
replayable reproducers.

```sh
nix develop --command python3 scripts/chaos-monkey.py --host 127.0.0.1 --port 50052
nix develop --command python3 scripts/chaos-monkey.py --only-direct --stop-on-finding
nix develop --command python3 scripts/chaos-monkey.py --execution   # + scheduler stress
```

Invariants include: an `OK` Read must return bytes matching the requested digest;
a partial/aborted upload must not become a readable blob whose content mismatches
its digest; a successful Write's `committed_size` must equal the advertised size;
`FindMissingBlobs` must be consistent; `QueryWriteStatus` must not over-report;
known-good traffic must recover after each fault. With `--execution`, it also
stresses the Execution/scheduler path and detects awaited-action queue-GC leaks
(store occupancy that never drains after completion).

## Architecture

The core imports no `IO`, clock, filesystem, gRPC, or random-generator API, and
contains no partial indexing, `error`, or `undefined`.

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
