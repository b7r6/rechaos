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
blobs (Command / empty input-root Directory / Action) are serialized protobufs,
hashed as-is.

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

Integrity is checked on the wire: uploaded blobs are re-read from CAS and the
SHA256 of the returned bytes is compared against the digest the generator
computed locally. Any mismatch is recorded in `errors` and makes the process
exit non-zero.

`--execute` is **off by default**: many dev REAPI servers expose CAS + AC but no
worker, so the tool synthesizes the `ActionResult` itself and exercises the
AC put/get round-trip without a real execution. Turn it on against a fleet that
has a scheduler/worker.

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
are everything `replay` needs. Because the graph is re-synthesized from its
recorded parameters (`graph_id`, `instance`, counts) under the **same `--seed`**,
the replayer reconstructs identical blob bytes/digests without storing payloads
in the trace.

## Trace format (JSONL)

One JSON object per line, in issue order:

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
| `GetActionResult`    | `actionDigest`           | `hit`, `missCode`             |
| `UpdateActionResult` | `actionDigest`, `outputDigest` | `ok`                    |
| `Execution/Execute`  | `actionDigest`           | `operation`, `done`           |

## Round-trip verification

`replay` re-issues each recorded RPC and asserts monotonic, store-consistent
outcomes (a CAS/AC store only grows):

- **FindMissingBlobs**: the replayed missing set must be a **subset** of the
  recorded missing set (blobs recorded as present must still be present).
- **GetActionResult**: any action recorded as a **hit** must still hit.
- **Read**: the readback SHA256 must equal the requested digest.
- **Write / UpdateActionResult**: re-applied idempotently so later asserts hold.
- **Execute**: not replayed by default (environment-dependent).

Mismatches are collected; `roundTripOk` is true iff empty, and the process exits
non-zero otherwise.

## Determinism

Everything derives from `--seed` + `--graph-id`:

- graph structure (layers, inputs, deps) via a seeded `random.Random`,
- blob content via `shake_256(graph_id, label)`,
- action digests via the serialized Command/Action protobufs.

Upload resource names use fresh UUIDs (as a real client does); these do not
affect digests or cache keys, so determinism of the *content-addressed* state is
preserved. Re-running the same seed against a warm cache yields all AC **hits**
(idempotent).

## Validated

Against a live local NativeLink at `127.0.0.1:50052` (instance `main`, SHA256):

- `generate` of a 6-target / 2-layer graph: 34 uploads, 6 AC misses, 6
  `UpdateActionResult`, 6 post-put AC hits, 6 output readbacks all verified,
  0 errors; dedup ratio 0.49.
- Re-running the same seed: all 6 targets report AC **hit** with no re-upload --
  idempotent against a warm cache.
- `FindMissingBlobs` transition observed in the trace: first call reports blobs
  missing, the subsequent `Write`s make them present.
- Full AC lifecycle observed for a single action digest:
  `GetActionResult:miss -> UpdateActionResult -> GetActionResult:hit`.
- `record` of a tiny graph (32 RPCs) then `replay`: all 32 RPCs re-driven,
  `roundTripOk: true`, zero mismatches.
```
