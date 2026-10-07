#!/usr/bin/env python3
"""rechaos conformance scorecard: point it at a REAPI/RBE endpoint, get a graded
correctness report.

This is the product-ization of the chaos/determinism toolkit. Where
``fleet-stress.py`` hunts for faults under concurrency and ``consistency_oracle.py``
checks a recorded history against a formal model, this driver runs a *fixed,
deterministic battery* of protocol-correctness and capability probes against a
single endpoint and renders a graded scorecard --- the kind of artifact you hand
to a vendor or attach to a procurement decision.

Design constraints:

  * Protocol-only. No server source imports, no configuration edits, no restarts.
    Everything here is a black-box gRPC call against the public REAPI surface
    (``build.bazel.remote.execution.v2`` + ``google.bytestream``).
  * Deterministic. Blob contents are derived from ``--seed`` via SHAKE-256 and the
    probe order is fixed, so two runs against the same server yield the same
    checks in the same order. Only observed server behaviour (and timing, which is
    excluded from the graded output) varies between runs.
  * Non-destructive to classification. A *missing* RPC (the server returns
    UNIMPLEMENTED / NOT_FOUND-for-method / 404) is classified UNSUPPORTED, never
    FAIL. A FAIL means the server implements the method but violates the spec.

Every probe returns a :class:`Check` with a stable ``id``, a ``category``, a
status in {PASS, FAIL, UNSUPPORTED, SKIP}, a one-line ``detail``, and structured
``evidence``. Probes are grouped into categories; categories roll up into a
feature-support matrix, an inferred consistency level, and an overall letter
grade. See ``docs/conformance.md`` for the full rubric.

CLI::

    conformance_report.py --endpoint HOST:PORT --instance NAME --out DIR

Writes ``DIR/scorecard.json`` and ``DIR/scorecard.md``. Exit status is 0 when the
battery ran to completion (regardless of grade) and non-zero only when the
battery could not run (e.g. the endpoint was unreachable), so this is safe to
wire into CI as an evidence generator while using the JSON ``grade`` for gating.
"""
import argparse
import collections
import datetime
import hashlib
import json
import pathlib
import sys
import uuid

from reapi_values import action_observation

ROOT = pathlib.Path(__file__).resolve().parents[1]
# The independent Python gRPC runtime and generated bindings live under
# .build/python (see scripts/test.sh), mirroring test/integration.py.
sys.path.insert(0, str(ROOT / ".build/python"))
import grpc
from build.bazel.remote.execution.v2 import remote_execution_pb2 as re
from build.bazel.remote.execution.v2 import remote_execution_pb2_grpc as re_grpc
from google.bytestream import bytestream_pb2 as bs
from google.bytestream import bytestream_pb2_grpc as bs_grpc

PASS, FAIL, UNSUPPORTED, SKIP = "PASS", "FAIL", "UNSUPPORTED", "SKIP"

# Categories, in report order, with human-readable titles. Probe ``category``
# values must be keys here.
CATEGORIES = {
    "capabilities": "Capability negotiation",
    "cas": "Content-addressable storage",
    "bytestream": "ByteStream semantics",
    "integrity": "Content-addressing integrity",
    "actioncache": "Action cache",
    "batch": "Batch operations",
}

# gRPC codes that mean "this method is not implemented here" rather than "this
# method is implemented and rejected your request". A server that answers an
# unknown method with an HTTP/2 404 surfaces as UNIMPLEMENTED in grpcio.
UNIMPLEMENTED_CODES = {grpc.StatusCode.UNIMPLEMENTED}

# Transport/availability codes that are NOT spec violations: an endpoint that is
# down, or a request that timed out, tells us nothing about conformance. Core
# probes map these to SKIP so an unreachable server grades as "unknown", never as
# a false FAIL that would slander a correct implementation.
TRANSPORT_CODES = {grpc.StatusCode.UNAVAILABLE, grpc.StatusCode.DEADLINE_EXCEEDED}


class Check:
    """One graded probe result."""

    def __init__(self, check_id, category, title, status, detail, evidence=None):
        assert status in (PASS, FAIL, UNSUPPORTED, SKIP), status
        assert category in CATEGORIES, category
        self.id = check_id
        self.category = category
        self.title = title
        self.status = status
        self.detail = detail
        self.evidence = evidence or {}

    def as_dict(self):
        return {
            "id": self.id,
            "category": self.category,
            "title": self.title,
            "status": self.status,
            "detail": self.detail,
            "evidence": self.evidence,
        }


def digest_bytes(data):
    return hashlib.sha256(data).hexdigest()


