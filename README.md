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
finding evidence, including proxy policies and timelines when available. A
frozen finding still needs a confirmed reproduction before minimization.

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

New here? [`docs/tutorial.md`](docs/tutorial.md) walks one concrete scenario from
build to minimized witness against a local NativeLink endpoint.

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

`--rst-rate-limit` (default 1000) is the number of `RST_STREAM` frames per
second one downstream connection may send before the gateway closes it with
`GOAWAY ENHANCE_YOUR_CALM` ("too many rst_stream"). The underlying `http2`
library defaults to 4/s as a rapid-reset (CVE-2023-44487) guard, which a build
client's fan-out exceeds under normal operation: a 21-action Bazel-like build
drew five `UNAVAILABLE` retries through the gateway while the same client direct
to NativeLink saw none. The guard stays on; the default is sized for a proxy
that fronts one multiplexed build connection, not for a browser.

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
| `{"kind":"corrupt","bytes":4}` | Flip the low bit of the first N payload bytes of a Read response or Write request, length-preserving, so the server must re-hash to detect the tampering. |

`truncate` and `corrupt` apply only to ByteStream `Read` responses and `Write`
requests (rewriting a unary message would produce an invalid proto); `truncate`
shortens the payload while `corrupt` rewrites its leading bytes in place without
changing its length. `dribble`, `delay`,
and `abort` apply to every supported method and direction — `dribble` paces a
unary message as a single whole-message chunk. The supported-method allow-list in
`validFault` covers nine REAPI methods (ByteStream `Read`/`Write`; CAS
`FindMissingBlobs`/`BatchUpdateBlobs`/`BatchReadBlobs`/`GetTree`; ActionCache
`GetActionResult`/`UpdateActionResult`; `Capabilities/GetCapabilities`); see
[`docs/fault-dsl.md`](docs/fault-dsl.md) for the exact set. Other methods listed in the proxy handler table pass through without injected
faults; unregistered methods are not proxied. Targets
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

# The same shrinker over a scheduler scenario (a JSONL step list) instead of a
# gateway timeline; the checker reads $RECHAOS_STEPS. See docs/scheduler-chaos.md.
./result/bin/rechaos minimize \
  --steps runs/monkey/corpus/queue-starvation/steps.jsonl --output runs/minimal-steps.jsonl \
  --signature queue-starvation \
  --check 'python3 scripts/scheduler_steps.py check --rig runs/rig/rig.json --signature queue-starvation --fresh'
