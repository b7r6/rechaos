#!/usr/bin/env python3
"""rechaos scale load generator + latency-regression oracle.

The chaos monkey and the consistency oracle answer *correctness* questions
("was this read torn?", "is this history linearizable?"). This module answers
the orthogonal *performance* question: under sustained high-concurrency REAPI
traffic, what are the per-operation latency percentiles, the achieved
throughput, and the error rate -- and have any of them *regressed* against a
committed baseline?

What it does
------------
* Drives a configurable REAPI/NativeLink endpoint (``--host/--port/--instance``)
  with N concurrent clients (``--clients``), each a worker thread owning its own
  gRPC channel so the server sees genuinely independent connections.
* The workload is a mix of three op types whose relative weights are
  configurable (``--read-weight/--write-weight/--fmb-weight``):

    - ``write``  ByteStream upload of a freshly generated blob,
    - ``read``   ByteStream read of a previously uploaded blob,
    - ``fmb``    ContentAddressableStorage.FindMissingBlobs probe.

  Blob sizes are drawn from a configurable distribution
  (``--size-min/--size-max/--size-dist``), so a single run can exercise both
  small-metadata and large-payload paths.
* Each op's wall-clock latency and outcome (ok / error) is recorded. At the end
  we compute, *per op type*, p50/p95/p99/max latency, mean, count, error count,
  error rate, and throughput (ops/s), plus run-wide aggregates.

Determinism
-----------
Each worker seeds its operation/size RNG with ``seed + worker_index``.
Fresh UUIDs, a shared successful-write pool, failures, and allocation of the
shared operation budget make the full stimulus timing-dependent. This is a
statistical load generator, not an exact workload replayer.

Regression oracle
-----------------
``--save-baseline FILE`` writes the run's metrics as JSON. ``--baseline FILE``
loads a committed baseline and compares the current run against it, flagging a
**regression** when, for any op type:

    - p50/p95/p99 latency grew by more than ``--latency-threshold`` (fractional,
      default 0.20 = 20%), OR
    - throughput dropped by more than ``--throughput-threshold`` (default 0.20),
      OR
    - the error rate rose by more than ``--error-threshold`` (absolute
      percentage-point delta, default 0.05 = 5pp).

A small *absolute* latency floor (``--latency-floor-ms``) suppresses noisy
percentage swings on sub-millisecond operations. The rubric is documented in
``docs/load-perf.md``. Exit code is non-zero when a regression is detected in
``--baseline`` mode, so this slots directly into CI.

Output
------
Human-readable table by default; ``--json`` emits the full metrics object (and,
in baseline mode, the comparison) as a single JSON document to stdout. ``--out
FILE`` additionally writes the metrics JSON to a file.

Everything is stdlib + ``grpc`` + the generated REAPI/ByteStream bindings
(resolved exactly like the other scripts in this repo), so it runs under
``nix develop`` with no extra dependencies.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import dataclasses
import hashlib
import json
import math
import pathlib
import random
import statistics
import sys
import threading
import time
import uuid
from typing import Dict, List, Optional, Tuple

# --------------------------------------------------------------------------- #
# Generated REAPI / ByteStream bindings (same resolution as the other scripts)
# --------------------------------------------------------------------------- #
def _import_reapi_bindings():
    """Locate the generated gRPC/proto bindings (either sys.path convention).

    Mirrors ``consistency_oracle._import_reapi_bindings`` so this script works
    both in a full checkout (``.build/python``) and in a worktree that only has
    the sibling ``test`` directory or a shared parent ``.build/python``.
    """
    root = pathlib.Path(__file__).resolve().parents[1]
    for cand in (root / ".build/python", root / "test"):
        if cand.exists():
            sys.path.insert(0, str(cand))
    for parent in root.parents:
        shared = parent / ".build/python"
        if shared.exists():
            sys.path.insert(0, str(shared))
            break
    import grpc  # noqa: E402
    from build.bazel.remote.execution.v2 import remote_execution_pb2 as re_pb  # noqa: E402
    from google.bytestream import bytestream_pb2 as bs_pb  # noqa: E402
    return grpc, re_pb, bs_pb


# --------------------------------------------------------------------------- #
# Op kinds
# --------------------------------------------------------------------------- #
READ = "read"
WRITE = "write"
FMB = "fmb"
OP_TYPES = (READ, WRITE, FMB)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
@dataclasses.dataclass
class LoadConfig:
    host: str = "127.0.0.1"
    port: int = 50052
    instance: str = "main"
    clients: int = 8
    duration: float = 3.0            # seconds; used unless op_count > 0
    op_count: int = 0                # total ops across all clients; 0 => use duration
    seed: int = 1234
    read_weight: float = 3.0
    write_weight: float = 1.0
    fmb_weight: float = 1.0
    size_min: int = 256
    size_max: int = 65536
    size_dist: str = "loguniform"    # "loguniform" | "uniform" | "fixed"
    timeout: float = 15.0
    warmup: int = 0                  # ops per client to run (untimed) before measuring

    def weights(self) -> Dict[str, float]:
        return {READ: self.read_weight, WRITE: self.write_weight, FMB: self.fmb_weight}


# --------------------------------------------------------------------------- #
# A single recorded sample
# --------------------------------------------------------------------------- #
@dataclasses.dataclass
class Sample:
    op: str
    latency: float          # seconds
    ok: bool
    size: int = 0
    error: Optional[str] = None


# --------------------------------------------------------------------------- #
# Workload planning (deterministic given the seed)
# --------------------------------------------------------------------------- #
def _choose_op(rng: random.Random, weights: Dict[str, float]) -> str:
    total = sum(weights.values())
    if total <= 0:
        return READ
    x = rng.random() * total
    acc = 0.0
    for op in OP_TYPES:
        acc += weights.get(op, 0.0)
        if x < acc:
            return op
    return OP_TYPES[-1]


def _choose_size(rng: random.Random, cfg: LoadConfig) -> int:
    lo, hi = cfg.size_min, cfg.size_max
    if hi <= lo or cfg.size_dist == "fixed":
        return lo
    if cfg.size_dist == "uniform":
        return rng.randint(lo, hi)
    # loguniform: emphasise the spread of magnitudes rather than raw bytes.
    log_lo, log_hi = math.log(max(lo, 1)), math.log(hi)
    return int(math.exp(rng.uniform(log_lo, log_hi)))


# --------------------------------------------------------------------------- #
# REAPI client wrapper (one per worker thread / one gRPC channel)
# --------------------------------------------------------------------------- #
class ReapiClient:
    """Thin per-worker REAPI/ByteStream client bound to one channel."""

    _CHUNK = 64 * 1024

    def __init__(self, grpc, re_pb, bs_pb, cfg: LoadConfig):
        self._grpc = grpc
        self._re = re_pb
        self._bs = bs_pb
        self.cfg = cfg
        self.pre = f"{cfg.instance}/" if cfg.instance else ""
        self.channel = grpc.insecure_channel(f"{cfg.host}:{cfg.port}")
        self._write = self.channel.stream_unary(
            "/google.bytestream.ByteStream/Write",
            request_serializer=bs_pb.WriteRequest.SerializeToString,
            response_deserializer=bs_pb.WriteResponse.FromString)
        self._read = self.channel.unary_stream(
            "/google.bytestream.ByteStream/Read",
            request_serializer=bs_pb.ReadRequest.SerializeToString,
            response_deserializer=bs_pb.ReadResponse.FromString)
        self._fmb = self.channel.unary_unary(
            "/build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs",
            request_serializer=re_pb.FindMissingBlobsRequest.SerializeToString,
            response_deserializer=re_pb.FindMissingBlobsResponse.FromString)

    def ready(self, timeout: float) -> None:
        self._grpc.channel_ready_future(self.channel).result(timeout=timeout)

    def close(self) -> None:
        self.channel.close()

    # -- operations: each returns (ok, bytes_transferred) or raises --------- #
    def write_blob(self, data: bytes) -> Tuple[str, int]:
        h, n = sha256_hex(data), len(data)
        name = f"{self.pre}uploads/{uuid.uuid4()}/blobs/{h}/{n}"

        def chunks():
            if n == 0:
                yield self._bs.WriteRequest(resource_name=name, write_offset=0,
                                            data=b"", finish_write=True)
                return
            off = 0
            while off < n:
                part = data[off:off + self._CHUNK]
                yield self._bs.WriteRequest(
                    resource_name=name if off == 0 else "",
                    write_offset=off, data=part,
                    finish_write=(off + len(part) == n))
                off += len(part)

        self._write(chunks(), timeout=self.cfg.timeout)
        return h, n

    def read_blob(self, h: str, n: int) -> int:
        name = f"{self.pre}blobs/{h}/{n}"
        got = 0
        for msg in self._read(self._bs.ReadRequest(resource_name=name),
                              timeout=self.cfg.timeout):
            got += len(msg.data)
        return got

    def find_missing(self, h: str, n: int) -> bool:
        resp = self._fmb(self._re.FindMissingBlobsRequest(
            instance_name=self.cfg.instance,
            digest_function=self._re.DigestFunction.SHA256,
            blob_digests=[self._re.Digest(hash=h, size_bytes=n)]),
            timeout=self.cfg.timeout)
        return any(d.hash == h for d in resp.missing_blob_digests)


# --------------------------------------------------------------------------- #
# Worker loop
# --------------------------------------------------------------------------- #
class _KnownBlobs:
    """Thread-safe pool of (hash, size) tuples that have been written.

    Reads draw from this so they target blobs that actually exist; before the
    pool is warm, a read falls back to writing first (counted as a write).
    """

    def __init__(self):
        self._items: List[Tuple[str, int]] = []
        self._lock = threading.Lock()

    def add(self, h: str, n: int) -> None:
        with self._lock:
            self._items.append((h, n))

    def pick(self, rng: random.Random) -> Optional[Tuple[str, int]]:
        with self._lock:
            if not self._items:
                return None
            return self._items[rng.randrange(len(self._items))]


def _run_worker(worker_index: int, client: ReapiClient, cfg: LoadConfig,
                known: _KnownBlobs, deadline: Optional[float],
                remaining_ops, samples_out: List[Sample],
                stop_flag: threading.Event) -> None:
    """Drive one client until the deadline or the shared op budget is spent."""
    rng = random.Random(cfg.seed + worker_index)
    weights = cfg.weights()
    local: List[Sample] = []

    def do_one(timed: bool) -> None:
        op = _choose_op(rng, weights)
        size = _choose_size(rng, cfg)
        t0 = time.perf_counter()
        ok, err, eff_op, bytes_n = True, None, op, size
        try:
            if op == WRITE:
                data = _make_blob(rng, size)
                h, n = client.write_blob(data)
                known.add(h, n)
                bytes_n = n
            elif op == READ:
                tgt = known.pick(rng)
                if tgt is None:
                    # pool cold: materialise a blob (counts as a write).
                    data = _make_blob(rng, size)
                    h, n = client.write_blob(data)
                    known.add(h, n)
                    eff_op, bytes_n = WRITE, n
                else:
                    h, n = tgt
                    client.read_blob(h, n)
                    bytes_n = n
            else:  # FMB
                tgt = known.pick(rng)
                if tgt is None:
                    data = _make_blob(rng, size)
                    h, n = data and sha256_hex(data), len(data)
                else:
                    h, n = tgt
                client.find_missing(h, n)
                bytes_n = n
        except Exception as exc:  # noqa: BLE001 -- any RPC failure is an op error
            ok, err = False, f"{type(exc).__name__}: {exc}"
        dt = time.perf_counter() - t0
        if timed:
            local.append(Sample(op=eff_op, latency=dt, ok=ok, size=bytes_n, error=err))

    # Untimed warmup.
    for _ in range(cfg.warmup):
        if stop_flag.is_set():
            break
        do_one(timed=False)

    while not stop_flag.is_set():
        if remaining_ops is not None:
            n = remaining_ops.take()
            if n <= 0:
                break
        elif deadline is not None and time.perf_counter() >= deadline:
            break
        do_one(timed=True)

    samples_out.extend(local)


class _OpBudget:
    """Shared, thread-safe countdown of the total op budget (op-count mode)."""

    def __init__(self, total: int):
        self._remaining = total
        self._lock = threading.Lock()

    def take(self) -> int:
        with self._lock:
            if self._remaining <= 0:
                return 0
            self._remaining -= 1
            return self._remaining + 1


def _make_blob(rng: random.Random, size: int) -> bytes:
    """Generate a fresh sampled blob of the requested size.

    Put random bytes first so tiny blobs do not all become the constant prefix
    of a textual label. Small payloads can still collide; uniqueness is not
    possible to guarantee over a finite byte domain.
    """
    token = uuid.uuid4().bytes
    if size <= len(token):
        return token[:max(size, 1)]
    body = bytes(rng.getrandbits(8) for _ in range(min(size - len(token), 4096)))
    if len(token) + len(body) < size:
        body = (body * (size // max(len(body), 1) + 1))[:size - len(token)]
    return token + body


# --------------------------------------------------------------------------- #
# Metrics
# --------------------------------------------------------------------------- #
def _percentile(sorted_vals: List[float], q: float) -> float:
    """Nearest-rank percentile on an already-sorted list (q in [0,1])."""
    if not sorted_vals:
        return 0.0
    if q <= 0:
        return sorted_vals[0]
    if q >= 1:
        return sorted_vals[-1]
    rank = math.ceil(q * len(sorted_vals))
    return sorted_vals[min(rank, len(sorted_vals)) - 1]


def _ms(x: float) -> float:
    return round(x * 1000.0, 3)


def summarize(samples: List[Sample], wall_seconds: float, cfg: LoadConfig) -> dict:
    """Compute per-op-type and aggregate metrics from raw samples."""
    by_op: Dict[str, List[Sample]] = {op: [] for op in OP_TYPES}
    for s in samples:
        by_op.setdefault(s.op, []).append(s)

    def op_metrics(group: List[Sample]) -> dict:
        count = len(group)
        errors = sum(1 for s in group if not s.ok)
        oks = [s.latency for s in group if s.ok]
        oks.sort()
        tput = round(count / wall_seconds, 3) if wall_seconds > 0 else 0.0
        bytes_total = sum(s.size for s in group if s.ok)
        return {
            "count": count,
            "errors": errors,
            "error_rate": round(errors / count, 6) if count else 0.0,
            "throughput_ops_s": tput,
            "bytes_total": bytes_total,
            "latency_ms": {
                "p50": _ms(_percentile(oks, 0.50)),
                "p95": _ms(_percentile(oks, 0.95)),
                "p99": _ms(_percentile(oks, 0.99)),
                "max": _ms(oks[-1]) if oks else 0.0,
                "mean": _ms(statistics.fmean(oks)) if oks else 0.0,
            },
        }

    total = len(samples)
    total_err = sum(1 for s in samples if not s.ok)
    all_ok = [s.latency for s in samples if s.ok]
    all_ok.sort()
    return {
        "schema": "rechaos.load-perf/v1",
        "config": {
            "host": cfg.host, "port": cfg.port, "instance": cfg.instance,
            "clients": cfg.clients, "duration": cfg.duration,
            "op_count": cfg.op_count, "seed": cfg.seed,
            "weights": cfg.weights(),
            "size_min": cfg.size_min, "size_max": cfg.size_max,
            "size_dist": cfg.size_dist, "warmup": cfg.warmup,
        },
        "wall_seconds": round(wall_seconds, 4),
        "aggregate": {
            "count": total,
            "errors": total_err,
            "error_rate": round(total_err / total, 6) if total else 0.0,
            "throughput_ops_s": round(total / wall_seconds, 3) if wall_seconds > 0 else 0.0,
            "latency_ms": {
                "p50": _ms(_percentile(all_ok, 0.50)),
                "p95": _ms(_percentile(all_ok, 0.95)),
                "p99": _ms(_percentile(all_ok, 0.99)),
                "max": _ms(all_ok[-1]) if all_ok else 0.0,
                "mean": _ms(statistics.fmean(all_ok)) if all_ok else 0.0,
            },
        },
        "by_op": {op: op_metrics(by_op.get(op, [])) for op in OP_TYPES},
    }


# --------------------------------------------------------------------------- #
# Load runner
# --------------------------------------------------------------------------- #
def run_load(cfg: LoadConfig) -> dict:
    """Execute the load and return the metrics summary."""
    grpc, re_pb, bs_pb = _import_reapi_bindings()

    clients = []
    for _ in range(cfg.clients):
        c = ReapiClient(grpc, re_pb, bs_pb, cfg)
        c.ready(timeout=cfg.timeout)
        clients.append(c)

    known = _KnownBlobs()
    stop_flag = threading.Event()
    budget = _OpBudget(cfg.op_count) if cfg.op_count > 0 else None
    per_worker: List[List[Sample]] = [[] for _ in range(cfg.clients)]

    start = time.perf_counter()
    deadline = None if budget is not None else start + cfg.duration

    with cf.ThreadPoolExecutor(max_workers=cfg.clients) as pool:
        futs = []
        for i in range(cfg.clients):
            futs.append(pool.submit(
                _run_worker, i, clients[i], cfg, known, deadline,
                budget, per_worker[i], stop_flag))
        try:
            for f in futs:
                f.result()
        except KeyboardInterrupt:
            stop_flag.set()
            for f in futs:
                f.result()
    wall = time.perf_counter() - start

    for c in clients:
        c.close()

    samples = [s for group in per_worker for s in group]
    return summarize(samples, wall, cfg)


# --------------------------------------------------------------------------- #
# Regression oracle
# --------------------------------------------------------------------------- #
@dataclasses.dataclass
class Regression:
    op: str
    metric: str
    baseline: float
    current: float
    delta: float          # fractional for latency/throughput, absolute for error_rate
    threshold: float
    message: str

    def to_json(self) -> dict:
        return dataclasses.asdict(self)

    def __str__(self) -> str:
        return f"[REGRESSION] {self.op}.{self.metric}: {self.message}"


def compare_to_baseline(baseline: dict, current: dict,
                        latency_threshold: float = 0.20,
                        throughput_threshold: float = 0.20,
                        error_threshold: float = 0.05,
                        latency_floor_ms: float = 1.0) -> List[Regression]:
    """Compare a current run against a baseline; return the list of regressions.

    Latency/throughput deltas are *fractional* relative to the baseline; error
    rate is an *absolute* percentage-point delta. Latencies below the floor are
    exempt from the fractional check (sub-ms jitter should not trip CI).
    """
    regs: List[Regression] = []

    def frac_delta(base: float, cur: float) -> float:
        if base <= 0:
            return 0.0 if cur <= 0 else float("inf")
        return (cur - base) / base

    scopes = [("aggregate", baseline.get("aggregate", {}), current.get("aggregate", {}))]
    for op in OP_TYPES:
        scopes.append((op, baseline.get("by_op", {}).get(op, {}),
                       current.get("by_op", {}).get(op, {})))

    for name, base, cur in scopes:
        if not base or not cur:
            continue
        # Latency percentiles.
        b_lat = base.get("latency_ms", {})
        c_lat = cur.get("latency_ms", {})
        for pct in ("p50", "p95", "p99"):
            bv, cvv = b_lat.get(pct, 0.0), c_lat.get(pct, 0.0)
            if bv < latency_floor_ms and cvv < latency_floor_ms:
                continue
            d = frac_delta(bv, cvv)
            if d > latency_threshold:
                regs.append(Regression(
                    op=name, metric=f"latency_ms.{pct}",
                    baseline=bv, current=cvv, delta=round(d, 4),
                    threshold=latency_threshold,
                    message=f"{pct} latency {bv}ms -> {cvv}ms (+{d*100:.1f}% > "
                            f"{latency_threshold*100:.0f}%)"))
        # Throughput (a DROP is bad).
        bt, ct = base.get("throughput_ops_s", 0.0), cur.get("throughput_ops_s", 0.0)
        if bt > 0:
            drop = (bt - ct) / bt
            if drop > throughput_threshold:
                regs.append(Regression(
                    op=name, metric="throughput_ops_s",
                    baseline=bt, current=ct, delta=round(-drop, 4),
                    threshold=throughput_threshold,
                    message=f"throughput {bt} -> {ct} ops/s (-{drop*100:.1f}% > "
                            f"{throughput_threshold*100:.0f}%)"))
        # Error rate (an absolute rise is bad).
        be, ce = base.get("error_rate", 0.0), cur.get("error_rate", 0.0)
        if ce - be > error_threshold:
            regs.append(Regression(
                op=name, metric="error_rate",
                baseline=be, current=ce, delta=round(ce - be, 6),
                threshold=error_threshold,
                message=f"error rate {be:.4f} -> {ce:.4f} (+{(ce-be)*100:.2f}pp > "
                        f"{error_threshold*100:.1f}pp)"))
    return regs


# --------------------------------------------------------------------------- #
# Human-readable rendering
# --------------------------------------------------------------------------- #
def render_human(metrics: dict) -> str:
    lines = []
    cfg = metrics["config"]
    lines.append(f"rechaos load-perf  target={cfg['host']}:{cfg['port']} "
                 f"instance={cfg['instance']!r} clients={cfg['clients']} "
                 f"seed={cfg['seed']}")
    mode = (f"op_count={cfg['op_count']}" if cfg["op_count"] > 0
            else f"duration={cfg['duration']}s")
    lines.append(f"  mode={mode}  wall={metrics['wall_seconds']}s  "
                 f"size={cfg['size_min']}..{cfg['size_max']}B ({cfg['size_dist']})  "
                 f"weights={cfg['weights']}")
    header = (f"  {'op':<10}{'count':>8}{'err':>6}{'err%':>8}"
              f"{'tput/s':>11}{'p50ms':>10}{'p95ms':>10}{'p99ms':>10}{'maxms':>10}")
    lines.append(header)
    lines.append("  " + "-" * (len(header) - 2))

    def row(name: str, m: dict) -> str:
        lat = m["latency_ms"]
        return (f"  {name:<10}{m['count']:>8}{m['errors']:>6}"
                f"{m['error_rate']*100:>7.2f}%{m['throughput_ops_s']:>11}"
                f"{lat['p50']:>10}{lat['p95']:>10}{lat['p99']:>10}{lat['max']:>10}")

    for op in OP_TYPES:
        lines.append(row(op, metrics["by_op"][op]))
    lines.append("  " + "-" * (len(header) - 2))
    lines.append(row("TOTAL", metrics["aggregate"]))
    return "\n".join(lines)


def render_regressions(regs: List[Regression]) -> str:
    if not regs:
        return "regression check: PASS (no latency/throughput/error regression)"
    out = [f"regression check: FAIL ({len(regs)} regression(s))"]
    out.extend("  " + str(r) for r in regs)
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="load_gen.py",
        description="Scale REAPI load generator + latency-regression oracle.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    tgt = p.add_argument_group("target")
    tgt.add_argument("--host", default="127.0.0.1")
    tgt.add_argument("--port", type=int, default=50052)
    tgt.add_argument("--instance", default="main",
                     help="REAPI instance name ('' for the default instance)")

    load = p.add_argument_group("load")
    load.add_argument("--clients", type=int, default=8,
                      help="number of concurrent client connections/workers")
    load.add_argument("--duration", type=float, default=3.0,
                      help="seconds of measured load (ignored if --op-count > 0)")
    load.add_argument("--op-count", type=int, default=0,
                      help="total measured ops across all clients (0 => use --duration)")
    load.add_argument("--warmup", type=int, default=0,
                      help="untimed ops per client before measurement begins")
    load.add_argument("--seed", type=int, default=1234,
                      help="RNG seed for per-worker operation and size draws")
    load.add_argument("--timeout", type=float, default=15.0,
                      help="per-RPC timeout (seconds)")

    mix = p.add_argument_group("workload mix")
    mix.add_argument("--read-weight", type=float, default=3.0)
    mix.add_argument("--write-weight", type=float, default=1.0)
    mix.add_argument("--fmb-weight", type=float, default=1.0,
                     help="FindMissingBlobs weight")
    mix.add_argument("--size-min", type=int, default=256, help="min blob size (bytes)")
    mix.add_argument("--size-max", type=int, default=65536, help="max blob size (bytes)")
    mix.add_argument("--size-dist", choices=("loguniform", "uniform", "fixed"),
                     default="loguniform", help="blob-size distribution")

    out = p.add_argument_group("output")
    out.add_argument("--json", action="store_true",
                     help="emit metrics (and comparison) as JSON to stdout")
    out.add_argument("--out", metavar="FILE",
                     help="also write the metrics JSON to FILE")

    reg = p.add_argument_group("regression oracle")
    reg.add_argument("--save-baseline", metavar="FILE",
                     help="write this run's metrics as a baseline JSON file")
    reg.add_argument("--baseline", metavar="FILE",
                     help="compare this run against a committed baseline JSON file")
    reg.add_argument("--latency-threshold", type=float, default=0.20,
                     help="fractional p50/p95/p99 growth that counts as a regression")
    reg.add_argument("--throughput-threshold", type=float, default=0.20,
                     help="fractional throughput drop that counts as a regression")
    reg.add_argument("--error-threshold", type=float, default=0.05,
                     help="absolute error-rate rise (fraction) that counts as a regression")
    reg.add_argument("--latency-floor-ms", type=float, default=1.0,
                     help="latencies below this (ms) are exempt from the fractional check")
    return p


def cfg_from_args(args) -> LoadConfig:
    return LoadConfig(
        host=args.host, port=args.port, instance=args.instance,
        clients=args.clients, duration=args.duration, op_count=args.op_count,
        seed=args.seed, read_weight=args.read_weight, write_weight=args.write_weight,
        fmb_weight=args.fmb_weight, size_min=args.size_min, size_max=args.size_max,
        size_dist=args.size_dist, timeout=args.timeout, warmup=args.warmup)


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    cfg = cfg_from_args(args)

    metrics = run_load(cfg)

    comparison = None
    regs: List[Regression] = []
    if args.baseline:
        with open(args.baseline, "r", encoding="utf-8") as fh:
            baseline = json.load(fh)
        regs = compare_to_baseline(
            baseline, metrics,
            latency_threshold=args.latency_threshold,
            throughput_threshold=args.throughput_threshold,
            error_threshold=args.error_threshold,
            latency_floor_ms=args.latency_floor_ms)
        comparison = {
            "baseline_file": args.baseline,
            "thresholds": {
                "latency": args.latency_threshold,
                "throughput": args.throughput_threshold,
                "error": args.error_threshold,
                "latency_floor_ms": args.latency_floor_ms,
            },
            "regressions": [r.to_json() for r in regs],
            "passed": not regs,
        }

    if args.save_baseline:
        with open(args.save_baseline, "w", encoding="utf-8") as fh:
            json.dump(metrics, fh, indent=2, sort_keys=True)
            fh.write("\n")

    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(metrics, fh, indent=2, sort_keys=True)
            fh.write("\n")

    if args.json:
        doc = dict(metrics)
        if comparison is not None:
            doc["comparison"] = comparison
        json.dump(doc, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        print(render_human(metrics))
        if args.save_baseline:
            print(f"baseline saved -> {args.save_baseline}")
        if comparison is not None:
            print(render_regressions(regs))

    return 1 if regs else 0


if __name__ == "__main__":
    sys.exit(main())
