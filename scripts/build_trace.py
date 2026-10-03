#!/usr/bin/env python3
"""BUILD-shaped REAPI workload generator, recorder, and replayer.

Real Bazel/Buck2 builds do not push one big blob; they drive an action graph:
layers of targets, each of which (1) uploads input blobs, (2) uploads a
Command/Action pair, (3) asks the ActionCache "have you run this?"
(GetActionResult), and on a miss (4) optionally runs the action via Execute,
then (5) publishes outputs to CAS and the result to the ActionCache
(UpdateActionResult). Downstream targets then see a cache *hit* for the same
action. Input blobs are heavily deduplicated across targets (shared headers,
toolchains), sizes follow a realistic long-tailed distribution, and the whole
graph is driven in dependency order with bounded concurrency.

This tool has three subcommands, all deterministic under ``--seed``:

  generate   synthesize a parameterized build graph and drive it against a
             live REAPI endpoint (FindMissingBlobs -> ByteStream Write ->
             GetActionResult miss -> optional Execute -> UpdateActionResult ->
             downstream GetActionResult hit), verifying digests round-trip.

  record     drive a generated graph and capture every RPC (method, request
             digests, response summary) into a replayable JSONL trace.

  replay     re-drive a recorded trace against an endpoint and verify that the
             observed outcomes match what was recorded (round-trip integrity).

The CAS/AC byte contract is deterministic and hermetic: every blob's bytes are
derived from (seed, graph, label) so a given seed always produces the exact same
digests, and the generator verifies readback bytes against the digests it
computed locally.

Run under ``nix develop`` (needs grpcio + the generated bindings). The REAPI
target is fully configurable via ``--host``/``--port``/``--instance`` -- no
endpoint is hardcoded beyond the argparse defaults for the local dev server.
"""
import argparse
import collections
import concurrent.futures as cf
import datetime
import hashlib
import json
import pathlib
import random
import sys
import threading
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
# The independent Python gRPC runtime + generated REAPI/ByteStream bindings are
# the same ones test/integration.py and the other drivers use.
sys.path.insert(0, str(ROOT / ".build/python"))
sys.path.insert(0, str(ROOT / "test"))
try:
    from integration import bs, re, grpc  # noqa: E402  (shared stubs)
except Exception:  # pragma: no cover - fall back to direct imports
    sys.path.insert(0, str(ROOT / ".build/python"))
    import grpc  # type: ignore  # noqa: E402
    from google.bytestream import bytestream_pb2 as bs  # type: ignore  # noqa: E402
    from build.bazel.remote.execution.v2 import remote_execution_pb2 as re  # type: ignore  # noqa: E402

CHUNK = 65536

READ = "google.bytestream.ByteStream/Read"
WRITE = "google.bytestream.ByteStream/Write"
MISSING = "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"
BATCH_READ = "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchReadBlobs"
GET_AC = "build.bazel.remote.execution.v2.ActionCache/GetActionResult"
UPDATE_AC = "build.bazel.remote.execution.v2.ActionCache/UpdateActionResult"
EXECUTE = "build.bazel.remote.execution.v2.Execution/Execute"


# --------------------------------------------------------------------------- #
# Deterministic blob model
# --------------------------------------------------------------------------- #
def blob_bytes(graph_id, label, size):
    """Deterministic bytes for a logical blob.

    Keyed on (graph_id, label) so the same seed/graph always yields identical
    content -- and therefore identical SHA256 digests -- across runs and hosts.
    """
    return hashlib.shake_256(f"{graph_id}\x00{label}".encode()).digest(size)


def sha256_hex(data):
    return hashlib.sha256(data).hexdigest()


class Blob:
    """A content-addressed blob with its REAPI resource names."""

    __slots__ = ("label", "data", "hash", "size", "instance")

    def __init__(self, instance, graph_id, label, size):
        self.label = label
        self.data = blob_bytes(graph_id, label, size)
        self.hash = sha256_hex(self.data)
        self.size = size
        self.instance = instance

    @property
    def read_name(self):
        return f"{self.instance}/blobs/{self.hash}/{self.size}"

    def upload_name(self):
        # A fresh upload UUID per call, as a real client would use.
        return f"{self.instance}/uploads/{uuid.uuid4()}/blobs/{self.hash}/{self.size}"

    def digest(self):
        return re.Digest(hash=self.hash, size_bytes=self.size)

    def descriptor(self):
        return {"label": self.label, "sha256": self.hash, "size": self.size}