```

The JSONL timeline stores the decisions needed for replay: each row contains an observed
event fingerprint and its selected fault (including `null` for no fault). It
does not store request payloads or server state; replay requires the workload to
produce matching traffic again. The determinism
contract is **same policy + seed + event trace ⇒ same decisions**. Replay reports
divergence instead of guessing. The oracle compares relative paths, SHA256 file
digests and sizes, executable bits, symlink targets, and directories, ignoring
timestamps. It reports `equivalent` (exit 0), `diverged` (exit 1), or
`inconclusive` (exit 2) when a directory cannot be snapshotted. The CLI assumes
the supplied trees came from completed successful builds; it cannot infer build
success from a directory. The library also returns `Inconclusive` for failed or
timed-out builds. The shrinker is deletion-1-minimal after an exhausted search
with a repeatable, conclusive checker. It reports `inconclusive` if unresolved
checker outcomes prevent that claim, and `trial-limit` if the search budget ends.
With `--steps`, the same candidate generator and acceptance rule run over an
opaque JSONL step list: every step is deletable, and a step may declare under
`weaker` which integer fields shrink (halving toward a floor), so a scheduler
scenario shrinks to a deletion-1-minimal witness exactly as a fault timeline does.

## Commands

| Command | Purpose | Key flags |
|---|---|---|
| `serve` | Run the REAPI chaos gateway | `--upstream-host`, `--upstream-port`, `--host`, `--port`, `--policy`, `--replay`, `--sparse`, `--record`, `--max-call-seconds`, `--rst-rate-limit`, `--upstream-tls`, `--ca`, `--certificate`, `--key` |
| `oracle` | Compare completed build output trees (exit 0 equivalent, 1 diverged, 2 inconclusive) | `CLEAN_TREE`, `CHAOS_TREE` |
| `schedule` | Recompute decisions from a recorded event trace | `--policy`, `--trace`, `--output` |
| `validate` | Validate a policy JSON file | `POLICY` |
| `verify-replay` | Check every expected event was observed with matching fingerprints and faults | `EXPECTED_TIMELINE`, `OBSERVED_TIMELINE` |
| `minimize` | Shrink a failure to a minimal witness under a repeatable checker | `--timeline` or `--steps`, `--output`, `--check`, `--signature`, `--repetitions`, `--trial-timeout`, `--max-trials` |
| `evaluate` | Evaluate the scheduler and object-store invariants (8-13) over a scenario's `observations.json` | `OBSERVATIONS`, `--queue-age-ms`, `--executing-ms`, `--download-budget-ms` |
| `validate-steps` | Validate a scenario step list (JSONL or JSON array) | `STEPS` |

## Chaos monkey

[`scripts/chaos-monkey.py`](scripts/chaos-monkey.py) runs continuously against a
live endpoint. Each iteration draws a seed and either drives a randomized fault
policy through the gateway or runs a randomized adversarial direct client, then
checks a fixed set of invariants, deduplicates findings by signature, and saves
finding evidence. Proxy timelines can drive replay when the workload reproduces
the recorded traffic; direct findings need their workload and backend conditions
recreated. Adaptive feedback and a seed alone do not recreate a campaign.

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
(store occupancy that never drains after completion). With `--rig rig.json`
(a fleet started by [`scripts/fleet_rig.py`](scripts/fleet_rig.py)) it adds a
scheduler mode that composes random multi-worker scenarios, replays them through
[`scripts/scheduler_steps.py`](scripts/scheduler_steps.py), and checks the
scheduler liveness invariants (queue starvation, dispatch stalls, operations
stuck in `EXECUTING`, worker-cache evictions failing actions whose inputs are
present) and, on a rig started with `--cas-backend azure|s3`, the object-store dialect
invariants (a hyperscaler throttle in its exact shape must neither fail an
action inside the worker's download budget nor re-dispatch it). Each such finding freezes its step list, observations, rig manifest,
and a `minimize.sh` that shrinks it with `rechaos minimize --steps`. See
[`docs/scheduler-chaos.md`](docs/scheduler-chaos.md).

```sh
NATIVELINK_BIN=/path/to/nativelink python3 scripts/fleet_rig.py up --backend redis --workers 3 --out runs/rig --detach
NATIVELINK_BIN=/path/to/nativelink python3 scripts/fleet_rig.py up --cas-backend azure --max-action-executing-timeout-s 0 --out runs/rig-az --detach
nix develop --command python3 scripts/chaos-monkey.py --rig runs/rig/rig.json --only-scheduler
```

The object-store egress proxy ([`scripts/s3_fault_proxy.py`](scripts/s3_fault_proxy.py))
speaks three dialects (`--dialect s3|azure|gcs`): Azure's `503 ServerBusy`
with `x-ms-error-code` and "Egress is over the account limit.", S3's
`SlowDown`, and GCS's JSON errors, each with `Retry-After`, plus a control
endpoint that switches a sustained throttle on and off and counts requests per
key. See [`docs/s3-faults.md`](docs/s3-faults.md).

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
| `Core/Shrink` | Element-generic delta debugging: chunk deletions plus caller-supplied intensity steps |
| `Core/Minimize` | `Core/Shrink` at gateway decisions: injected-fault filtering and the per-fault `weaker` order |
| `Core/Scenario` | Scheduler and object-store liveness invariants (8-13) as a pure function of observed actions and fault windows |
| `Shell/Json` | Versioned policy/timeline decoding and validation |
| `Shell/Runtime` | Monotonic observations, occurrence allocation, journal writes |
| `Shell/Wire`, `Protocol`, `Proxy` | grapesy server/client, pacing, stream edits, deadlines |
| `Shell/Oracle`, `Shell/Minimize` | Filesystem snapshot + SHA256; external checker driver over timelines or step lists |
| `Shell/Steps` | Opaque JSONL scenario steps: validation and the declared `weaker` halving |
| `Shell/Scenario` | `observations.json` decoding and findings as JSON for `rechaos evaluate` |

## Repository layout

| Path | Contents |
|---|---|
| `dhall/` | Typed scenario steps, fleet parameters, NativeLink configs, and limits, rendered with `dhall-to-json`; a flake check keeps them equal to the Python emitter. See [`docs/scheduler-chaos.md`](docs/scheduler-chaos.md#authoring-scenarios-and-fleets-in-dhall) |
| `vendor/dhall-cpp/` | A C++ Dhall evaluator vendored for measurement (`nix build .#dhall-cpp`), 33x faster than the reference on literal witnesses, equal as parsed JSON on every scenario input, but without a type checker and with a non-standard union normal form; MIT, like its upstream; provenance and patches in its `NOTICE.md`, numbers in [`docs/dhall-cost.md`](docs/dhall-cost.md) |
| `examples/` | `fault-policy.json`, the complete one-file policy example; `examples/chaos/*.json5`, NativeLink server configs for isolated local endpoints used in reproductions, mapped to their roles and launch commands in [`examples/chaos/README.md`](examples/chaos/README.md) |
| `scripts/` | `chaos-monkey.py`, `fleet_rig.py` (local multi-worker NativeLink fleet, optionally Redis-backed), `scheduler_steps.py` (scenario engine, invariant evaluator, minimize checker), build/test wrappers, protobuf fetch/generate helpers, and standalone `repro-*.py` reproducers |
| `runs/` | Local, ignored run artifacts: timelines, outcomes, summaries, and reproducer evidence |
| `proto/` | Vendored `remote-apis` and `googleapis` protocol definitions with their licenses |
| `docs/` | Reference docs, indexed by [`docs/README.md`](docs/README.md): [`tutorial.md`](docs/tutorial.md) (end-to-end walkthrough), [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) (design rationale), [`invariants.md`](docs/invariants.md) (invariants catalog), [`fault-dsl.md`](docs/fault-dsl.md) (policy DSL), [`timeline-format.md`](docs/timeline-format.md) (on-disk timeline/outcomes schema), and [`scheduler-chaos.md`](docs/scheduler-chaos.md) (fleet rig, scenario steps, scheduler invariants) |

