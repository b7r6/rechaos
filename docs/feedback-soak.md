# Feedback-guided generation and the resource-leak soak

`scripts/chaos-monkey.py` runs continuous randomized REAPI fault campaigns against
a live REAPI/NativeLink endpoint, checking every result against a fixed set of
correctness and liveness invariants (see `docs/invariants.md`). This document
covers the two closed-loop extensions layered on top of the original pure-random
generator:

1. **Feedback-guided generation** (`--feedback`, on by default) — a
   novelty-seeking bias that steers the generator toward combinations that keep
   producing *new* observable behavior.
2. **Resource-leak soak** (`--soak`) — a generalized rising-floor detector that
   tracks every scrapable numeric signal over a long run and flags any that grow
   without bound.

Both are fully reproducible under `--seed`, both are additive (every existing
mode, flag, and invariant is unchanged), and neither touches server
configuration — the tool only ever speaks REAPI and scrapes the Prometheus
`/metrics` endpoint.

---

## 1. Feedback-guided generation

### The problem with uniform random

The original generator draws each iteration's mode (`proxy` / `direct` /
`execution`), operation, and fault parameters uniformly at random. That is simple
and unbiased, but it spends the same effort on fault combinations that have
already been exercised a hundred times as on combinations never seen. Over a long
campaign most iterations re-cover known ground.

### Coverage signatures

After each iteration the monkey scrapes Prometheus `/metrics` and computes a
**coverage signature** — a compact string describing what that iteration
*observably did*. It is built from:

- the discrete generator choices (`mode`, the proxy op / direct scenario / exec
  scenario, and for proxy the first rule's `fault_kind` and `direction`);
- the RPC outcome(s) observed (gateway read/write/missing status, exec result,
  write/query status);
- **which metric families moved**, bucketed — see below;
- any new finding signatures minted this iteration.

Metric movement is the key novelty source. Raw Prometheus series are noisy and
per-shard/per-operation (e.g. `action_db_operation_ids_<uuid>`), so before
comparing we:

- **fold families**: strip `{labels}` and collapse trailing hex-UUID and numeric
  shards to `_*`, then sum sibling series, so "the awaited-action store family
  moved" is one signal rather than one-per-operation-id (`family_of`,
  `_fold_families`);
- **bucket deltas**: map each family's before→after change to a coarse,
  sign-aware magnitude bucket (`0`, `+f`, `+1`, `+2`, `+3`, `+4`, `+5`, and the
  negatives) via `delta_bucket`, so jitter in a gauge's low digits does not mint
  a brand-new signature every iteration.

The set of coverage signatures ever seen is the run's novelty memory. An
iteration is **novel** iff its signature was not already in that set. (Logged to
`feedback.jsonl`; the live console shows `cov=<N>` with a `*` when the iteration
was novel.)

### Novelty-seeking bias

A `Feedback` object keeps, per decision dimension (`mode`, `proxy_op`,
`direct_scenario`, `exec_scenario`), a decayed **reward** for each choice. When an
iteration is novel, every choice that led there is credited `+1.0`; all rewards
for that dimension decay by `--`decay each iteration so stale wins fade.

Selection is epsilon-greedy with an optimistic prior:

- with probability `--explore-floor` (default `0.25`) the choice is **uniform
  random** — a permanent exploration floor so nothing is ever starved;
- otherwise the choice is sampled proportional to `reward + prior`, where a
  never-tried option gets an optimistic `+1.0` prior so everything is tried once
  before exploitation begins, and a small `+0.05` keeps all weights positive.

Because every draw comes from a single seeded RNG (`Random("<seed>:feedback")`)
and never from global state, a given `--seed` replays the campaign identically.

With `--no-feedback` the `Feedback.choose` path degenerates to a plain
`rng.choice`, so the tool reproduces the original uniform-random behavior exactly
(no `cov=` tag, no feedback section in the summary).

### What you see

```
[    19s] iter     22 direct concurrent-writers found=0 recov=ok | total findings=0 unique=0 cov=11*
```

`cov=11` = 11 distinct coverage signatures so far; the trailing `*` = this
iteration was novel. The end-of-run summary (`summary.json`) includes a
`feedback` block with the final reward and try tables, e.g. after a short direct
campaign the scenarios that kept minting new signatures
(`concurrent-writers`, `short-upload`) carry the highest reward and so are
sampled more often.

### Files written

| file | contents |
|------|----------|
| `feedback.jsonl` | one row per iteration: `novel`, `coverage_signature`, `choices` |
| `summary.json` → `feedback` | final `unique_coverage_signatures`, `novel_iterations`, `reward`, `tries` |

### Flags

| flag | default | effect |
|------|---------|--------|
| `--feedback` | on | enable novelty-seeking bias |
| `--no-feedback` | — | restore original uniform-random generation |
| `--explore-floor F` | `0.25` | fraction of choices kept uniformly random even with feedback on |
| `--feedback-always-log` | off | compute+log coverage signatures even under `--no-feedback` (does **not** bias selection) — useful to measure uniform coverage |

---

## 2. Resource-leak soak

### From one detector to all signals

The original tool already had a scheduler-specific rising-floor detector: it
scraped the awaited-action store occupancy and flagged the P0 leak when the
*minimum* occupancy over a window kept climbing (GC not keeping pace with
terminal/abandoned entries). `--soak` generalizes exactly that idea to **every**
numeric signal the server exposes, plus process RSS/FD when reachable.

