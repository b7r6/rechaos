# S3/R2 egress faults: the slow-store fault proxy

`scripts/s3_fault_proxy.py` is a stdlib-only HTTP(S) forwarding proxy that sits on
the **NativeLink &rarr; object-store** hop and injects faults on the S3 REST API
(GET / PUT / DELETE / HEAD / ListObjects). It is the egress-side companion to the
`rechaos serve` gRPC gateway.

## Why this exists (what it breaks)

The `rechaos serve` gateway sits on the **client &harr; NativeLink** gRPC path. It
can tear REAPI reads and writes, but it can never exercise what happens when
NativeLink's *own* object-store egress degrades. The CAS &rarr; object-store
write-back "death spiral" &mdash; the R2/S3 retry loop fighting a throttling or
slow backend, `fast_slow` reconciliation stalling, buffers growing while retries
pile up &mdash; was never reproduced, because nothing injected faults on the
NativeLink &harr; R2/S3 hop. This proxy closes that gap.

Concretely, it stresses:

- **`slow_store` write-back.** When the fast tier accepts a blob and NativeLink
  writes it back to the slow (object-store) tier, a throttling or truncating slow
  tier makes that write-back fail, retry, and back up.
- **The R2/S3 retry loop** (`max_retries`, `delay`, `jitter`, retry budget). The
  `slowdown` and `burst` faults return `503 SlowDown` / `429` with a `Retry-After`
  header, exactly the throttle signal the S3 client's backoff path keys on.
- **`fast` &rarr; `slow` reconciliation.** `truncate` and `reset` return partial
  or abruptly-cut bodies, so a read-through or verify step on the slow tier sees a
  short object or a mid-body connection reset.

## The proxy at a glance

```
bazel/client --grpc--> NativeLink --s3 http--> s3_fault_proxy --http(s)--> object store
                         (fast_slow slow tier)   (injects faults here)      (R2 / S3 / MinIO)
```

- Speaks plain HTTP on its listen socket; forwards every request verbatim to an
  `--upstream` base URL (http **or** https) and streams the response back.
- Faults are selected by **S3 operation**, **key prefix**, and **probability**,
  with a fixed `--seed` so a run is reproducible given the seed and request order.
- Anything not selected for a fault is forwarded transparently (status line,
  headers, body). Credentials (`Authorization`, `x-amz-*`) are copied through
  **untouched and never logged**.
- Stdlib only: `http.server` + `ThreadingHTTPServer` + `urllib` + `ssl`. No
  external dependencies, runs under `nix develop` or bare `python3`.

`--upstream` is **required** and has no default &mdash; there is no hardcoded
endpoint anywhere. Point it only at an object store you control.

## The fault menu

Each fault is its own flag group. Latency is orthogonal (it can co-occur with a
body/status fault); the body/status faults are mutually exclusive per request and
evaluated in the priority order below, first match wins.

| Fault | Flags | What the client sees | Breaks |
|---|---|---|---|
| **latency** | `--latency-ops --latency-ms --latency-prob --latency-prefix` | request held N ms before forwarding | slow write-back; deadline/timeout tuning |
| **slowdown** | `--slowdown-ops --slowdown-prob --slowdown-prefix --slowdown-status --slowdown-code` | `503 SlowDown` (or chosen status/code) + XML `<Error>` + `Retry-After: 1`, **no upstream call** | the retry/backoff loop, retry budget exhaustion |
| **truncate** | `--truncate-ops --truncate-prob --truncate-prefix --truncate-bytes` | full `Content-Length` advertised, only first N body bytes sent, then close | short-read / checksum validation on reconcile |
| **reset** | `--reset-ops --reset-prob --reset-prefix --reset-after` | N body bytes then a TCP RST (SO_LINGER 0) mid-body | mid-stream connection drop handling |
| **drip** | `--drip-ops --drip-prob --drip-prefix --drip-bps --drip-chunk` | body dribbled at a byte-rate in small chunks (slow-loris) | read timeouts; head-of-line stalls on the slow tier |
| **burst** | `--burst-ops --burst-every --burst-len --burst-prefix` | deterministic error runs: the first `--burst-len` of every `--burst-every` matching requests fail with the slowdown status/code | sustained-throttle / circuit-breaker behavior |

Operation names for every `--*-ops` flag are a comma list drawn from
`GET,PUT,DELETE,HEAD,List` (case-insensitive; `List` == `ListObjects`). The S3
operation is derived from the HTTP method and query string, not from any
credential:

