#!/usr/bin/env python3
"""rechaos chaos monkey: continuous randomized REAPI fault campaigns.

Runs forever against a live REAPI/NativeLink endpoint. Each iteration draws a
fresh seed, then either (a) generates a randomized fault policy and drives
traffic through the `rechaos serve` gateway, or (b) runs a randomized hostile
direct client. Every result is checked against a fixed set of correctness and
liveness invariants. Violations are deduplicated by signature, printed, and
frozen as evidence (policy + gateway timeline when available for proxy findings;
scenario evidence for direct findings). Reproduction still requires matching
workload and backend conditions.

Nothing here edits server configuration or restarts the server. It only speaks
REAPI. Blobs depend on the master seed, run id, label, and size; retain all of those
to reconstruct content.

Two feedback loops extend the random generator. Their results depend on
observed server responses and metrics as well as the seed:

  * FEEDBACK-GUIDED generation (--feedback, default on). After each iteration we
    scrape Prometheus /metrics, compute which metric families moved and bucket
    the deltas, and fold that together with the RPC outcome and any finding
    signatures into a coverage signature. A memory of seen (fault-kind, method,
    direction, outcome/metric-bucket) signatures drives a novelty-seeking bias:
    the mode/op/fault choices that have historically produced NEW signatures get
    up-weighted, while a floor of uniform exploration is always retained. Pass
    --no-feedback to restore the original uniform-random policy.

  * RESOURCE-LEAK SOAK (--soak). Generalizes the scheduler rising-floor detector
    to EVERY scrapable numeric gauge (plus process RSS/FD when reachable). Over a
    long run it tracks each signal against a windowed baseline, normalizes for
    offered load, and flags sustained rising-floor patterns as leak candidates, emitting
    the offending metric and its growth evidence as a finding.

    nix develop --command python3 scripts/chaos-monkey.py --host 127.0.0.1 --port 50052
    nix develop --command python3 scripts/chaos-monkey.py --iterations 200 --seed 1
    nix develop --command python3 scripts/chaos-monkey.py --only-direct --stop-on-finding
    nix develop --command python3 scripts/chaos-monkey.py --no-feedback --iterations 50
    nix develop --command python3 scripts/chaos-monkey.py --soak --minutes 30

See docs/feedback-soak.md for the design and the signatures each mode emits.
"""
import argparse
import collections
import concurrent.futures as cf
import hashlib
import importlib.util
import json
import pathlib
import random
import re as rx
import signal
import sys
import time
import traceback
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test"))
from integration import proxy, rule, READ, WRITE, MISSING  # noqa: E402
from integration import re as reapi, bs, grpc  # noqa: E402  proto modules + grpc
from google.longrunning import operations_pb2 as oplr  # noqa: E402

EXECUTE = "build.bazel.remote.execution.v2.Execution/Execute"
WAIT_EXECUTION = "build.bazel.remote.execution.v2.Execution/WaitExecution"
CAPABILITIES = "build.bazel.remote.execution.v2.Capabilities/GetCapabilities"
BS_WRITE = "google.bytestream.ByteStream/Write"
STAGE = {0: "UNKNOWN", 1: "CACHE_CHECK", 2: "QUEUED", 3: "EXECUTING", 4: "COMPLETED"}

# Reuse the adversarial Endpoint/Blob primitives from the stress harness.
_spec = importlib.util.spec_from_file_location("fleet_stress", ROOT / "scripts" / "fleet-stress.py")
_fleet = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_fleet)
Endpoint, Blob = _fleet.Endpoint, _fleet.Blob

CHUNK = 65536
STATUSES = ["Cancelled", "InvalidArgument", "DeadlineExceeded", "NotFound", "ResourceExhausted",
            "FailedPrecondition", "Internal", "Unavailable", "DataLoss"]
METHODS = [READ, WRITE, MISSING]
# Sizes span the chunking boundaries that have historically mattered, plus a
# bounded tail. Capped at 4 MiB to limit object-store write-back volume.
SIZES = [0, 1, 17, 4095, 4096, 4097, 65535, 65536, 65537, 131072, 1048576, 4194304]


# --------------------------------------------------------------------------- #
# Randomized policy generation (valid per Shell/Json.hs, else serve rejects).
# --------------------------------------------------------------------------- #
def gen_fault(rng, method, direction):
    kinds = ["delay", "abort", "dribble"]
    # truncate is only valid on Read/response or Write/request.
    if (method == READ and direction == "response") or (method == WRITE and direction == "request"):
        kinds.append("truncate")
    kind = rng.choice(kinds)
    if kind == "delay":
        return {"kind": "delay", "micros": rng.choice([1000, 50000, 250000, 900000, 2000000, 5000000])}
    if kind == "abort":
        return {"kind": "abort", "status": rng.choice(STATUSES)}
    if kind == "dribble":
        chunk = rng.choice([256, 1024, 4096, 16384, 65536])
        return {"kind": "dribble", "bytesPerSecond": rng.choice([4096, 65536, 262144, 1048576]), "chunkBytes": chunk}
    return {"kind": "truncate", "keepBytes": rng.choice([0, 1, 7, 17, 4096, 65536, 131072])}


def gen_rule(rng, method=None):
    method = method or rng.choice(METHODS)
    direction = rng.choice(["request", "response"])
    fault = gen_fault(rng, method, direction)
    target = {}
    if rng.random() < 0.5:
        target["occurrence"] = rng.randint(1, 3)
    if rng.random() < 0.4 and direction == "response" and method == READ:
        target["messageIndex"] = rng.randint(1, 4)
    if rng.random() < 0.3:
        lo = rng.choice([0, 4096, 65536])
        target["minBlobBytes"] = lo
        if rng.random() < 0.5:
            target["maxBlobBytes"] = lo + rng.choice([65536, 1048576, 8388608])
    if rng.random() < 0.3:
        target["afterMicros"] = rng.choice([0, 1000, 100000])
    r = rule(method, direction, fault, **target)
    if rng.random() < 0.3:
        r["chancePpm"] = rng.choice([250000, 500000, 750000])
    return r


def gen_policy(rng):
    return [gen_rule(rng) for _ in range(rng.randint(1, 3))]


# --------------------------------------------------------------------------- #
# Prometheus text parsing
# --------------------------------------------------------------------------- #
_METRIC_LINE = rx.compile(r"^([A-Za-z_:][A-Za-z0-9_:]*(?:\{[^}]*\})?)\s+([-+0-9.eE]+|NaN|[-+]?Inf)\s*$")


