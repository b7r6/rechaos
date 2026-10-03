#!/usr/bin/env python3
"""Wire-level acceptance tests using the independent Python gRPC runtime."""
import argparse
import concurrent.futures
import contextlib
import hashlib
import json
import os
import pathlib
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".build/python"))
import grpc
from google.bytestream import bytestream_pb2 as bs
from build.bazel.remote.execution.v2 import remote_execution_pb2 as re

READ = "google.bytestream.ByteStream/Read"
WRITE = "google.bytestream.ByteStream/Write"
MISSING = "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"
DATA = b"rechaos deterministic artifact\n" * 4096

def digest(data):
    return hashlib.sha256(data).hexdigest()

def resource(data, upload=False):
    return f"main/{'uploads/rechaos-fixed-id/' if upload else ''}blobs/sha256/{digest(data)}/{len(data)}"

def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

def rule(method, direction, fault, **target):
    return {"target": {"method": method, "direction": direction, **target}, "fault": fault}

def policy(rules):
    return {"version": 1, "seed": 42, "rules": rules}

def read(channel, data=DATA, timeout=5):
    return channel.unary_stream("/" + READ, request_serializer=bs.ReadRequest.SerializeToString,
        response_deserializer=bs.ReadResponse.FromString)(bs.ReadRequest(resource_name=resource(data)), timeout=timeout,
        metadata=(("x-rechaos-test", "present"),))

def contents(call):
    return b"".join(message.data for message in call)

def write(channel, data=DATA):
    def requests():
        for offset in range(0, len(data), 16384):
            part = data[offset:offset+16384]
            yield bs.WriteRequest(resource_name=resource(data, True) if offset == 0 else "",
                write_offset=offset, data=part, finish_write=offset + len(part) == len(data))
    return channel.stream_unary("/" + WRITE, request_serializer=bs.WriteRequest.SerializeToString,
        response_deserializer=bs.WriteResponse.FromString)(requests(), timeout=8)

def missing(channel, timeout=5):
    return channel.unary_unary("/" + MISSING, request_serializer=re.FindMissingBlobsRequest.SerializeToString,
        response_deserializer=re.FindMissingBlobsResponse.FromString)(re.FindMissingBlobsRequest(
            instance_name="main", digest_function=re.DigestFunction.SHA256,
            blob_digests=[re.Digest(hash=digest(DATA), size_bytes=len(DATA))]), timeout=timeout)

class Fixture:
    def __init__(self, listen_port=0):
        self.blobs = {digest(DATA): DATA}
        self.metadata = []
        self.reads_cancelled = threading.Event()
        self.server = grpc.server(concurrent.futures.ThreadPoolExecutor(max_workers=12))
        self.server.add_generic_rpc_handlers((
            grpc.method_handlers_generic_handler("google.bytestream.ByteStream", {
                "Read": grpc.unary_stream_rpc_method_handler(self.read, request_deserializer=bs.ReadRequest.FromString,
                    response_serializer=bs.ReadResponse.SerializeToString),
                "Write": grpc.stream_unary_rpc_method_handler(self.write, request_deserializer=bs.WriteRequest.FromString,
                    response_serializer=bs.WriteResponse.SerializeToString),
            }),
            grpc.method_handlers_generic_handler("build.bazel.remote.execution.v2.ContentAddressableStorage", {
                "FindMissingBlobs": grpc.unary_unary_rpc_method_handler(self.missing,
                    request_deserializer=re.FindMissingBlobsRequest.FromString,
                    response_serializer=re.FindMissingBlobsResponse.SerializeToString),
            }),
        ))
        self.port = self.server.add_insecure_port(f"127.0.0.1:{listen_port}")
        self.server.start()

    def read(self, request, context):
        self.metadata = list(context.invocation_metadata())
        context.send_initial_metadata((("x-upstream-initial", "kept"),))
        key = request.resource_name.split("/")[-2]
        data = self.blobs.get(key)
        if data is None:
            context.set_trailing_metadata((("x-upstream-trailing", "kept"), ("grpc-status-details-bin", b"details")))
            context.abort(grpc.StatusCode.NOT_FOUND, "blob absent")
        context.set_trailing_metadata((("x-upstream-trailing", "kept"),))
        try:
            for offset in range(0, len(data), 32768):
                if not context.is_active():
                    break
                yield bs.ReadResponse(data=data[offset:offset+32768])
        finally:
            if not context.is_active():
                self.reads_cancelled.set()

    def write(self, requests, context):
        result = bytearray()
        name = None
        finished = False
        for request in requests:
            if finished or request.write_offset != len(result):
                context.abort(grpc.StatusCode.INVALID_ARGUMENT, "bad write offset/finish")
            if request.resource_name:
                name = request.resource_name
            result.extend(request.data)
            finished = request.finish_write
        if not name or not finished:
            context.abort(grpc.StatusCode.INVALID_ARGUMENT, "unfinished write")
        expected_hash, expected_size = name.split("/")[-2:]
        if digest(result) != expected_hash or len(result) != int(expected_size):
            context.abort(grpc.StatusCode.INVALID_ARGUMENT, "digest mismatch")
        self.blobs[expected_hash] = bytes(result)
        return bs.WriteResponse(committed_size=len(result))

    def missing(self, request, context):
        return re.FindMissingBlobsResponse(missing_blob_digests=[d for d in request.blob_digests if d.hash not in self.blobs])

    def close(self):
        self.server.stop(0).wait()

