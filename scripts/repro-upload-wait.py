#!/usr/bin/env python3
"""Measure how unfinished uploads affect CAS lookups and replacement uploads.

Each observer uses its own gRPC connection. QueryWriteStatus acknowledges the
prefix before the upload is cancelled, half-closed, or allowed to time out.
Observers start after that interruption; a later full upload measures recovery.
"""
import argparse
import concurrent.futures as cf
import datetime
import gzip
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
    parser.add_argument("--endpoint", default="127.0.0.1:50051")
    parser.add_argument("--instance", default="main")
    parser.add_argument("--mode", choices=["cancel", "half-close", "deadline"], default="cancel")
    parser.add_argument("--repair", choices=["resume", "fresh"], default="resume")
    parser.add_argument("--size", type=int, default=1048576)
    parser.add_argument("--prefix", type=int, default=65536)
    parser.add_argument("--observe-seconds", type=float, default=3)
    parser.add_argument("--timeout", type=float, default=12)
    parser.add_argument("--seed", type=int, default=20261002)
    parser.add_argument("--run-id", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if not 0 < args.prefix < args.size: parser.error("prefix must be inside the artifact")
    if not 0 < args.observe_seconds < args.timeout: parser.error("observation interval must be shorter than timeout")
    out = pathlib.Path(args.output)
    out.mkdir(parents=True, exist_ok=False)
    blobs = {label: Blob(label, size, args.seed, args.run_id, args.instance)
             for label, size in [("unfinished", args.size), ("healthy", 1024), ("absent", 1024), ("fresh", 1024)]}
    (out/"manifest.json").write_text(json.dumps({**vars(args), "blobs": [b.descriptor() for b in blobs.values()]}, indent=2)+"\n")
    start = time.monotonic()
    lock = threading.Lock()
    calls = []
    log = (out/"calls.jsonl").open("w", buffering=1)

    def record(operation, result, started=None):
        row = {"operation": operation, "startedSeconds": started,
               "finishedSeconds": time.monotonic()-start, **result}
        with lock:
            calls.append(row)
            log.write(json.dumps(row)+"\n")
            print(json.dumps(row), flush=True)
        return row

    def endpoint():
        return Endpoint(args.endpoint, grpc.insecure_channel(args.endpoint,
            options=[("grpc.use_local_subchannel_pool", 1)]))

    def isolated(operation, action):
        e = endpoint()
        began = time.monotonic()-start
        try: return record(operation, action(e), began)
        finally: e.channel.close()

    def metrics(label):
        try:
            data = urllib.request.urlopen("http://"+args.endpoint+"/metrics", timeout=3).read()
            (out/("metrics-"+label+".prom.gz")).write_bytes(gzip.compress(data, mtime=0))
        except Exception as error: record("metrics-"+label, {"status": "unavailable", "details": str(error)})

    metrics("before")
    blob, healthy, absent, fresh = [blobs[label] for label in ("unfinished", "healthy", "absent", "fresh")]
    uploaded = isolated("healthy-setup-write", lambda e: e.write(healthy))
    verified = isolated("healthy-setup-read", lambda e: e.read(healthy))
    if uploaded["status"] != "OK" or not verified.get("matches"): raise RuntimeError("healthy control unavailable")
    initial = isolated("unfinished-baseline-missing", lambda e: e.missing([blob], args.instance))
    if initial.get("missing") != [{"hash": blob.hash, "size": blob.size}]: raise RuntimeError("fresh digest required")
    isolated("absent-baseline-missing", lambda e: e.missing([absent], args.instance))
    upload = endpoint()
    release = threading.Event()
    writer = "interrupted"

    def requests():
        yield bs.WriteRequest(resource_name=blob.upload_name(writer), data=blob.data[:args.prefix])
        release.wait(args.timeout+3)

    began = time.monotonic()-start
    call = upload.write_rpc.future(requests(), timeout=2 if args.mode == "deadline" else args.timeout+5)
    try:
        until = time.monotonic()+1.5
        while True:
            acknowledged = upload.query(blob, writer, timeout=1)
            if acknowledged.get("committedBytes") == args.prefix: break
            if time.monotonic() > until: raise RuntimeError(f"prefix not acknowledged: {acknowledged}")
            time.sleep(.03)
        record("prefix-acknowledged", acknowledged)
        if args.mode == "cancel": call.cancel()
        if args.mode == "half-close": release.set()
        interrupted = measured(lambda: {"committedBytes": call.result().committed_size})
        record("upload-"+args.mode, interrupted, began)
    finally:
        call.cancel()
        release.set()
        upload.channel.close()
    time.sleep(.2)
    status = isolated("status-after-interruption", lambda e: e.query(blob, writer))
    work = {
        "unfinished-missing": lambda e: e.missing([blob], args.instance, timeout=args.timeout),
        "mixed-missing": lambda e: e.missing([blob, absent, healthy], args.instance, timeout=args.timeout),
        "absent-missing": lambda e: e.missing([absent], args.instance, timeout=args.timeout),
        "healthy-missing": lambda e: e.missing([healthy], args.instance, timeout=args.timeout),
        "unfinished-read": lambda e: e.read(blob, timeout=args.timeout),
        "healthy-read": lambda e: e.read(healthy, timeout=args.timeout),
        "fresh-artifact-write": lambda e: e.write(fresh, timeout=args.timeout),
    }
    with cf.ThreadPoolExecutor(max_workers=len(work)) as pool:
        futures = {name: pool.submit(isolated, name, action) for name, action in work.items()}
        time.sleep(args.observe_seconds)
        pending = sorted(name for name, future in futures.items() if not future.done())
        record("observation-window", {"status": "OBSERVED", "pending": pending, "seconds": args.observe_seconds})
        repair_start = time.monotonic()-start
        offset = status.get("committedBytes", 0)
        if args.repair == "resume" and status["status"] == "OK" and not status.get("complete"):
            repaired = isolated("repair-resume", lambda e: e.write(blob, writer, offset=offset, timeout=args.timeout))
        else:
            repaired = isolated("repair-fresh", lambda e: e.write(blob, "fresh-repair", timeout=args.timeout))
        immediate_read = isolated("read-immediately-after-repair", lambda e: e.read(blob, timeout=args.timeout))
        immediate_missing = isolated("missing-immediately-after-repair", lambda e: e.missing([blob], args.instance, timeout=args.timeout))
        pending_after = sorted(name for name, future in futures.items() if not future.done())
        record("after-repair-observation", {"status": "OBSERVED", "pending": pending_after})
        rows = {name: future.result() for name, future in futures.items()}
    after = isolated("read-after-repair", lambda e: e.read(blob, timeout=args.timeout))
    if not after.get("matches"):
        isolated("fallback-full-upload", lambda e: e.write(blob, "fallback-repair", timeout=args.timeout))
        after = isolated("read-after-fallback", lambda e: e.read(blob, timeout=args.timeout))
    final_missing = isolated("missing-after-repair", lambda e: e.missing([blob, absent, healthy], args.instance))
    isolated("fresh-artifact-read", lambda e: e.read(fresh))
    metrics("after")
    result = {"pendingBeforeRepair": pending, "repairStartedSeconds": repair_start,
              "pendingAfterRepair": pending_after, "immediateRead": immediate_read, "immediateMissing": immediate_missing,
              "repair": repaired, "observers": rows, "artifactRecovered": after.get("matches") is True,
              "finalMissing": final_missing}
    result["waitingLookupDeadlineAfterVerifiedReplacement"] = (
        args.repair == "fresh" and repaired["status"] == "OK" and
        immediate_read.get("matches") is True and immediate_missing.get("missing") == [] and
        all(rows[name]["status"] == "DEADLINE_EXCEEDED" for name in ("unfinished-missing", "mixed-missing")))
    (out/"summary.json").write_text(json.dumps(result, indent=2)+"\n")
    log.close()
    print("SUMMARY", json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
