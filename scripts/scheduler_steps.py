#!/usr/bin/env python3
"""Scheduler scenario engine: replay a step list against a fleet rig and
evaluate the scheduler liveness invariants (docs/invariants.md 8-13).

A scenario is a JSONL list of steps (the witness `rechaos minimize --steps`
shrinks). The engine turns it into REAPI traffic plus control-plane faults
against the fleet that scripts/fleet_rig.py started, records what each action
was observed to do, and then evaluates the observations with a pure function
(`evaluate`) that names each violation by a stable signature:

    queue-starvation          an action waited past the bound while later
                              submissions were dispatched ahead of it
    dispatch-stall            an action waited past the bound although the
                              fleet had room for everything in flight
    stuck-executing           an operation stayed EXECUTING past the scheduler's
                              own executing timeout with no client attached
    input-evicted-failure     an action failed on a worker-local eviction while
                              every input was present in the CAS
    action-failed-inputs-present:<CODE>
                              any other server-side failure with inputs present
    store-throttle-giveup     an input fetch failed during an object-store throttle
                              shorter than the worker's download budget
    store-throttle-redispatch an action was requeued to another worker because of
                              an object-store throttle instead of retried in place

Step kinds (all fields integers unless noted; `weaker` declares the fields
the shrinker may halve toward a floor):

    {"step":"blob","id":"tool","bytes":2000000,"executable":true}
    {"step":"action","id":"a1","at_ms":0,"cpu":1,"memory_kb":2048,"sleep_ms":500,
     "inputs":["tool","u1"],"detach":false,"timeout_ms":30000,"weaker":{"sleep_ms":0}}
    {"step":"store-full","at_ms":1500,"for_ms":4000}      # scheduler Redis refuses writes
    {"step":"store-pause","at_ms":1500,"for_ms":4000}     # scheduler Redis SIGSTOPped
    {"step":"worker-pause","at_ms":1500,"for_ms":4000,"worker":0}
    {"step":"store-throttle","at_ms":1500,"for_ms":45000,"ops":"GET"}   # object store answers the
                                                                     # rig dialect's throttle error

Unknown step kinds and control steps the rig cannot serve (no Redis) make the
run INCONCLUSIVE: the checker exits non-zero and the minimizer treats the
trial as Unknown, never as a reproduction.

    # Run a scenario and print findings as JSON (stdout) with evidence on disk.
    python3 scripts/scheduler_steps.py run --rig runs/rig/rig.json --steps steps.jsonl --out runs/scn
    # Act as the `rechaos minimize --steps` checker.
    RECHAOS_STEPS=... RECHAOS_VERDICT=... python3 scripts/scheduler_steps.py check \\
        --rig runs/rig/rig.json --signature queue-starvation --fresh
"""
import argparse
import dataclasses
import hashlib
import json
import os
import pathlib
import re
import signal
import sys
import threading
import time
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test"))
sys.path.insert(0, str(ROOT / "scripts"))
from integration import re as reapi, bs, grpc  # noqa: E402
from google.longrunning import operations_pb2 as oplr  # noqa: E402
import fleet_rig  # noqa: E402

EXECUTE = "/build.bazel.remote.execution.v2.Execution/Execute"
WAIT_EXECUTION = "/build.bazel.remote.execution.v2.Execution/WaitExecution"
FIND_MISSING = "/build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"
BS_WRITE = "/google.bytestream.ByteStream/Write"
STAGE = {0: "UNKNOWN", 1: "CACHE_CHECK", 2: "QUEUED", 3: "EXECUTING", 4: "COMPLETED"}
CLIENT_SIDE = {"CANCELLED", "DEADLINE_EXCEEDED", "CLIENT_CANCELLED", "UNAVAILABLE"}
EVICTION_TEXT = re.compile(r"evict|hard ?link", re.IGNORECASE)
CONTROL_STEPS = {"store-full", "store-pause", "worker-pause", "store-throttle"}
# PATH handed to every action's command. The worker clears the environment, so
# `sleep` must be found through this; it covers NixOS (/run/current-system/sw/bin)
# and FHS hosts alike and is part of the action digest.
WORKER_PATH = "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin"
# Time inside any control window is discounted from the queue-age and executing
# bounds (see _faulted_ms); a store throttle additionally has invariants 12 and
# 13 that look inside its window, because the store says "retry later" and giving
# up or re-dispatching inside it is the behavior under test.
OVERTAKE_MARGIN_MS = 1000
STORE_FETCH_TEXT = re.compile(r"download|fetch|ServerBusy|SlowDown|rateLimit|throttl|On attempt|"
                              r"Failed to start|Error reading from", re.IGNORECASE)