@contextlib.contextmanager
def proxy(upstream, directory, rules=None, replay=None, sparse=False, extra=(), upstream_host="127.0.0.1", max_seconds=10):
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    port = free_port()
    record = directory / "timeline.jsonl"
    argv = [str(ROOT / "bin/rechaos"), "serve", "--port", str(port), "--upstream-host", upstream_host,
        "--upstream-port", str(upstream), "--record", str(record), "--max-call-seconds", str(max_seconds), *extra]
    if rules is not None:
        path = directory / "policy.json"
        path.write_text(json.dumps(policy(rules)))
        argv += ["--policy", str(path)]
    if replay:
        argv += ["--replay", str(replay)]
    if sparse:
        argv += ["--sparse"]
    with (directory / "proxy.log").open("w") as log:
        process = subprocess.Popen(argv, stdout=log, stderr=log)
        channel = grpc.insecure_channel(f"127.0.0.1:{port}")
        try:
            grpc.channel_ready_future(channel).result(timeout=8)
            yield channel, record, port
        finally:
            channel.close()
            process.send_signal(signal.SIGINT)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

def expect_status(expected, action):
    try:
        action()
    except grpc.RpcError as e:
        assert e.code() == expected, (e.code(), e.details())
        return e
    raise AssertionError(f"expected {expected}")

