#!/usr/bin/env python3
"""Vendor pinned public protocol definitions, without server source dependencies."""
import pathlib
import re
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1] / "proto"
SOURCES = {
    "build/": ("bazelbuild/remote-apis", "adbf4a27c86fbea4a37637a6cbcacef372406fe7"),
    "google/": ("googleapis/googleapis", "0394833bee92e202125b97078d76b1950883f354"),
}
seen = set()

def fetch(path):
    if path in seen or path.startswith("google/protobuf/"):
        return  # supplied by protoc and proto-lens-protobuf-types
    seen.add(path)
    repo, commit = SOURCES["build/" if path.startswith("build/") else "google/"]
    url = f"https://raw.githubusercontent.com/{repo}/{commit}/{path}"
    data = urllib.request.urlopen(url, timeout=30).read()
    out = ROOT / path
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    for dependency in re.findall(rb'^import (?:public )?"([^"]+)";', data, re.M):
        fetch(dependency.decode())

for entry in ("build/bazel/remote/execution/v2/remote_execution.proto",
              "google/bytestream/bytestream.proto"):
    fetch(entry)
for repo, commit in SOURCES.values():
    (ROOT / (repo.split("/")[-1] + "-LICENSE")).write_bytes(
        urllib.request.urlopen(f"https://raw.githubusercontent.com/{repo}/{commit}/LICENSE", timeout=30).read())
print(f"Vendored {len(seen)} pinned protocol files")
