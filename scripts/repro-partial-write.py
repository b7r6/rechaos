#!/usr/bin/env python3
"""Reproduce a rejected short upload becoming a successful, incomplete CAS read.

Speaks directly to NativeLink. No proxy or server internals are involved.
Fresh deterministic content prevents a prior cache entry from satisfying a case.
"""
import argparse
import datetime
import json
import pathlib
import runpy

helpers = runpy.run_path(str(pathlib.Path(__file__).with_name("fleet-stress.py")))
Blob, Endpoint = helpers["Blob"], helpers["Endpoint"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", default="127.0.0.1:50051")
    parser.add_argument("--observe", action="append", default=[])
    parser.add_argument("--instance", default="main")
    parser.add_argument("--size", type=int, default=1048576)
    parser.add_argument("--prefixes", default="0,1,17,65553,1048575")
    parser.add_argument("--seed", type=int, default=20261002)
    parser.add_argument("--run-id", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    prefixes = [int(value) for value in args.prefixes.split(",")]
    if any(not 0 <= prefix < args.size for prefix in prefixes):
        parser.error("prefix lengths must be smaller than the expected blob size")
    out = pathlib.Path(args.output)
    out.mkdir(parents=True, exist_ok=False)
    (out / "manifest.json").write_text(json.dumps(vars(args), indent=2)+"\n")
    endpoint = Endpoint(args.endpoint)
    observers = {address: Endpoint(address) for address in args.observe}
    cases = []
    with (out / "calls.jsonl").open("w", buffering=1) as log:
        def record(case, operation, result):
            row = {"case": case, "operation": operation, **result}
            log.write(json.dumps(row)+"\n")
            print(json.dumps(row), flush=True)
            return result

        for prefix in prefixes:
            blob = Blob(f"prefix-{prefix}", args.size, args.seed, args.run_id, args.instance)
            name = blob.label
            evidence = {"blob": blob.descriptor(), "prefix": prefix}
            evidence["before"] = record(name, "FindMissingBlobs-before", endpoint.missing([blob], args.instance))
            if evidence["before"].get("missing") != [{"hash": blob.hash, "size": blob.size}]:
                raise RuntimeError("case requires a fresh, absent blob")
            # This is the entire fault: finish_write before the advertised length.
            evidence["write"] = record(name, "Write-short-finish", endpoint.write(blob, stop_at=prefix, finish=True))
            evidence["query"] = record(name, "QueryWriteStatus", endpoint.query(blob))
            evidence["missing"] = record(name, "FindMissingBlobs-after", endpoint.missing([blob], args.instance))
            evidence["read"] = record(name, "Read-after-short-write", endpoint.read(blob))
            evidence["observers"] = {address: record(name, "Read-observer-"+address, observer.read(blob))
                                      for address, observer in observers.items()}
            query = evidence["query"]
            if query["status"] == "OK" and not query["complete"]:
                evidence["resume"] = record(name, "Write-resume", endpoint.write(blob, offset=query["committedBytes"]))
            evidence["freshRetry"] = record(name, "Write-fresh-upload-id", endpoint.write(blob, writer="fresh-retry"))
            evidence["afterRetry"] = record(name, "Read-after-fresh-upload", endpoint.read(blob))
            evidence["queryAfterRetry"] = record(name, "QueryWriteStatus-after-fresh-upload", endpoint.query(blob, writer="fresh-retry"))
            evidence["observersAfterRetry"] = {address: record(name, "Read-observer-after-retry-"+address, observer.read(blob))
                                               for address, observer in observers.items()}
            evidence["reproduced"] = (evidence["read"]["status"] == "OK" and
                evidence["read"].get("matches") is False)
            evidence["writeWasRejected"] = evidence["write"]["status"] != "OK"
            cases.append(evidence)
            (out / "summary.json").write_text(json.dumps(cases, indent=2)+"\n")
        endpoint.channel.close()
        for observer in observers.values(): observer.channel.close()
    print(json.dumps({"reproduced": sum(case["reproduced"] for case in cases), "cases": len(cases)}), flush=True)


if __name__ == "__main__":
    main()
