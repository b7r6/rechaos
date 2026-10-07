# Local NativeLink chaos configs

The three basic NativeLink configs below use loopback listeners and local
filesystem stores under `/tmp/rechaos/...`. Two additional object-store rigs
are described after the table; their proxy upstream determines whether traffic
remains local or reaches a configured external object store. The descriptions below are read directly from the config files;
see the [top-level README](../../README.md) and the
[tutorial](../../docs/tutorial.md) for the end-to-end workflow.

## The three configs

| Config | Role | Server listener | Worker | Notes |
|---|---|---|---|---|
| [`test-cas.json5`](test-cas.json5) | **CAS only** (cache) | `127.0.0.1:50099` | none | `cas` / `ac` / `bytestream` / `capabilities`; filesystem stores, no verify wrapper, no slow tier. Instance name `main`. |
| [`test-sched.json5`](test-sched.json5) | **Scheduler, no worker** | `127.0.0.1:50090` | none | Adds `execution` + a `simple` in-memory scheduler. With no worker, actions stay `QUEUED`; terminal state is driven via client cancel/timeout. For the queue-GC leak check. Instance name `main`. |
| [`local-rbe-worker.json5`](local-rbe-worker.json5) | **Full RBE cluster with worker** | `127.0.0.1:50090` | local worker on `127.0.0.1:50062` | CAS + AC + scheduler + an executing `local` worker; completed actions should be reclaimed within seconds (`retain_completed_for_s: 5`). For the completed-action queue-GC leak. No instance name set (default). |

- **CAS vs scheduler vs worker.** `test-cas.json5` is a pure content-addressable
  store / action cache (no `execution`, no `schedulers`). `test-sched.json5` adds a
  scheduler but deliberately has **no `workers`**, so the queue fills and never
  drains through execution. `local-rbe-worker.json5` is the only config with a
  `workers` section — a real executing worker, so completed actions exercise the
  reclaim path rather than the abandoned path.
- `test-sched.json5` and `local-rbe-worker.json5` both bind the main server to
  `127.0.0.1:50090`; run only one of them at a time.

## Object-store rigs

- [`s3-deathspiral.json5`](s3-deathspiral.json5) uses ports 51055/51081/51090
  for NativeLink, the S3 fault proxy, and local MinIO. It targets the
  `experimental_cloud_object_store` AWS schema and enables background write-back.
- [`r2-fault-proxy.json5`](r2-fault-proxy.json5) is a configurable template for
  the `experimental_s3_store` schema. Its proxy may forward to local MinIO or an
  external S3/R2 endpoint supplied by the operator. It requires bucket and
  credential configuration; it is not a ready-to-run offline fixture.

See [S3 faults](../../docs/s3-faults.md) and each config's schema/environment
comments. Schema compatibility depends on the NativeLink build being tested.

## Launch a local endpoint

Pick the config for the behavior you want to reproduce and launch NativeLink
directly against it (from a dev shell: `nix develop`):

```sh
# CAS-only cache endpoint on 127.0.0.1:50099.
nativelink examples/chaos/test-cas.json5

# Scheduler without a worker on 127.0.0.1:50090.
nativelink examples/chaos/test-sched.json5

# Full RBE cluster with an executing worker: server on :50090, worker_api on :50062.
nativelink examples/chaos/local-rbe-worker.json5
```

## Wire the rechaos gateway in front of it

Put the gateway between a client and the endpoint. Set `--upstream-port` to match
the config you launched (`50099` for CAS-only, `50090` for the scheduler/worker
configs). The gateway's downstream listener defaults to `127.0.0.1:50070`:

```sh
# In front of the CAS-only endpoint, recording a clean baseline (no faults).
./result/bin/rechaos serve \
  --upstream-host 127.0.0.1 --upstream-port 50099 \
  --port 50070 --record runs/clean.jsonl

# In front of the scheduler endpoint, applying the example fault policy.
./result/bin/rechaos serve \
  --upstream-host 127.0.0.1 --upstream-port 50090 \
  --port 50070 --policy examples/fault-policy.json \
  --record runs/chaos.jsonl
```

Point a build client at the gateway with the upstream's instance name, e.g.
`bazel build //... --remote_cache=grpc://127.0.0.1:50070 --remote_instance_name=main`.
See the [tutorial](../../docs/tutorial.md) for the full record / replay / oracle /
minimize loop.

## Point the chaos monkey at the gateway

[`scripts/chaos-monkey.py`](../../scripts/chaos-monkey.py) runs continuously
against a live endpoint — either the gateway (faulted proxy traffic) or a direct
endpoint (adversarial clients). Point `--host`/`--port` at the gateway's downstream
listener:

```sh
nix develop --command python3 scripts/chaos-monkey.py --host 127.0.0.1 --port 50070
nix develop --command python3 scripts/chaos-monkey.py --only-direct --stop-on-finding
nix develop --command python3 scripts/chaos-monkey.py --execution   # + scheduler stress
```

## Prometheus metrics port (required for `--execution`)

The scheduler queue-GC leak detectors that `--execution` enables scrape the
endpoint's Prometheus metrics; see invariant 7 ("Awaited-action store does not
leak") in [`docs/invariants.md`](../../docs/invariants.md). All three configs
enable `experimental_prometheus` on the server listener (`test-sched.json5` and
`local-rbe-worker.json5` set `path: "/metrics"`), so metrics are served on the
**same port** as the gRPC server. The chaos monkey scrapes metrics from
`--metrics-port`, which **defaults to `--port`** — correct when pointed directly at
the endpoint, but the gateway (`:50070`) does not proxy the HTTP metrics path. When
driving `--execution` through the gateway, set `--metrics-port` to the endpoint's
server port (`50090`) so the detectors can reach `/metrics`:

```sh
nix develop --command python3 scripts/chaos-monkey.py \
  --host 127.0.0.1 --port 50070 --execution --metrics-port 50090
```
