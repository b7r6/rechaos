# Load generator and latency-regression oracle

The chaos monkey and the [consistency oracle](consistency-oracle.md) answer
*correctness* questions about a REAPI/NativeLink endpoint. This document covers
the orthogonal *performance* question, answered by
[`scripts/load_gen.py`](../scripts/load_gen.py): under sustained
high-concurrency traffic, what are the per-operation latency percentiles, the
achieved throughput, and the error rate — and have any of them **regressed**
against a committed baseline?

The tool is stdlib + `grpc` + the generated REAPI/ByteStream bindings, so it
runs under `nix develop` with no extra dependencies.

## What it drives

Each of `--clients` workers runs on its own thread and owns its own gRPC
channel, so the server sees genuinely independent connections. Every worker
loops, issuing operations drawn from a configurable mix until the run's deadline
(or shared op budget) is reached. Three op types are exercised:

| Op      | REAPI surface                                              | Weight flag      |
|---------|-----------------------------------------------------------|------------------|
| `write` | `google.bytestream.ByteStream/Write` (chunked upload)     | `--write-weight` |
| `read`  | `google.bytestream.ByteStream/Read` of a known blob       | `--read-weight`  |
| `fmb`   | `ContentAddressableStorage/FindMissingBlobs`              | `--fmb-weight`   |

Blob sizes are drawn from a distribution between `--size-min` and `--size-max`:

- `loguniform` (default) — uniform in *log* space, so a single run spreads
  across magnitudes (metadata-sized and payload-sized blobs alike);
- `uniform` — uniform in raw bytes;
- `fixed` — always `--size-min`.

Writes sample fresh payloads with random UUID bytes at the start. Tiny blobs
can collide because their byte domain is small; they do not guarantee a cold
cache entry for every upload. Reads draw from the
pool of blobs written so far; before the pool is warm a read falls back to a
write (and is counted as a write, so the mix stays honest).

## Determinism

Each worker uses `random.Random(seed + i)` for operation and size draws. The
full stimulus is not deterministic: blob bytes include fresh UUIDs, readers use
a shared pool populated by successful writes, and thread scheduling determines
which worker consumes the shared operation budget. Server failures also change
pool contents and fallback writes.

Use the same seed, client count, mix, and size distribution for statistically
comparable runs, and inspect the observed operation counts. Exact workload
replay is not provided by this load generator.

Prefer `--op-count` (a fixed total number of measured ops across all clients)
over `--duration` when you want the two runs to issue the *same amount of work*;
use `--duration` when you want to measure what the endpoint sustains in a fixed
wall-clock window. `--warmup N` runs `N` untimed ops per client first so channel
setup and cold caches do not pollute the measured percentiles.

## Metrics

For each op type and for the run-wide aggregate the tool reports:

- `count`, `errors`, `error_rate` (errors / count);
- `throughput_ops_s` (count / wall-clock seconds);
- `latency_ms`: `p50`, `p95`, `p99`, `max`, `mean`, computed over the
  **successful** ops only (a failed RPC's latency is not a latency sample).

Percentiles use the **nearest-rank** method on the sorted latency vector, which
is exact for a recorded sample set and needs no interpolation assumptions. All
latencies are reported in milliseconds.

Output is a human-readable table by default; `--json` emits the full metrics
object (plus the comparison, in baseline mode) to stdout, and `--out FILE` also
writes the metrics JSON to a file. The JSON carries `"schema":
"rechaos.load-perf/v1"` and echoes the full `config` so a saved run is
self-describing.

## Regression rubric

Save a baseline from a known-good run:

```
python3 scripts/load_gen.py --clients 8 --duration 10 --seed 42 \
    --save-baseline baselines/reapi-8c.json
```

Compare a later run against it:

```
python3 scripts/load_gen.py --clients 8 --duration 10 --seed 42 \
    --baseline baselines/reapi-8c.json
```

In `--baseline` mode the tool compares the current run to the baseline for the
aggregate **and** each op type, and flags a regression when:

| Metric                | Rule                                                      | Default threshold            |
|-----------------------|----------------------------------------------------------|------------------------------|
| `p50`/`p95`/`p99`     | fractional **growth** over baseline exceeds the threshold | `--latency-threshold` = 0.20 (20%) |
| `throughput_ops_s`    | fractional **drop** below baseline exceeds the threshold  | `--throughput-threshold` = 0.20 (20%) |
| `error_rate`          | **absolute** rise (percentage points) exceeds the threshold | `--error-threshold` = 0.05 (5pp) |

Latency deltas are relative to the baseline value; throughput is a drop; error
rate is an absolute percentage-point increase (a fraction, e.g. `0.05` = 5
points). A regression on *any* op type or on the aggregate is a regression for
the run.

### Noise floor

Sub-millisecond operations produce huge *percentage* swings from tiny absolute
jitter (a p50 moving from 0.4 ms to 0.9 ms is +125% but operationally
meaningless). To avoid false positives, the fractional latency check is skipped
when **both** the baseline and current values for a percentile are below
`--latency-floor-ms` (default 1.0 ms). Raise the floor on a very fast
loopback endpoint; lower it when sub-millisecond latency genuinely matters.

### Exit code

In `--baseline` mode the process exits non-zero when any regression is detected
and zero otherwise, so the oracle slots directly into CI as a gate. Outside
`--baseline` mode (plain load or `--save-baseline`) the exit code is always
zero.

### Choosing thresholds and a baseline

- Commit baselines produced on the same class of hardware you will compare on;
  absolute latency is sensitive to the host and to loopback vs. network.
- Run long enough that the tail percentiles are stable. A few thousand ops per
  op type is a reasonable floor; a single slow outlier dominates `max` and can
  move `p99` on a short run (`max` is reported for visibility but is *not* part
  of the regression rubric for exactly this reason).
- Keep `--seed`, `--clients`, the weights, and the size distribution identical
  between baseline and comparison. Changing the workload invalidates the
  comparison.
- Tighten thresholds as the endpoint and baseline stabilise; start at the 20%
  defaults, which tolerate normal run-to-run variance on a shared machine.

## Example

```
$ python3 scripts/load_gen.py --clients 8 --duration 3 --seed 42
rechaos load-perf  target=127.0.0.1:50052 instance='main' clients=8 seed=42
  mode=duration=3.0s  wall=3.04s  size=256..65536B (loguniform)  weights={...}
  op           count   err    err%     tput/s     p50ms     p95ms     p99ms     maxms
  -----------------------------------------------------------------------------------
  read          6305     0   0.00%   2072.458     1.458     2.469     3.207    44.505
  write         2094     0   0.00%    688.299     3.534    15.498    45.377     48.09
  fmb           2122     0   0.00%    697.503     0.554      1.09      1.46    86.846
  -----------------------------------------------------------------------------------
  TOTAL        10521     0   0.00%   3458.261     1.461     4.136    42.848    86.846
```

Re-running the same command with `--baseline` against a baseline saved from a
stable run prints `regression check: PASS` and exits 0; against a baseline whose
numbers the current run cannot meet it prints one `[REGRESSION]` line per
failing metric and exits 1.
