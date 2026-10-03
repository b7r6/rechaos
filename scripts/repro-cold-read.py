#!/usr/bin/env python3
"""Check cold CAS downloads with paused/cancelled readers and independent peers.

Upload a fresh artifact to one CAS node, wait for another node to find it, then
read it on that second node. All observer RPCs use independent connections.
"""
import argparse
import concurrent.futures as cf
import datetime
import gzip
import hashlib
import json
import pathlib
import runpy
import threading
import time
import urllib.request

helpers = runpy.run_path(str(pathlib.Path(__file__).with_name("fleet-stress.py")))
Blob, Endpoint, measured, bs, grpc = [helpers[name] for name in ("Blob", "Endpoint", "measured", "bs", "grpc")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="127.0.0.1:50052")
    parser.add_argument("--target", default="127.0.0.1:50052")
    parser.add_argument("--instance", default="main")
    parser.add_argument("--mode", choices=["normal", "cancel-first", "cancel-early", "pause", "pause-cancel"], default="cancel-first")
    parser.add_argument("--warm", action="store_true", help="Read the whole artifact on the target before the reader experiment")
    parser.add_argument("--follower-timeout", type=float, help="Optional independent deadline for follower reads")
    parser.add_argument("--size", type=int, default=16777216)
    parser.add_argument("--followers", type=int, default=4)
    parser.add_argument("--pause-seconds", type=float, default=3)
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--seed", type=int, default=20261002)
    parser.add_argument("--run-id", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.source == args.target: parser.error("source and target must be different CAS nodes")
    if not 1 <= args.followers <= 32: parser.error("followers must be 1..32")
    if not 0 < args.pause_seconds < args.timeout: parser.error("pause must be shorter than timeout")
    out = pathlib.Path(args.output); out.mkdir(parents=True, exist_ok=False)
    blob = Blob("cold-artifact", args.size, args.seed, args.run_id, args.instance)
    health = Blob("healthy", 1024, args.seed, args.run_id, args.instance)
    (out/"manifest.json").write_text(json.dumps({**vars(args), "blobs": [blob.descriptor(), health.descriptor()]}, indent=2)+"\n")
    start = time.monotonic(); lock = threading.Lock(); log = (out/"calls.jsonl").open("w", buffering=1)

    def record(operation, result, began=None):
        row = {"operation": operation, "startedSeconds": began, "finishedSeconds": time.monotonic()-start, **result}
        with lock:
            log.write(json.dumps(row)+"\n"); print(json.dumps(row), flush=True)
        return row

    def endpoint(address):
        return Endpoint(address, grpc.insecure_channel(address, options=[("grpc.use_local_subchannel_pool", 1)]))

    def isolated(operation, action, address=None):
        e = endpoint(address or args.target); began = time.monotonic()-start
        try: return record(operation, action(e), began)
        finally: e.channel.close()

    def metrics(label):
        data = urllib.request.urlopen("http://"+args.target+"/metrics", timeout=3).read()
        (out/("metrics-"+label+".prom.gz")).write_bytes(gzip.compress(data, mtime=0))
        result = {}
        for line in data.decode().splitlines():
            if line.startswith("nativelink_stores_CAS_LOCAL_"):
                name, value = line.rsplit(" ", 1)
                try: result[name] = float(value)
                except ValueError: pass
        return result

    initial = isolated("target-initial-missing", lambda e: e.missing([blob], args.instance))
    if initial.get("missing") != [{"hash": blob.hash, "size": blob.size}]: raise RuntimeError("fresh absent artifact required")
    write = isolated("source-write", lambda e: e.write(blob, timeout=args.timeout), args.source)
    check = isolated("source-read", lambda e: e.read(blob, timeout=args.timeout), args.source)
    if write["status"] != "OK" or not check.get("matches"): raise RuntimeError("source artifact failed verification")
    until = time.monotonic()+15
    while True:
        present = isolated("target-publication-check", lambda e: e.missing([blob], args.instance, timeout=3))
        if present.get("missing") == []: break
        if time.monotonic() > until: raise RuntimeError("artifact did not become visible on target")
        time.sleep(.1)
    isolated("healthy-write", lambda e: e.write(health))
    healthy = isolated("healthy-baseline", lambda e: e.read(health))
    if not healthy.get("matches"): raise RuntimeError("healthy baseline failed")
    if args.warm:
        warmed = isolated("target-warmup-read", lambda e: e.read(blob, timeout=args.timeout))
        if not warmed.get("matches"): raise RuntimeError("warmup read failed")
    before = metrics("before-read")
    leader = endpoint(args.target)
    began = time.monotonic()-start
    call = leader.read_rpc(bs.ReadRequest(resource_name=blob.read_name), timeout=args.timeout)
    first_data = b""
    if args.mode == "cancel-early":
        time.sleep(.01)
        record("leader-cancel", {"status": "CLIENT_CANCELLED" if call.cancel() else call.code().name}, began)
    else:
        first = next(call)
        first_data = first.data
        record("leader-first-message", {"status": "OK", "bytes": len(first_data)}, began)
        if args.mode == "cancel-first":
            record("leader-cancel", {"status": "CLIENT_CANCELLED" if call.cancel() else call.code().name})
    if args.mode.startswith("cancel"):
        leader.channel.close()

    def finish_leader():
        def consume():
            digest = hashlib.sha256(first_data); length = len(first_data)
            for response in call: digest.update(response.data); length += len(response.data)
            return {"bytes": length, "sha256": digest.hexdigest(), "matches": length == blob.size and digest.hexdigest() == blob.hash}
        try: return record("leader-complete", measured(consume))
        finally: call.cancel(); leader.channel.close()

    with cf.ThreadPoolExecutor(max_workers=args.followers+4) as pool:
        futures = {"follower-"+str(i): pool.submit(isolated, "follower-"+str(i),
            lambda e: e.read(blob, timeout=args.follower_timeout or args.timeout)) for i in range(args.followers)}
        futures["same-artifact-missing"] = pool.submit(isolated, "same-artifact-missing", lambda e: e.missing([blob], args.instance, timeout=args.timeout))
        futures["healthy-read"] = pool.submit(isolated, "healthy-read", lambda e: e.read(health, timeout=args.timeout))
        futures["healthy-missing"] = pool.submit(isolated, "healthy-missing", lambda e: e.missing([health], args.instance, timeout=args.timeout))
        if args.mode == "normal": futures["leader"] = pool.submit(finish_leader)
        time.sleep(args.pause_seconds)
        pending = sorted(name for name, future in futures.items() if not future.done())
        record("observation-window", {"status": "OBSERVED", "pending": pending, "seconds": args.pause_seconds})
        during = metrics("during-read")
        record("leader-release", {"status": "OBSERVED", "mode": args.mode})
        if args.mode == "pause": futures["leader"] = pool.submit(finish_leader)
        if args.mode == "pause-cancel":
            record("leader-cancel", {"status": "CLIENT_CANCELLED" if call.cancel() else call.code().name})
            leader.channel.close()
        rows = {name: future.result() for name, future in futures.items()}
    recovery = isolated("target-final-read", lambda e: e.read(blob, timeout=args.timeout))
    after = metrics("after-read")
    result = {"mode": args.mode, "pendingAtObservation": pending, "observers": rows, "recovery": recovery,
              "metricDeltasDuring": {k: during[k]-before.get(k, 0) for k in during if during[k] != before.get(k)},
              "metricDeltasAfter": {k: after[k]-before.get(k, 0) for k in after if after[k] != before.get(k)},
              "allCompletedReadsCorrect": all(row.get("matches") is True for key,row in rows.items() if key.startswith("follower") or key in ["leader", "healthy-read"]) and recovery.get("matches") is True}
    (out/"summary.json").write_text(json.dumps(result, indent=2)+"\n")
    print("SUMMARY", json.dumps(result), flush=True); log.close()


if __name__ == "__main__": main()