def parse_metrics(text):
    """Parse a Prometheus text exposition into {series_name: float}.

    Series name includes any {labels}. HELP/TYPE/comment lines are skipped, as are
    NaN/Inf samples (they can't participate in a monotone-growth comparison)."""
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = _METRIC_LINE.match(line)
        if not m:
            continue
        name, raw = m.group(1), m.group(2)
        try:
            val = float(raw)
        except ValueError:
            continue
        if val != val or val in (float("inf"), float("-inf")):  # NaN / Inf
            continue
        out[name] = val
    return out


def family_of(series):
    """Strip {labels} and a trailing numeric/hex shard suffix so that sibling
    per-shard or per-operation series collapse to one coverage family. This keeps
    the novelty signature from exploding into one bucket per random operation id."""
    base = series.split("{", 1)[0]
    # Collapse hex-uuid-ish and pure-numeric trailing shards to a wildcard.
    base = rx.sub(r"_[0-9a-f]{8}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{12}$", "_*", base)
    base = rx.sub(r"_[0-9]+$", "_*", base)
    return base


def _fold_families(metrics):
    """Sum per-family so sibling series (per-shard, per-op) collapse to one value.
    Used only for the coverage signature, which cares about which FAMILY moved, not
    which individual operation id did."""
    fam = collections.defaultdict(float)
    for name, val in metrics.items():
        fam[family_of(name)] += val
    return fam


def delta_bucket(before, after):
    """Coarse log-ish bucket for a per-family movement, sign-aware. Buckets keep the
    coverage alphabet small and stable across runs (noise in the last digits of a
    gauge does not mint a brand-new signature every iteration)."""
    d = after - before
    if d == 0:
        return "0"
    sign = "+" if d > 0 else "-"
    a = abs(d)
    if a < 1:
        mag = "f"      # fractional
    elif a < 10:
        mag = "1"
    elif a < 100:
        mag = "2"
    elif a < 1e4:
        mag = "3"
    elif a < 1e6:
        mag = "4"
    else:
        mag = "5"
    return sign + mag


# --------------------------------------------------------------------------- #
# Feedback-guided generation: novelty memory + biased sampler
# --------------------------------------------------------------------------- #
class Feedback:
    """Tracks coverage signatures seen so far and biases discrete choices toward
    buckets that have recently produced NEW signatures (novelty-seeking), while
    always retaining a uniform exploration floor. Fully reproducible: every random
    draw comes from a caller-supplied seeded RNG, never from global state."""

    def __init__(self, enabled, explore_floor=0.25, decay=0.9):
        self.enabled = enabled
        self.explore_floor = explore_floor
        self.decay = decay
        self.signatures = set()              # coverage signatures ever observed
        self.novel_total = 0                 # count of iterations that minted >=1 new signature
        # reward[dimension][choice] -> running novelty reward (decayed)
        self.reward = collections.defaultdict(lambda: collections.defaultdict(float))
        self.tries = collections.defaultdict(lambda: collections.Counter())

    # -- choice interface -------------------------------------------------- #
    def choose(self, rng, dimension, options):
        """Pick one of `options` for `dimension`. With feedback off this is a plain
        uniform choice, so --no-feedback reproduces the original behavior exactly."""
        if not self.enabled or len(options) <= 1:
            return rng.choice(list(options))
        options = list(options)
        # epsilon-greedy with a reward-weighted body; unseen options get an
        # optimistic prior so everything is tried before exploitation kicks in.
        if rng.random() < self.explore_floor:
            return rng.choice(options)
        rtab = self.reward[dimension]
        ttab = self.tries[dimension]
        weights = []
        for o in options:
            seen = ttab.get(o, 0)
            prior = 1.0 if seen == 0 else 0.0   # optimistic: never-tried gets a boost
            weights.append(rtab.get(o, 0.0) + prior + 0.05)  # 0.05 keeps all > 0
        total = sum(weights)
        pick = rng.random() * total
        upto = 0.0
        for o, w in zip(options, weights):
            upto += w
            if pick <= upto:
                return o
        return options[-1]

    # -- learning ---------------------------------------------------------- #
    def record(self, choices, coverage_sig):
        """After an iteration, register its coverage signature and credit every
        discrete choice that led there if the signature was new."""
        novel = coverage_sig not in self.signatures
        if novel:
            self.signatures.add(coverage_sig)
            self.novel_total += 1
        for dimension, choice in choices.items():
            self.tries[dimension][choice] += 1
            tab = self.reward[dimension]
            # Decay all rewards for this dimension so stale wins fade.
            for k in list(tab.keys()):
                tab[k] *= self.decay
            if novel:
                tab[choice] += 1.0
        return novel

    def snapshot(self):
        return {"unique_coverage_signatures": len(self.signatures),
                "novel_iterations": self.novel_total,
                "reward": {d: dict(t) for d, t in self.reward.items()},
                "tries": {d: dict(c) for d, c in self.tries.items()}}


