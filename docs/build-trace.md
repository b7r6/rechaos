# build-trace: BUILD-shaped REAPI workloads

`scripts/build_trace.py` moves rechaos past synthetic single-blob traffic and
onto **action-graph-shaped** workloads that mirror how real Bazel/Buck2 builds
talk to a Remote Execution API (REAPI) cache. It is a deterministic generator,
recorder, and replayer, driven entirely over the public REAPI/ByteStream
protocol -- no server source, no restarts, no hardcoded internal endpoint.

Run it under `nix develop` (it needs `grpcio` plus the generated Python bindings
that `scripts/test.sh` drops into `.build/python`):

```sh
nix develop --command bash -c '
  mapfile -t protos < <(rg --files proto -g "*.proto")
  mkdir -p .build/python
  python3 -m grpc_tools.protoc -Iproto --python_out=.build/python "${protos[@]}"
  python3 scripts/build_trace.py generate --host 127.0.0.1 --port 50052
'
```

## Why this shape matters

A real build does not upload one object. It drives a dependency DAG where each
target:

1. makes its **input blobs** present in CAS (shared toolchain/headers are
   deduplicated across the whole graph),
2. uploads a **Command** and an **Action** describing the work,
3. asks the **ActionCache** `GetActionResult` -- *check* before doing work,
4. on a miss, optionally **Execute**s the action, then publishes the **output
   blob** to CAS and the result via `UpdateActionResult` -- *cache*,
5. downstream targets that share the same action then see a cache **hit**.

The interesting cache behavior -- `FindMissingBlobs` transitioning
`missing -> present`, AC `miss -> put -> hit`, dedup, and fan-out concurrency --
only appears under this shape. That is exactly what this tool synthesizes.

## The graph model

A graph is synthesized deterministically from CLI parameters (see
`BuildGraph.synthesize`). Everything is keyed on `--seed` and `--graph-id`, so a
given invocation always produces identical blob bytes and therefore identical
digests across runs and hosts.