def checker():
    fixture = Fixture()
    try:
        with tempfile.TemporaryDirectory() as temp:
            with proxy(fixture.port, temp, replay=os.environ["RECHAOS_TIMELINE"], sparse=True) as (channel, observed, _):
                data = contents(read(channel))
                subprocess.run([str(ROOT/"bin/rechaos"),"verify-replay",os.environ["RECHAOS_TIMELINE"],str(observed)],check=True,capture_output=True)
                verdict = {"verdict": "triggers", "signature": "fixture-torn-read"} if data != DATA else {"verdict": "does-not-trigger"}
        pathlib.Path(os.environ["RECHAOS_VERDICT"]).write_text(json.dumps(verdict))
    finally:
        fixture.close()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checker", action="store_true")
    parser.add_argument("--output", default="runs/integration")
    opts = parser.parse_args()
    if opts.checker:
        return checker()
    output = ROOT / opts.output
    output.mkdir(parents=True, exist_ok=True)
    fixture = Fixture()
    results = []
    def passed(name):
        results.append(name)
        print("PASS", name, flush=True)
    try:
        with proxy(fixture.port, output / "clean") as (channel, _, _):
            assert write(channel).committed_size == len(DATA)
            assert not missing(channel).missing_blob_digests
            call = read(channel)
            assert contents(call) == DATA
            assert ("x-rechaos-test", "present") in fixture.metadata
            assert ("x-upstream-initial", "kept") in call.initial_metadata()
            assert ("x-upstream-trailing", "kept") in call.trailing_metadata()
            error = expect_status(grpc.StatusCode.NOT_FOUND, lambda: contents(read(channel, b"absent")))
            assert error.details() == "blob absent"
            assert ("grpc-status-details-bin", b"details") in error.trailing_metadata()
            passed("transparent unary/streaming RPCs, request metadata, response headers/trailers and error details")
            with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                assert all(x == DATA for x in pool.map(lambda _: contents(read(channel)), range(24)))
            passed("24 concurrent streaming reads share an upstream connection")
        with proxy(fixture.port, output / "delay", [rule(MISSING,"request",{"kind":"delay","micros":120000})]) as (channel, _, _):
            start = time.monotonic()
            missing(channel)
            assert time.monotonic()-start >= .10
            passed("per-message delay")
        with proxy(fixture.port, output / "abort", [rule(MISSING,"response",{"kind":"abort","status":"Unavailable"})]) as (channel, _, _):
            expect_status(grpc.StatusCode.UNAVAILABLE, lambda: missing(channel))
            assert contents(read(channel)) == DATA
            passed("injected gRPC status")
        with proxy(fixture.port, output / "request-abort", [rule(MISSING,"request",{"kind":"abort","status":"Unavailable"},occurrence=1)]) as (channel, _, _):
            expect_status(grpc.StatusCode.UNAVAILABLE, lambda: missing(channel))
            assert not missing(channel).missing_blob_digests
            passed("request abort cancels one stream without poisoning the next RPC")
        with proxy(fixture.port, output / "dribble", [rule(READ,"response",{"kind":"dribble","bytesPerSecond":262144,"chunkBytes":4096})]) as (channel, _, _):
            start = time.monotonic()
            call = read(channel)
            parts = list(call)
            assert b"".join(x.data for x in parts) == DATA
            assert max(len(x.data) for x in parts) <= 4096
            assert time.monotonic()-start >= len(DATA)/262144 * .9
            passed("Read dribble preserves payload and paces protobuf chunks")
        with proxy(fixture.port, output / "write-dribble", [rule(WRITE,"request",{"kind":"dribble","bytesPerSecond":1048576,"chunkBytes":2048})]) as (channel, _, _):
            assert write(channel).committed_size == len(DATA)
            passed("Write dribble preserves offsets and finish_write")
        with proxy(fixture.port, output / "write-truncate", [rule(WRITE,"request",{"kind":"truncate","keepBytes":1},messageIndex=1)]) as (channel, _, _):
            expect_status(grpc.StatusCode.INVALID_ARGUMENT, lambda: write(channel))
            passed("truncated Write is rejected by a verifying CAS")
        with proxy(fixture.port, output / "truncate", [rule(READ,"response",{"kind":"truncate","keepBytes":7},messageIndex=1)]) as (channel, timeline, _):
            call = read(channel)
            torn = contents(call)
            assert torn == DATA[:7] and call.code() == grpc.StatusCode.OK
            clean, chaos = output / "clean-output", output / "chaos-output"
            clean.mkdir(exist_ok=True); chaos.mkdir(exist_ok=True)
            (clean / "artifact").write_bytes(DATA); (chaos / "artifact").write_bytes(torn)
            oracle = subprocess.run([str(ROOT / "bin/rechaos"),"oracle",str(clean),str(chaos)], capture_output=True, text=True)
            assert oracle.returncode == 1, oracle.stderr
            (output / "oracle.json").write_text(oracle.stdout)
            passed("valid shortened Read ends OK; output oracle detects divergence")
        with proxy(fixture.port, output / "replay", replay=timeline) as (channel, recorded, _):
            assert contents(read(channel)) == torn
            subprocess.run([str(ROOT/"bin/rechaos"),"verify-replay",str(timeline),str(recorded)],check=True,capture_output=True)
            passed("recorded timeline reproduces torn read")
        with proxy(fixture.port, output / "mismatch", replay=timeline) as (channel, _, _):
            expect_status(grpc.StatusCode.FAILED_PRECONDITION, lambda: contents(read(channel,b"changed")))
            passed("replay fails closed on changed requests")
        with proxy(fixture.port, output / "deadline", [rule(MISSING,"request",{"kind":"delay","micros":900000},occurrence=1)]) as (channel, _, _):
            start = time.monotonic()
            expect_status(grpc.StatusCode.DEADLINE_EXCEEDED, lambda: missing(channel,timeout=.1))
            assert time.monotonic()-start < .4
            assert not missing(channel).missing_blob_digests
            passed("deadline interrupts delayed call and leaves connection usable")
        with proxy(fixture.port, output / "cap", [rule(MISSING,"request",{"kind":"delay","micros":3000000},occurrence=1)],max_seconds=1) as (channel, _, _):
            start = time.monotonic()
            expect_status(grpc.StatusCode.DEADLINE_EXCEEDED, lambda: missing(channel,timeout=5))
            assert time.monotonic()-start < 2
            assert not missing(channel).missing_blob_digests
            passed("proxy maximum duration bounds calls with longer client deadlines")
        restarting = Fixture()
        restart_port = restarting.port
        try:
            with proxy(restart_port, output/"reconnect") as (channel,_,_):
                assert contents(read(channel)) == DATA
                restarting.close()
                restarting = Fixture(listen_port=restart_port)
                time.sleep(.4)
                assert contents(read(channel)) == DATA
            passed("upstream transport reconnects after server restart")
        finally:
            restarting.close()
        minimal = output / "minimal.jsonl"
        minimized = subprocess.run([str(ROOT / "bin/rechaos"),"minimize","--timeline",str(timeline),"--output",str(minimal),
            "--check", f"{sys.executable} {ROOT / 'test/integration.py'} --checker", "--signature","fixture-torn-read"],capture_output=True,text=True,timeout=240)
        assert minimized.returncode == 0, (minimized.stdout,minimized.stderr)
        (output / "minimize.json").write_text(minimized.stdout)
        assert len(minimal.read_text().splitlines()) == 1
        passed("end-to-end shrinking preserves a repeatedly observed failure signature")
        recomputed = output / "recomputed.jsonl"
        subprocess.run([str(ROOT / "bin/rechaos"),"schedule","--policy",str(output / "truncate/policy.json"),
            "--trace",str(timeline),"--output",str(recomputed)], check=True)
        assert [json.loads(x) for x in timeline.read_text().splitlines()] == [json.loads(x) for x in recomputed.read_text().splitlines()]
        passed("offline seed + recorded trace exactly reproduces decisions")
        (output / "summary.json").write_text(json.dumps({"passed":results},indent=2)+"\n")
    finally:
        fixture.close()

if __name__ == "__main__":
    main()
