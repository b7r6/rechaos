# rechaos tutorial

A single concrete scenario, start to finish: build the tool, stand up a local
NativeLink endpoint, put the rechaos gateway in front of it, record a clean
baseline, inject a fault policy, then replay, compare, and shrink the result to a
minimal witness. Every command and flag below is taken verbatim from the current
CLI (`app/Main.hs`); nothing here is aspirational.

This page is a narrative on-ramp. For the authoritative, field-by-field
references it links out to, start at the [docs index](README.md): the fault-policy
grammar and eligibility matrix live in [`fault-dsl.md`](fault-dsl.md), the on-disk
timeline/outcomes schema in [`timeline-format.md`](timeline-format.md), the stdout
verdict vocabulary and exit codes in [`cli-output.md`](cli-output.md), and the
invariants the chaos monkey asserts in [`invariants.md`](invariants.md).

## 0. Build and enter the dev shell

```sh
nix build
./result/bin/rechaos --help
```

For an interactive session (and to run the Python harnesses, which need the
project's gRPC peer), enter the dev shell:

```sh
nix develop
```

## 1. Stand up a local endpoint

The tutorial runs against an isolated, local NativeLink endpoint — nothing here
touches a shared cluster. The three committed configs under `examples/chaos/` and
their exact launch commands are documented in
[`examples/chaos/README.md`](../examples/chaos/README.md). For this walkthrough,
launch the CAS-only endpoint (`test-cas.json5`), which listens on
`127.0.0.1:50099` with instance name `main`:

```sh
nativelink examples/chaos/test-cas.json5
```

## 2. Record a clean baseline

Start the gateway in front of the upstream endpoint with no policy — with neither
`--policy` nor `--replay`, the gateway injects no faults and simply records what
it sees. The default downstream listener is `127.0.0.1:50070`; point `serve` at
the upstream from step 1:

```sh
./result/bin/rechaos serve \
  --upstream-host 127.0.0.1 --upstream-port 50099 \
  --port 50070 --record runs/clean.jsonl
```

`serve` runs until interrupted; banners go to stderr. Each run writes the decision
timeline to `--record` and RPC outcomes to `RECORD.outcomes.jsonl` (here
`runs/clean.jsonl.outcomes.jsonl`). The on-disk schema of both files is documented
in [`timeline-format.md`](timeline-format.md).

## 3. Point a client at the gateway

With the gateway listening on `127.0.0.1:50070`, point your build client at it
instead of the upstream, keeping the upstream's instance name (`main`):

```sh
bazel build //... \
  --remote_cache=grpc://127.0.0.1:50070 \
  --remote_instance_name=main
```

Buck2 can use the same gateway address in its RE client configuration. Drive a
representative build so the gateway records real traffic into `runs/clean.jsonl`,
then stop it (Ctrl-C). The output tree your build produced is the clean reference
tree for step 6.

## 4. Apply a fault policy and observe a verdict

Validate the committed example policy, then run the gateway with it. The policy is
[`examples/fault-policy.json`](../examples/fault-policy.json): a strict, versioned
document with a required `version` and 64-bit `seed`. Its three rules truncate the
second ByteStream `Read` response of blobs of at least 2 bytes, abort half of all
`FindMissingBlobs` responses with `Unavailable`, and dribble every ByteStream
`Write` request. (For which faults are legal on which methods and directions, see
the eligibility matrix in [`fault-dsl.md`](fault-dsl.md); the concrete rules above
are exactly those in the committed policy.)

```sh
# Validate first: exit 0 and {"verdict":"valid"} on stdout, exit 2 otherwise.
./result/bin/rechaos validate examples/fault-policy.json

# Stop the clean gateway, then run the fault policy.
./result/bin/rechaos serve \
  --upstream-host 127.0.0.1 --upstream-port 50099 \
  --port 50070 --policy examples/fault-policy.json \
  --record runs/chaos.jsonl
```

Re-run the same build from step 3 against the gateway and keep its output tree as
the chaos tree. Because the selected faults are recorded line-by-line into
`runs/chaos.jsonl`, this run is a self-contained, replayable reproducer. The
`validate` verdict object and exit codes are documented in
[`cli-output.md`](cli-output.md).

## 5. Verify the recorded timeline replays

Replay the recorded timeline through a fresh gateway, then check that every
recorded event was observed again with matching fingerprints and faults. Replay
mode (`--replay`) is mutually exclusive with `--policy`, and the record path must
differ from the replay path:

```sh
./result/bin/rechaos serve \
  --upstream-host 127.0.0.1 --upstream-port 50099 \
  --replay runs/chaos.jsonl --record runs/replayed.jsonl

./result/bin/rechaos verify-replay runs/chaos.jsonl runs/replayed.jsonl
```

`verify-replay` emits `{"verdict":"covered"}` and exits 0 when every expected
event was observed; it fails on stderr with exit 2 otherwise. The determinism
contract is **same policy + seed + event trace ⇒ same decisions**; replay reports
divergence rather than guessing. The recompute path is `schedule`, which replays
the scheduler over exactly the recorded event trace:

```sh
./result/bin/rechaos schedule \
  --policy examples/fault-policy.json \
  --trace runs/chaos.jsonl --output runs/recomputed.jsonl
```

## 6. Oracle-compare the two output trees

Compare the clean output tree (step 3) against the chaos output tree (step 4).
The oracle compares relative paths, SHA256 file digests and sizes, executable
bits, symlink targets, and directories, ignoring timestamps:

```sh
./result/bin/rechaos oracle runs/clean-output runs/chaos-output
```

Exit codes carry the verdict: `0` equivalent, `1` diverged, `2` inconclusive (an
input was not a completed build tree). On divergence, stdout carries a `changes`
array naming each differing path. The full verdict schema is in
[`cli-output.md`](cli-output.md).

## 7. Minimize to a witness

If the chaos run exposed a failure, shrink its timeline to a deletion-minimal
witness that still triggers your checker. `minimize` drives an external checker
subprocess per trial under a strict env-var contract, documented in
[`cli-output.md`](cli-output.md#minimize--the-delta-debugging-summary) and
implemented in
[`src/Rechaos/Shell/Minimize.hs`](../src/Rechaos/Shell/Minimize.hs):

- the checker command is run via `/bin/sh -c`;
- it reads the candidate timeline path from `RECHAOS_TIMELINE`;
- it writes its verdict JSON to the path in `RECHAOS_VERDICT`, as
  `{"verdict":"triggers","signature":"<sig>"}` (shrink this candidate),
  `{"verdict":"does-not-trigger"}`, or anything else (treated as unknown);
- a trial only counts as reproducing when the checker's `signature` equals the
  `--signature` argument, and only confirmed, repeated matches shrink.

```sh
./result/bin/rechaos minimize \
  --timeline runs/chaos.jsonl --output runs/minimal.jsonl \
  --signature my-repro --check 'python3 my_checker.py'
```

`minimize` writes the minimized timeline to `--output`, a per-trial evidence log
to `<output>.trials.jsonl`, and a summary object to stdout on success. It also
accepts `--repetitions` (default 2), `--trial-timeout` (seconds, default 30), and
`--max-trials` (default 1000). `scripts/read-checker.py` is a worked example of a
conforming checker.

## Where to go next

- [`examples/chaos/README.md`](../examples/chaos/README.md) — which committed
  config is CAS vs scheduler vs worker, how to launch each local endpoint, and how
  to point the continuous chaos monkey at the gateway.
- [`fault-dsl.md`](fault-dsl.md) — the complete policy grammar, every field and
  constraint, and the method × direction × fault eligibility matrix.
- [`invariants.md`](invariants.md) — the correctness and liveness invariants the
  chaos monkey asserts, each with its REAPI basis.
- [`README.md`](README.md) — the reference-docs index.