## Develop

```sh
nix flake check       # complete validation gate; the same command runs in CI
nix develop
bash scripts/build.sh
bash scripts/test.sh
```

Protocol definitions are vendored from pinned, public `bazelbuild/remote-apis` and
`googleapis/googleapis` commits; generated Haskell is included. Tests use an
independent Python gRPC peer plus QuickCheck properties for the core.
`nix flake check` builds and tests the source tarball and developer wrapper,
runs the Python contracts, local adapter tests, consistency and process
self-tests, and wire suite against the built executable. It also checks script
syntax, Haskell formatting/lint, generated protobuf and conformance corpus drift,
Haddock, package metadata, and every Lean module. See
[`CONTRIBUTING.md`](CONTRIBUTING.md#build-and-test) for the check inventory.

API documentation (Haddock) is published at
<https://b7r6.github.io/rechaos/>; build it locally with `nix build .#docs` and
open `result/share/doc/*/html/index.html`. The flake also exposes
`nix run .# -- serve ...` to run the gateway without a prior `nix build`, and
`nix fmt` to format the hand-written Haskell sources in place.

## License

[MIT](LICENSE).

[reapi]: https://github.com/bazelbuild/remote-apis
[nativelink]: https://github.com/TraceMachina/nativelink
[grapesy]: https://github.com/well-typed/grapesy