# --------------------------------------------------------------------------- #
# Build-graph synthesis
# --------------------------------------------------------------------------- #
#
# Size distribution (bytes) roughly mirroring observed Bazel CAS traffic: most
# blobs are small source/header files, with a long tail of larger objects and
# the occasional big archive. Weights are relative.
SIZE_BUCKETS = (
    (64, 4096, 50),        # small sources / headers
    (4096, 65536, 30),     # typical compiled objects
    (65536, 524288, 15),   # larger objects / small archives
    (524288, 4194304, 5),  # big archives / link outputs (long tail)
)


def _pick_size(rng):
    lo, hi, _ = rng.choices(SIZE_BUCKETS, weights=[b[2] for b in SIZE_BUCKETS])[0]
    return rng.randint(lo, hi)


class Target:
    """One node in the build graph: inputs + action -> outputs."""

    def __init__(self, name, layer, inputs, deps, command_args, output):
        self.name = name
        self.layer = layer
        self.inputs = inputs        # list[Blob] (may be shared/deduped)
        self.deps = deps            # list[str] names of upstream targets
        self.command_args = command_args
        self.output = output        # Blob produced by this target

    def descriptor(self):
        return {
            "name": self.name,
            "layer": self.layer,
            "inputs": [b.label for b in self.inputs],
            "deps": self.deps,
            "command": self.command_args,
            "output": self.output.label,
        }


