# Differential harness

The [chaos monkey](../scripts/chaos-monkey.py) and the
[consistency oracle](consistency-oracle.md) answer **"is *this* endpoint
correct?"** — one against point invariants, the other against a history-level
model. [`scripts/reapi_differential.py`](../scripts/reapi_differential.py)
answers a complementary, vendor-grade question:

> **"Do these *N* REAPI endpoints behave the same?"**

It runs one deterministic probe battery against every configured endpoint,
normalizes each response to an implementation-independent **observation**, and
diffs the observations probe-by-probe. Where every endpoint agrees, the probe is
conformant; where they disagree, the harness emits a structured **divergence
witness**. That witness is exactly the artifact a vendor uses to demonstrate "we
conform and competitor X diverges" — or that a client uses to decide whether two
REAPI backends are drop-in interchangeable.

## The model: observable equivalence

Two endpoints are **observably equivalent on a probe** iff that probe's
normalized observation is byte-for-byte equal between them. Equivalence over the
whole battery is equivalence on every probe.

The power of the model is in the *normalization*: it deliberately discards
implementation-private, non-semantic detail and keeps only what a REAPI
**client** is entitled to rely on. A difference the spec does not constrain is
not a divergence; a difference a client could observe and depend on **is**.

| RPC | Kept (semantic) | Discarded (private) |
|---|---|---|
| `ByteStream.Write` | status; committed size; whether it equals the blob size | latency; server-assigned upload UUID; chunking |
| `ByteStream.Read` (incl. ranges) | status; byte count; SHA-256 of returned bytes; whether bytes hash to the requested digest | latency; number/size of response messages |
| `ByteStream.QueryWriteStatus` | status; committed size; `complete` flag | latency |
| `CAS.FindMissingBlobs` | status; the **set** of missing digests (order-independent, canonicalized) | latency; response ordering |
| `ActionCache.GetActionResult` | status (presence/absence); `exit_code`; the set of referenced output-file digests | latency; error wording; private metadata |
| `ActionCache.UpdateActionResult` | status; `exit_code` | latency |

Content-addressing (returned bytes must hash to the requested digest) is a hard
REAPI contract, so the returned-bytes SHA-256 and the `matches` flag are first
class in every read observation: a corrupt read on one endpoint diverges from a
correct read on another even if both report `OK`.

### Determinism

Everything the harness touches is a pure function of `--seed`:

- **Blob contents** are `shake_256(seed/run_id/label)` (via the shared `Blob`
  helper), so the same seed produces the same bytes, the same digests, and the
  same content-addressed resource names on every run.
- **Action Cache action digests** are derived from each blob's digest.
- **Probe order** is fixed and seed-independent.

Consequently two runs against the same fleet produce identical observations and
therefore an identical verdict, and any divergence is **reproducible** from the
seed alone — paste the seed into a bug report and the counter-example regrows.

## What a divergence means

A flagged probe means the endpoints returned *different client-observable
semantics* for the *same* request. Reading the witness:

- **One endpoint `OK` with `matches:true`, another `OK` with `matches:false`** —
  a silent content-addressing violation (torn/corrupt read) on the second. This
  is the most serious class: the client gets bytes that do not hash to the
  digest it asked for.
- **Different `committedBytes` / `complete` on Write or QueryWriteStatus** — the
  two implementations disagree on upload accounting; a client that trusts
  `QueryWriteStatus` to resume an upload would resume differently.
- **Different `missing` sets from FindMissingBlobs** — the endpoints disagree on
  what is present, so a build client would upload different blob sets to each. A
  present blob reported missing wastes work; an absent blob reported present is a
  correctness hazard.
- **Different AC presence / `exit_code` / output digests** — cache-hit behavior
  diverges; one endpoint serves a cached result the other does not (or serves a
  *different* result), which changes build outcomes.
- **One endpoint errors where another succeeds** (e.g. `NOT_FOUND` vs `OK`,
  `INTERNAL` vs `OK`) — a raw status-code divergence.

A divergence is **not** a verdict on *which* endpoint is right — it is evidence
that they are not interchangeable. In practice the content-addressing and
AC-contract checks make the direction obvious (an endpoint returning
`matches:false` is the wrong one), but the harness reports symmetric witnesses
and leaves attribution to the reader.

Agreement is **not** a proof of correctness: two endpoints can be wrong in the
same way (both corrupt identically) and still agree. Differential testing finds
*divergence*; pair it with the oracle and the chaos monkey for absolute
correctness. This is why the self-check below — the same endpoint listed twice —
must always report full agreement: it is the harness's own soundness test.

## Usage

Run under `nix develop` (needs `grpcio` and the generated bindings). Build the
Python bindings once if they are not present:

```bash
nix develop -c scripts/test.sh    # builds .build/python and runs the wire suite
# or just the bindings:
nix develop -c bash -c 'mkdir -p .build/python &&
  python3 -m grpc_tools.protoc -Iproto --python_out=.build/python \
  $(rg --files proto -g "*.proto")'
```

Then diff two or more endpoints:

```bash
# Self-check: the same endpoint twice must report full agreement.
nix develop -c python3 scripts/reapi_differential.py \
  --endpoint 127.0.0.1:50052 --endpoint 127.0.0.1:50052

# Two different backends, machine-readable report, custom sizes and seed.
nix develop -c python3 scripts/reapi_differential.py \
  --endpoint HOST_A:PORT --endpoint HOST_B:PORT \
  --instance main --seed 20261002 --sizes 1,4096,65537,1048577 \
  --json report.json
```

### CLI flags

| Flag | Meaning |
|---|---|
| `--endpoint HOST:PORT` | A REAPI endpoint to probe. Repeat **≥2** times. The same address twice is a valid self-check. |
| `--instance` | REAPI instance name (default `main`). |
| `--seed` | Deterministic seed for blob content and the probe battery (default `20261002`). |
| `--sizes` | Comma-separated blob sizes for write/read/range probes (default covers the 64 KiB ByteStream chunk boundary). |
| `--run-id` | Override the seed-derived run id (advanced; stays deterministic within a run). |
| `--json PATH` | Write the full structured report as JSON (`-` for stdout). |
| `--quiet` | Suppress the human summary (pair with `--json`). |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Full agreement — all endpoints observably equivalent on every probe. |
| `2` | At least one divergence — see the per-probe witnesses. |
| `1` | Operational error (bad arguments, unreachable fleet, etc.). |

### Output

Human output is a banner-framed list of probes, each marked `ok` or `DIFF`; a
`DIFF` probe lists each distinct observation and the endpoints that produced it,
followed by an `AGREE` / `DIVERGE` verdict. The `--json` report is the full
structure: top-level `verdict` and `divergences`, then every probe with its
per-endpoint `observations` and, for divergent probes, the `groups` (each a
distinct observation and the set of endpoints that returned it).

## Fault timelines (optional)

Because the harness drives any REAPI endpoint, the gateway can sit in front of
one of them: point an `--endpoint` at a `bin/rechaos serve` instance configured
with a fault policy (see [fault-dsl.md](fault-dsl.md) and
[timeline-format.md](timeline-format.md)) and differentially compare "endpoint
under fault injection" against "endpoint clean". A seeded gateway policy plus the
seeded probe battery makes the whole comparison reproducible: the same
`--seed` and the same gateway policy seed regrow the identical fault schedule and
the identical divergence.

## Relationship to the other tools

- **Chaos monkey** — point invariants on one endpoint under injected faults.
- **Consistency oracle** — history-level linearizability on one endpoint.
- **Differential harness** (this) — cross-endpoint observable equivalence; the
  only tool here that compares *implementations* rather than judging one.