# --------------------------------------------------------------------------- #
# Resource-leak soak: generalized rising-floor detector over all numeric signals
# --------------------------------------------------------------------------- #
class SoakTracker:
    """Tracks every numeric scrapable signal across the run and flags any that grow
    without bound. Generalizes the scheduler rising-floor detector: for each signal
    we compare the MINIMUM (floor) over an older window against the floor over the
    most recent window. A persistently rising floor means the signal never returns
    to its earlier low even when load ebbs, i.e. it accumulates — the leak shape.

    To avoid flagging legitimately load-driven gauges, a signal is only a candidate
    when its floor rises in BOTH of the last two window transitions (monotone-ish)
    and the rise exceeds a relative threshold. Config knobs (max_bytes, *_last_time
    timestamps, weights) are excluded by name."""

    # Series whose growth is expected or meaningless for leak detection.
    _IGNORE = rx.compile(
        r"(_max_bytes|_max_count|_max_seconds|_last_time|_weight|_block_size|"
        r"_read_buffer_size|lifetime_inserted|_downloaded_bytes|_uploaded_bytes|"
        r"consider_expired_after_s|max_retry_buffer|multipart_max_concurrent)$")

    def __init__(self, window, rel_threshold, abs_threshold, min_samples):
        self.window = window
        self.rel_threshold = rel_threshold
        self.abs_threshold = abs_threshold
        self.min_samples = min_samples
        self.series = collections.defaultdict(list)   # name -> [values]
        self.load = []                                # offered-load proxy per sample
        self.samples = 0

    def observe(self, metrics, load):
        """metrics: {name: float}. load: a scalar proxy for offered load this sample
        (e.g. cumulative iterations), used to normalize growth against work done."""
        self.samples += 1
        self.load.append(load)
        seen = set()
        for name, val in metrics.items():
            if self._IGNORE.search(name):
                continue
            self.series[name].append(val)
            seen.add(name)
        # Keep ragged series aligned: carry-forward last value for any that vanished.
        for name, vals in self.series.items():
            if name not in seen and vals:
                vals.append(vals[-1])

    def _floor(self, vals, lo, hi):
        window = vals[lo:hi]
        return min(window) if window else None

    def findings(self):
        """Return a list of leak candidates: dicts with metric + growth evidence.
        Called at the end (and optionally mid-run) of a soak campaign."""
        w = self.window
        out = []
        if self.samples < 3 * w:
            return out
        n = self.samples
        for name, vals in self.series.items():
            if len(vals) < 3 * w:
                continue
            f_old = self._floor(vals, n - 3 * w, n - 2 * w)
            f_mid = self._floor(vals, n - 2 * w, n - w)
            f_new = self._floor(vals, n - w, n)
            if None in (f_old, f_mid, f_new):
                continue
            # Monotone-ish rising floor across two consecutive window transitions.
            if not (f_new > f_mid >= f_old):
                continue
            rise = f_new - f_old
            if rise < self.abs_threshold:
                continue
            base = abs(f_old) if f_old != 0 else 1.0
            rel = rise / base
            if f_old != 0 and rel < self.rel_threshold:
                continue
            # Normalize against offered load: a signal that scales with load but then
            # does not recede is still a candidate; we report the per-load slope so a
            # human can judge. (Load is monotone, so this is descriptive, not a gate.)
            load_delta = (self.load[-1] - self.load[max(0, n - 3 * w)]) if self.load else 0
            out.append({
                "metric": name,
                "floor_window_old": f_old,
                "floor_window_mid": f_mid,
                "floor_window_now": f_new,
                "absolute_rise": rise,
                "relative_rise": round(rel, 4),
                "load_delta_over_windows": load_delta,
                "rise_per_unit_load": round(rise / load_delta, 6) if load_delta else None,
                "samples": len(vals),
                "window": w,
            })
        out.sort(key=lambda d: d["relative_rise"], reverse=True)
        return out