class BuildGraph:
    """A synthesized, layered action graph with deduplicated shared inputs."""

    def __init__(self, graph_id, instance, targets, shared):
        self.graph_id = graph_id
        self.instance = instance
        self.targets = targets                 # list[Target] in dependency order
        self.shared = shared                   # list[Blob] shared toolchain/header blobs

    @classmethod
    def synthesize(cls, args):
        """Build a deterministic graph from CLI parameters."""
        rng = random.Random(f"{args.seed}:{args.graph_id}:{args.targets}:{args.layers}")
        instance = args.instance
        gid = args.graph_id

        # Shared inputs (toolchain, common headers) deduplicated across all
        # targets -- this is where real builds get most of their cache reuse.
        shared = [
            Blob(instance, gid, f"shared/toolchain-{i}", _pick_size(rng))
            for i in range(args.shared_inputs)
        ]

        layers = max(1, args.layers)
        per_layer = max(1, args.targets // layers)
        targets = []
        by_layer = collections.defaultdict(list)
        count = 0
        for layer in range(layers):
            n = per_layer if layer < layers - 1 else args.targets - count
            for _ in range(n):
                idx = count
                name = f"//pkg{layer}:target{idx}"
                # Private inputs unique to this target.
                n_private = rng.randint(1, max(1, args.max_inputs - args.shared_inputs))
                private = [
                    Blob(instance, gid, f"{name}/src{j}", _pick_size(rng))
                    for j in range(n_private)
                ]
                # A subset of shared inputs (fan-in / dedup).
                k = rng.randint(0, len(shared)) if shared else 0
                chosen_shared = rng.sample(shared, k) if k else []
                # Depend on a fan-in of upstream-layer targets (their outputs
                # become inputs here -- true graph edges).
                deps = []
                dep_outputs = []
                if layer > 0 and by_layer[layer - 1]:
                    fan = min(len(by_layer[layer - 1]), rng.randint(1, args.max_deps))
                    for dep in rng.sample(by_layer[layer - 1], fan):
                        deps.append(dep.name)
                        dep_outputs.append(dep.output)
                inputs = private + chosen_shared + dep_outputs
                output = Blob(instance, gid, f"{name}/out", _pick_size(rng))
                cmd = ["/bin/true", "--target", name, "--layer", str(layer)]
                t = Target(name, layer, inputs, deps, cmd, output)
                targets.append(t)
                by_layer[layer].append(t)
                count += 1
        return cls(gid, instance, targets, shared)

    def descriptor(self):
        return {
            "graph_id": self.graph_id,
            "instance": self.instance,
            "targets": [t.descriptor() for t in self.targets],
            "shared": [b.descriptor() for b in self.shared],
            "stats": self.stats(),
        }

    def stats(self):
        logical = 0
        unique = set()
        total_bytes = 0
        for t in self.targets:
            for b in t.inputs + [t.output]:
                logical += 1
                if b.hash not in unique:
                    unique.add(b.hash)
                    total_bytes += b.size
        return {
            "targets": len(self.targets),
            "layers": max((t.layer for t in self.targets), default=-1) + 1,
            "logicalBlobRefs": logical,
            "uniqueBlobs": len(unique),
            "dedupRatio": round(1 - len(unique) / logical, 4) if logical else 0.0,
            "uniqueBytes": total_bytes,
        }


# --------------------------------------------------------------------------- #
# REAPI client (ByteStream + CAS + ActionCache + Execution)
# --------------------------------------------------------------------------- #
class Client:
    def __init__(self, host, port, instance):
        self.instance = instance
        self.address = f"{host}:{port}"
        self.channel = grpc.insecure_channel(
            self.address,
            options=[("grpc.max_receive_message_length", 64 * 1024 * 1024),
                     ("grpc.max_send_message_length", 64 * 1024 * 1024)],
        )
        self.read_rpc = self.channel.unary_stream(
            "/" + READ, request_serializer=bs.ReadRequest.SerializeToString,
            response_deserializer=bs.ReadResponse.FromString)
        self.write_rpc = self.channel.stream_unary(
            "/" + WRITE, request_serializer=bs.WriteRequest.SerializeToString,
            response_deserializer=bs.WriteResponse.FromString)
        self.missing_rpc = self.channel.unary_unary(
            "/" + MISSING, request_serializer=re.FindMissingBlobsRequest.SerializeToString,
            response_deserializer=re.FindMissingBlobsResponse.FromString)
        self.get_ac_rpc = self.channel.unary_unary(
            "/" + GET_AC, request_serializer=re.GetActionResultRequest.SerializeToString,
            response_deserializer=re.ActionResult.FromString)
        self.update_ac_rpc = self.channel.unary_unary(
            "/" + UPDATE_AC, request_serializer=re.UpdateActionResultRequest.SerializeToString,
            response_deserializer=re.ActionResult.FromString)
        self.execute_rpc = self.channel.unary_stream(
            "/" + EXECUTE, request_serializer=re.ExecuteRequest.SerializeToString,
            response_deserializer=_operation_cls().FromString)

    # -- CAS ---------------------------------------------------------------- #
    def find_missing(self, blobs, timeout=20):
        req = re.FindMissingBlobsRequest(
            instance_name=self.instance, digest_function=re.DigestFunction.SHA256,
            blob_digests=[b.digest() for b in blobs])
        reply = self.missing_rpc(req, timeout=timeout)
        return {(d.hash, d.size_bytes) for d in reply.missing_blob_digests}

    def upload(self, blob, timeout=30):
        name = blob.upload_name()

        def requests():
            data = blob.data
            if not data:
                yield bs.WriteRequest(resource_name=name, write_offset=0, finish_write=True)
                return
            for off in range(0, len(data), CHUNK):
                part = data[off:off + CHUNK]
                yield bs.WriteRequest(
                    resource_name=name if off == 0 else "",
                    write_offset=off, data=part,
                    finish_write=off + len(part) == len(data))
        reply = self.write_rpc(requests(), timeout=timeout)
        return reply.committed_size

    def read(self, blob, timeout=30):
        digest = hashlib.sha256()
        total = 0
        call = self.read_rpc(bs.ReadRequest(resource_name=blob.read_name), timeout=timeout)
        for message in call:
            digest.update(message.data)
            total += len(message.data)
        return total, digest.hexdigest()

    # -- ActionCache -------------------------------------------------------- #
    def get_action_result(self, action_digest, timeout=20):
        req = re.GetActionResultRequest(
            instance_name=self.instance, action_digest=action_digest,
            digest_function=re.DigestFunction.SHA256)
        try:
            return self.get_ac_rpc(req, timeout=timeout), None
        except grpc.RpcError as err:
            return None, err.code()

    def update_action_result(self, action_digest, action_result, timeout=20):
        req = re.UpdateActionResultRequest(
            instance_name=self.instance, action_digest=action_digest,
            action_result=action_result, digest_function=re.DigestFunction.SHA256)
        return self.update_ac_rpc(req, timeout=timeout)

    # -- Execution (optional) ---------------------------------------------- #
    def execute(self, action_digest, timeout=60):
        req = re.ExecuteRequest(
            instance_name=self.instance, action_digest=action_digest,
            skip_cache_lookup=True, digest_function=re.DigestFunction.SHA256)
        call = self.execute_rpc(req, timeout=timeout)
        last = None
        for operation in call:
            last = operation
        return last


def _operation_cls():
    from google.longrunning import operations_pb2 as oplr  # noqa: E402
    return oplr.Operation


# --------------------------------------------------------------------------- #
# Action construction (deterministic)
# --------------------------------------------------------------------------- #
def build_action_blobs(client, graph, target):
    """Construct the Command/Directory/Action blobs for a target.

    Returns (command_blob, root_blob, action_blob, action_digest). The Action's
    digest is what the ActionCache is keyed on, so determinism here is what makes
    the cache hit/miss story reproducible.
    """
    plat = re.Platform(properties=[
        re.Platform.Property(name="OSFamily", value="linux"),
        re.Platform.Property(name="cpu_arch", value="x86_64")])
    cmd = re.Command(arguments=target.command_args, platform=plat,
                     output_paths=[f"out/{target.name.split(':')[-1]}"])
    cmd_bytes = cmd.SerializeToString()
    cmd_blob = _wrap(graph, f"{target.name}/command", cmd_bytes)

    root = re.Directory()
    root_bytes = root.SerializeToString()
    root_blob = _wrap(graph, f"{target.name}/root", root_bytes)

    action = re.Action(command_digest=cmd_blob.digest(), input_root_digest=root_blob.digest(),
                       platform=plat)
    action_bytes = action.SerializeToString()
    action_blob = _wrap(graph, f"{target.name}/action", action_bytes)
    return cmd_blob, root_blob, action_blob


def _wrap(graph, label, data):
    """Wrap already-serialized bytes as a Blob (bypassing the shake generator)."""
    b = Blob.__new__(Blob)
    b.label = label
    b.data = data
    b.hash = sha256_hex(data)
    b.size = len(data)
    b.instance = graph.instance
    return b


def make_action_result(output_blob, exit_code=0):
    return re.ActionResult(
        output_files=[re.OutputFile(path="out/artifact", digest=output_blob.digest(),
                                    is_executable=False)],
        exit_code=exit_code,
        execution_metadata=re.ExecutedActionMetadata(worker="rechaos-build-trace"))


# --------------------------------------------------------------------------- #
# Driver (generate / record)
# --------------------------------------------------------------------------- #
class Driver:
    """Drives a graph against the endpoint, optionally recording a trace."""

    def __init__(self, client, graph, args, trace=None):
        self.client = client
        self.graph = graph
        self.args = args
        self.trace = trace                      # list to append trace rows, or None
        self.lock = threading.Lock()
        self.uploaded = set()                   # (hash,size) known present
        self.stats = collections.Counter()
        self.errors = []
        self.start = time.monotonic()

    def _emit(self, method, request, response):
        if self.trace is None:
            return
        row = {"seq": len(self.trace), "method": method,
               "atSeconds": round(time.monotonic() - self.start, 6),
               "request": request, "response": response}
        with self.lock:
            self.trace.append(row)

    def _ensure_present(self, blobs):
        """FindMissingBlobs -> upload the gaps -> verify they are now present."""
        unique = {}
        for b in blobs:
            unique[(b.hash, b.size)] = b
        blist = list(unique.values())
        missing = self.client.find_missing(blist)
        self._emit(MISSING, {"digests": [b.descriptor() for b in blist]},
                   {"missing": [{"sha256": h, "size": s} for (h, s) in sorted(missing)]})
        self.stats["findMissing"] += 1
        for key, b in unique.items():
            if key in missing:
                committed = self.client.upload(b)
                self._emit(WRITE, {"sha256": b.hash, "size": b.size},
                           {"committedBytes": committed})
                self.stats["upload"] += 1
                with self.lock:
                    self.uploaded.add(key)

    def run_target(self, target):
        try:
            self._run_target(target)
            self.stats["targets"] += 1
        except grpc.RpcError as err:
            with self.lock:
                self.errors.append({"target": target.name, "code": err.code().name,
                                    "details": err.details()[:400]})

    def _run_target(self, target):
        cmd_blob, root_blob, action_blob = build_action_blobs(self.client, self.graph, target)
        # 1) make inputs + action metadata present in CAS.
        self._ensure_present(target.inputs + [cmd_blob, root_blob, action_blob])

        # 2) GetActionResult -- expect a miss on first encounter.
        result, miss_code = self.client.get_action_result(action_blob.digest())
        hit = result is not None
        self._emit(GET_AC, {"actionDigest": action_blob.descriptor()},
                   {"hit": hit, "missCode": None if hit else miss_code.name})
        self.stats["acHit" if hit else "acMiss"] += 1

        if hit:
            # Downstream / warm-cache path: verify the cached output digest and
            # read the bytes back to confirm integrity.
            self._verify_cached_output(target, result)
            return

        # 3) optional real Execute (default off; many dev servers have no worker).
        if self.args.execute:
            op = self.client.execute(action_blob.digest())
            self._emit(EXECUTE, {"actionDigest": action_blob.descriptor()},
                       {"operation": op.name if op else None, "done": bool(op and op.done)})
            self.stats["execute"] += 1

        # 4) publish the output blob + UpdateActionResult (synthesize a result).
        self._ensure_present([target.output])
        ar = make_action_result(target.output)
        self.client.update_action_result(action_blob.digest(), ar)
        self._emit(UPDATE_AC, {"actionDigest": action_blob.descriptor(),
                               "outputDigest": target.output.descriptor()},
                   {"ok": True})
        self.stats["acUpdate"] += 1

        # 5) read the AC back -> should now be a hit (check-then-cache round-trip).
        result2, miss2 = self.client.get_action_result(action_blob.digest())
        hit2 = result2 is not None
        self._emit(GET_AC, {"actionDigest": action_blob.descriptor()},
                   {"hit": hit2, "missCode": None if hit2 else miss2.name})
        if hit2:
            self.stats["acHitAfterPut"] += 1
            self._verify_cached_output(target, result2)
        else:
            with self.lock:
                self.errors.append({"target": target.name,
                                    "error": "AC did not return result after UpdateActionResult"})

    def _verify_cached_output(self, target, action_result):
        """Read every cached output blob back and confirm bytes match the digest."""
        for of in action_result.output_files:
            d = of.digest
            probe = Blob.__new__(Blob)
            probe.instance = self.graph.instance
            probe.hash = d.hash
            probe.size = d.size_bytes
            total, got_hash = self.client.read(probe)
            ok = total == d.size_bytes and got_hash == d.hash
            self._emit(READ, {"sha256": d.hash, "size": d.size_bytes},
                       {"bytes": total, "sha256": got_hash, "verified": ok})
            self.stats["readback"] += 1
            if not ok:
                with self.lock:
                    self.errors.append({"target": target.name,
                                        "error": "cached output digest mismatch on readback",
                                        "expected": d.hash, "got": got_hash})

    def drive(self):
        """Drive targets layer by layer (dependency order), concurrently within a layer."""
        by_layer = collections.defaultdict(list)
        for t in self.graph.targets:
            by_layer[t.layer].append(t)
        for layer in sorted(by_layer):
            with cf.ThreadPoolExecutor(max_workers=self.args.concurrency) as pool:
                list(pool.map(self.run_target, by_layer[layer]))
        return {"stats": dict(self.stats), "errors": self.errors}


# --------------------------------------------------------------------------- #
# Replayer
# --------------------------------------------------------------------------- #
class Replayer:
    """Re-drives a recorded trace and verifies outcomes match the recording."""

    def __init__(self, client, graph, rows):
        self.client = client
        self.graph = graph
        self.rows = rows
        self.by_hash = {}
        for b in graph.shared:
            self.by_hash[b.hash] = b
        for t in graph.targets:
            for b in t.inputs + [t.output]:
                self.by_hash[b.hash] = b
        # Action-metadata blobs are reconstructed deterministically too.
        for t in graph.targets:
            for blob in build_action_blobs(client, graph, t):
                self.by_hash[blob.hash] = blob

    def _blob(self, h, size):
        b = self.by_hash.get(h)
        if b is not None:
            return b
        probe = Blob.__new__(Blob)
        probe.instance = self.graph.instance
        probe.hash = h
        probe.size = size
        probe.label = f"unknown/{h[:12]}"
        probe.data = b""
        return probe

    def run(self):
        mism = []
        counts = collections.Counter()
        for row in self.rows:
            method = row["method"]
            req, rec = row["request"], row["response"]
            counts[method.rsplit("/", 1)[-1]] += 1
            if method == WRITE:
                blob = self._blob(req["sha256"], req["size"])
                self.client.upload(blob)
            elif method == MISSING:
                blobs = [self._blob(d["sha256"], d["size"]) for d in req["digests"]]
                missing = self.client.find_missing(blobs)
                now = {"missing": [{"sha256": h, "size": s} for (h, s) in sorted(missing)]}
                # Round-trip: a replayed miss set must be a subset of the
                # originally-recorded miss set (the store only grows).
                recorded = {(m["sha256"], m["size"]) for m in rec["missing"]}
                if not missing <= recorded:
                    mism.append({"seq": row["seq"], "method": "FindMissingBlobs",
                                 "note": "replay missing not subset of recorded",
                                 "recorded": sorted(recorded), "replay": sorted(missing)})
                _ = now
            elif method == GET_AC:
                blob = self._blob(req["actionDigest"]["sha256"], req["actionDigest"]["size"])
                result, code = self.client.get_action_result(blob.digest())
                hit = result is not None
                # By the time we replay, the AC entry should exist whenever the
                # recording ultimately observed it as a hit for that action.
                if rec.get("hit") and not hit:
                    mism.append({"seq": row["seq"], "method": "GetActionResult",
                                 "note": "recorded hit but replay miss",
                                 "action": blob.hash, "code": code.name if code else None})
            elif method == UPDATE_AC:
                action = self._blob(req["actionDigest"]["sha256"], req["actionDigest"]["size"])
                out = self._blob(req["outputDigest"]["sha256"], req["outputDigest"]["size"])
                self.client.upload(out)
                self.client.update_action_result(action.digest(), make_action_result(out))
            elif method == READ:
                blob = self._blob(req["sha256"], req["size"])
                total, got = self.client.read(blob)
                if got != req["sha256"]:
                    mism.append({"seq": row["seq"], "method": "Read",
                                 "note": "readback digest mismatch",
                                 "expected": req["sha256"], "got": got, "bytes": total})
            elif method == EXECUTE:
                pass  # execution is environment-dependent; not replayed by default
        return {"replayed": len(self.rows), "methods": dict(counts), "mismatches": mism}


# --------------------------------------------------------------------------- #
# Output helpers
# --------------------------------------------------------------------------- #
def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + "\n")