class Harness:
    """Deterministic blob factory + REAPI call helpers against one endpoint.

    Blob bytes are a pure function of (seed, label), so the probe battery is
    reproducible. Upload resource ids embed a UUID derived from the digest and a
    nonce label, keeping uploads collision-free without introducing nondeterminism
    that would change the *content* being tested.
    """

    def __init__(self, endpoint, instance, seed):
        self.endpoint = endpoint
        self.instance = instance
        self.seed = seed
        self.channel = grpc.insecure_channel(endpoint)
        self.bs = bs_grpc.ByteStreamStub(self.channel)
        self.cas = re_grpc.ContentAddressableStorageStub(self.channel)
        self.ac = re_grpc.ActionCacheStub(self.channel)
        self.caps = re_grpc.CapabilitiesStub(self.channel)

    def close(self):
        self.channel.close()

    def blob(self, label, size):
        data = hashlib.shake_256(f"{self.seed}/{label}".encode()).digest(size)
        return data, digest_bytes(data), size

    def read_name(self, h, n):
        return f"{self.instance}/blobs/{h}/{n}"

    def upload_name(self, h, n, nonce):
        raw = hashlib.sha256(f"{h}/{nonce}".encode()).digest()[:16]
        return f"{self.instance}/uploads/{uuid.UUID(bytes=raw, version=4)}/blobs/{h}/{n}"

    def write(self, data, h, n, nonce, declared_size=None, send_bytes=None,
              finish=True, chunk=65536, timeout=8):
        """Stream an upload. ``declared_size`` overrides the size in the resource
        name (to probe honesty); ``send_bytes`` overrides how many bytes are
        actually streamed (to probe short-upload rejection)."""
        name = self.upload_name(h, declared_size if declared_size is not None else n, nonce)
        payload = data if send_bytes is None else data[:send_bytes]

        def requests():
            if not payload:
                yield bs.WriteRequest(resource_name=name, write_offset=0, finish_write=finish)
                return
            for pos in range(0, len(payload), chunk):
                part = payload[pos:pos + chunk]
                yield bs.WriteRequest(
                    resource_name=name if pos == 0 else "",
                    write_offset=pos, data=part,
                    finish_write=finish and pos + len(part) == len(payload))

        reply = self.bs.Write(requests(), timeout=timeout)
        return name, reply.committed_size

    def read(self, h, n, offset=0, limit=0, timeout=8):
        got = b"".join(
            m.data for m in self.bs.Read(
                bs.ReadRequest(resource_name=self.read_name(h, n),
                               read_offset=offset, read_limit=limit),
                timeout=timeout))
        return got


def unimplemented(error):
    """True when a gRPC error means the method is not implemented here."""
    return error.code() in UNIMPLEMENTED_CODES


def transport(error):
    """True when a gRPC error is a transport/availability fault, not a spec signal."""
    return error.code() in TRANSPORT_CODES


def error_status(error):
    return UNSUPPORTED if unimplemented(error) else (SKIP if transport(error) else FAIL)


# --------------------------------------------------------------------------- #
# Probes. Each takes (harness, context) and returns one or more Checks. ``context``
# is a mutable dict shared across probes so earlier discoveries (e.g. advertised
# digest functions, max batch size) inform later probes.
# --------------------------------------------------------------------------- #

