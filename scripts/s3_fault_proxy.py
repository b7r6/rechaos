#!/usr/bin/env python3
"""rechaos S3/R2 egress fault proxy: a transparent HTTP(S) forwarding proxy that
sits between NativeLink's ``fast_slow`` *slow* store and the real object store and
injects faults on the S3 REST API (GET/PUT/DELETE/HEAD/ListObjects).

This is the capability rechaos most lacked. The existing ``rechaos serve`` gateway
sits on the *client <-> NativeLink* gRPC path, so it can tear REAPI reads/writes
but can never exercise what happens when NativeLink's own object-store egress
degrades. The "death spiral" on the CAS -> object-store write-back path (the R2
retry loop fighting a throttling/slow backend, fast->slow reconciliation stalling,
unbounded buffering) was never reproduced because nothing injected faults on the
NativeLink <-> R2/S3 hop. This proxy closes that gap.

It speaks plain HTTP on its listen socket, forwards every request verbatim to an
``--upstream`` base URL, and streams the upstream response back to the caller.
Before forwarding, and while streaming the body back, it can inject faults
selected by S3 operation, key prefix, and probability, with a fixed RNG seed so a
run is reproducible.

Fault menu (each independently configurable; see ``--help``):

  * latency      -- sleep before forwarding (adds request-side delay)
  * slowdown     -- return 503 ``SlowDown`` (S3/R2 throttle signal) without
                    contacting upstream; also supports 429 / 500 / 503 generic
  * truncate     -- forward upstream headers, then send only the first N bytes of
                    the body and close (partial / short read)
  * reset        -- forward some bytes, then abruptly drop the TCP connection
                    mid-body (RST-like: no clean close, no trailing bytes)
  * drip         -- slow-loris: dribble the body at a byte-rate with small chunks
  * burst        -- deterministic error bursts: every Nth matching request in a
                    window fails with the slowdown status

Everything not selected for a fault is forwarded transparently (status line,
headers, and body), so NativeLink sees a faithful object store except where you
asked for trouble.

Stdlib only (http.server + ThreadingHTTPServer + urllib + ssl). No external deps.

Typical use (wire NativeLink's slow tier at this proxy; see
``examples/chaos/r2-fault-proxy.json5`` and ``docs/s3-faults.md``):

    # throttle 30% of PUTs under the cas/ prefix, add 200ms to every GET
    nix develop --command python3 scripts/s3_fault_proxy.py \\
        --listen 127.0.0.1:8081 \\
        --upstream https://<ACCOUNT>.r2.cloudflarestorage.com \\
        --slowdown-ops PUT --slowdown-prob 0.3 --slowdown-prefix cas/ \\
        --latency-ops GET --latency-ms 200 \\
        --seed 1

Design notes:
  * S3 operation is derived from HTTP method + query string, not from any R2/S3
    credential: GET/HEAD/PUT/DELETE map to themselves; a GET on a bucket root
    (no key) or with ``?list-type``/``?prefix`` is classified ListObjects.
  * Prefix matching is against the object key (the request path with the leading
    ``/`` and, for virtual-host style, the bucket segment stripped by ``--strip``).
  * Each incoming request is assigned a deterministic sub-seed derived from the
    master seed and a monotonically increasing request counter, so the fault
    decisions for request #k are identical across runs with the same seed and
    same request order. (Order is the only nondeterminism; for a single-threaded
    client like NativeLink's store under a fixed workload this is stable.)
  * This proxy NEVER inspects or logs credentials; it copies the ``Authorization``
    and ``x-amz-*`` headers through untouched. Do not point it at anything you do
    not control, and never hardcode an endpoint -- ``--upstream`` is required.
"""
import argparse
import http.server
import io
import random
import socket
import socketserver
import ssl
import struct
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

# S3 operations we classify and can target.
GET = "GET"
PUT = "PUT"
DELETE = "DELETE"
HEAD = "HEAD"
LIST = "ListObjects"
ALL_OPS = (GET, PUT, DELETE, HEAD, LIST)

# Hop-by-hop headers that must not be forwarded (RFC 7230 6.1) plus length/encoding
# fields we recompute per-leg as we stream.
HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade",
}


def parse_hostport(s, default_port):
    """Parse ``host:port`` (port optional) into a (host, port) tuple."""
    if ":" in s:
        host, _, port = s.rpartition(":")
        return host, int(port)
    return s, default_port