- `PUT` / `DELETE` / `HEAD` map to themselves.
- `GET` with an object key &rarr; `GET`.
- `GET` on a bucket root, or with `?list-type` / `?prefix` / `?delimiter` /
  `?marker` &rarr; `ListObjects`.

**Prefix matching** is against the object key: the request path minus the leading
`/` and, with `--strip N`, minus the first `N` path segments (use `--strip 1` for
a path-style `/<bucket>/<key>` endpoint so the prefix matches the key, not the
bucket).

**Determinism.** Each request gets a sub-seed `f"{seed}:{counter}"` from the
master `--seed` and a monotonic request counter, so the decision for request #k is
identical across runs with the same seed and request order. The `burst` fault uses
the counter directly (not the RNG), so its pattern is exact.

## Wiring it to NativeLink

See [`examples/chaos/r2-fault-proxy.json5`](../examples/chaos/r2-fault-proxy.json5)
for a ready-to-edit NativeLink config whose CAS is a `fast_slow` store with a local
filesystem fast tier and a slow tier that is an `experimental_s3_store` pointed at
`http://127.0.0.1:8081` &mdash; this proxy. Fill in `<BUCKET>` and supply
credentials from your environment; the endpoint placeholders are generic and all
local state lives under `/tmp/rechaos/r2faults`.

Start order (nothing touches a shared cluster; the proxy only reaches whatever you
pass as `--upstream`):

```sh
# 1) Have a real object store you control, OR a local MinIO on 127.0.0.1:9000 for
#    a fully offline loop.

# 2) Start the fault proxy pointed at it. Example: throttle 30% of PUTs under cas/,
#    add 200ms to every GET, truncate 10% of GET bodies to 128 bytes.
nix develop --command python3 scripts/s3_fault_proxy.py \
  --listen 127.0.0.1:8081 \
  --upstream https://<ACCOUNT>.r2.cloudflarestorage.com \
  --slowdown-ops PUT   --slowdown-prob 0.3 --slowdown-prefix cas/ \
  --latency-ops  GET   --latency-ms 200 \
  --truncate-ops GET   --truncate-prob 0.1 --truncate-bytes 128 \
  --seed 1 --verbose

# 3) Start NativeLink against the example config (CAS slow tier -> the proxy).
nativelink examples/chaos/r2-fault-proxy.json5

# 4) Drive REAPI traffic (bazel, or scripts/fleet-stress.py) and watch the
#    write-back / retry behavior on the slow tier degrade under the injected faults.
```

### Reproducing the write-back death spiral

To push the CAS &rarr; object-store write-back loop toward the spiral, combine a
sustained throttle burst with latency so retries queue faster than they drain:

```sh
nix develop --command python3 scripts/s3_fault_proxy.py \
  --listen 127.0.0.1:8081 --upstream http://127.0.0.1:9000 --strip 1 \
  --burst-ops PUT --burst-every 5 --burst-len 3 --burst-prefix cas/ \
  --slowdown-status 503 --slowdown-code SlowDown \
  --latency-ops PUT --latency-ms 500 \
  --seed 1 --verbose
```

Then upload blobs through NativeLink (e.g. `scripts/fleet-stress.py` or a Bazel
build with remote cache) and watch the slow-tier write-back retry loop against the
`503 SlowDown` bursts.

## Validation

`scripts/s3_fault_proxy.py` is covered by a stdlib harness that starts a trivial
`http.server` upstream, runs the proxy against it, and asserts each fault fires:

- transparent GET forwards status, body, and an upstream header (`ETag`);
- transparent PUT reaches the upstream with the exact bytes;
- `latency` adds the configured delay to targeted ops and not to others;
- `slowdown` returns `503 SlowDown` with an XML `<Error>` body and `Retry-After`,
  without contacting upstream, leaving untargeted ops transparent;
- `truncate` advertises the full `Content-Length` but sends only the kept bytes;
- `reset` drops the connection mid-body (observed as short body / RST);
- `drip` paces the body to the configured rate while preserving the payload;
- `burst` fails the first `burst-len` of every `burst-every` requests exactly;
- a key prefix selects only matching keys;
- probabilistic decisions are reproducible across runs with the same seed.

## Safety notes

- `--upstream` is required; there is no default endpoint. Never commit a real
  endpoint or credential &mdash; the example config uses placeholders.
- The proxy copies auth headers through verbatim and never logs them.
- It binds wherever `--listen` says (default `127.0.0.1:8081`); keep it on
  loopback. Point it only at an object store you own.