# --------------------------------------------------------------------------- #
# Monkey
# --------------------------------------------------------------------------- #
class Monkey:
    def __init__(self, args):
        self.args = args
        self.run_id = args.run_id
        self.seed = args.seed
        self.instance = args.instance
        self.out = (ROOT / args.output / self.run_id).resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        self.corpus = self.out / "corpus"
        self.corpus.mkdir(exist_ok=True)
        self.findings_log = (self.out / "findings.jsonl").open("a", buffering=1)
        self.iter_log = (self.out / "iterations.jsonl").open("a", buffering=1)
        self.sched_log = (self.out / "scheduler-series.jsonl").open("a", buffering=1)
        self.seen = collections.Counter()      # signature -> times seen
        self.finding_total = 0
        self.iteration = 0
        self.started = time.monotonic()
        self.stop = False
        self.direct = Endpoint(f"{args.host}:{args.port}")
        self.metrics_baseline = self._scrape_metrics()
        self.health = self._make_blob("health", 65537)
        self._ensure_present("startup", self.health)
        self._exec = None
        self._sched_series = []
        self._store_rx = rx.compile(args.store_metric)
        self._active_rx = rx.compile(args.active_metric)
        # Feedback-guided generation: one novelty memory for the whole run, driven
        # by a seeded RNG; identical choices also require identical feedback history.
        self.feedback = Feedback(enabled=args.feedback, explore_floor=args.explore_floor)
        self._feedback_rng = random.Random(f"{self.seed}:feedback")
        self._prev_metrics = self._parse_metrics()   # baseline family values for deltas
        self.feedback_log = (self.out / "feedback.jsonl").open("a", buffering=1)
        # Resource-leak soak: lazily used only when --soak is set, but always
        # constructed so the end-of-run report is uniform.
        self.soak = SoakTracker(window=args.soak_window, rel_threshold=args.soak_rel_threshold,
                                abs_threshold=args.soak_abs_threshold, min_samples=args.soak_window)
        self.soak_log = (self.out / "soak-series.jsonl").open("a", buffering=1)
        self._soak_flagged = set()                    # metric names already reported this run
        manifest = {**vars(args), "metrics_reachable": self.metrics_baseline is not None}
        (self.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    # ---- infrastructure -------------------------------------------------- #
    def _make_blob(self, label, size):
        return Blob(label, size, self.seed, self.run_id, self.instance)

    def _scrape_metrics(self):
        try:
            return len(urllib.request.urlopen(
                f"http://{self.args.host}:{self.args.port}/metrics", timeout=3).read())
        except Exception:
            return None

    def _metrics_text(self):
        """Raw Prometheus exposition text from the metrics port, or None."""
        try:
            return urllib.request.urlopen(
                f"http://{self.args.host}:{self.args.metrics_port}/metrics", timeout=3).read().decode()
        except Exception:
            return None

    def _parse_metrics(self):
        """{series_name: float} for every numeric gauge, or {} if unreachable."""
        text = self._metrics_text()
        return parse_metrics(text) if text is not None else {}

    def _process_signals(self):
        """Best-effort process RSS/FD for the target, by name convention only — we
        never assume a PID or path. Tries (1) a Prometheus process_* exporter if the
        server exposes one, (2) /proc for a co-located server when --proc-pid is set.
        Returns a dict of extra numeric signals to fold into the soak tracker; empty
        when nothing is reachable (documented, not silently faked)."""
        extra = {}
        # (1) Prometheus process collector, if present in the already-parsed scrape.
        #     Handled by the caller via the normal metric dict; nothing to add here.
        # (2) Explicit, opt-in /proc inspection of a co-located server PID.
        pid = self.args.proc_pid
        if pid:
            try:
                with open(f"/proc/{pid}/status") as fh:
                    for line in fh:
                        if line.startswith("VmRSS:"):
                            extra["process_resident_memory_kb"] = float(line.split()[1])
                            break
                extra["process_open_fds"] = float(len(__import__("os").listdir(f"/proc/{pid}/fd")))
            except Exception:
                pass
        return extra

    def _ensure_present(self, phase, blob):
        w = self.direct.write(blob)
        if w["status"] != "OK" or w.get("committedBytes") != blob.size:
            raise RuntimeError(f"setup upload failed for {blob.label}: {w}")

    def finding(self, signature, kind, evidence, repro_dir=None):
        self.seen[signature] += 1
        self.finding_total += 1
        first = self.seen[signature] == 1
        item = {"iteration": self.iteration, "signature": signature, "kind": kind,
                "first": first, "seen": self.seen[signature], "evidence": evidence}
        self.findings_log.write(json.dumps(item, separators=(",", ":")) + "\n")
        tag = "NEW " if first else "dup "
        print(f"  !! FINDING [{tag}{self.seen[signature]:>3}x] {signature} :: {kind}", flush=True)
        if first:
            dest = self.corpus / _slug(signature)
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "finding.json").write_text(json.dumps(item, indent=2) + "\n")
            # Freeze the proxy reproducer (policy + recorded timeline) if present.
            if repro_dir is not None:
                for name in ("policy.json", "timeline.jsonl", "timeline.jsonl.outcomes.jsonl"):
                    src = pathlib.Path(repro_dir) / name
                    if src.exists():
                        (dest / name).write_bytes(src.read_bytes())
        return item

    # ---- invariant checks ------------------------------------------------ #
    def check_read_integrity(self, phase, endpoint, blob, repro=None, **kw):
        """A Read that ends OK must return bytes matching the requested digest."""
        r = endpoint.read(blob, **kw)
        if r["status"] == "OK" and r.get("matches") is False:
            self.finding(f"torn-read:{phase}", "OK Read returned bytes not matching the requested digest",
                         {"blob": blob.descriptor(), "read": r}, repro)
        return r

    def check_absent(self, phase, blob, signature_tag):
        """A partial/aborted upload must not leave a blob whose stored bytes do
        not match its digest. (A fully-written blob is legitimately present in a
        content-addressed store even if the client's upload ack was lost, so we
        flag only genuine content mismatch, not mere presence.)"""
        rd = self.direct.read(blob, timeout=4)
        corrupt = rd["status"] == "OK" and rd.get("matches") is False
        if corrupt:
            self.finding(f"incomplete-upload-readable:{signature_tag}",
                         "a blob is readable under its digest but its bytes do not match that digest",
                         {"blob": blob.descriptor(), "read": rd})
        fmb = self.direct.missing([blob], self.instance, timeout=4)
        if corrupt and fmb["status"] == "OK" and not fmb["missing"]:
            self.finding(f"fmb-present-phantom:{signature_tag}",
                         "FindMissingBlobs reports a digest present whose stored bytes do not match it",
                         {"blob": blob.descriptor(), "fmb": fmb})

    def check_committed(self, phase, blob, w):
        if w["status"] == "OK" and w.get("committedBytes") not in (None, blob.size):
            self.finding("wrong-committed-size", "successful Write reported committed_size != advertised size",
                         {"blob": blob.descriptor(), "write": w})

    def check_query_sane(self, phase, blob, writer, uploaded):
        q = self.direct.query(blob, writer, timeout=4)
        if q["status"] == "OK":
            c = q["committedBytes"]
            if c > uploaded:
                self.finding("query-overcount", "QueryWriteStatus committed_size exceeds bytes actually sent",
                             {"blob": blob.descriptor(), "uploaded": uploaded, "query": q})
            if q["complete"] and uploaded != blob.size:
                self.finding("query-false-complete", "QueryWriteStatus reports complete for an incomplete upload",
                             {"blob": blob.descriptor(), "uploaded": uploaded, "query": q})
        return q

    def recovery(self, phase):
        """A known-good blob must round-trip OK within deadline every iteration."""
        r = self.direct.read(self.health, timeout=5)
        if r["status"] != "OK" or not r.get("matches"):
            self.finding("recovery-failed", "known-good health blob failed to read cleanly after fault",
                         {"phase": phase, "read": r})
            return False
        if self.metrics_baseline is not None and self._scrape_metrics() is None:
            self.finding("endpoint-metrics-unreachable",
                         "Prometheus endpoint stopped responding (possible crash/hang)", {"phase": phase})
            return False
        return True

    # ---- execution / scheduler stress ----------------------------------- #
    def _exec_stubs(self):
        if self._exec is None:
            ch = self.direct.channel
            self._exec = {
                "execute": ch.unary_stream("/" + EXECUTE,
                    request_serializer=reapi.ExecuteRequest.SerializeToString,
                    response_deserializer=oplr.Operation.FromString),
                "wait": ch.unary_stream("/" + WAIT_EXECUTION,
                    request_serializer=reapi.WaitExecutionRequest.SerializeToString,
                    response_deserializer=oplr.Operation.FromString),
                "write": ch.stream_unary("/" + BS_WRITE,
                    request_serializer=bs.WriteRequest.SerializeToString,
                    response_deserializer=bs.WriteResponse.FromString),
            }
        return self._exec

    def _upload_raw(self, data):
        """Upload arbitrary bytes to CAS, return a reapi.Digest."""
        h = hashlib.sha256(data).hexdigest()
        name = f"{self.instance}/uploads/{uuid.uuid4()}/blobs/{h}/{len(data)}"
        req = bs.WriteRequest(resource_name=name, write_offset=0, data=data, finish_write=True)
        self._exec_stubs()["write"](iter([req]), timeout=8)
        return reapi.Digest(hash=h, size_bytes=len(data))

    def _build_action(self, rng, salt, do_not_cache):
        """Upload a trivial Command + empty input root + Action; return Action digest."""
        plat = reapi.Platform(properties=[
            reapi.Platform.Property(name="OSFamily", value="linux"),
            reapi.Platform.Property(name="cpu_arch", value="x86_64")])
        cmd = reapi.Command(arguments=["/bin/true"], platform=plat)
        cmd_d = self._upload_raw(cmd.SerializeToString())
        root_d = self._upload_raw(reapi.Directory().SerializeToString())
        action = reapi.Action(command_digest=cmd_d, input_root_digest=root_d,
                              do_not_cache=do_not_cache, salt=salt, platform=plat)
        return self._upload_raw(action.SerializeToString())

    def _execute(self, action_digest, cancel_after=None, timeout=8, skip_cache=True):
        """Drive one Execute RPC; optionally cancel after N operations. Returns
        (status, last_stage, op_name)."""
        stub = self._exec_stubs()["execute"]
        req = reapi.ExecuteRequest(instance_name=self.instance, action_digest=action_digest,
                                   skip_cache_lookup=skip_cache,
                                   digest_function=reapi.DigestFunction.SHA256)
        call = stub(req, timeout=timeout)
        stage, name, n = None, None, 0
        try:
            for operation in call:
                n += 1
                name = operation.name or name
                md = reapi.ExecuteOperationMetadata()
                if operation.metadata.Is(md.DESCRIPTOR):
                    operation.metadata.Unpack(md)
                    stage = STAGE.get(md.stage, md.stage)
                if cancel_after is not None and n >= cancel_after:
                    call.cancel()
                    return ("CLIENT_CANCELLED", stage, name)
                if operation.done:
                    return ("OK", stage, name)
        except grpc.RpcError as e:
            return (e.code().name, stage, name)
        finally:
            call.cancel()
        return ("OK", stage, name)

    def scheduler_snapshot(self):
        """Scrape Prometheus and count the awaited-action store occupancy directly:
        distinct per-operation metric families = store size; distinct queued-set
        slots = queue depth. Returns {"ops","queued"} or None if unavailable."""
        try:
            text = urllib.request.urlopen(
                f"http://{self.args.host}:{self.args.metrics_port}/metrics", timeout=3).read().decode()
        except Exception:
            return None
        ops = len(set(self._store_rx.findall(text)))
        queued = len(set(self._active_rx.findall(text)))
        snap = {"iteration": self.iteration, "ops": ops, "queued": queued}
        self.sched_log.write(json.dumps(snap, separators=(",", ":")) + "\n")
        return snap

    def scheduler_leak_check(self, phase):
        """Rising-floor detector: if the MINIMUM store occupancy over a window keeps
        climbing, GC is not keeping pace with terminal/abandoned entries — the P0
        leak signature. (A definitive drain check also runs at end of the campaign.)"""
        snap = self.scheduler_snapshot()
        if snap is None:
            return
        self._sched_series.append(snap)
        w = self.args.leak_window
        if len(self._sched_series) < 2 * w:
            return
        # Track the NON-queued residue (ops not in the queued set); queued backlog is
        # legitimate when there is no worker, so only the residue isolates a real leak.
        def residue(s):
            return max(0, s["ops"] - s["queued"])
        first = min(residue(s) for s in self._sched_series[-2 * w:-w])
        last = min(residue(s) for s in self._sched_series[-w:])
        if last - first > max(3, self.args.leak_threshold):
            self.finding("scheduler-queue-leak-rising",
                         "non-queued awaited-action residue floor keeps rising across the run "
                         "(terminal/abandoned entries not being GC'd)",
                         {"phase": phase, "residue_floor_start": first, "residue_floor_now": last, "window": w})

    def drain_check(self):
        """Definitive leak test: stop creating work, wait past client_action_timeout
        + retain_completed_for, then confirm the store drained. Anything left is a
        leak (all clients are gone, so every entry should have been abandoned+GC'd)."""
        if not (self.args.execution or self.args.only_execution):
            return
        before = self.scheduler_snapshot()
        if before is None:
            return
        print(f"draining {self.args.drain_seconds}s (store ops={before['ops']} queued={before['queued']})…",
              flush=True)
        time.sleep(self.args.drain_seconds)
        after = self.scheduler_snapshot()
        if after is None:
            return
        print(f"after drain: store ops={after['ops']} queued={after['queued']}", flush=True)
        if after["ops"] <= self.args.leak_threshold:
            return
        # Confirmation: touch the map with one throwaway execution. If the stale
        # entries then evict, the GC is access-triggered with no background timer
        # (RCA candidate #1) rather than merely slow.
        touch_evicted = None
        try:
            salt = self.iteration.to_bytes(8, "big")
            self._execute(self._build_action(random.Random("touch"), salt, True), cancel_after=1, timeout=4)
            time.sleep(2)
            touched = self.scheduler_snapshot()
            if touched is not None:
                touch_evicted = after["ops"] - touched["ops"]
                print(f"after touch: store ops={touched['ops']} "
                      f"(evicted {touch_evicted} stale on access)", flush=True)
        except Exception:
            pass
        self.finding("scheduler-queue-leak",
                     "awaited-action store did not drain after all clients left and the "
                     "abandon+retain window elapsed (entries leaked, not GC'd)",
                     {"ops_before_drain": before["ops"], "ops_after_drain": after["ops"],
                      "queued_after_drain": after["queued"], "drain_seconds": self.args.drain_seconds,
                      "stale_evicted_on_touch": touch_evicted,
                      "note": "positive stale_evicted_on_touch ⇒ access-triggered GC with no background timer"})

    def execution_iteration(self, rng):
        scenario = self.feedback.choose(self._feedback_rng, "exec_scenario",
                                        ["exec-cancel", "exec-abandon", "exec-timeout",
                                         "exec-dup", "exec-wait"])
        self._last_choices = {"mode": "execution", "exec_scenario": scenario}
        info = {"mode": "execution", "scenario": scenario}
        # Fresh salt per iteration except exec-dup, which reuses one to force dedup.
        salt = rng.getrandbits(64).to_bytes(8, "big")
        if scenario == "exec-cancel":
            a = self._build_action(rng, salt, do_not_cache=True)
            info["result"] = self._execute(a, cancel_after=rng.randint(1, 2), timeout=6)[0]
        elif scenario == "exec-abandon":
            a = self._build_action(rng, salt, do_not_cache=True)
            info["result"] = self._execute(a, cancel_after=1, timeout=6)[0]
        elif scenario == "exec-timeout":
            a = self._build_action(rng, salt, do_not_cache=True)
            info["result"] = self._execute(a, cancel_after=None, timeout=0.5)[0]
        elif scenario == "exec-dup":
            # Many concurrent identical actions → dedup/out-of-sync cleanup path.
            a = self._build_action(rng, salt, do_not_cache=False)
            n = rng.randint(4, 12)
            with cf.ThreadPoolExecutor(max_workers=n) as pool:
                outs = list(pool.map(lambda i: self._execute(
                    a, cancel_after=(1 if i % 2 else 2), timeout=6)[0], range(n)))
            info["results"] = dict(collections.Counter(outs))
        else:  # exec-wait: start, grab op name, WaitExecution, then abandon
            a = self._build_action(rng, salt, do_not_cache=True)
            status, stage, name = self._execute(a, cancel_after=1, timeout=6)
            info["result"], info["stage"] = status, stage
            if name:
                wstub = self._exec_stubs()["wait"]
                call = wstub(reapi.WaitExecutionRequest(name=name), timeout=4)
                try:
                    next(iter(call)); call.cancel()
                except (grpc.RpcError, StopIteration):
                    pass
        self.scheduler_leak_check(scenario)
        return info

    # ---- iteration modes ------------------------------------------------- #
    def proxy_iteration(self, rng):
        op = self.feedback.choose(self._feedback_rng, "proxy_op", ["read", "write", "missing"])
        rules = gen_policy(rng)
        # Record the dominant fault dimensions this iteration exercised so the
        # novelty memory can credit them (fault kind + direction of first rule).
        self._last_choices = {"mode": "proxy", "proxy_op": op,
                              "fault_kind": rules[0]["fault"]["kind"],
                              "direction": rules[0]["target"]["direction"]}
        idir = self.out / "iters" / f"{self.iteration:06d}"
        polpath = idir
        idir.mkdir(parents=True, exist_ok=True)
        (idir / "policy.json").write_text(json.dumps(
            {"version": 1, "seed": rng.getrandbits(64), "rules": rules}))
        label = f"p{self.iteration}"
        info = {"mode": "proxy", "op": op, "rules": rules}
        with proxy(self.args.port, idir, rules=None, extra=("--policy", str(idir / "policy.json")),
                   upstream_host=self.args.host, max_seconds=self.args.max_seconds) as (channel, timeline, port):
            gw = Endpoint(f"127.0.0.1:{port}", channel)
            if op == "read":
                blob = self._make_blob(f"{label}-r", rng.choice(SIZES[1:]))
                self._ensure_present("proxy-read-setup", blob)
                g = self.check_read_integrity("proxy", gw, blob, repro=idir, timeout=self.args.max_seconds + 2)
                info["gateway_read"] = g["status"]
                # The server must still serve correct bytes directly after the faulted read.
                self.check_read_integrity("proxy-after", self.direct, blob, timeout=6)
            elif op == "write":
                blob = self._make_blob(f"{label}-w", rng.choice(SIZES))
                w = gw.write(blob, "monkey", timeout=self.args.max_seconds + 2)
                info["gateway_write"] = w["status"]
                self.check_committed("proxy", blob, w)
                if w["status"] == "OK" and w.get("committedBytes") == blob.size:
                    self.check_read_integrity("proxy-write-back", self.direct, blob, repro=idir, timeout=6)
                else:
                    # A faulted/failed write must not leave a readable partial artifact.
                    self.check_absent("proxy", blob, f"proxy-{w['status']}")
            else:  # missing
                present = [self._make_blob(f"{label}-m{i}", rng.choice(SIZES[1:5])) for i in range(2)]
                for b in present:
                    self._ensure_present("proxy-missing-setup", b)
                absent = [self._make_blob(f"{label}-x{i}", 31 + i) for i in range(3)]
                batch = present + absent
                m = gw.missing(batch, self.instance, timeout=self.args.max_seconds + 2)
                info["gateway_missing"] = m["status"]
                if m["status"] == "OK":
                    returned = {(d["hash"], d["size"]) for d in m["missing"]}
                    expected = {(b.hash, b.size) for b in absent}
                    if returned != expected:
                        self.finding("fmb-wrong-set", "FindMissingBlobs returned the wrong missing set",
                                     {"expected": sorted(expected), "returned": sorted(returned)}, idir)
        return info

    def direct_iteration(self, rng):
        scenario = self.feedback.choose(self._feedback_rng, "direct_scenario",
                                        ["short-upload", "empty-finish", "cancel-write",
                                         "concurrent-writers", "range-read", "resume"])
        self._last_choices = {"mode": "direct", "direct_scenario": scenario}
        info = {"mode": "direct", "scenario": scenario}
        if scenario in ("short-upload", "empty-finish"):
            blob = self._make_blob(f"d{self.iteration}", rng.choice([33, 65553, 1048576]))
            stop = 0 if scenario == "empty-finish" else rng.randint(1, max(1, blob.size - 1))
            w = self.direct.write(blob, "short", stop_at=stop, finish=True, timeout=6)
            info["write"] = w["status"]
            self.check_query_sane("direct", blob, "short", uploaded=stop)
            self.check_absent("direct", blob, f"short-{w['status']}")
        elif scenario == "cancel-write":
            blob = self._make_blob(f"d{self.iteration}", 1048576)
            w = self.direct.write(blob, "cancel", stop_at=blob.size, finish=False,
                                  pause=0.002, cancel_after=0.02, timeout=6)
            info["write"] = w["status"]
            self.check_absent("direct", blob, "cancel")
        elif scenario == "concurrent-writers":
            import concurrent.futures as cf
            import threading
            blob = self._make_blob(f"d{self.iteration}", 8 * 1024 * 1024)
            n = rng.randint(4, 16)
            barrier = threading.Barrier(n)

            def writer(i):
                barrier.wait(timeout=10)
                cancel = i % 3 == 0
                w = self.direct.write(blob, f"w{i}", pause=0.002 if cancel else 0,
                                      cancel_after=0.02 if cancel else None, timeout=12)
                self.check_committed("direct", blob, w)
                if w["status"] == "OK":
                    self.check_read_integrity("direct-concurrent", self.direct, blob, timeout=6)
                return w["status"]
            with cf.ThreadPoolExecutor(max_workers=n) as pool:
                statuses = list(pool.map(writer, range(n)))
            info["statuses"] = dict(collections.Counter(statuses))
            self.check_read_integrity("direct-concurrent-final", self.direct, blob, timeout=6)
        elif scenario == "range-read":
            blob = self._make_blob(f"d{self.iteration}", rng.choice([65537, 1048576]))
            self._ensure_present("range-setup", blob)
            # Valid ranges must return correct bytes; offsets past EOF must not
            # return wrong bytes with OK.
            for off, lim in [(0, 0), (0, 1), (blob.size - 1, 0), (blob.size, 0),
                             (rng.randint(0, blob.size), rng.randint(1, 65536))]:
                r = self.direct.read(blob, offset=off, limit=lim, timeout=6)
                if r["status"] == "OK" and r.get("matches") is False:
                    self.finding("range-wrong-bytes", "range Read returned OK with wrong bytes",
                                 {"blob": blob.descriptor(), "offset": off, "limit": lim, "read": r})
            info["ranges"] = "checked"
        else:  # resume
            blob = self._make_blob(f"d{self.iteration}", 1048576)
            w = self.direct.write(blob, "resume", stop_at=CHUNK, finish=False, timeout=6)
            q = self.check_query_sane("direct", blob, "resume", uploaded=CHUNK)
            info["query"] = q.get("committedBytes")
            if q["status"] == "OK" and not q["complete"] and 0 <= q["committedBytes"] <= blob.size:
                r = self.direct.write(blob, "resume", offset=q["committedBytes"], timeout=8)
                info["resume"] = r["status"]
                if r["status"] == "OK":
                    self.check_read_integrity("direct-resume", self.direct, blob, timeout=6)
        return info

    # ---- coverage / feedback / soak ------------------------------------- #
    def _mode_options(self):
        if self.args.only_execution:
            return ["execution"]
        if self.args.only_direct:
            return ["direct"]
        if self.args.only_proxy:
            return ["proxy"]
        return ["proxy", "direct", "execution"] if self.args.execution else ["proxy", "direct"]

    def _coverage_signature(self, info, new_sigs, before_metrics, after_metrics):
        """Fold (fault-kind, method/op, direction, outcome, moved-metric-family buckets,
        new-finding signatures) into one coverage signature string. This is what the
        novelty memory dedups on. Metric families are bucketed and sorted so noise in
        gauge tails does not mint endless 'new' signatures."""
        ch = getattr(self, "_last_choices", {}) or {}
        parts = [ch.get("mode", info.get("mode", "?"))]
        for key in ("proxy_op", "direct_scenario", "exec_scenario", "fault_kind", "direction"):
            if key in ch:
                parts.append(f"{key}={ch[key]}")
        # RPC outcome(s) observed.
        for key in ("gateway_read", "gateway_write", "gateway_missing", "result", "write", "query"):
            if info.get(key) is not None:
                parts.append(f"{key}:{info[key]}")
        # Metric families that moved, bucketed.
        moved = []
        if after_metrics:
            fam_before = _fold_families(before_metrics)
            fam_after = _fold_families(after_metrics)
            for fam in sorted(set(fam_before) | set(fam_after)):
                b = delta_bucket(fam_before.get(fam, 0.0), fam_after.get(fam, 0.0))
                if b != "0":
                    moved.append(f"{fam}:{b}")
        if moved:
            parts.append("Δ" + ",".join(moved))
        for s in sorted(new_sigs):
            parts.append(f"finding:{s}")
        return "|".join(parts)

    # ---- driver ---------------------------------------------------------- #
    def one(self):
        self.iteration += 1
        it = self.iteration
        rng = random.Random(f"{self.seed}:{it}")
        self._last_choices = {}
        mode = self.feedback.choose(self._feedback_rng, "mode", self._mode_options())
        before = self.finding_total
        before_sigs = set(self.seen)
        t0 = time.monotonic()
        try:
            info = (self.execution_iteration(rng) if mode == "execution" else
                    self.proxy_iteration(rng) if mode == "proxy" else
                    self.direct_iteration(rng))
            info["error"] = None
        except Exception as e:  # keep the loop alive; a crashed iteration is itself a signal
            info = {"mode": mode, "error": f"{type(e).__name__}: {e}"}
            tb = traceback.format_exc()
            (self.out / "iters" / f"{it:06d}").mkdir(parents=True, exist_ok=True)
            (self.out / "iters" / f"{it:06d}" / "traceback.txt").write_text(tb)
            self.finding(f"iteration-exception:{mode}:{type(e).__name__}",
                         "iteration raised before completing its invariant checks",
                         {"error": info["error"]})
        recovered = self.recovery(mode)
        # Post-iteration scrape drives both the feedback loop and the soak tracker.
        after_metrics = self._parse_metrics()
        extra = self._process_signals()
        if extra:
            after_metrics = {**after_metrics, **extra}
        new_sigs = set(self.seen) - before_sigs
        novel = False
        cov_sig = None
        if self.feedback.enabled or self.args.feedback_always_log:
            cov_sig = self._coverage_signature(info, new_sigs, self._prev_metrics, after_metrics)
            novel = self.feedback.record(getattr(self, "_last_choices", {}) or {"mode": mode}, cov_sig)
            self.feedback_log.write(json.dumps(
                {"iteration": it, "mode": mode, "novel": novel, "coverage_signature": cov_sig,
                 "choices": getattr(self, "_last_choices", {})}, separators=(",", ":")) + "\n")
        if self.args.soak and after_metrics:
            self.soak.observe(after_metrics, load=float(it))
            self.soak_log.write(json.dumps(
                {"iteration": it, "tracked_signals": len(self.soak.series)},
                separators=(",", ":")) + "\n")
            self._soak_check(phase=mode)
        if after_metrics:
            self._prev_metrics = after_metrics
        info.update(iteration=it, seed=self.seed, found=self.finding_total - before,
                    recovered=recovered, seconds=round(time.monotonic() - t0, 3),
                    novel_coverage=novel)
        self.iter_log.write(json.dumps(info, separators=(",", ":")) + "\n")
        elapsed = int(time.monotonic() - self.started)
        extra_tag = ""
        if self.feedback.enabled:
            extra_tag = f" cov={len(self.feedback.signatures)}{'*' if novel else ''}"
        if self.args.soak:
            extra_tag += f" soak={len(self.soak.series)}"
        print(f"[{elapsed:>6}s] iter {it:>6} {mode:<6} "
              f"{info.get('op') or info.get('scenario') or '-':<18} "
              f"found={info['found']} recov={'ok' if recovered else 'FAIL'} "
              f"| total findings={self.finding_total} unique={len(self.seen)}{extra_tag}", flush=True)
        return info

    def _soak_check(self, phase):
        """Emit a finding for each newly-detected unbounded-growth signal. Dedups by
        metric name so a persistent leak is reported once, not every window."""
        for cand in self.soak.findings():
            if cand["metric"] in self._soak_flagged:
                continue
            self._soak_flagged.add(cand["metric"])
            self.finding(f"resource-leak-rising:{cand['metric']}",
                         "a scrapable signal's floor keeps rising across windows "
                         "(accumulates without returning to baseline — leak shape)",
                         {"phase": phase, **cand})

    def soak_final(self):
        """End-of-run soak pass: report any remaining rising-floor signals (covers
        signals whose growth only became monotone over the full run)."""
        if not self.args.soak:
            return
        self._soak_check(phase="final")
        leaks = [{"metric": m} for m in sorted(self._soak_flagged)]
        (self.out / "soak-summary.json").write_text(json.dumps(
            {"samples": self.soak.samples, "tracked_signals": len(self.soak.series),
             "flagged": sorted(self._soak_flagged), "window": self.soak.window}, indent=2) + "\n")
        print(f"soak: {self.soak.samples} samples over {len(self.soak.series)} signals; "
              f"flagged {len(leaks)} rising-floor signal(s).", flush=True)

    def report(self):
        summary = {"run_id": self.run_id, "iterations": self.iteration,
                   "findings_total": self.finding_total, "unique_signatures": len(self.seen),
                   "signatures": dict(self.seen.most_common()),
                   "seconds": round(time.monotonic() - self.started, 1)}
        if self.feedback.enabled:
            summary["feedback"] = self.feedback.snapshot()
        if self.args.soak:
            summary["soak"] = {"samples": self.soak.samples,
                               "tracked_signals": len(self.soak.series),
                               "flagged": sorted(self._soak_flagged)}
        (self.out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print("\n=== chaos-monkey summary ===", flush=True)
        print(json.dumps(summary["signatures"], indent=2), flush=True)
        if self.feedback.enabled:
            fb = summary["feedback"]
            print(f"feedback: {fb['unique_coverage_signatures']} unique coverage signatures, "
                  f"{fb['novel_iterations']} novel iterations.", flush=True)
        print(f"{self.iteration} iterations, {self.finding_total} findings, "
              f"{len(self.seen)} unique signatures. corpus: {self.corpus}", flush=True)

    def run(self):
        def handle(signum, frame):
            self.stop = True
            print("\n(stopping after current iteration)", flush=True)
        signal.signal(signal.SIGINT, handle)
        signal.signal(signal.SIGTERM, handle)
        deadline = self.started + self.args.minutes * 60 if self.args.minutes else None
        print(f"chaos-monkey → {self.args.host}:{self.args.port} instance={self.instance} "
              f"seed={self.seed} run={self.run_id}", flush=True)
        try:
            while not self.stop:
                if self.args.iterations and self.iteration >= self.args.iterations:
                    break
                if deadline and time.monotonic() >= deadline:
                    break
                info = self.one()
                if self.args.stop_on_finding and info["found"]:
                    print("stopping on first finding (--stop-on-finding)", flush=True)
                    break
        finally:
            try:
                self.drain_check()
            except Exception as e:  # drain is best-effort; never mask the run
                print(f"(drain check skipped: {e})", flush=True)
            try:
                self.soak_final()
            except Exception as e:  # soak report is best-effort; never mask the run
                print(f"(soak final check skipped: {e})", flush=True)
            self.report()
            self.findings_log.close()
            self.iter_log.close()
            self.sched_log.close()
            self.feedback_log.close()
            self.soak_log.close()
            self.direct.channel.close()


def _slug(s):
    return "".join(c if c.isalnum() or c in "-._" else "_" for c in s)[:120]


def main():
    import datetime
    p = argparse.ArgumentParser(description="continuous randomized REAPI chaos monkey")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=50052)
    p.add_argument("--instance", default="main")
    p.add_argument("--seed", type=int, default=20261002)
    p.add_argument("--run-id", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    p.add_argument("--output", default="runs/monkey")
    p.add_argument("--iterations", type=int, default=0, help="0 = run forever")
    p.add_argument("--minutes", type=float, default=0, help="0 = no time limit")
    p.add_argument("--max-seconds", type=int, default=8, help="per-call proxy cap")
    p.add_argument("--only-proxy", action="store_true")
    p.add_argument("--only-direct", action="store_true")
    p.add_argument("--execution", action="store_true",
                   help="mix in Execution/scheduler stress (needs an endpoint exposing the Execution service)")
    p.add_argument("--only-execution", action="store_true", help="run only Execution/scheduler stress")
    p.add_argument("--metrics-port", type=int, default=0, help="Prometheus port (default: --port)")
    p.add_argument("--store-metric",
                   default=r"action_db_operation_ids_([0-9a-f]{8}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{12})",
                   help="regex (one capture group): distinct matches counted as awaited-action store size")
    p.add_argument("--active-metric", default=r"sorted_action_infos_queued_(\d+)_sort_key",
                   help="regex (one capture group): distinct matches counted as queue depth")
    p.add_argument("--leak-window", type=int, default=10, help="samples per rising-floor window")
    p.add_argument("--leak-threshold", type=int, default=0,
                   help="store entries allowed to remain after a full drain (0 = any leftover is a leak)")
    p.add_argument("--drain-seconds", type=float, default=30,
                   help="quiet-drain wait for the definitive end-of-run leak check")
    p.add_argument("--stop-on-finding", action="store_true")
    # Feedback-guided generation (on by default; --no-feedback restores uniform random).
    p.add_argument("--feedback", action="store_true", default=True,
                   help="bias generation toward combinations that produce NEW coverage signatures (default on)")
    p.add_argument("--no-feedback", dest="feedback", action="store_false",
                   help="disable feedback; use the original uniform-random policy")
    p.add_argument("--explore-floor", type=float, default=0.25,
                   help="fraction of choices kept uniformly random even with feedback on (exploration floor)")
    p.add_argument("--feedback-always-log", action="store_true",
                   help="compute+log coverage signatures even with --no-feedback (does not bias)")
    # Resource-leak soak.
    p.add_argument("--soak", action="store_true",
                   help="track every numeric /metrics signal (plus process RSS/FD if reachable) for unbounded growth")
    p.add_argument("--soak-window", type=int, default=15,
                   help="samples per soak rising-floor window (needs 3 windows before any verdict)")
    p.add_argument("--soak-rel-threshold", type=float, default=0.5,
                   help="minimum relative floor rise (over 3 windows) to flag a signal as leaking")
    p.add_argument("--soak-abs-threshold", type=float, default=1.0,
                   help="minimum absolute floor rise to flag (filters sub-unit gauge noise)")
    p.add_argument("--proc-pid", type=int, default=0,
                   help="optional PID of a co-located server to read RSS/FD from /proc (0 = skip)")
    args = p.parse_args()
    if sum(bool(x) for x in (args.only_proxy, args.only_direct, args.only_execution)) > 1:
        p.error("choose at most one of --only-proxy / --only-direct / --only-execution")
    if not args.metrics_port:
        args.metrics_port = args.port
    Monkey(args).run()


if __name__ == "__main__":
    main()