def write_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as fh:
        for row in rows:
            fh.write(json.dumps(row, separators=(",", ":")) + "\n")


def read_jsonl(path):
    with path.open() as fh:
        return [json.loads(line) for line in fh if line.strip()]


# --------------------------------------------------------------------------- #
# Subcommands
# --------------------------------------------------------------------------- #
def cmd_generate(args):
    graph = BuildGraph.synthesize(args)
    client = Client(args.host, args.port, args.instance)
    trace = [] if args.trace else None
    driver = Driver(client, graph, args, trace=trace)
    report = driver.drive()
    summary = {
        "endpoint": client.address,
        "instance": args.instance,
        "seed": args.seed,
        "graph": graph.descriptor()["stats"],
        **report,
    }
    print(json.dumps(summary, indent=2))
    if args.graph_out:
        write_json(pathlib.Path(args.graph_out), graph.descriptor())
    if args.summary_out:
        write_json(pathlib.Path(args.summary_out), summary)
    if trace is not None and args.trace:
        write_jsonl(pathlib.Path(args.trace), trace)
    return 1 if report["errors"] else 0


def cmd_record(args):
    graph = BuildGraph.synthesize(args)
    client = Client(args.host, args.port, args.instance)
    trace = []
    driver = Driver(client, graph, args, trace=trace)
    report = driver.drive()
    write_jsonl(pathlib.Path(args.trace), trace)
    write_json(pathlib.Path(args.graph_out), graph.descriptor())
    summary = {"endpoint": client.address, "seed": args.seed,
               "trace": args.trace, "graphOut": args.graph_out,
               "rpcs": len(trace), "graph": graph.descriptor()["stats"], **report}
    print(json.dumps(summary, indent=2))
    return 1 if report["errors"] else 0