def log(message):
    print(f"[scheduler-steps] {message}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Limits: the bounds the invariants are evaluated against. Derived from the rig
# where the rig defines them (executing timeout), chosen by the scenario
# generator otherwise (queue-age bound) and carried on the checker command line
# so a frozen witness evaluates identically.
# ---------------------------------------------------------------------------
@dataclasses.dataclass
class Limits:
    queue_age_ms: int
    executing_ms: int
    workers: int
    slots: int
    memory_kb: int
    settle_ms: int = 3000
    download_budget_ms: int = 600000   # the worker's max_download_timeout_s (NativeLink default 10 min)

    @classmethod
    def for_rig(cls, manifest, queue_age_ms=6000, executing_ms=None, settle_ms=3000, download_budget_ms=None):
        sched = manifest["scheduler"]
        if executing_ms is None:
            executing_ms = (sched["max_action_executing_timeout_s"] + sched["worker_timeout_s"]) * 1000 + 5000
        if download_budget_ms is None:
            download_budget_ms = int(manifest.get("worker", {}).get("max_download_timeout_s", 600)) * 1000
        return cls(queue_age_ms=queue_age_ms, executing_ms=executing_ms, workers=manifest["workers"],
                   slots=manifest["slots"], memory_kb=manifest["memory_kb"], settle_ms=settle_ms,
                   download_budget_ms=download_budget_ms)

    def as_args(self):
        return ["--queue-age-ms", str(self.queue_age_ms), "--executing-ms", str(self.executing_ms),
                "--settle-ms", str(self.settle_ms), "--download-budget-ms", str(self.download_budget_ms)]


# ---------------------------------------------------------------------------
# Steps: parsing and validation. The same rules as the fail-closed reader in
# src/Rechaos/Shell/Steps.hs (JSONL or a JSON array; a `weaker` declaration
# must name existing non-negative integer fields with floors at or below their
# values), so the engine and `rechaos minimize --steps` reject the same files.
# ---------------------------------------------------------------------------
class StepError(ValueError):
    pass


def _weaker_problem(step):
    """Why a step's `weaker` declaration is unusable, or None."""
    floors = step.get("weaker")
    if floors is None:
        return None
    if not isinstance(floors, dict):
        return "weaker must be an object of field -> floor"
    for field, floor in floors.items():
        if not isinstance(floor, int) or isinstance(floor, bool) or floor < 0:
            return f"weaker.{field}: floor must be a non-negative integer"
        if field not in step:
            return f"weaker.{field}: declared field is absent"
        value = step[field]
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            return f"weaker.{field}: declared field must be a non-negative integer"
        if value < floor:
            return f"weaker.{field}: value is below its floor"
    return None


def _checked(step, place):
    if not isinstance(step, dict) or "step" not in step:
        raise StepError(f"{place}: must be an object with a 'step' kind")
    problem = _weaker_problem(step)
    if problem:
        raise StepError(f"{place}: {problem}")
    return step


def read_steps(path):
    text = pathlib.Path(path).read_text()
    stripped = text.lstrip()
    if stripped.startswith("["):
        try:
            elements = json.loads(text)
        except json.JSONDecodeError as e:
            raise StepError(f"steps: {e}")
        return [_checked(step, f"step {n} (array element)") for n, step in enumerate(elements)]
    steps = []
    for n, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            step = json.loads(line)
        except json.JSONDecodeError as e:
            raise StepError(f"steps line {n}: {e}")
        steps.append(_checked(step, f"steps line {n}"))
    return steps


def write_steps(path, steps):
    pathlib.Path(path).write_text("".join(json.dumps(s, separators=(",", ":")) + "\n" for s in steps))


def validate_steps(steps, manifest):
    """Reject what the rig cannot replay. Returns the list of reasons (empty = ok)."""
    reasons = []
    has_redis = bool(manifest.get("redis"))
    for i, s in enumerate(steps):
        kind = s.get("step")
        if kind == "blob":
            if not isinstance(s.get("id"), str) or not isinstance(s.get("bytes"), int) or s["bytes"] < 0:
                reasons.append(f"step {i}: blob needs string id and non-negative bytes")
        elif kind == "action":
            if not isinstance(s.get("id"), str):
                reasons.append(f"step {i}: action needs a string id")
            for f in ("at_ms", "cpu", "memory_kb", "sleep_ms"):
                if not isinstance(s.get(f, 0), int) or s.get(f, 0) < 0:
                    reasons.append(f"step {i}: action.{f} must be a non-negative integer")
        elif kind in ("store-full", "store-pause"):
            if not has_redis:
                reasons.append(f"step {i}: {kind} needs a redis-backed rig")
        elif kind == "store-throttle":
            if not manifest.get("object_store"):
                reasons.append(f"step {i}: store-throttle needs a rig whose CAS sits behind the fault proxy")
            # n.b. A scheduler executing timeout shorter than the throttle requeues
            # every fetching action on its own clock, which would be reported as a
            # re-dispatch the throttle did not cause. Such a scenario is inconclusive.
            executing_s = manifest.get("scheduler", {}).get("max_action_executing_timeout_s", 0)
            if executing_s and s.get("for_ms", 0) > executing_s * 1000:
                reasons.append(f"step {i}: store-throttle of {s.get('for_ms')} ms outlasts the scheduler's "
                               f"max_action_executing_timeout_s ({executing_s} s); disable it or shorten the throttle")
        elif kind == "worker-pause":
            if not (0 <= s.get("worker", 0) < manifest["workers"]):
                reasons.append(f"step {i}: worker index out of range")
        else:
            reasons.append(f"step {i}: unknown step kind {kind!r}")
    return reasons


# ---------------------------------------------------------------------------
# REAPI client.
# ---------------------------------------------------------------------------
class Client:
    def __init__(self, host, port, instance):
        self.instance = instance
        self.channel = grpc.insecure_channel(f"{host}:{port}")
        grpc.channel_ready_future(self.channel).result(timeout=15)
        self.execute = self.channel.unary_stream(EXECUTE, request_serializer=reapi.ExecuteRequest.SerializeToString,
                                                 response_deserializer=oplr.Operation.FromString)
        self.wait = self.channel.unary_stream(WAIT_EXECUTION, request_serializer=reapi.WaitExecutionRequest.SerializeToString,
                                              response_deserializer=oplr.Operation.FromString)
        self.write = self.channel.stream_unary(BS_WRITE, request_serializer=bs.WriteRequest.SerializeToString,
                                               response_deserializer=bs.WriteResponse.FromString)
        self.missing = self.channel.unary_unary(FIND_MISSING, request_serializer=reapi.FindMissingBlobsRequest.SerializeToString,
                                                response_deserializer=reapi.FindMissingBlobsResponse.FromString)

    def upload(self, data, timeout=30):
        h = hashlib.sha256(data).hexdigest()
        name = f"{self.instance}/uploads/{uuid.uuid4()}/blobs/{h}/{len(data)}"
        chunk = 1 << 16

        def requests():
            if not data:
                yield bs.WriteRequest(resource_name=name, write_offset=0, data=b"", finish_write=True)
                return
            for offset in range(0, len(data), chunk):
                piece = data[offset:offset + chunk]
                yield bs.WriteRequest(resource_name=name, write_offset=offset, data=piece,
                                      finish_write=offset + len(piece) >= len(data))
        response = self.write(requests(), timeout=timeout)
        if response.committed_size != len(data):
            raise RuntimeError(f"upload committed {response.committed_size} of {len(data)} bytes")
        return reapi.Digest(hash=h, size_bytes=len(data))

    def find_missing(self, digests, timeout=10):
        if not digests:
            return []
        response = self.missing(reapi.FindMissingBlobsRequest(
            instance_name=self.instance, blob_digests=list(digests),
            digest_function=reapi.DigestFunction.SHA256), timeout=timeout)
        return [f"{d.hash}/{d.size_bytes}" for d in response.missing_blob_digests]

    def close(self):
        self.channel.close()


def blob_bytes(nonce, blob_id, size):
    return hashlib.shake_256(f"{nonce}/{blob_id}".encode()).digest(size) if size else b""


def platform(cpu, memory_kb):
    return reapi.Platform(properties=[
        reapi.Platform.Property(name="cpu_count", value=str(cpu)),
        reapi.Platform.Property(name="memory_kb", value=str(memory_kb)),
        reapi.Platform.Property(name="OSFamily", value="linux"),
    ])


# ---------------------------------------------------------------------------
# One observed action.
# ---------------------------------------------------------------------------
@dataclasses.dataclass
class Observed:
    id: str
    submit_ms: int | None = None
    queued_ms: int | None = None
    executing_ms: int | None = None
    done_ms: int | None = None
    last_ms: int | None = None
    last_stage: str | None = None
    status: str | None = None          # OK, a gRPC code name, or CLIENT_CANCELLED
    message: str = ""
    exit_code: int | None = None
    operation: str | None = None
    detached: bool = False
    probes: list = dataclasses.field(default_factory=list)   # [{"ms","stage","done","status"}]
    inputs_present: bool | None = None
    missing: list = dataclasses.field(default_factory=list)
    requeues: list = dataclasses.field(default_factory=list)   # ms at which EXECUTING fell back to QUEUED
    cpu: int = 1
    memory_kb: int = 0
    sleep_ms: int = 0

    def as_dict(self):
        return dataclasses.asdict(self)


# ---------------------------------------------------------------------------
# The scenario runner.
# ---------------------------------------------------------------------------
class Scenario:
    def __init__(self, steps, manifest, limits: Limits, out_dir=None, nonce=None):
        self.steps = steps
        self.manifest = manifest
        self.limits = limits
        self.out = pathlib.Path(out_dir) if out_dir else None
        self.nonce = nonce or uuid.uuid4().hex
        self.client: Client | None = None
        self.t0: float = 0.0
        self.observed = {}
        self.controls = []
        self.action_digests = {}
        self.input_digests = {}
        self.lock = threading.Lock()
        # n.b. Fail-closed on two fronts: any exception on a scenario thread is
        # collected here and makes the run inconclusive (a daemon thread's
        # exception would otherwise vanish and the run would be adjudicated
        # without the fault it was supposed to have), and every fault switched
        # on is recorded so it can be undone even when the run is torn down.
        self.errors = []
        self.active_faults = []
        # n.b. The command runs on the WORKER with an empty environment, so it
        # is `/bin/sh -c 'sleep N'` (every REAPI worker ships /bin/sh) with an
        # explicit PATH that covers NixOS and FHS hosts; a `sleep` path resolved
        # on this host would be shipped to a worker that may not have it. Both
        # are constant for the run, so the action digest varies only with the
        # scenario's own fields.
        self.worker_path = WORKER_PATH
        # Every control window's length: actions must outlive the faults they share a scenario with.
        self.control_ms = sum(int(s.get("for_ms", 0)) for s in steps if s.get("step") in CONTROL_STEPS)

    # -- time ------------------------------------------------------------- #
    def now_ms(self):
        return int((time.monotonic() - self.t0) * 1000)

    def sleep_until(self, at_ms):
        delay = (self.t0 + at_ms / 1000) - time.monotonic()
        if delay > 0:
            time.sleep(delay)

    def _client(self) -> "Client":
        if self.client is None:
            raise RuntimeError("scenario not prepared")
        return self.client

    def _guarded(self, target, step):
        """Run a step thread's body, collecting any exception as an engine error."""
        try:
            target(step)
        except BaseException as e:  # noqa: BLE001  every failure here must surface
            with self.lock:
                self.errors.append({"step": step.get("step"), "id": step.get("id"),
                                    "error": f"{type(e).__name__}: {e}"})

    # -- preparation ------------------------------------------------------ #
    def prepare(self):
        m = self.manifest
        self.client = Client(m["host"], m["port"], m["instance"])
        client = self.client
        blobs, executable = {}, {}
        for s in self.steps:
            if s["step"] == "blob":
                blobs[s["id"]] = client.upload(blob_bytes(self.nonce, s["id"], s["bytes"]))
                executable[s["id"]] = bool(s.get("executable", False))
        for s in self.steps:
            if s["step"] != "action":
                continue
            names = [i for i in s.get("inputs", []) if i in blobs]
            inputs = [blobs[i] for i in names]
            # n.b. Executable inputs take the worker's "variant" staging path (a
            # private 0o555 copy), the path shared toolchain binaries take.
            directory = reapi.Directory(files=[
                reapi.FileNode(name=f"in-{i}", digest=blobs[n], is_executable=executable[n])
                for i, n in enumerate(names)])
            root = client.upload(directory.SerializeToString())
            cpu, memory_kb, sleep_ms = s.get("cpu", 1), s.get("memory_kb", 0), s.get("sleep_ms", 0)
            command = reapi.Command(
                arguments=["/bin/sh", "-c", f"sleep {sleep_ms / 1000:.3f}"],
                environment_variables=[reapi.Command.EnvironmentVariable(name="PATH", value=self.worker_path)],
                platform=platform(cpu, memory_kb))
            command_digest = client.upload(command.SerializeToString())
            salt = hashlib.sha256(f"{self.nonce}/{s['id']}".encode()).digest()
            action = reapi.Action(command_digest=command_digest, input_root_digest=root, do_not_cache=True,
                                  salt=salt, platform=platform(cpu, memory_kb))
            self.action_digests[s["id"]] = client.upload(action.SerializeToString())
            self.input_digests[s["id"]] = inputs + [root, command_digest]
            self.observed[s["id"]] = Observed(id=s["id"], cpu=cpu, memory_kb=memory_kb, sleep_ms=sleep_ms)

    # -- actions ---------------------------------------------------------- #
    def run_action(self, step):
        o = self.observed[step["id"]]
        self.sleep_until(step.get("at_ms", 0))
        timeout_ms = step.get("timeout_ms") or (self.limits.queue_age_ms + o.sleep_ms + self.limits.executing_ms
                                                 + self.control_ms)
        request = reapi.ExecuteRequest(instance_name=self.manifest["instance"],
                                       action_digest=self.action_digests[step["id"]],
                                       skip_cache_lookup=True, digest_function=reapi.DigestFunction.SHA256)
        o.submit_ms = self.now_ms()
        call = self._client().execute(request, timeout=timeout_ms / 1000)
        try:
            for operation in call:
                self._note(o, operation)
                if operation.done:
                    o.done_ms = self.now_ms()
                    self._finish(o, operation)
                    return
                if step.get("detach") and o.last_stage == "EXECUTING":
                    o.detached = True
                    call.cancel()
                    return
        except grpc.RpcError as e:
            o.last_ms = self.now_ms()
            o.status = e.code().name if e.code() != grpc.StatusCode.CANCELLED else "CLIENT_CANCELLED"
            o.message = (e.details() or "")[:1000]
        finally:
            call.cancel()

    def _note(self, o, operation):
        o.last_ms = self.now_ms()
        o.operation = operation.name or o.operation
        md = reapi.ExecuteOperationMetadata()
        if operation.metadata.Is(md.DESCRIPTOR):
            operation.metadata.Unpack(md)
            stage = STAGE.get(md.stage, str(md.stage))
            if stage == "QUEUED" and o.last_stage == "EXECUTING":
                o.requeues.append(o.last_ms)
            o.last_stage = stage
            if stage == "QUEUED" and o.queued_ms is None:
                o.queued_ms = o.last_ms
            if stage == "EXECUTING" and o.executing_ms is None:
                o.executing_ms = o.last_ms

    def _finish(self, o, operation):
        o.last_stage = "COMPLETED"
        if operation.HasField("error"):
            o.status = _code_name(operation.error.code)
            o.message = operation.error.message[:1000]
        else:
            response = reapi.ExecuteResponse()
            if operation.response.Is(response.DESCRIPTOR):
                operation.response.Unpack(response)
                code = response.status.code
                o.status = "OK" if code == 0 else _code_name(code)
                o.message = response.status.message[:1000]
                o.exit_code = response.result.exit_code
            else:
                o.status = "OK"

    # -- control steps ---------------------------------------------------- #
    def run_control(self, step):
        kind = step["step"]
        self.sleep_until(step.get("at_ms", 0))
        record = {"step": kind, "start_ms": self.now_ms()}
        for_s = step.get("for_ms", 0) / 1000
        undo = None
        try:
            if kind == "store-full":
                redis = fleet_rig.Redis(self.manifest["redis"]["port"])
                used = redis.used_memory()
                # Cap at what is in use right now: every further allocation is
                # refused with OOM, exactly what a full noeviction scheduler store does.
                redis.set_maxmemory(used)
                record["maxmemory"] = used
                undo = lambda: redis.set_maxmemory(0)  # noqa: E731
            elif kind == "store-pause":
                pid = fleet_rig.verified_pid(self.manifest, "redis")
                os.kill(pid, signal.SIGSTOP)
                undo = lambda: os.kill(pid, signal.SIGCONT)  # noqa: E731
            elif kind == "worker-pause":
                pid = fleet_rig.verified_pid(self.manifest, f"worker-{step.get('worker', 0)}")
                os.kill(pid, signal.SIGSTOP)
                undo = lambda: os.kill(pid, signal.SIGCONT)  # noqa: E731
            elif kind == "store-throttle":
                control = self.manifest["object_store"]["control_url"]
                record["dialect"] = self.manifest["object_store"]["dialect"]
                record["throttle"] = control_post(control, "/throttle",
                                                  {"on": True, "ops": step.get("ops", "GET")}).get("throttle")
                undo = lambda: control_post(control, "/throttle", {"on": False})  # noqa: E731
            with self.lock:
                self.active_faults.append((kind, undo))
            time.sleep(for_s)
        finally:
            if undo is not None:
                undo()
                with self.lock:
                    self.active_faults = [f for f in self.active_faults if f[1] is not undo]
        record["end_ms"] = self.now_ms()
        with self.lock:
            self.controls.append(record)

    def undo_active_faults(self):
        """Undo every fault still switched on (teardown after an interrupted run)."""
        with self.lock:
            pending, self.active_faults = self.active_faults, []
        for kind, undo in pending:
            try:
                undo()
            except Exception as e:  # noqa: BLE001  best effort on the way out
                log(f"could not undo {kind}: {e}")

    # -- detached operations ---------------------------------------------- #
    def probe_detached(self):
        """Re-attach to every detached operation until it is done or the
        executing bound has elapsed since it was first seen EXECUTING."""
        pending = [o for o in self.observed.values() if o.detached and o.operation]
        while pending:
            still = []
            for o in pending:
                started = o.executing_ms or o.submit_ms or 0
                with self.lock:
                    faulted = _faulted_ms(started, self.now_ms(), self.controls)
                deadline_ms = started + self.limits.executing_ms + faulted + 1000
                done = self._probe(o)
                if not done and self.now_ms() < deadline_ms:
                    still.append(o)
            pending = still
            if pending:
                time.sleep(1.0)

    def _probe(self, o):
        call = self._client().wait(reapi.WaitExecutionRequest(name=o.operation), timeout=2.0)
        probe = {"ms": self.now_ms(), "stage": None, "done": False, "status": None}
        try:
            for operation in call:
                self._note(o, operation)
                probe["stage"] = o.last_stage
                if operation.done:
                    o.done_ms = self.now_ms()
                    self._finish(o, operation)
                    probe["done"], probe["status"] = True, o.status
                    break
                break
        except grpc.RpcError as e:
            probe["status"] = e.code().name
            if e.code() == grpc.StatusCode.NOT_FOUND:
                probe["stage"] = "NOT_FOUND"
        finally:
            call.cancel()
        o.probes.append(probe)
        return probe["done"]

    # -- inputs-present check for failures -------------------------------- #
    def check_inputs(self):
        for o in self.observed.values():
            if o.status not in (None, "OK") and o.status not in CLIENT_SIDE:
                try:
                    o.missing = self._client().find_missing(self.input_digests[o.id])
                    o.inputs_present = not o.missing
                except grpc.RpcError as e:
                    o.inputs_present = None
                    o.missing = [f"find-missing failed: {e.code().name}"]

    # -- driver ----------------------------------------------------------- #
    def run(self):
        store = self.manifest.get("object_store")
        if store:
            # A throttle a previous run left switched on would be attributed to this one.
            control_post(store["control_url"], "/throttle", {"on": False})
            control_post(store["control_url"], "/reset", {})
        self.prepare()
        actions = [s for s in self.steps if s["step"] == "action"]
        controls = [s for s in self.steps if s["step"] in CONTROL_STEPS]
        self.t0 = time.monotonic() + 0.2
        threads = [threading.Thread(target=self._guarded, args=(self.run_action, s), daemon=True) for s in actions]
        threads += [threading.Thread(target=self._guarded, args=(self.run_control, s), daemon=True) for s in controls]
        try:
            for t in threads:
                t.start()
            for t in threads:
                t.join()
        finally:
            self.undo_active_faults()
        if self.errors:
            raise RuntimeError("scenario thread failed; run is inconclusive: " + json.dumps(self.errors[:5]))
        self.probe_detached()
        time.sleep(self.limits.settle_ms / 1000)
        self.check_inputs()
        observations = {
            "version": 1,
            "nonce": self.nonce,
            "rig": {k: self.manifest.get(k) for k in ("backend", "workers", "slots", "memory_kb", "worker_cache_bytes",
                                                        "scheduler", "nativelink_sha256")},
            "limits": dataclasses.asdict(self.limits),
            "actions": [o.as_dict() for o in self.observed.values()],
            "controls": sorted(self.controls, key=lambda c: c["start_ms"]),
            "store": control_get(store["control_url"], "/stats") if store else None,
        }
        if self.out:
            self.out.mkdir(parents=True, exist_ok=True)
            (self.out / "observations.json").write_text(json.dumps(observations, indent=2) + "\n")
        self._client().close()
        return observations


def control_post(base, path, payload):
    data = json.dumps(payload).encode()
    request = urllib.request.Request(base.rstrip("/") + path, data=data, method="POST",
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read() or b"{}")


def control_get(base, path):
    with urllib.request.urlopen(base.rstrip("/") + path, timeout=5) as response:
        return json.loads(response.read() or b"{}")


def _code_name(code):
    for member in grpc.StatusCode:
        if member.value[0] == code:
            return member.name
    return str(code)


# ---------------------------------------------------------------------------
# The invariants, as a pure function of the observations.
# ---------------------------------------------------------------------------
def evaluate(observations, limits=None):
    """Return the list of findings for one scenario's observations. Pure and
    deterministic: the same observations and limits always give the same
    findings, so a frozen witness re-evaluates identically."""
    lim = limits or Limits(**observations["limits"])
    actions = sorted(observations["actions"], key=lambda a: (a["submit_ms"] if a["submit_ms"] is not None else 1 << 60, a["id"]))
    findings = []
    controls = observations.get("controls", [])
    for a in actions:
        if a["submit_ms"] is None:
            continue
        findings.extend(_queue_findings(a, actions, lim, controls))
        findings.extend(_executing_findings(a, lim, controls))
        findings.extend(_failure_findings(a, controls, lim))
        findings.extend(_throttle_findings(a, controls, lim))
    return sorted(findings, key=lambda f: (f["signature"], f["action"]))


def _faulted_ms(start, end, controls, kinds=CONTROL_STEPS):
    """Milliseconds of [start, end) that fall inside a control-fault window of
    one of `kinds`. n.b. A fault's direct effect is not a scheduler decision:
    nothing dispatches while the store is paused, every slot is held by a
    retrying fetch while the store throttles. The invariants measure what the
    scheduler does outside and after a fault, so that time is discounted from
    the queue-age and executing bounds. The throttle invariants (12, 13) look
    inside the window on purpose."""
    total = 0
    for c in controls:
        if c.get("step") not in kinds:
            continue
        lo, hi = max(start, c["start_ms"]), min(end, c["end_ms"])
        if hi > lo:
            total += hi - lo
    return total


def _throttle_windows(controls):
    return [c for c in controls if c.get("step") == "store-throttle"]


def _in_window(ms, windows, tail_ms=0):
    return any(w["start_ms"] <= ms <= w["end_ms"] + tail_ms for w in windows)


def _wait_ms(a, controls):
    end = a["executing_ms"] if a["executing_ms"] is not None else a["last_ms"]
    if end is None:
        return None
    return end - a["submit_ms"] - _faulted_ms(a["submit_ms"], end, controls)


def _queue_findings(a, actions, lim, controls=()):
    wait = _wait_ms(a, controls)
    if wait is None or wait <= lim.queue_age_ms:
        return []
    # n.b. An overtake has to be a decision, not a wobble: a later submission
    # dispatched at least OVERTAKE_MARGIN_MS before this action (or while this
    # action never ran). Sub-second ordering among actions that were all waiting
    # for the same slot is not starvation.
    overtaken_by = [b["id"] for b in actions
                    if b["id"] != a["id"] and b["submit_ms"] is not None and b["submit_ms"] > a["submit_ms"]
                    and b["executing_ms"] is not None
                    and (a["executing_ms"] is None or b["executing_ms"] + OVERTAKE_MARGIN_MS < a["executing_ms"])]
    evidence = {"wait_ms": wait, "bound_ms": lim.queue_age_ms, "dispatched": a["executing_ms"] is not None,
                "cpu": a["cpu"], "memory_kb": a["memory_kb"]}
    if overtaken_by:
        return [{"signature": "queue-starvation", "action": a["id"],
                 "kind": "an action waited past the bound while later submissions were dispatched ahead of it",
                 "evidence": {**evidence, "overtaken_by": overtaken_by[:12], "overtaken_count": len(overtaken_by)}}]
    at = a["submit_ms"] + lim.queue_age_ms
    inflight = [b for b in actions if b["submit_ms"] is not None and b["submit_ms"] <= at
                and (b["done_ms"] is None or b["done_ms"] > at)]
    fits = (sum(b["cpu"] for b in inflight) <= lim.workers * lim.slots
            and all(b["memory_kb"] <= lim.memory_kb for b in inflight)
            and sum(b["memory_kb"] for b in inflight) <= lim.workers * lim.memory_kb)
    if fits:
        return [{"signature": "dispatch-stall", "action": a["id"],
                 "kind": "an action waited past the bound although the fleet had room for everything in flight",
                 "evidence": {**evidence, "inflight": len(inflight), "capacity_slots": lim.workers * lim.slots}}]
    return []


def _executing_findings(a, lim, controls=()):
    if a["executing_ms"] is None or a["done_ms"] is not None:
        return []
    last = a["last_ms"]
    if last is None or a["last_stage"] != "EXECUTING":
        return []
    executing = last - a["executing_ms"] - _faulted_ms(a["executing_ms"], last, controls)
    if executing < lim.executing_ms:
        return []
    return [{"signature": "stuck-executing", "action": a["id"],
             "kind": "an operation stayed EXECUTING past the scheduler's executing timeout with no client attached",
             "evidence": {"executing_ms": a["executing_ms"], "last_seen_ms": last, "executing_outside_faults_ms": executing,
                          "bound_ms": lim.executing_ms, "operation": a["operation"], "detached": a["detached"],
                          "probes": len(a["probes"])}}]


def _failure_findings(a, controls=(), lim=None):
    status = a["status"]
    if status in (None, "OK") or status in CLIENT_SIDE or not a.get("inputs_present"):
        return []
    evidence = {"status": status, "message": a["message"][:300], "exit_code": a["exit_code"]}
    if EVICTION_TEXT.search(a["message"] or ""):
        return [{"signature": "input-evicted-failure", "action": a["id"],
                 "kind": "an action failed on a worker-local eviction while every input was present in the CAS",
                 "evidence": evidence}]
    failed_at = a["done_ms"] if a["done_ms"] is not None else a["last_ms"]
    # A failure answered while a control fault was active (a scheduler store
    # refusing a new action with OOM, say) is the fault's own honest effect.
    if failed_at is not None and _faulted_ms(failed_at, failed_at + 1, controls):
        return []
    # A store-fetch failure during a throttle is invariant 12's business.
    if (failed_at is not None and STORE_FETCH_TEXT.search(a["message"] or "")
            and _in_window(failed_at, _throttle_windows(controls), tail_ms=5000)):
        return []
    return [{"signature": f"action-failed-inputs-present:{status}", "action": a["id"],
             "kind": "an action failed server-side while every input was present in the CAS",
             "evidence": evidence}]


def _throttle_findings(a, controls, lim):
    """Invariants 12 and 13: an object-store throttle shorter than the worker's
    download budget must neither fail an action whose inputs are present nor
    bounce it to another worker; the store said "retry later"."""
    windows = [w for w in _throttle_windows(controls) if w["end_ms"] - w["start_ms"] < lim.download_budget_ms]
    # n.b. Unknown presence counts as absent: a failed action whose inputs were
    # never confirmed present is not attributed to the throttle.
    if not windows or (not a.get("inputs_present") and a["status"] not in (None, "OK")):
        return []
    findings = []
    failed_at = a["done_ms"] if a["done_ms"] is not None else a["last_ms"]
    status = a["status"]
    if (status not in (None, "OK") and status not in CLIENT_SIDE and a.get("inputs_present")
            and failed_at is not None and STORE_FETCH_TEXT.search(a["message"] or "")
            and _in_window(failed_at, windows, tail_ms=5000)):
        findings.append({"signature": "store-throttle-giveup", "action": a["id"],
                         "kind": "an input fetch failed during an object-store throttle shorter than the "
                                 "worker's download budget",
                         "evidence": {"status": status, "message": a["message"][:300], "failed_at_ms": failed_at,
                                      "throttle": [{"start_ms": w["start_ms"], "end_ms": w["end_ms"]} for w in windows],
                                      "download_budget_ms": lim.download_budget_ms}})
    bounced = [t for t in a.get("requeues", []) if _in_window(t, windows, tail_ms=5000)]
    if bounced:
        findings.append({"signature": "store-throttle-redispatch", "action": a["id"],
                         "kind": "an action was requeued to another worker because of an object-store throttle "
                                 "instead of being retried in place",
                         "evidence": {"requeues_ms": bounced[:12], "requeue_count": len(bounced),
                                      "final_status": status,
                                      "throttle": [{"start_ms": w["start_ms"], "end_ms": w["end_ms"]} for w in windows]}})
    return findings


def signatures(findings):
    return sorted({f["signature"] for f in findings})


# ---------------------------------------------------------------------------
# CLI: `run` for ad-hoc scenarios, `check` as the minimize checker.
# ---------------------------------------------------------------------------
def load_manifest(path):
    return json.loads(pathlib.Path(path).read_text())


def run_scenario(steps, manifest, limits, out_dir=None, fresh=False, rig_path=None):
    """Replay steps against the rig named by manifest; returns (observations,
    findings). Raises on anything that makes the run inconclusive."""
    if fresh:
        rig = fleet_rig.Rig.restart(rig_path)
        manifest = rig.manifest
    if not fleet_rig.healthy(manifest):
        raise RuntimeError("rig is not healthy; refusing to attribute anything to the scheduler")
    reasons = validate_steps(steps, manifest)
    if reasons:
        raise StepError("; ".join(reasons))
    observations = Scenario(steps, manifest, limits, out_dir).run()
    if not fleet_rig.healthy(manifest):
        raise RuntimeError("rig became unhealthy during the scenario (process died?)")
    return observations, evaluate(observations, limits)


def add_limit_args(parser):
    parser.add_argument("--queue-age-ms", type=int, default=6000, help="invariant 8/9 wait bound")
    parser.add_argument("--executing-ms", type=int, default=0,
                        help="invariant 10 bound (0 = rig's executing+worker timeouts + 5s)")
    parser.add_argument("--settle-ms", type=int, default=3000)
    parser.add_argument("--download-budget-ms", type=int, default=0,
                        help="invariant 12 bound (0 = rig worker's max_download_timeout_s)")


def limits_from_args(args, manifest):
    return Limits.for_rig(manifest, queue_age_ms=args.queue_age_ms, executing_ms=args.executing_ms or None,
                          settle_ms=args.settle_ms, download_budget_ms=args.download_budget_ms or None)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run", help="replay a steps file and print findings JSON")
    run.add_argument("--rig", required=True)
    run.add_argument("--steps", required=True)
    run.add_argument("--out", default="", help="evidence directory (observations.json)")
    run.add_argument("--fresh", action="store_true", help="restart the rig with fresh state first")
    add_limit_args(run)
    check = sub.add_parser("check", help="minimize checker: reads $RECHAOS_STEPS, writes $RECHAOS_VERDICT")
    check.add_argument("--rig", required=True)
    check.add_argument("--signature", required=True)
    check.add_argument("--fresh", action="store_true", help="restart the rig with fresh state per trial")
    add_limit_args(check)
    args = parser.parse_args()

    manifest = load_manifest(args.rig)
    limits = limits_from_args(args, manifest)
    if args.command == "run":
        steps = read_steps(args.steps)
        observations, findings = run_scenario(steps, manifest, limits, args.out or None, args.fresh, args.rig)
        print(json.dumps({"findings": findings, "signatures": signatures(findings),
                          "actions": len(observations["actions"])}, indent=2))
        return 0
    steps_path, verdict_path = os.environ.get("RECHAOS_STEPS"), os.environ.get("RECHAOS_VERDICT")
    if not steps_path or not verdict_path:
        log("check needs RECHAOS_STEPS and RECHAOS_VERDICT in the environment")
        return 2
    try:
        steps = read_steps(steps_path)
        _, findings = run_scenario(steps, manifest, limits, None, args.fresh, args.rig)
    except Exception as e:  # inconclusive: no verdict, non-zero exit -> Unknown to the minimizer
        log(f"inconclusive trial: {type(e).__name__}: {e}")
        return 3
    found = signatures(findings)
    verdict = ({"verdict": "triggers", "signature": args.signature} if args.signature in found
               else {"verdict": "does-not-trigger", "observed": found})
    pathlib.Path(verdict_path).write_text(json.dumps(verdict) + "\n")
    log(f"verdict: {verdict}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