### What is tracked

On every iteration (when `--soak` is set) the monkey parses the full `/metrics`
exposition into `{series_name: float}` (`parse_metrics`) and appends each value to
a per-series history (`SoakTracker.observe`). Config-like and inherently-growing
series are excluded by name so they cannot produce false positives:

- `*_max_bytes`, `*_max_count`, `*_max_seconds` (static limits),
- `*_last_time` (timestamps),
- `*_weight`, `*_block_size`, `*_read_buffer_size` (static config),
- `*lifetime_inserted*`, `*_downloaded_bytes`, `*_uploaded_bytes` (cumulative
  counters that are *supposed* to grow),
- a few other NativeLink config gauges (`consider_expired_after_s`,
  `max_retry_buffer*`, `multipart_max_concurrent*`).

**Process RSS/FD** are best-effort and opt-in. The target server here does not
export a Prometheus `process_*` collector, so there is nothing to read from the
scrape by default. If you run the chaos monkey co-located with the server you can
pass `--proc-pid <PID>` to additionally fold `process_resident_memory_kb` and
`process_open_fds` (read from `/proc/<pid>`) into the soak tracker. When neither
is reachable the tool simply tracks the gauges it *can* see — it never silently
fabricates a process signal.

### The rising-floor test

A leak is a signal that **accumulates** — it never returns to its earlier low
even when offered load ebbs. Pure growth-under-load is not a leak; the signal
must fail to recede. So for each series we compare the **floor** (minimum) over
three consecutive windows of `--soak-window` samples each:

```
          |<-- old -->|<-- mid -->|<-- now -->|
floor:        f_old       f_mid       f_new
```

A series is flagged only when:

- `f_new > f_mid >= f_old` — the floor rises across **both** window transitions
  (monotone-ish; a single bump is not enough), and
- the absolute rise `f_new - f_old` ≥ `--soak-abs-threshold` (filters sub-unit
  gauge noise), and
- the relative rise `(f_new - f_old) / |f_old|` ≥ `--soak-rel-threshold` (so a
  tiny wobble on a large gauge is ignored).

Requiring the floor — not the peak — to rise is what accounts for load: a gauge
that spikes under a burst and drains back keeps a flat floor and is never
flagged. The detector reports the per-unit-load slope (`rise_per_unit_load`,
using cumulative iteration count as the load proxy) so a human can judge whether
growth tracks work done or runs away independent of it.

Each offending metric is reported **once** per run as a finding with the
signature `resource-leak-rising:<metric>` and the full growth evidence
(the three window floors, absolute/relative rise, load delta, slope, sample
count). A final pass at end-of-run (`soak_final`) catches signals whose growth
only became monotone over the whole campaign.

### Validation note

Against the local CAS/AC endpoint the soak run tracked 51 numeric signals over a
short campaign and correctly flagged **zero** (a true negative — this server has
no leak for CAS/AC traffic). The detector was separately verified to fire on the
known scheduler-leak shape (a monotonically rising awaited-action store) while
ignoring a bounded, load-driven queue-depth gauge oscillating around a fixed
floor.

### Files written

| file | contents |
|------|----------|
| `soak-series.jsonl` | one row per iteration: `iteration`, `tracked_signals` |
| `soak-summary.json` | `samples`, `tracked_signals`, `flagged` metric names, `window` |
| `findings.jsonl` / `corpus/` | any `resource-leak-rising:<metric>` findings, with growth evidence |
| `summary.json` → `soak` | `samples`, `tracked_signals`, `flagged` |

### Flags

| flag | default | effect |
|------|---------|--------|
| `--soak` | off | track every numeric signal (plus process RSS/FD if reachable) for unbounded growth |
| `--soak-window N` | `15` | samples per rising-floor window (needs 3 windows before any verdict) |
| `--soak-rel-threshold R` | `0.5` | minimum relative floor rise to flag |
| `--soak-abs-threshold A` | `1.0` | minimum absolute floor rise to flag (filters sub-unit noise) |
| `--proc-pid PID` | `0` | optional co-located server PID to read RSS/FD from `/proc` (`0` = skip) |

`--soak` is intended for long runs (`--minutes 30`, or a large `--iterations`):
the detector needs at least `3 × --soak-window` samples before it will emit any
verdict, and longer runs let a slow leak separate from load-driven noise.

---

## Examples

```sh
# Default: feedback-guided, forever, against the local endpoint.
nix develop --command python3 scripts/chaos-monkey.py --host 127.0.0.1 --port 50052

# Old uniform-random behavior, bounded run.
nix develop --command python3 scripts/chaos-monkey.py --no-feedback --iterations 200 --seed 1

# Long resource-leak soak (feedback still on).
nix develop --command python3 scripts/chaos-monkey.py --soak --minutes 30

# Soak with a tighter window and co-located process RSS/FD tracking.
nix develop --command python3 scripts/chaos-monkey.py --soak --soak-window 20 --proc-pid 12345 --minutes 60

# Measure uniform coverage without biasing (research mode).
nix develop --command python3 scripts/chaos-monkey.py --no-feedback --feedback-always-log --iterations 500
```

All existing selectors (`--only-proxy`, `--only-direct`, `--only-execution`,
`--execution`, `--stop-on-finding`, the scheduler `--leak-*` / `--drain-seconds`
knobs) continue to work unchanged and compose with both new modes.