class FaultConfig:
    """Immutable-ish bundle of fault parameters, built from argparse."""

    def __init__(self, args):
        self.upstream = args.upstream.rstrip("/")
        parsed = urllib.parse.urlparse(self.upstream)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            raise ValueError(f"--upstream must be an http(s) URL, got {args.upstream!r}")
        self.upstream_scheme = parsed.scheme
        self.upstream_netloc = parsed.netloc
        self.upstream_path = parsed.path.rstrip("/")  # base path prefix, usually ""
        self.strip = args.strip  # path segments to drop for key/prefix matching
        self.timeout = args.upstream_timeout
        self.seed = args.seed
        self.verbose = args.verbose

        self.latency_ops = _opset(args.latency_ops)
        self.latency_ms = args.latency_ms
        self.latency_prob = args.latency_prob
        self.latency_prefix = args.latency_prefix

        self.slowdown_ops = _opset(args.slowdown_ops)
        self.slowdown_prob = args.slowdown_prob
        self.slowdown_prefix = args.slowdown_prefix
        self.slowdown_status = args.slowdown_status
        self.slowdown_code = args.slowdown_code

        self.truncate_ops = _opset(args.truncate_ops)
        self.truncate_prob = args.truncate_prob
        self.truncate_prefix = args.truncate_prefix
        self.truncate_bytes = args.truncate_bytes

        self.reset_ops = _opset(args.reset_ops)
        self.reset_prob = args.reset_prob
        self.reset_prefix = args.reset_prefix
        self.reset_after = args.reset_after

        self.drip_ops = _opset(args.drip_ops)
        self.drip_prob = args.drip_prob
        self.drip_prefix = args.drip_prefix
        self.drip_bps = args.drip_bps
        self.drip_chunk = args.drip_chunk

        self.burst_ops = _opset(args.burst_ops)
        self.burst_every = args.burst_every
        self.burst_len = args.burst_len
        self.burst_prefix = args.burst_prefix


def _opset(csv):
    if not csv:
        return frozenset()
    out = set()
    for raw in csv.split(","):
        tok = raw.strip()
        if not tok:
            continue
        up = tok.upper()
        if up in (GET, PUT, DELETE, HEAD):
            out.add(up)
        elif up in ("LIST", "LISTOBJECTS"):
            out.add(LIST)
        else:
            raise ValueError(f"unknown op {tok!r}; choose from GET,PUT,DELETE,HEAD,List")
    return frozenset(out)


def classify(method, path, query):
    """Map an HTTP request to an S3 operation name."""
    method = method.upper()
    if method == PUT:
        return PUT
    if method == DELETE:
        return DELETE
    if method == HEAD:
        return HEAD
    if method == GET:
        q = urllib.parse.parse_qs(query)
        key = path.strip("/")
        # A list is a GET with no object key, or an explicit list-type/prefix query,
        # or the delimiter/marker family that S3 ListObjects(V2) uses.
        if not key or "list-type" in q or "prefix" in q or "delimiter" in q or "marker" in q:
            return LIST
        return GET
    return method  # anything exotic (POST multipart etc.) passes through by its verb


def object_key(path, strip):
    """Derive the object key used for prefix matching: drop the leading slash and,
    if requested, the first ``strip`` path segments (e.g. a bucket segment in a
    path-style endpoint)."""
    parts = path.lstrip("/").split("/")
    if strip:
        parts = parts[strip:]
    return "/".join(parts)


class Decision:
    """The fault (if any) chosen for one request."""

    __slots__ = ("kind", "detail")

    def __init__(self, kind="pass", detail=None):
        self.kind = kind
        self.detail = detail or {}

    def __repr__(self):
        return f"Decision({self.kind}, {self.detail})"


def _match(prefix, key):
    return (not prefix) or key.startswith(prefix)