- **Targets** are arranged into `--layers` dependency layers, `--targets` total.
- Each target has:
  - **private inputs** unique to it,
  - a random subset of **shared inputs** (`--shared-inputs` toolchain/header
    blobs reused across the whole graph -- the main source of dedup),
  - **deps**: up to `--max-deps` targets from the previous layer, whose *output*
    blobs become *inputs* here (true graph edges / fan-in),
  - a deterministic **Command**/**Action** pair,
  - one **output** blob.
- **Blob sizes** follow a long-tailed distribution (`SIZE_BUCKETS`): mostly
  small sources/headers, a tail of larger objects and the occasional big
  archive, roughly mirroring observed Bazel CAS traffic.

Blob content is `shake_256(graph_id, label)` truncated to the chosen size, so
content is stable and collisions across labels are negligible. Action-metadata
blobs (Command / input-root Directory / Action) are deterministically serialized
protobufs. The root names every input by its digest and size, so input changes
change the action digest.

The **Action digest** is what the ActionCache is keyed on. It is built from the
Command digest + input-root digest + platform, so two targets whose command and
inputs match share a cache entry -- the mechanism behind cache hits.

Graph statistics reported by the tool:

| field             | meaning                                               |
| ----------------- | ----------------------------------------------------- |
| `logicalBlobRefs` | total input+output references across all targets      |
| `uniqueBlobs`     | distinct blobs after dedup                             |
| `dedupRatio`      | `1 - uniqueBlobs/logicalBlobRefs`                      |
| `uniqueBytes`     | total bytes of the distinct blob set                  |

## How a target is driven

`Driver._run_target` performs, per target:

```
FindMissingBlobs(inputs + command + root + action)
  -> ByteStream.Write for each still-missing blob
GetActionResult(action)                       # expect MISS on first encounter
  (hit) -> read every cached output back, verify bytes == digest
  (miss):
    [optional] Execute(action)                # only with --execute + a worker
    ByteStream.Write(output)
    UpdateActionResult(action, result{output})
    GetActionResult(action)                   # now a HIT (check-then-cache)
      -> read output back, verify bytes == digest
```

Targets within a layer run concurrently (`--concurrency`); layers run in order,
so every dependency's output exists before a dependent references it.

Integrity is checked on the wire: every performed upload must acknowledge the
exact size, is re-read from CAS, and is checked again for presence. The
SHA256 of the returned bytes is compared against the digest the generator
computed locally. Any mismatch is recorded in `errors` and makes the process
exit non-zero.

`--execute` is **off by default**: many dev REAPI servers expose CAS + AC but no
worker, so the tool synthesizes the `ActionResult` itself and exercises the
AC put/get round-trip without a real execution. Turn it on against a fleet that
has a scheduler/worker. This optional step checks a terminal successful
ExecuteResponse; outputs in the cache workload are still synthesized by the
driver, not derived from a real compiler invocation.

## Subcommands

```
build_trace.py generate   synthesize a graph and drive it (optionally --trace)
build_trace.py record     drive a graph and capture a replayable JSONL trace
build_trace.py replay     re-drive a recorded trace and verify round-trip
```

Common flags: `--host/--port/--instance` (endpoint), `--seed`, `--graph-id`,
`--targets`, `--layers`, `--shared-inputs`, `--max-inputs`, `--max-deps`,
`--concurrency`, `--execute`.

### generate

Drives the graph and prints a JSON summary (endpoint, seed, graph stats, per-RPC
counts, and any errors). Optional outputs: `--trace` (RPC JSONL), `--graph-out`
(graph descriptor JSON), `--summary-out`. Exits non-zero if any target errored.

### record / replay

`record` is `generate` with a mandatory trace + graph descriptor, which together
contain the workload reconstruction data. The version 2 descriptor stores
every generated blob label, size, and digest plus the exact graph edges. The
replayer regenerates bytes from those descriptors and checks their digests,
without inferring generator parameters from summary counts. The graph file also
records the trace count, canonical SHA256, and whether recording completed
without errors. Replay rejects failed recordings and changed, reordered, or
truncated traces before opening a connection.

## Trace format (JSONL)

One JSON object per completed recorded operation, in synchronized completion
order. This is a sequential replay trace, not a recording of the concurrent
invocation/response intervals:

```json
{"seq":0,"method":"...ContentAddressableStorage/FindMissingBlobs",
 "atSeconds":0.012,
 "request":{"digests":[{"label":"...","sha256":"...","size":1234}]},
 "response":{"missing":[{"sha256":"...","size":1234}]}}
```

`method` is the full gRPC method path. `request`/`response` hold a compact,
digest-oriented summary -- never raw blob bytes -- sufficient to replay and to
verify outcomes. Recorded method shapes:

| method               | request keys             | response keys                 |
| -------------------- | ------------------------ | ----------------------------- |
| `FindMissingBlobs`   | `digests[]`              | `missing[]`                   |
| `ByteStream/Write`   | `sha256`, `size`         | `committedBytes`              |
| `ByteStream/Read`    | `sha256`, `size`         | `bytes`, `sha256`, `verified` |
| `GetActionResult`    | `actionDigest`           | `hit`, `missCode`, serialized `result` |
| `UpdateActionResult` | `actionDigest`, `outputDigest` | `ok`                    |
| `Execution/Execute`  | `actionDigest`           | `operation`, `done`           |

## Round-trip verification

`replay` reconstructs all blob bytes and graph edges from the version 2 graph
descriptor and verifies every stored digest before issuing traffic. Earlier
descriptors omit private blob sizes and cannot be reconstructed reliably; record
again to produce version 2. No seed guessing is used.

Replay checks use a no-eviction workload assumption:

- **FindMissingBlobs**: the replayed missing set must be a **subset** of the
  recorded missing set (blobs recorded as present must still be present).
- **GetActionResult**: a recorded hit must still hit with the recorded result,
  excluding execution metadata. Transport errors cannot count as cache misses.
- **Read**: size and hash must match both the requested blob and recording.
- **Write / UpdateActionResult**: committed sizes and returned results are checked.
- **Execute**: counted as skipped because this replayer does not reproduce execution.
- Unknown methods and missing graph blobs fail instead of counting as replayed.

`roundTripOk` is true only when there are no mismatches or skipped operations.
Exit 0 means verified, 1 means mismatches, and 2 means incomplete/invalid replay.
Replaying a cache workload does not recreate the original concurrency schedule.

## Determinism

Generated structure and bytes depend on all graph parameters, including
`--seed`, `--graph-id`, target/layer counts, and input/dependency bounds:

- graph structure (layers, inputs, deps) via a seeded `random.Random`,
- blob content via `shake_256(graph_id, label)`,
- action digests via the serialized Command/Action protobufs.

Upload resource names use fresh UUIDs (as a real client does); these do not
affect digests or cache keys, so determinism of the *content-addressed* state is
preserved. Re-running the same graph against an unchanged warm cache should
yield AC hits. Cache eviction, other writers, faults, and scheduling can change
responses and trace ordering.

## Validation

`test/python_contracts.py` exercises graph descriptor reconstruction, digest
corruption rejection, action dependence on inputs, wrong upload accounting,
transport errors, cached-output mismatches, and record/replay against the local
independent gRPC fixture. Those tests run in `nix flake check`.
