#!/usr/bin/env python3
"""Compare QueryWriteStatus with complete, verified artifact uploads."""
import argparse
import datetime
import json
import pathlib
import runpy

helpers = runpy.run_path(str(pathlib.Path(__file__).with_name("fleet-stress.py")))
Blob, Endpoint = helpers["Blob"], helpers["Endpoint"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", default="127.0.0.1:50052")
    parser.add_argument("--instance", default="main")
    parser.add_argument("--sizes", default="17,4095,4096,4097,65537,1048577")
    parser.add_argument("--seed", type=int, default=20261002)
    parser.add_argument("--run-id", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    sizes = [int(size) for size in args.sizes.split(",")]
    if any(size < 1 for size in sizes): parser.error("sizes must be positive")
    out = pathlib.Path(args.output)
    out.mkdir(parents=True, exist_ok=False)
    (out / "manifest.json").write_text(json.dumps(vars(args), indent=2)+"\n")
    endpoint = Endpoint(args.endpoint)
    rows = []
    for size in sizes:
        blob = Blob(f"valid-{size}", size, args.seed, args.run_id, args.instance)
        row = {"blob": blob.descriptor(), "write": endpoint.write(blob),
               "read": endpoint.read(blob), "query": endpoint.query(blob)}
        row["setupVerified"] = (row["write"]["status"] == "OK" and
            row["write"].get("committedBytes") == size and row["read"].get("matches") is True)
        row["wrongCommittedSize"] = (row["setupVerified"] and row["query"]["status"] == "OK" and
            row["query"].get("committedBytes") != size)
        rows.append(row)
        print(json.dumps(row), flush=True)
        (out / "results.json").write_text(json.dumps(rows, indent=2)+"\n")
    endpoint.channel.close()
    print(json.dumps({"cases": len(rows), "wrongCommittedSize": sum(row["wrongCommittedSize"] for row in rows)}))


if __name__ == "__main__":
    main()