def decide(cfg, rng, op, key, counter):
    """Choose at most one body/status fault for this request. Faults are evaluated
    in a fixed priority order so the decision is deterministic; the first that
    fires wins. The latency fault is orthogonal (it can co-occur with a body
    fault), so this returns (latency_ms, Decision)."""
    latency_ms = 0
    if op in cfg.latency_ops and _match(cfg.latency_prefix, key) and rng.random() < cfg.latency_prob:
        latency_ms = cfg.latency_ms

    # Deterministic error burst: every window of burst_every requests begins a run
    # of burst_len failures. Uses the request counter, not the RNG, so it is exact.
    if op in cfg.burst_ops and _match(cfg.burst_prefix, key) and cfg.burst_every > 0:
        phase = counter % cfg.burst_every
        if phase < cfg.burst_len:
            return latency_ms, Decision("slowdown", {"status": cfg.slowdown_status,
                                                     "code": cfg.slowdown_code, "via": "burst"})

    if op in cfg.slowdown_ops and _match(cfg.slowdown_prefix, key) and rng.random() < cfg.slowdown_prob:
        return latency_ms, Decision("slowdown", {"status": cfg.slowdown_status,
                                                 "code": cfg.slowdown_code, "via": "prob"})

    if op in cfg.reset_ops and _match(cfg.reset_prefix, key) and rng.random() < cfg.reset_prob:
        return latency_ms, Decision("reset", {"after": cfg.reset_after})

    if op in cfg.truncate_ops and _match(cfg.truncate_prefix, key) and rng.random() < cfg.truncate_prob:
        return latency_ms, Decision("truncate", {"keep": cfg.truncate_bytes})

    if op in cfg.drip_ops and _match(cfg.drip_prefix, key) and rng.random() < cfg.drip_prob:
        return latency_ms, Decision("drip", {"bps": cfg.drip_bps, "chunk": cfg.drip_chunk})

    return latency_ms, Decision("pass")