def probe_capabilities(h, ctx):
    try:
        reply = h.caps.GetCapabilities(
            re.GetCapabilitiesRequest(instance_name=h.instance), timeout=8)
    except grpc.RpcError as error:
        if unimplemented(error):
            return [Check("cap.get", "capabilities", "GetCapabilities negotiation",
                          UNSUPPORTED, "server does not implement Capabilities",
                          {"code": error.code().name, "details": error.details()[:200]})]
        status = SKIP if transport(error) else FAIL
        return [Check("cap.get", "capabilities", "GetCapabilities negotiation",
                      status, f"GetCapabilities errored: {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]})]
    cc = reply.cache_capabilities
    digests = [re.DigestFunction.Value.Name(d) for d in cc.digest_functions]
    ctx["advertised_digest_functions"] = digests
    ctx["advertised_max_batch"] = cc.max_batch_total_size_bytes
    evidence = {
        "digestFunctions": digests,
        "maxBatchTotalSizeBytes": cc.max_batch_total_size_bytes,
        "maxCasBlobSizeBytes": cc.max_cas_blob_size_bytes,
        "actionCacheUpdateEnabled": cc.action_cache_update_capabilities.update_enabled,
        "symlinkAbsolutePathStrategy": cc.symlink_absolute_path_strategy,
        "supportedCompressors": list(cc.supported_compressors),
        "lowApiVersion": {"major": reply.low_api_version.major,
                          "minor": reply.low_api_version.minor,
                          "patch": reply.low_api_version.patch},
        "highApiVersion": {"major": reply.high_api_version.major,
                           "minor": reply.high_api_version.minor,
                           "patch": reply.high_api_version.patch},
    }
    checks = [Check("cap.get", "capabilities", "GetCapabilities negotiation",
                    PASS, f"advertised {len(digests)} digest function(s)", evidence)]
    # A server that implements Capabilities but advertises no digest function or
    # no API version range is giving a malformed negotiation; flag it.
    if not digests:
        checks.append(Check("cap.digests", "capabilities",
                            "Advertises at least one digest function",
                            FAIL, "digest_functions empty", evidence))
    else:
        checks.append(Check("cap.digests", "capabilities",
                            "Advertises at least one digest function",
                            PASS, ", ".join(digests), {"digestFunctions": digests}))
    return checks


def probe_cas_roundtrip(h, ctx):
    data, dig, n = h.blob("roundtrip", 4096)
    try:
        name, committed = h.write(data, dig, n, "roundtrip")
    except grpc.RpcError as error:
        status = SKIP if transport(error) else FAIL
        return [Check("cas.write", "cas", "CAS upload (ByteStream.Write)",
                      status, f"write errored: {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]})]
    checks = []
    if committed == n:
        checks.append(Check("cas.write", "cas", "CAS upload (ByteStream.Write)",
                            PASS, f"committed {committed} bytes",
                            {"declared": n, "committed": committed}))
    else:
        checks.append(Check("cas.write", "cas", "CAS upload (ByteStream.Write)",
                            FAIL, f"committed {committed} != declared {n}",
                            {"declared": n, "committed": committed}))
    ctx["roundtrip_present"] = committed == n
    try:
        got = h.read(dig, n)
    except grpc.RpcError as error:
        status = SKIP if transport(error) else FAIL
        checks.append(Check("cas.read", "cas", "CAS download (ByteStream.Read)",
                            status, f"read errored: {error.code().name}",
                            {"code": error.code().name, "details": error.details()[:200]}))
        return checks
    if got == data:
        checks.append(Check("cas.read", "cas", "CAS download (ByteStream.Read)",
                            PASS, "round-trip bytes match",
                            {"bytes": len(got)}))
    else:
        checks.append(Check("cas.read", "cas", "CAS download (ByteStream.Read)",
                            FAIL, "read-back bytes differ from upload",
                            {"expectedSha256": dig, "gotSha256": digest_bytes(got),
                             "gotBytes": len(got)}))
    return checks


def probe_find_missing(h, ctx):
    present, dig_p, n_p = h.blob("fmb-present", 512)
    absent, dig_a, n_a = h.blob("fmb-absent", 517)
    try:
        h.write(present, dig_p, n_p, "fmb-present")
    except grpc.RpcError as error:
        return [Check("cas.fmb", "cas", "FindMissingBlobs integrity",
                      SKIP, f"setup write failed: {error.code().name}", {})]
    try:
        reply = h.cas.FindMissingBlobs(re.FindMissingBlobsRequest(
            instance_name=h.instance, digest_function=re.DigestFunction.SHA256,
            blob_digests=[re.Digest(hash=dig_p, size_bytes=n_p),
                          re.Digest(hash=dig_a, size_bytes=n_a)]), timeout=8)
    except grpc.RpcError as error:
        if unimplemented(error):
            return [Check("cas.fmb", "cas", "FindMissingBlobs integrity",
                          UNSUPPORTED, "FindMissingBlobs not implemented",
                          {"code": error.code().name})]
        return [Check("cas.fmb", "cas", "FindMissingBlobs integrity",
                      error_status(error), f"errored: {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]})]
    missing = {(d.hash, d.size_bytes) for d in reply.missing_blob_digests}
    expected = {(dig_a, n_a)}
    evidence = {"missingReported": [{"hash": hh, "size": ss} for hh, ss in sorted(missing)],
                "expectedMissing": [{"hash": dig_a, "size": n_a}],
                "presentDigest": {"hash": dig_p, "size": n_p}}
    if missing == expected:
        return [Check("cas.fmb", "cas", "FindMissingBlobs integrity",
                      PASS, "reports exactly the absent blob", evidence)]
    return [Check("cas.fmb", "cas", "FindMissingBlobs integrity",
                  FAIL, "missing set does not match ground truth", evidence)]


def probe_committed_size_honesty(h, ctx):
    data, dig, n = h.blob("committed", 8192)
    try:
        name, committed = h.write(data, dig, n, "committed")
    except grpc.RpcError as error:
        return [Check("bs.committed", "bytestream", "Committed-size honesty",
                      SKIP, f"write failed: {error.code().name}", {})]
    if committed != n:
        return [Check("bs.committed", "bytestream", "Committed-size honesty",
                      FAIL, f"Write reported committed {committed} != {n}",
                      {"declared": n, "committed": committed})]
    try:
        q = h.bs.QueryWriteStatus(bs.QueryWriteStatusRequest(resource_name=name), timeout=6)
    except grpc.RpcError as error:
        if unimplemented(error):
            return [Check("bs.committed", "bytestream", "Committed-size honesty",
                          PASS, "Write committed_size correct (QueryWriteStatus absent)",
                          {"writeCommitted": committed})]
        return [Check("bs.committed", "bytestream", "Committed-size honesty",
                      SKIP if error.code() == grpc.StatusCode.NOT_FOUND else error_status(error),
                      f"QueryWriteStatus errored: {error.code().name}",
                      {"code": error.code().name})]
    ok = q.complete and q.committed_size == n
    evidence = {"declared": n, "writeCommitted": committed,
                "queryCommitted": q.committed_size, "queryComplete": q.complete}
    return [Check("bs.committed", "bytestream", "Committed-size honesty",
                  PASS if ok else FAIL,
                  "Write and QueryWriteStatus agree on size" if ok
                  else "committed-size disagreement after finished upload", evidence)]


def probe_query_write_status(h, ctx):
    """QueryWriteStatus sanity: on a fully-written upload it must report complete."""
    data, dig, n = h.blob("qws", 3000)
    try:
        name, _ = h.write(data, dig, n, "qws")
    except grpc.RpcError as error:
        return [Check("bs.qws", "bytestream", "QueryWriteStatus sanity",
                      SKIP, f"write failed: {error.code().name}", {})]
    try:
        q = h.bs.QueryWriteStatus(bs.QueryWriteStatusRequest(resource_name=name), timeout=6)
    except grpc.RpcError as error:
        if unimplemented(error):
            return [Check("bs.qws", "bytestream", "QueryWriteStatus sanity",
                          UNSUPPORTED, "QueryWriteStatus not implemented",
                          {"code": error.code().name})]
        return [Check("bs.qws", "bytestream", "QueryWriteStatus sanity",
                      SKIP if error.code() == grpc.StatusCode.NOT_FOUND else error_status(error),
                      f"errored: {error.code().name}", {"code": error.code().name})]
    evidence = {"complete": q.complete, "committedSize": q.committed_size, "declared": n}
    ok = q.complete and q.committed_size == n
    return [Check("bs.qws", "bytestream", "QueryWriteStatus sanity",
                  PASS if ok else FAIL,
                  "reports complete with exact committed size" if ok
                  else "complete/committed inconsistent", evidence)]


def probe_range_reads(h, ctx):
    """Range-read correctness, including the past-EOF case. REAPI requires a read
    with read_offset == size (or read_limit past the end) to succeed and yield
    exactly the remaining bytes (zero at EOF)."""
    data, dig, n = h.blob("ranges", 10000)
    try:
        h.write(data, dig, n, "ranges")
    except grpc.RpcError as error:
        return [Check("bs.range", "bytestream", "Range-read correctness",
                      SKIP, f"write failed: {error.code().name}", {})]
    cases = [
        ("whole", 0, 0, data),
        ("prefix", 0, 100, data[:100]),
        ("suffix", n - 100, 0, data[n - 100:]),
        ("interior", 4096, 2048, data[4096:4096 + 2048]),
        ("at-eof", n, 0, b""),
        ("limit-past-eof", n - 50, 1000, data[n - 50:]),
    ]
    results = []
    all_ok = True
    incorrect = False
    for label, off, lim, expect in cases:
        try:
            got = h.read(dig, n, offset=off, limit=lim)
            ok = got == expect
            results.append({"case": label, "offset": off, "limit": lim,
                            "gotBytes": len(got), "expectBytes": len(expect), "ok": ok})
            all_ok = all_ok and ok
            incorrect = incorrect or not ok
        except grpc.RpcError as error:
            results.append({"case": label, "offset": off, "limit": lim,
                            "error": error.code().name})
            all_ok = False
            incorrect = incorrect or not (transport(error) or unimplemented(error))
    return [Check("bs.range", "bytestream", "Range-read correctness",
                  PASS if all_ok else (FAIL if incorrect else SKIP),
                  "all range cases correct (incl. past-EOF)" if all_ok
                  else "one or more range cases incorrect",
                  {"cases": results})]


def probe_short_upload_rejection(h, ctx):
    """A client that declares size N but finishes after < N bytes must be rejected
    (INVALID_ARGUMENT), never silently accepted as a valid blob."""
    data, dig, n = h.blob("short", 6000)
    try:
        name, committed = h.write(data, dig, n, "short", send_bytes=100, finish=True)
    except grpc.RpcError as error:
        if error.code() in (grpc.StatusCode.INVALID_ARGUMENT,
                            grpc.StatusCode.FAILED_PRECONDITION,
                            grpc.StatusCode.DATA_LOSS):
            return [Check("bs.short", "bytestream", "Short-upload rejection",
                          PASS, f"rejected with {error.code().name}",
                          {"code": error.code().name, "details": error.details()[:200]})]
        if unimplemented(error):
            return [Check("bs.short", "bytestream", "Short-upload rejection",
                          UNSUPPORTED, "Write not implemented", {"code": error.code().name})]
        status = SKIP if transport(error) else FAIL
        return [Check("bs.short", "bytestream", "Short-upload rejection",
                      status, f"unexpected error {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]})]
    # No error: accepting a short upload is a correctness failure only if the
    # server then exposes it. committed < n already proves it did not honour the
    # declared size as a complete blob.
    exposed = False
    try:
        got = h.read(dig, n, timeout=5)
        exposed = got == data
    except grpc.RpcError:
        exposed = False
    evidence = {"declared": n, "sent": 100, "committed": committed, "fullBlobReadable": exposed}
    return [Check("bs.short", "bytestream", "Short-upload rejection",
                  FAIL, "short upload not rejected", evidence)]


def probe_integrity(h, ctx):
    """Content-addressing integrity: bytes served under digest D must hash to D.
    We upload bytes that do NOT hash to the declared digest and check that the
    server either rejects the write or, at minimum, never serves those wrong bytes
    back under the claimed digest."""
    data, dig, n = h.blob("integrity-good", 777)
    wrong = bytes((b ^ 0x5A) for b in data)  # same length, different content
    assert digest_bytes(wrong) != dig
    try:
        name, committed = h.write(wrong, dig, n, "integrity-bad")
    except grpc.RpcError as error:
        if error.code() in (grpc.StatusCode.INVALID_ARGUMENT,
                            grpc.StatusCode.FAILED_PRECONDITION,
                            grpc.StatusCode.DATA_LOSS):
            return [Check("integrity.write", "integrity",
                          "Rejects bytes that do not match the digest",
                          PASS, f"mismatched upload rejected with {error.code().name}",
                          {"code": error.code().name})]
        status = SKIP if transport(error) else FAIL
        return [Check("integrity.write", "integrity",
                      "Rejects bytes that do not match the digest",
                      status, f"unexpected error {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]})]
    # Write was accepted; see whether the wrong bytes are now readable under the
    # claimed digest. If so, content-addressing is violated.
    try:
        got = h.read(dig, n, timeout=6)
    except grpc.RpcError as error:
        return [Check("integrity.write", "integrity",
                      "Rejects bytes that do not match the digest",
                      (SKIP if transport(error) or unimplemented(error) else
                       PASS if error.code() in {grpc.StatusCode.NOT_FOUND, grpc.StatusCode.DATA_LOSS,
                                               grpc.StatusCode.INVALID_ARGUMENT, grpc.StatusCode.FAILED_PRECONDITION}
                       else SKIP),
                      "mismatched upload readback failed; see readError",
                      {"committed": committed, "readError": error.code().name})]
    violated = digest_bytes(got) != dig or len(got) != n
    evidence = {"claimedDigest": dig, "servedSha256": digest_bytes(got),
                "committed": committed, "servedWrongBytes": got == wrong}
    return [Check("integrity.write", "integrity",
                  "Rejects bytes that do not match the digest",
                  FAIL if violated else PASS,
                  "serves bytes that do not hash to the claimed digest" if violated
                  else "mismatched bytes not served under claimed digest", evidence)]


def probe_action_cache(h, ctx):
    """ActionCache put/get round-trip. The AC is a mutable last-writer-wins
    register keyed by action digest; we write an ActionResult and read it back."""
    # A valid AC update requires its Action and Command to exist in CAS.
    command = re.Command(arguments=["/bin/true", str(h.seed)])
    command_data = command.SerializeToString(deterministic=True)
    root_data = re.Directory().SerializeToString(deterministic=True)
    action = re.Action(command_digest=re.Digest(hash=digest_bytes(command_data), size_bytes=len(command_data)),
                       input_root_digest=re.Digest(hash=digest_bytes(root_data), size_bytes=len(root_data)))
    action_data = action.SerializeToString(deterministic=True)
    try:
        for label, data in (("command", command_data), ("root", root_data), ("action", action_data)):
            _, committed = h.write(data, digest_bytes(data), len(data), "ac-" + label)
            if committed != len(data):
                return [Check("ac.update", "actioncache", "UpdateActionResult", SKIP,
                              "prerequisite upload reported wrong size", {})]
    except grpc.RpcError as error:
        return [Check("ac.update", "actioncache", "UpdateActionResult", SKIP,
                      f"prerequisite upload failed: {error.code().name}", {})]
    action_digest = re.Digest(hash=digest_bytes(action_data), size_bytes=len(action_data))
    result = re.ActionResult(exit_code=0)
    try:
        updated = h.ac.UpdateActionResult(re.UpdateActionResultRequest(
            instance_name=h.instance, action_digest=action_digest,
            action_result=result, digest_function=re.DigestFunction.SHA256), timeout=8)
    except grpc.RpcError as error:
        if unimplemented(error):
            return [Check("ac.update", "actioncache", "UpdateActionResult",
                          UNSUPPORTED, "UpdateActionResult not implemented",
                          {"code": error.code().name}),
                    Check("ac.get", "actioncache", "GetActionResult",
                          SKIP, "skipped: AC update unsupported", {})]
        status = SKIP if transport(error) else FAIL
        return [Check("ac.update", "actioncache", "UpdateActionResult",
                      status, f"errored: {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]}),
                Check("ac.get", "actioncache", "GetActionResult",
                      SKIP, "skipped: AC update failed", {})]
    checks = [Check("ac.update", "actioncache", "UpdateActionResult",
                    PASS if action_observation(updated) == action_observation(result) else FAIL,
                    f"returned ActionResult (exit_code={updated.exit_code})",
                    {"exitCode": updated.exit_code})]
    try:
        got = h.ac.GetActionResult(re.GetActionResultRequest(
            instance_name=h.instance, action_digest=action_digest,
            digest_function=re.DigestFunction.SHA256), timeout=8)
    except grpc.RpcError as error:
        if unimplemented(error):
            checks.append(Check("ac.get", "actioncache", "GetActionResult",
                                UNSUPPORTED, "GetActionResult not implemented",
                                {"code": error.code().name}))
        else:
            checks.append(Check("ac.get", "actioncache", "GetActionResult",
                                error_status(error), f"errored: {error.code().name}",
                                {"code": error.code().name}))
        return checks
    ok = action_observation(got) == action_observation(result)
    checks.append(Check("ac.get", "actioncache", "GetActionResult",
                        PASS if ok else FAIL,
                        "round-trips stored ActionResult" if ok
                        else "read-back ActionResult differs from the stored value",
                        {"stored": action_observation(result), "read": action_observation(got)}))
    return checks


def probe_digest_functions(h, ctx):
    """Digest-function support. If Capabilities advertised a set, verify SHA256 is
    among it (the one we exercise everywhere). Without Capabilities, we infer
    SHA256 support from the fact that the CAS round-trip above succeeded."""
    advertised = ctx.get("advertised_digest_functions")
    if advertised is not None:
        ok = "SHA256" in advertised
        return [Check("digest.sha256", "cas", "SHA256 digest-function support",
                      PASS if ok else FAIL,
                      "SHA256 advertised" if ok else "SHA256 not advertised",
                      {"advertised": advertised})]
    inferred = ctx.get("roundtrip_present")
    if inferred:
        return [Check("digest.sha256", "cas", "SHA256 digest-function support",
                      PASS, "SHA256 round-trip succeeded (no Capabilities to advertise)",
                      {"inferredFrom": "cas.roundtrip"})]
    return [Check("digest.sha256", "cas", "SHA256 digest-function support",
                  SKIP, "could not determine digest support", {})]


def probe_batch(h, ctx):
    """Batch operations: BatchUpdateBlobs then BatchReadBlobs for small blobs, and
    an inferred max-batch limit from Capabilities when present."""
    blobs = [h.blob(f"batch-{i}", 64 + i) for i in range(3)]
    requests = [re.BatchUpdateBlobsRequest.Request(
        digest=re.Digest(hash=d, size_bytes=n), data=data)
        for (data, d, n) in blobs]
    checks = []
    try:
        up = h.cas.BatchUpdateBlobs(re.BatchUpdateBlobsRequest(
            instance_name=h.instance, requests=requests,
            digest_function=re.DigestFunction.SHA256), timeout=8)
    except grpc.RpcError as error:
        if unimplemented(error):
            return [Check("batch.update", "batch", "BatchUpdateBlobs",
                          UNSUPPORTED, "BatchUpdateBlobs not implemented",
                          {"code": error.code().name}),
                    Check("batch.read", "batch", "BatchReadBlobs",
                          SKIP, "skipped: batch update unsupported", {}),
                    Check("batch.limit", "batch", "max_batch_total_size_bytes advertised",
                          SKIP, "skipped: batch unsupported", {})]
        status = SKIP if transport(error) else FAIL
        return [Check("batch.update", "batch", "BatchUpdateBlobs",
                      status, f"errored: {error.code().name}",
                      {"code": error.code().name, "details": error.details()[:200]}),
                Check("batch.read", "batch", "BatchReadBlobs",
                      SKIP, "skipped: batch update failed", {}),
                Check("batch.limit", "batch", "max_batch_total_size_bytes advertised",
                      SKIP, "skipped: batch update failed", {})]
    expected_digests = {(d, n) for _, d, n in blobs}
    update_ok = (all(r.status.code == 0 for r in up.responses)
                 and len(up.responses) == len(blobs)
                 and {(r.digest.hash, r.digest.size_bytes) for r in up.responses} == expected_digests)
    checks.append(Check("batch.update", "batch", "BatchUpdateBlobs",
                        PASS if update_ok else FAIL,
                        f"stored {len(up.responses)} blob(s)" if update_ok
                        else "one or more sub-responses failed",
                        {"responses": [{"code": r.status.code} for r in up.responses]}))
    try:
        rd = h.cas.BatchReadBlobs(re.BatchReadBlobsRequest(
            instance_name=h.instance,
            digests=[re.Digest(hash=d, size_bytes=n) for (_, d, n) in blobs],
            digest_function=re.DigestFunction.SHA256), timeout=8)
    except grpc.RpcError as error:
        if unimplemented(error):
            checks.append(Check("batch.read", "batch", "BatchReadBlobs",
                                UNSUPPORTED, "BatchReadBlobs not implemented",
                                {"code": error.code().name}))
        else:
            checks.append(Check("batch.read", "batch", "BatchReadBlobs",
                                error_status(error), f"errored: {error.code().name}",
                                {"code": error.code().name}))
    else:
        by_digest = {(r.digest.hash, r.digest.size_bytes): r for r in rd.responses}
        read_ok = len(rd.responses) == len(blobs) and set(by_digest) == expected_digests
        detail_rows = []
        for (data, d, n) in blobs:
            r = by_digest.get((d, n))
            good = r is not None and r.status.code == 0 and r.data == data
            read_ok = read_ok and good
            detail_rows.append({"hash": d[:12], "ok": good,
                                "code": None if r is None else r.status.code})
        checks.append(Check("batch.read", "batch", "BatchReadBlobs",
                            PASS if read_ok else FAIL,
                            "round-trips all batch blobs" if read_ok
                            else "batch read-back mismatch",
                            {"blobs": detail_rows}))
    # Max-batch limit: report from Capabilities if advertised, else inferred.
    advertised_limit = ctx.get("advertised_max_batch")
    if advertised_limit:
        checks.append(Check("batch.limit", "batch", "max_batch_total_size_bytes advertised",
                            PASS, f"server advertises {advertised_limit} bytes",
                            {"maxBatchTotalSizeBytes": advertised_limit}))
    else:
        checks.append(Check("batch.limit", "batch", "max_batch_total_size_bytes advertised",
                            UNSUPPORTED, "no batch-size limit advertised (Capabilities absent)",
                            {}))
    return checks


# Ordered battery. Capabilities first (populates ctx), then CAS round-trip
# (populates roundtrip_present used by digest inference), then the rest.
PROBES = [
    probe_capabilities,
    probe_cas_roundtrip,
    probe_digest_functions,
    probe_find_missing,
    probe_committed_size_honesty,
    probe_query_write_status,
    probe_range_reads,
    probe_short_upload_rejection,
    probe_integrity,
    probe_action_cache,
    probe_batch,
]


# --------------------------------------------------------------------------- #
# Grading
# --------------------------------------------------------------------------- #

def grade(checks):
    """Compute the overall letter grade from the graded checks.

    Only PASS/FAIL count toward the grade; UNSUPPORTED and SKIP are excluded from
    the denominator (an absent optional method should not tank the score, and the
    feature matrix already records it). Any FAIL in the ``integrity`` category is a
    hard cap at D, because content-addressing integrity is the one property whose
    violation makes the store unsafe regardless of everything else.
    """
    graded = [c for c in checks if c.status in (PASS, FAIL)]
    passed = sum(1 for c in graded if c.status == PASS)
    total = len(graded)
    integrity_failed = any(c.status == FAIL and c.category == "integrity" for c in checks)
    if total == 0:
        # Nothing was gradable (e.g. the endpoint was unreachable). Report N/A
        # rather than a misleading F so callers can distinguish "could not test"
        # from "tested and failed everything".
        return {"letter": "N/A", "passed": 0, "failed": 0, "graded": 0,
                "passRatio": None, "integrityFailed": integrity_failed,
                "integrityCapApplied": False}
    ratio = passed / total
    if ratio >= 0.97:
        letter = "A"
    elif ratio >= 0.90:
        letter = "B"
    elif ratio >= 0.80:
        letter = "C"
    elif ratio >= 0.65:
        letter = "D"
    else:
        letter = "F"
    capped = False
    if integrity_failed and letter in ("A", "B", "C"):
        letter = "D"
        capped = True
    return {
        "letter": letter,
        "passed": passed,
        "failed": total - passed,
        "graded": total,
        "passRatio": round(ratio, 4),
        "integrityFailed": integrity_failed,
        "integrityCapApplied": capped,
    }


def infer_consistency(checks):
    """Infer a coarse consistency level from the correctness evidence.

    This is deliberately conservative and explainable, not a linearizability proof
    (that is consistency_oracle.py's job). We map observed guarantees to a level:

      content-addressed : CAS round-trip PASS, integrity PASS, FindMissingBlobs PASS
      read-your-writes  : CAS round-trip PASS (read-back) but integrity FAIL or no
                          FindMissingBlobs evidence
      unknown           : CAS round-trip did not pass
    """
    by_id = {c.id: c.status for c in checks}
    roundtrip = by_id.get("cas.read") == PASS and by_id.get("cas.write") == PASS
    integrity_ok = by_id.get("integrity.write") == PASS
    fmb_ok = by_id.get("cas.fmb") == PASS
    if not roundtrip:
        level, reason = "unknown", "CAS round-trip did not pass"
    elif integrity_ok and fmb_ok:
        level, reason = "content-addressed", "round-trip, integrity, and FindMissingBlobs all pass"
    elif integrity_ok:
        level, reason = "read-your-writes", "round-trip and integrity pass; FindMissingBlobs not confirmed"
    else:
        level, reason = "read-your-writes", "read-back works but content-addressing integrity is violated"
    return {"level": level, "reason": reason,
            "signals": {"roundtrip": roundtrip, "integrity": integrity_ok, "findMissingBlobs": fmb_ok}}


def feature_matrix(checks):
    """Feature-support matrix: one row per notable method, derived from check ids."""
    features = [
        ("Capabilities.GetCapabilities", "cap.get"),
        ("ByteStream.Write", "cas.write"),
        ("ByteStream.Read", "cas.read"),
        ("ByteStream.QueryWriteStatus", "bs.qws"),
        ("CAS.FindMissingBlobs", "cas.fmb"),
        ("CAS.BatchUpdateBlobs", "batch.update"),
        ("CAS.BatchReadBlobs", "batch.read"),
        ("ActionCache.UpdateActionResult", "ac.update"),
        ("ActionCache.GetActionResult", "ac.get"),
    ]
    by_id = {c.id: c for c in checks}
    rows = []
    for name, cid in features:
        c = by_id.get(cid)
        if c is None:
            support = "unknown"
        elif c.status == UNSUPPORTED:
            support = "unsupported"
        elif c.status == SKIP:
            support = "untested"
        elif c.status == PASS:
            support = "supported"
        else:
            support = "supported-with-defects"
        rows.append({"feature": name, "support": support,
                     "status": None if c is None else c.status})
    return rows


# --------------------------------------------------------------------------- #
# Rendering
# --------------------------------------------------------------------------- #

def build_scorecard(args, checks):
    by_cat = collections.OrderedDict((k, []) for k in CATEGORIES)
    for c in checks:
        by_cat[c.category].append(c.as_dict())
    status_counts = collections.Counter(c.status for c in checks)
    return {
        "tool": "rechaos-conformance",
        "formatVersion": 1,
        "endpoint": args.endpoint,
        "instance": args.instance,
        "seed": args.seed,
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "grade": grade(checks),
        "consistency": infer_consistency(checks),
        "statusCounts": dict(status_counts),
        "featureMatrix": feature_matrix(checks),
        "categories": [
            {"id": cid, "title": CATEGORIES[cid], "checks": by_cat[cid]}
            for cid in CATEGORIES
        ],
    }


def render_markdown(card):
    g = card["grade"]
    con = card["consistency"]
    out = []
    out.append(f"# REAPI conformance scorecard")
    out.append("")
    out.append(f"- **Endpoint**: `{card['endpoint']}`  (instance `{card['instance']}`)")
    out.append(f"- **Generated**: {card['generatedAt']}  (seed `{card['seed']}`)")
    ratio_text = "n/a" if g["passRatio"] is None else g["passRatio"]
    out.append(f"- **Overall grade**: **{g['letter']}**  "
               f"({g['passed']}/{g['graded']} graded checks pass, "
               f"ratio {ratio_text})")
    if g["integrityCapApplied"]:
        out.append(f"- **Note**: grade capped at D by a content-addressing "
                   f"integrity failure.")
    out.append(f"- **Inferred consistency**: `{con['level']}` — {con['reason']}")
    counts = card["statusCounts"]
    out.append(f"- **Status counts**: " + ", ".join(
        f"{k}={counts.get(k, 0)}" for k in (PASS, FAIL, UNSUPPORTED, SKIP)))
    out.append("")
    out.append("## Feature-support matrix")
    out.append("")
    out.append("| Feature | Support | Last check |")
    out.append("| --- | --- | --- |")
    for row in card["featureMatrix"]:
        out.append(f"| {row['feature']} | {row['support']} | {row['status'] or '-'} |")
    out.append("")
    out.append("## Checks by category")
    glyph = {PASS: "PASS", FAIL: "FAIL", UNSUPPORTED: "UNSUP", SKIP: "SKIP"}
    for cat in card["categories"]:
        if not cat["checks"]:
            continue
        out.append("")
        out.append(f"### {cat['title']}")
        out.append("")
        out.append("| Status | Check | Detail |")
        out.append("| --- | --- | --- |")
        for c in cat["checks"]:
            detail = c["detail"].replace("|", "\\|")
            out.append(f"| {glyph[c['status']]} | {c['title']} | {detail} |")
    out.append("")
    out.append("## Grading rubric")
    out.append("")
    out.append("Only PASS/FAIL count toward the grade; UNSUPPORTED and SKIP are "
               "excluded from the denominator. A content-addressing integrity "
               "failure caps the grade at D. See `docs/conformance.md` for the "
               "full rubric and per-check definitions.")
    out.append("")
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--endpoint", default="127.0.0.1:50052",
                        help="host:port of the REAPI/RBE endpoint (default 127.0.0.1:50052)")
    parser.add_argument("--instance", default="main",
                        help="REAPI instance name (default: main)")
    parser.add_argument("--seed", type=int, default=20261002,
                        help="deterministic seed for blob contents (default: 20261002)")
    parser.add_argument("--out", required=True,
                        help="output directory; scorecard.json and scorecard.md are written here")
    args = parser.parse_args()

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    harness = Harness(args.endpoint, args.instance, args.seed)
    checks = []
    ctx = {}
    try:
        for probe in PROBES:
            try:
                checks.extend(probe(harness, ctx))
            except grpc.RpcError as error:
                # A probe that raises an un-handled RPC error becomes an explicit
                # SKIP so the battery always completes.
                checks.append(Check(f"{probe.__name__}.error", "capabilities",
                                    probe.__name__, SKIP,
                                    f"probe raised {error.code().name}",
                                    {"code": error.code().name}))
    finally:
        harness.close()

    card = build_scorecard(args, checks)
    (out / "scorecard.json").write_text(json.dumps(card, indent=2) + "\n")
    (out / "scorecard.md").write_text(render_markdown(card))

    # Compact summary to stdout for CI logs.
    g = card["grade"]
    print(json.dumps({
        "endpoint": args.endpoint, "grade": g["letter"],
        "passed": g["passed"], "failed": g["failed"], "graded": g["graded"],
        "consistency": card["consistency"]["level"],
        "statusCounts": card["statusCounts"],
        "out": str(out / "scorecard.json"),
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