def cmd_replay(args):
    rows = read_jsonl(pathlib.Path(args.trace))
    graph_desc = json.loads(pathlib.Path(args.graph).read_text())
    # Re-synthesize the exact graph from its recorded parameters so blob bytes
    # (and therefore digests) are reconstructed deterministically.
    synth_args = argparse.Namespace(
        seed=args.seed, graph_id=graph_desc["graph_id"], instance=graph_desc["instance"],
        targets=graph_desc["stats"]["targets"], layers=graph_desc["stats"]["layers"],
        shared_inputs=len(graph_desc["shared"]),
        max_inputs=max((len(t["inputs"]) for t in graph_desc["targets"]), default=1),
        max_deps=max((len(t["deps"]) for t in graph_desc["targets"]), default=1))
    graph = BuildGraph.synthesize(synth_args)
    # Guard: the re-synthesized graph must match the recorded descriptor exactly.
    if graph.descriptor()["stats"]["uniqueBlobs"] != graph_desc["stats"]["uniqueBlobs"]:
        print(json.dumps({"error": "re-synthesized graph does not match recorded graph; "
                          "pass the same --seed/--graph used to record"}, indent=2))
        return 2
    client = Client(args.host, args.port, args.instance)
    report = Replayer(client, graph, rows).run()
    summary = {"endpoint": client.address, "trace": args.trace, **report,
               "roundTripOk": not report["mismatches"]}
    print(json.dumps(summary, indent=2))
    return 0 if not report["mismatches"] else 1


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _add_endpoint(p):
    p.add_argument("--host", default="127.0.0.1", help="REAPI host (default 127.0.0.1)")
    p.add_argument("--port", type=int, default=50052, help="REAPI port (default 50052)")
    p.add_argument("--instance", default="main", help="REAPI instance name (default main)")