# S3 error payloads are XML; NativeLink's S3 client and the aws-sdk parse the
# <Code> element to drive its retry/backoff policy, so we emit a well-formed body.
def s3_error_xml(code, message, resource):
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<Error>"
        f"<Code>{code}</Code>"
        f"<Message>{message}</Message>"
        f"<Resource>{resource}</Resource>"
        "</Error>"
    ).encode("utf-8")


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    # cfg and server-wide state are injected onto the class by serve().
    cfg = None
    _counter_lock = threading.Lock()
    _counter = 0

    # Quieter, single-line logging that respects --verbose.
    def log_message(self, fmt, *args):
        if self.cfg and self.cfg.verbose:
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # Dispatch every verb through one path.
    def do_GET(self):
        self._proxy("GET")

    def do_PUT(self):
        self._proxy("PUT")

    def do_POST(self):
        self._proxy("POST")

    def do_DELETE(self):
        self._proxy("DELETE")

    def do_HEAD(self):
        self._proxy("HEAD")

    def _next_counter(self):
        with Handler._counter_lock:
            n = Handler._counter
            Handler._counter += 1
        return n

    def _read_request_body(self):
        length = self.headers.get("Content-Length")
        if length is not None:
            try:
                return self.rfile.read(int(length))
            except (ValueError, OSError):
                return b""
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            # Read a chunked body into memory (object-store PUTs here are bounded).
            body = io.BytesIO()
            while True:
                size_line = self.rfile.readline().strip()
                if not size_line:
                    break
                try:
                    size = int(size_line.split(b";")[0], 16)
                except ValueError:
                    break
                if size == 0:
                    self.rfile.readline()  # trailing CRLF
                    break
                body.write(self.rfile.read(size))
                self.rfile.readline()  # CRLF after each chunk
            return body.getvalue()
        return b""

    def _proxy(self, method):
        cfg = self.cfg
        counter = self._next_counter()
        parsed = urllib.parse.urlsplit(self.path)
        op = classify(method, parsed.path, parsed.query)
        key = object_key(parsed.path, cfg.strip)
        rng = random.Random(f"{cfg.seed}:{counter}")
        latency_ms, decision = decide(cfg, rng, op, key, counter)

        if cfg.verbose:
            sys.stderr.write(
                f"[req {counter}] {method} {self.path} op={op} key={key!r} "
                f"latency={latency_ms}ms fault={decision.kind}\n")

        body = self._read_request_body()

        if latency_ms:
            time.sleep(latency_ms / 1000.0)

        if decision.kind == "slowdown":
            return self._emit_slowdown(decision, key)

        # Forward to upstream and obtain the real response.
        try:
            resp = self._forward(method, parsed, body)
        except urllib.error.HTTPError as e:
            # Upstream returned a non-2xx: relay it faithfully (headers + body).
            resp = e
        except Exception as e:  # upstream unreachable/timeout: surface as 502
            return self._emit_bad_gateway(str(e))

        with resp:
            self._relay_response(method, resp, decision)

    def _forward(self, method, parsed, body):
        cfg = self.cfg
        # Reconstruct the upstream URL: base + original path + original query.
        path = cfg.upstream_path + parsed.path
        url = urllib.parse.urlunsplit((cfg.upstream_scheme, cfg.upstream_netloc,
                                       path, parsed.query, ""))
        req = urllib.request.Request(url=url, method=method,
                                     data=body if body else None)
        # Copy client headers through, minus hop-by-hop, Host and Content-Length.
        # urllib sets Host to the upstream netloc and recomputes Content-Length, so
        # SigV4 presigned URLs keyed to the upstream host remain valid. We preserve
        # Authorization / x-amz-* verbatim.
        for name, value in self.headers.items():
            low = name.lower()
            if low in HOP_BY_HOP or low in ("host", "content-length"):
                continue
            req.add_header(name, value)
        ctx = None
        if cfg.upstream_scheme == "https":
            ctx = ssl.create_default_context()
            opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))
        else:
            opener = urllib.request.build_opener()
        return opener.open(req, timeout=cfg.timeout)

    def _response_headers(self, resp):
        """Collect upstream headers minus hop-by-hop/length so we can re-frame."""
        out = []
        hdrs = resp.headers if hasattr(resp, "headers") else resp.info()
        for name, value in hdrs.items():
            low = name.lower()
            if low in HOP_BY_HOP or low == "content-length":
                continue
            out.append((name, value))
        return out

    def _relay_response(self, method, resp, decision):
        status = resp.status if hasattr(resp, "status") else resp.getcode()
        headers = self._response_headers(resp)

        # HEAD has no body; faults that mutate a body do not apply.
        if method == "HEAD":
            self.send_response(status)
            for n, v in headers:
                self.send_header(n, v)
            self.send_header("Content-Length", resp.headers.get("Content-Length", "0"))
            self.end_headers()
            return

        if decision.kind == "truncate":
            return self._relay_truncate(status, headers, resp, decision.detail["keep"])
        if decision.kind == "reset":
            return self._relay_reset(status, headers, resp, decision.detail["after"])
        if decision.kind == "drip":
            return self._relay_drip(status, headers, resp,
                                    decision.detail["bps"], decision.detail["chunk"])
        return self._relay_full(status, headers, resp)

    def _relay_full(self, status, headers, resp):
        payload = resp.read()
        self.send_response(status)
        for n, v in headers:
            self.send_header(n, v)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)

    def _relay_truncate(self, status, headers, resp, keep):
        payload = resp.read()
        kept = payload[:max(0, keep)]
        # Advertise the ORIGINAL length but send fewer bytes, then close: the classic
        # short/partial read that makes a client's content-length or checksum
        # validation fail -- the fault we want on fast->slow reconcile.
        self.send_response(status)
        for n, v in headers:
            self.send_header(n, v)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if kept:
            self.wfile.write(kept)
        self.wfile.flush()
        self.close_connection = True  # no more requests on this socket

    def _relay_reset(self, status, headers, resp, after):
        payload = resp.read()
        self.send_response(status)
        for n, v in headers:
            self.send_header(n, v)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if after > 0 and payload:
            self.wfile.write(payload[:after])
            self.wfile.flush()
        # Abort hard: set SO_LINGER{on,0} so close() sends a TCP RST rather than a
        # graceful FIN, and the peer observes a mid-body connection reset.
        try:
            self.connection.setsockopt(
                socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        except OSError:
            pass
        try:
            self.connection.close()
        except OSError:
            pass
        self.close_connection = True

    def _relay_drip(self, status, headers, resp, bps, chunk):
        payload = resp.read()
        self.send_response(status)
        for n, v in headers:
            self.send_header(n, v)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if not payload:
            return
        chunk = max(1, chunk)
        bps = max(1, bps)
        delay = chunk / float(bps)
        for off in range(0, len(payload), chunk):
            try:
                self.wfile.write(payload[off:off + chunk])
                self.wfile.flush()
            except OSError:
                break
            if off + chunk < len(payload):
                time.sleep(delay)

    def _emit_slowdown(self, decision, key):
        status = decision.detail["status"]
        code = decision.detail["code"]
        payload = s3_error_xml(code, f"{code} injected by rechaos s3_fault_proxy "
                               f"({decision.detail.get('via', 'prob')})", key)
        self.send_response(status)
        self.send_header("Content-Type", "application/xml")
        self.send_header("Content-Length", str(len(payload)))
        # S3/R2 attach a Retry-After hint on throttles; emit a small one so the
        # client's backoff path is exercised.
        self.send_header("Retry-After", "1")
        self.send_header("x-rechaos-fault", f"slowdown:{code}")
        self.end_headers()
        self.wfile.write(payload)

    def _emit_bad_gateway(self, reason):
        payload = s3_error_xml("InternalError",
                               f"rechaos s3_fault_proxy upstream error: {reason}", "")
        self.send_response(502)
        self.send_header("Content-Type", "application/xml")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("x-rechaos-fault", "upstream-error")
        self.end_headers()
        self.wfile.write(payload)


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def build_parser():
    p = argparse.ArgumentParser(
        description="S3/R2 egress fault proxy for NativeLink fast_slow slow-store chaos.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    p.add_argument("--listen", default="127.0.0.1:8081",
                   help="host:port to listen on")
    p.add_argument("--upstream", required=True,
                   help="base URL of the real object store, e.g. "
                        "https://<ACCOUNT>.r2.cloudflarestorage.com or http://127.0.0.1:9000")
    p.add_argument("--strip", type=int, default=0,
                   help="path segments to drop when computing the object key for "
                        "prefix matching (use 1 for path-style '/<bucket>/<key>')")
    p.add_argument("--upstream-timeout", type=float, default=30.0,
                   help="seconds to wait on the upstream object store")
    p.add_argument("--seed", type=int, default=1,
                   help="master RNG seed; fault decisions are reproducible given seed + request order")
    p.add_argument("--verbose", action="store_true", help="log every request and its decision")

    g = p.add_argument_group("latency (request-side delay)")
    g.add_argument("--latency-ops", default="", help="comma list: GET,PUT,DELETE,HEAD,List")
    g.add_argument("--latency-ms", type=int, default=0, help="milliseconds to sleep before forwarding")
    g.add_argument("--latency-prob", type=float, default=1.0, help="probability [0,1]")
    g.add_argument("--latency-prefix", default="", help="only keys under this prefix")

    g = p.add_argument_group("slowdown (throttle: return an error status, no upstream call)")
    g.add_argument("--slowdown-ops", default="", help="comma list of ops to throttle")
    g.add_argument("--slowdown-prob", type=float, default=1.0, help="probability [0,1]")
    g.add_argument("--slowdown-prefix", default="", help="only keys under this prefix")
    g.add_argument("--slowdown-status", type=int, default=503, help="HTTP status to return")
    g.add_argument("--slowdown-code", default="SlowDown",
                   help="S3 <Code> in the XML body (SlowDown, TooManyRequests, InternalError, ...)")

    g = p.add_argument_group("truncate (short/partial body then close)")
    g.add_argument("--truncate-ops", default="", help="comma list of ops to truncate (usually GET)")
    g.add_argument("--truncate-prob", type=float, default=1.0, help="probability [0,1]")
    g.add_argument("--truncate-prefix", default="", help="only keys under this prefix")
    g.add_argument("--truncate-bytes", type=int, default=0,
                   help="bytes of body to keep (Content-Length still advertises the full size)")

    g = p.add_argument_group("reset (abort TCP mid-body with RST)")
    g.add_argument("--reset-ops", default="", help="comma list of ops to reset")
    g.add_argument("--reset-prob", type=float, default=1.0, help="probability [0,1]")
    g.add_argument("--reset-prefix", default="", help="only keys under this prefix")
    g.add_argument("--reset-after", type=int, default=0,
                   help="bytes to send before resetting the connection")

    g = p.add_argument_group("drip (slow-loris body pacing)")
    g.add_argument("--drip-ops", default="", help="comma list of ops to drip")
    g.add_argument("--drip-prob", type=float, default=1.0, help="probability [0,1]")
    g.add_argument("--drip-prefix", default="", help="only keys under this prefix")
    g.add_argument("--drip-bps", type=int, default=4096, help="bytes per second")
    g.add_argument("--drip-chunk", type=int, default=256, help="bytes per write")

    g = p.add_argument_group("burst (deterministic error runs)")
    g.add_argument("--burst-ops", default="", help="comma list of ops subject to bursts")
    g.add_argument("--burst-every", type=int, default=0,
                   help="window length; every window of this many requests begins a burst (0=off)")
    g.add_argument("--burst-len", type=int, default=0,
                   help="requests at the start of each window that fail (uses --slowdown-status/code)")
    g.add_argument("--burst-prefix", default="", help="only keys under this prefix")
    return p


def serve(cfg, listen_host, listen_port):
    Handler.cfg = cfg
    Handler._counter = 0
    httpd = ThreadingHTTPServer((listen_host, listen_port), Handler)
    actual = httpd.server_address
    sys.stderr.write(
        f"rechaos s3_fault_proxy listening on {actual[0]}:{actual[1]} "
        f"-> {cfg.upstream} (seed={cfg.seed})\n")
    sys.stderr.flush()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.shutdown()
        httpd.server_close()


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        cfg = FaultConfig(args)
    except ValueError as e:
        parser.error(str(e))
    host, port = parse_hostport(args.listen, 8081)
    serve(cfg, host, port)
    return 0


if __name__ == "__main__":
    sys.exit(main())
