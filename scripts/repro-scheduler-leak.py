#!/usr/bin/env python3
"""Airtight, deterministic reproduction of the NativeLink scheduler queue-GC leak.

Completed actions are not garbage-collected out of the awaited-action store, even
after all clients disconnect and the completed-retention window elapses. The
scheduler's stage-transition count stays accurate; only the backing store leaks.

This is standalone (no fuzzer, no randomness): it runs N trivial actions to
COMPLETED on a real worker, confirms the awaited-action store holds N entries,
waits quietly past retain_completed_for_s, and asserts the store never drained.
A final "touch" (one more action) shows the stale entries evict on access —
proving the GC is access-triggered with no background timer.

Run against the single-process cluster in
examples/chaos/local-rbe-worker.json5 (stock NativeLink HEAD):

    nix develop --command python3 scripts/repro-scheduler-leak.py

Exit 0 = leak reproduced; exit 1 = store drained correctly (no leak).
"""
import argparse
import hashlib
import pathlib
import re
import sys
import time
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".build/python"))
import grpc  # noqa: E402
from build.bazel.remote.execution.v2 import remote_execution_pb2 as re_pb  # noqa: E402
from google.bytestream import bytestream_pb2 as bs  # noqa: E402
from google.longrunning import operations_pb2 as oplr  # noqa: E402

OP_FAMILY = re.compile(
    r"action_db_operation_ids_([0-9a-f]{8}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{12})")
DEFAULT_TRUE = "/usr/bin/true"


class Cluster:
    def __init__(self, host, port, metrics_port, instance, true_path):
        self.instance = instance
        self.true_path = true_path
        self.metrics_url = f"http://{host}:{metrics_port}/metrics"
        self.ch = grpc.insecure_channel(f"{host}:{port}")
        grpc.channel_ready_future(self.ch).result(timeout=10)
        self._write = self.ch.stream_unary("/google.bytestream.ByteStream/Write",
            request_serializer=bs.WriteRequest.SerializeToString,
            response_deserializer=bs.WriteResponse.FromString)
        self._execute = self.ch.unary_stream("/build.bazel.remote.execution.v2.Execution/Execute",
            request_serializer=re_pb.ExecuteRequest.SerializeToString,
            response_deserializer=oplr.Operation.FromString)

    def _upload(self, data):
        h = hashlib.sha256(data).hexdigest()
        pre = f"{self.instance}/" if self.instance else ""
        name = f"{pre}uploads/{uuid.uuid4()}/blobs/{h}/{len(data)}"
        self._write(iter([bs.WriteRequest(resource_name=name, write_offset=0,
                                          data=data, finish_write=True)]), timeout=10)
        return re_pb.Digest(hash=h, size_bytes=len(data))

    def run_action(self, salt, timeout=30):
        """Build a trivial /bin/true action and run it to a terminal state.
        Returns (stage, exit_code, grpc_status_code)."""
        plat = re_pb.Platform(properties=[re_pb.Platform.Property(name="cpu_count", value="1")])
        cmd_d = self._upload(re_pb.Command(arguments=[self.true_path], platform=plat).SerializeToString())
        root_d = self._upload(re_pb.Directory().SerializeToString())
        act_d = self._upload(re_pb.Action(command_digest=cmd_d, input_root_digest=root_d,
                                          do_not_cache=True, salt=salt, platform=plat).SerializeToString())
        req = re_pb.ExecuteRequest(instance_name=self.instance, action_digest=act_d,
                                   skip_cache_lookup=True, digest_function=re_pb.DigestFunction.SHA256)
        stage = exit_code = status = None
        for op in self._execute(req, timeout=timeout):
            md = re_pb.ExecuteOperationMetadata()
            if op.metadata.Is(md.DESCRIPTOR):
                op.metadata.Unpack(md)
                stage = md.stage
            if op.done:
                resp = re_pb.ExecuteResponse()
                if op.response.Is(resp.DESCRIPTOR):
                    op.response.Unpack(resp)
                    exit_code, status = resp.result.exit_code, resp.status.code
                break
        return stage, exit_code, status

    def store_occupancy(self):
        """Distinct per-operation metric families = awaited-action store size."""
        text = urllib.request.urlopen(self.metrics_url, timeout=5).read().decode()
        return len(set(OP_FAMILY.findall(text)))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=50090)
    p.add_argument("--metrics-port", type=int, default=0, help="default: --port")
    p.add_argument("--instance", default="")
    p.add_argument("--count", type=int, default=20, help="actions to run to completion")
    p.add_argument("--quiet-wait", type=float, default=20,
                   help="quiet seconds to wait after completion (must exceed retain_completed_for_s)")
    p.add_argument("--true-path", default=DEFAULT_TRUE)
    args = p.parse_args()
    mp = args.metrics_port or args.port
    c = Cluster(args.host, args.port, mp, args.instance, args.true_path)

    base = c.store_occupancy()
    print(f"[0] baseline awaited-action store occupancy: {base}", flush=True)

    print(f"[1] running {args.count} trivial actions to completion…", flush=True)
    stages = []
    exit_code = status = None
    for i in range(args.count):
        stage, exit_code, status = c.run_action(salt=i.to_bytes(8, "big"))
        stages.append(stage)
    completed = sum(1 for s in stages if s == 4)  # ExecutionStage.COMPLETED
    print(f"    {completed}/{args.count} reached COMPLETED (terminal). "
          f"last exit_code={exit_code} grpc_status={status}", flush=True)
    if completed == 0:
        print("ABORT: no action reached a terminal state; cannot test GC.", flush=True)
        return 2

    after = c.store_occupancy()
    print(f"[2] store occupancy immediately after completion: {after}", flush=True)

    print(f"[3] waiting {args.quiet_wait}s QUIET (no clients, past retain window)…", flush=True)
    time.sleep(args.quiet_wait)
    remained = c.store_occupancy()
    print(f"[4] store occupancy after quiet drain: {remained}", flush=True)

    leaked = remained - base
    if leaked <= 0:
        print(f"\nRESULT: NO LEAK — store drained to {remained} (baseline {base}). "
              f"GC reclaimed completed actions.", flush=True)
        return 1

    # Confirmation: one more action touches the EvictingMap.
    print(f"[5] leak suspected ({leaked} entries lingering); touching the map with one action…", flush=True)
    c.run_action(salt=b"touch")
    time.sleep(3)
    after_touch = c.store_occupancy()
    evicted = remained - after_touch
    print(f"    store occupancy after one touch: {after_touch} (evicted {evicted} stale on access)", flush=True)

    print("\n" + "=" * 72, flush=True)
    print("RESULT: SCHEDULER QUEUE-GC LEAK REPRODUCED", flush=True)
    print(f"  {completed} actions completed; store held {after} entries; after {args.quiet_wait}s quiet "
          f"it still held {remained} (baseline {base}) — {leaked} completed actions never GC'd.", flush=True)
    if evicted > 0:
        print(f"  A single subsequent map access evicted {evicted} of them ⇒ access-triggered GC "
              f"with no background timer (EvictingMap, no sweep task).", flush=True)
    print("=" * 72, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