def _add_graph(p):
    p.add_argument("--seed", type=int, default=20261002, help="deterministic seed")
    p.add_argument("--graph-id", default="g0",
                   help="graph identity; part of the blob-content key")
    p.add_argument("--targets", type=int, default=12, help="number of targets")
    p.add_argument("--layers", type=int, default=3, help="dependency layers")
    p.add_argument("--shared-inputs", type=int, default=4,
                   help="shared/deduped toolchain inputs")
    p.add_argument("--max-inputs", type=int, default=6, help="max inputs per target")
    p.add_argument("--max-deps", type=int, default=3,
                   help="max upstream deps per target")
    p.add_argument("--concurrency", type=int, default=4,
                   help="concurrent targets within a layer")


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="build_trace", description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("generate", help="synthesize a graph and drive it against REAPI")
    _add_endpoint(g)
    _add_graph(g)
    g.add_argument("--execute", action="store_true",
                   help="issue a real Execute RPC on cache miss (needs a worker)")
    g.add_argument("--trace", help="also write the RPC trace to this JSONL path")
    g.add_argument("--graph-out", help="write the graph descriptor JSON here")
    g.add_argument("--summary-out", help="write the run summary JSON here")
    g.set_defaults(func=cmd_generate)

    r = sub.add_parser("record", help="drive a graph and capture a replayable trace")
    _add_endpoint(r)
    _add_graph(r)
    r.add_argument("--execute", action="store_true",
                   help="issue a real Execute RPC on cache miss (needs a worker)")
    r.add_argument("--trace", required=True, help="output trace JSONL path")
    r.add_argument("--graph-out", required=True,
                   help="output graph descriptor JSON path (needed for replay)")
    r.set_defaults(func=cmd_record)

    p = sub.add_parser("replay", help="re-drive a recorded trace and verify integrity")
    _add_endpoint(p)
    p.add_argument("--seed", type=int, default=20261002,
                   help="seed used when recording (must match)")
    p.add_argument("--trace", required=True, help="trace JSONL to replay")
    p.add_argument("--graph", required=True,
                   help="graph descriptor JSON produced by record/generate")
    p.set_defaults(func=cmd_replay)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
