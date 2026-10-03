#!/usr/bin/env python3
"""rechaos multi-implementation DIFFERENTIAL harness for REAPI endpoints.

The chaos monkey and the consistency oracle ask "is *this* endpoint correct?".
This harness asks a complementary, vendor-grade question: "do *these N*
endpoints behave the **same**?". It runs one deterministic probe battery against
every configured REAPI endpoint, normalizes each response to an
implementation-independent *observation*, and diffs the observations
probe-by-probe. Where all endpoints agree, the probe is conformant. Where they
disagree, the harness emits a structured divergence witness — exactly the
artifact a vendor uses to say "we conform and competitor X diverges".

Observable-equivalence model (see docs/differential.md)
-------------------------------------------------------
Two endpoints are *observably equivalent on a probe* iff the probe's normalized
observation is byte-for-byte equal between them. The normalization deliberately
discards implementation-private, non-semantic detail (latency, error message
wording, server-assigned upload UUIDs) and keeps only what REAPI *clients* are
entitled to rely on:

  * RPC status code (OK / NOT_FOUND / INVALID_ARGUMENT / ...).
  * Committed sizes on Write / QueryWriteStatus, and the `complete` flag.
  * The SHA-256 of returned bytes, and whether returned bytes match the
    content-addressed digest (content-addressing is a hard REAPI contract).
  * The *set* of digests reported missing by FindMissingBlobs.
  * Action Cache presence/absence and (on a hit) the ActionResult's exit_code
    and the digests of its referenced blobs.

Everything the harness touches is deterministic in `--seed`: blob contents,
AC action digests, and the probe order are all derived from the seed, so two
runs against the same fleet produce identical observations (and therefore an
identical verdict), and a divergence is reproducible.

This is BOTH a library and a CLI:

  * Library: construct `DifferentialHarness(endpoints, seed=...)`, call
    `.run()` -> `Report`. `Report.verdict` is "agree" or "diverge".
  * CLI: `reapi_differential.py --endpoint host:port --endpoint host:port ...`
    prints a human summary (and `--json` a machine report). Exit code is 0 on
    full agreement, 2 on any divergence, 1 on operational error.

Reusing the project's own gRPC bindings and the battle-tested `Endpoint`/`Blob`
helpers from `scripts/fleet-stress.py` (loaded via `test/integration.py`), so
the harness speaks exactly the same wire dialect as every other rechaos driver.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime
import hashlib
import json
import pathlib
import runpy
import sys
import traceback

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Reuse the shared helpers rather than re-implementing the wire protocol. The
# fleet-stress module exposes the `Endpoint` (per-RPC wrappers) and `Blob`
# (deterministic content) abstractions; importing it also pulls in the generated
# bindings via test/integration.py, exactly like the other repro scripts.
_HELPERS = runpy.run_path(str(ROOT / "scripts" / "fleet-stress.py"))
Blob = _HELPERS["Blob"]
Endpoint = _HELPERS["Endpoint"]
grpc = _HELPERS["grpc"]
re = _HELPERS["re"]

# Default probe blob sizes: boundary conditions around the 64 KiB ByteStream
# chunk and typical small/large artifacts. All positive, all deterministic.
DEFAULT_SIZES = (1, 17, 4096, 65536, 65537, 1048577)


# ---------------------------------------------------------------------------
# Normalization: raw helper results -> implementation-independent observations.
# ---------------------------------------------------------------------------
def _status(result: dict) -> str:
    """The semantic status of a helper result ("OK", "NOT_FOUND", ...)."""
    return result.get("status", "UNKNOWN")


def normalize_write(result: dict, blob) -> dict:
    """Observation of a Write: status + committed size (upload UUID discarded)."""
    obs = {"status": _status(result)}
    if obs["status"] == "OK":
        obs["committedBytes"] = result.get("committedBytes")
        # A conforming CAS commits exactly the blob's size.
        obs["committedMatchesSize"] = result.get("committedBytes") == blob.size
    return obs


def normalize_read(result: dict) -> dict:
    """Observation of a Read: status, byte count, payload hash and digest match.

    The returned-bytes SHA-256 and the `matches` flag (bytes hash to the
    requested digest) are the content-addressing contract and the core of the
    comparison — the exact *latency* and *chunking* are intentionally dropped.
    """
    obs = {"status": _status(result)}
    if obs["status"] == "OK":
        obs["bytes"] = result.get("bytes")
        obs["sha256"] = result.get("sha256")
        obs["matches"] = result.get("matches")
    return obs


def normalize_query(result: dict) -> dict:
    """Observation of QueryWriteStatus: status, committed size and completeness."""
    obs = {"status": _status(result)}
    if obs["status"] == "OK":
        obs["committedBytes"] = result.get("committedBytes")
        obs["complete"] = result.get("complete")
    return obs


def normalize_missing(result: dict) -> dict:
    """Observation of FindMissingBlobs: status + the *set* of missing digests.

    Order is not significant in REAPI, so the missing digests are returned as a
    sorted list of ``"hash/size"`` strings to make the observation canonical.
    """
    obs = {"status": _status(result)}
    if obs["status"] == "OK":
        obs["missing"] = sorted(f"{d['hash']}/{d['size']}" for d in result.get("missing", []))
    return obs


def normalize_ac(result: dict) -> dict:
    """Observation of an AC get: presence plus exit_code and referenced digests."""
    obs = {"status": _status(result)}
    if obs["status"] == "OK":
        obs["exitCode"] = result.get("exitCode")
        obs["outputDigests"] = sorted(result.get("outputDigests", []))
    return obs


# ---------------------------------------------------------------------------
# Action Cache helpers (fleet-stress's Endpoint covers CAS/BS only).
# ---------------------------------------------------------------------------
def _ac_rpcs(endpoint):
    """Lazily attach GetActionResult / UpdateActionResult RPC stubs."""
    channel = endpoint.channel
    get = channel.unary_unary(
        "/build.bazel.remote.execution.v2.ActionCache/GetActionResult",
        request_serializer=re.GetActionResultRequest.SerializeToString,
        response_deserializer=re.ActionResult.FromString,
    )
    update = channel.unary_unary(
        "/build.bazel.remote.execution.v2.ActionCache/UpdateActionResult",
        request_serializer=re.UpdateActionResultRequest.SerializeToString,
        response_deserializer=re.ActionResult.FromString,
    )
    return get, update


def _measured(fn):
    """Run ``fn`` and classify its outcome the same way fleet-stress does."""
    try:
        return {"status": "OK", **fn()}
    except grpc.RpcError as error:
        return {"status": error.code().name, "details": (error.details() or "")[:400]}


def ac_action_digest(blob, instance):
    """Deterministic *action* digest for an AC entry keyed off ``blob``."""
    raw = hashlib.sha256(f"action/{blob.hash}".encode()).hexdigest()
    return re.Digest(hash=raw, size_bytes=max(1, blob.size % 256))


def ac_update(endpoint, blob, instance):
    """Put an ActionResult referencing ``blob`` as an output file."""
    _, update = _ac_rpcs(endpoint)

    def perform():
        action_digest = ac_action_digest(blob, instance)
        result = re.ActionResult(
            exit_code=0,
            output_files=[re.OutputFile(path="out", digest=re.Digest(hash=blob.hash, size_bytes=blob.size))],
        )
        reply = update(
            re.UpdateActionResultRequest(
                instance_name=instance,
                action_digest=action_digest,
                digest_function=re.DigestFunction.SHA256,
                action_result=result,
            ),
            timeout=8,
        )
        return {"exitCode": reply.exit_code}

    return _measured(perform)


def ac_get(endpoint, blob, instance):
    """Get the ActionResult for ``blob``'s deterministic action digest."""
    get, _ = _ac_rpcs(endpoint)

    def perform():
        reply = get(
            re.GetActionResultRequest(
                instance_name=instance,
                action_digest=ac_action_digest(blob, instance),
                digest_function=re.DigestFunction.SHA256,
            ),
            timeout=8,
        )
        return {
            "exitCode": reply.exit_code,
            "outputDigests": [f"{f.digest.hash}/{f.digest.size_bytes}" for f in reply.output_files],
        }

    return _measured(perform)


# ---------------------------------------------------------------------------
# Probe battery.
# ---------------------------------------------------------------------------
@dataclasses.dataclass
class Probe:
    """One named probe: a callable against an Endpoint and its normalizer."""

    name: str
    run: object       # Endpoint -> raw helper result dict
    normalize: object  # raw result dict -> observation dict


def build_probes(blobs, absent_blob, instance):
    """The deterministic probe battery, in a fixed (seed-independent) order.

    Covers: write roundtrips across sizes, read-back, range reads, missing-blob
    sets (present and absent), QueryWriteStatus, and AC put/get. Every probe is
    pure w.r.t. the deterministic blobs, so re-running yields the same
    observations on a conforming endpoint.
    """
    probes = []
    for blob in blobs:
        probes.append(Probe(
            f"write[{blob.size}]",
            lambda ep, b=blob: ep.write(b, writer="diff"),
            lambda r, b=blob: normalize_write(r, b),
        ))
        probes.append(Probe(
            f"read[{blob.size}]",
            lambda ep, b=blob: ep.read(b),
            normalize_read,
        ))
        # Range reads: a head slice and an interior slice (both well within size).
        probes.append(Probe(
            f"read-range[{blob.size}:head]",
            lambda ep, b=blob: ep.read(b, offset=0, limit=min(b.size, 1024)),
            normalize_read,
        ))
        if blob.size > 2:
            probes.append(Probe(
                f"read-range[{blob.size}:mid]",
                lambda ep, b=blob: ep.read(b, offset=b.size // 2, limit=max(1, b.size // 4)),
                normalize_read,
            ))
        probes.append(Probe(
            f"query-write-status[{blob.size}]",
            lambda ep, b=blob: ep.query(b, writer="diff"),
            normalize_query,
        ))
        probes.append(Probe(
            f"find-missing[present:{blob.size}]",
            lambda ep, b=blob: ep.missing([b], instance=instance),
            normalize_missing,
        ))
        # Action Cache put then get for the same deterministic action digest.
        probes.append(Probe(
            f"ac-update[{blob.size}]",
            lambda ep, b=blob: ac_update(ep, b, instance),
            normalize_ac,
        ))
        probes.append(Probe(
            f"ac-get[{blob.size}]",
            lambda ep, b=blob: ac_get(ep, b, instance),
            normalize_ac,
        ))
    # A blob that is never uploaded: every endpoint must report it missing/absent.
    probes.append(Probe(
        "find-missing[absent]",
        lambda ep: ep.missing([absent_blob], instance=instance),
        normalize_missing,
    ))
    probes.append(Probe(
        "read[absent]",
        lambda ep: ep.read(absent_blob),
        normalize_read,
    ))
    probes.append(Probe(
        "ac-get[absent]",
        lambda ep: ac_get(ep, absent_blob, instance),
        normalize_ac,
    ))
    return probes


# ---------------------------------------------------------------------------
# Harness.
# ---------------------------------------------------------------------------
@dataclasses.dataclass
class ProbeResult:
    """Per-probe outcome across all endpoints."""

    name: str
    observations: dict          # endpoint address -> normalized observation
    agree: bool
    groups: list                # list of {"observation", "endpoints"} divergence groups


@dataclasses.dataclass
class Report:
    """Full differential report."""

    seed: int
    instance: str
    endpoints: list
    sizes: list
    probes: list                # list[ProbeResult]
    verdict: str                # "agree" | "diverge"
    divergences: int

    def to_dict(self):
        return {
            "tool": "reapi_differential",
            "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "seed": self.seed,
            "instance": self.instance,
            "endpoints": self.endpoints,
            "sizes": self.sizes,
            "verdict": self.verdict,
            "divergences": self.divergences,
            "probeCount": len(self.probes),
            "probes": [
                {
                    "name": p.name,
                    "agree": p.agree,
                    "observations": p.observations,
                    "groups": p.groups if not p.agree else None,
                }
                for p in self.probes
            ],
        }


class DifferentialHarness:
    """Run one probe battery against N endpoints and diff the observations."""

    def __init__(self, addresses, seed=20261002, instance="main", sizes=DEFAULT_SIZES, run_id=None):
        if len(addresses) < 2:
            raise ValueError("differential testing needs at least 2 endpoints")
        self.addresses = list(addresses)
        self.seed = seed
        self.instance = instance
        self.sizes = [int(s) for s in sizes]
        if any(s < 1 for s in self.sizes):
            raise ValueError("sizes must be positive")
        # run_id is folded into blob content; fixing it keeps the fleet consistent
        # within a run while staying deterministic across runs (seed-derived).
        self.run_id = run_id or f"differential/{seed}"

    def _blobs(self):
        blobs = [Blob(f"diff-{size}", size, self.seed, self.run_id, self.instance) for size in self.sizes]
        absent = Blob("diff-absent", 777, self.seed ^ 0xABCDEF, self.run_id, self.instance)
        return blobs, absent

    def run(self):
        blobs, absent = self._blobs()
        probes = build_probes(blobs, absent, self.instance)
        endpoints = {addr: Endpoint(addr) for addr in self.addresses}
        try:
            probe_results = []
            for probe in probes:
                observations = {}
                for addr, endpoint in endpoints.items():
                    try:
                        raw = probe.run(endpoint)
                        observations[addr] = probe.normalize(raw)
                    except Exception as error:  # operational failure for this probe/endpoint
                        observations[addr] = {"status": "HARNESS_ERROR", "error": str(error)[:400]}
                probe_results.append(self._diff(probe.name, observations))
            diverged = [p for p in probe_results if not p.agree]
            return Report(
                seed=self.seed,
                instance=self.instance,
                endpoints=self.addresses,
                sizes=self.sizes,
                probes=probe_results,
                verdict="diverge" if diverged else "agree",
                divergences=len(diverged),
            )
        finally:
            for endpoint in endpoints.values():
                try:
                    endpoint.channel.close()
                except Exception:
                    pass

    @staticmethod
    def _canonical(observation):
        """Canonical JSON key for grouping identical observations."""
        return json.dumps(observation, sort_keys=True, separators=(",", ":"))

    def _diff(self, name, observations):
        """Group endpoints by identical observation; agreement == one group."""
        groups = {}
        for addr, obs in observations.items():
            groups.setdefault(self._canonical(obs), []).append(addr)
        agree = len(groups) == 1
        group_list = [
            {"observation": json.loads(key), "endpoints": sorted(addrs)}
            for key, addrs in groups.items()
        ]
        return ProbeResult(name=name, observations=observations, agree=agree, groups=group_list)


# ---------------------------------------------------------------------------
# Human-readable rendering.
# ---------------------------------------------------------------------------
def render_human(report: Report) -> str:
    lines = []
    bar = "━" * 72
    lines.append(bar)
    lines.append(f"rechaos REAPI differential  seed={report.seed}  instance={report.instance}")
    lines.append(f"endpoints: {', '.join(report.endpoints)}")
    lines.append(f"probes: {len(report.probes)}   divergences: {report.divergences}")
    lines.append(bar)
    for probe in report.probes:
        mark = "ok  " if probe.agree else "DIFF"
        lines.append(f"[{mark}] {probe.name}")
        if not probe.agree:
            for group in probe.groups:
                eps = ", ".join(group["endpoints"])
                obs = json.dumps(group["observation"], sort_keys=True)
                lines.append(f"         {eps}: {obs}")
    lines.append(bar)
    verdict = "AGREE (observably equivalent)" if report.verdict == "agree" else "DIVERGE"
    lines.append(f"VERDICT: {verdict}")
    lines.append(bar)
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------
def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Differential REAPI harness: diff observable behavior across N endpoints.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--endpoint",
        action="append",
        default=[],
        metavar="HOST:PORT",
        help="A REAPI endpoint to probe. Repeat >=2 times (the same address twice is a valid self-check).",
    )
    parser.add_argument("--instance", default="main", help="REAPI instance name (default: main).")
    parser.add_argument("--seed", type=int, default=20261002, help="Deterministic seed for blob content and probes.")
    parser.add_argument(
        "--sizes",
        default=",".join(str(s) for s in DEFAULT_SIZES),
        help="Comma-separated blob sizes for the write/read/range probes.",
    )
    parser.add_argument("--run-id", default=None, help="Override the seed-derived run id (advanced; stays deterministic).")
    parser.add_argument("--json", dest="json_out", metavar="PATH", default=None,
                        help="Write the full structured report as JSON to PATH ('-' for stdout).")
    parser.add_argument("--quiet", action="store_true", help="Suppress the human-readable summary.")
    args = parser.parse_args(argv)

    if len(args.endpoint) < 2:
        parser.error("need at least 2 --endpoint specs (pass the same address twice for a self-check)")
    try:
        sizes = [int(s) for s in args.sizes.split(",") if s.strip()]
    except ValueError:
        parser.error("--sizes must be a comma-separated list of integers")

    try:
        harness = DifferentialHarness(
            args.endpoint, seed=args.seed, instance=args.instance, sizes=sizes, run_id=args.run_id
        )
        report = harness.run()
    except Exception as error:
        sys.stderr.write(f"differential harness error: {error}\n")
        traceback.print_exc()
        return 1

    if not args.quiet:
        print(render_human(report))
    if args.json_out:
        payload = json.dumps(report.to_dict(), indent=2) + "\n"
        if args.json_out == "-":
            sys.stdout.write(payload)
        else:
            path = pathlib.Path(args.json_out)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(payload)

    return 2 if report.verdict == "diverge" else 0


if __name__ == "__main__":
    sys.exit(main())
