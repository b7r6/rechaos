#!/usr/bin/env python3
"""rechaos HTTP/2 frame-level fault proxy (h2c / cleartext gRPC).

A transparent TCP proxy that sits between a gRPC client and an --upstream
host:port, parses the raw HTTP/2 wire protocol frame-by-frame, and can inject
faults *below* the gRPC message layer -- the layer a high-level gRPC stack
(grapesy, grpcio) cannot reach because it only sees decoded messages, not
frames. We have already observed connection-management failures on the live
server ("GOAWAY: too many rst_stream", healthy calls stalling behind resets);
those live here, in the frame/flow-control machinery.

Why raw sockets, no `h2`/`hyperframe`
-------------------------------------
This proxy prefers the `h2`/`hyperframe` libraries if they are importable, but
under `nix develop` on this repo they are NOT present (only `grpcio`). So the
default and fully-supported path is a from-scratch, stdlib-only HTTP/2 framing
layer. We deliberately do NOT maintain HPACK state or re-encode HEADERS: we
splice the connection at the *frame* boundary and forward every frame's bytes
verbatim unless a fault rule says otherwise. This keeps HPACK dynamic tables on
both peers consistent (we never drop or reorder a HEADERS/CONTINUATION frame,
which would desync the decoder) while still letting us:

  * fabricate brand-new frames (RST_STREAM, GOAWAY, PING, WINDOW_UPDATE),
  * drop/delay whole frames (SETTINGS, WINDOW_UPDATE, PING),
  * fragment and reorder DATA frames (safe: no HPACK state),
  * rewrite GOAWAY last-stream-id / error code.

Faults that require re-encoding header blocks (arbitrary trailer/HEADERS
mutation of field *values*) need an HPACK codec; without `hpack` we support the
structural subset (inject a synthetic trailers HEADERS frame, truncate/duplicate
header frames) and clearly flag value-level rewriting as needing the lib. See
docs/h2-faults.md.

Fault menu (selectable by direction / stream / probability, fixed seed)
-----------------------------------------------------------------------
  withhold-window-update   flow-control starvation (drop WINDOW_UPDATE frames)
  zero-window-settings     advertise SETTINGS_INITIAL_WINDOW_SIZE=0 downstream
  rst-stream-flood         emit a burst of RST_STREAM at a chosen stream
  goaway-midstream         send GOAWAY while streams are open
  drop-settings            drop the peer's initial SETTINGS (handshake stall)
  delay-settings           hold the peer's SETTINGS for N ms
  ping-flood               emit unsolicited PING frames (liveness/anti-abuse)
  ping-drop                swallow PING so the peer's keepalive never acks
  data-fragment            split DATA frames into tiny fragments
  data-reorder             buffer then emit DATA frames out of order
  trailer-inject           append a synthetic HEADERS (trailers) frame
  header-truncate          drop a HEADERS frame (desyncs stream; lifecycle bug)

Each fault targets a *bug class*: flow-control, connection liveness, or stream
lifecycle. See docs/h2-faults.md for the full mapping and worked examples.

Usage
-----
Transparent (no fault), in front of the live NativeLink:

    nix develop --command python3 scripts/h2_fault_proxy.py \
        --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052

Inject a GOAWAY mid-stream on the upstream->client direction with p=1.0:

    nix develop --command python3 scripts/h2_fault_proxy.py \
        --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052 \
        --fault goaway-midstream --direction s2c --probability 1.0 --seed 7

Starve flow control (drop all client->upstream WINDOW_UPDATE frames):

    nix develop --command python3 scripts/h2_fault_proxy.py \
        --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052 \
        --fault withhold-window-update --direction c2s --probability 1.0

This proxy never speaks to the server about configuration; it only forwards /
mutates the client's own HTTP/2 traffic. It is idempotent and side-effect free
on the upstream beyond the gRPC calls the client itself makes.
"""
import argparse
import random
import selectors
import socket
import struct
import sys
import threading
import time

# ---- HTTP/2 wire constants (RFC 7540) ------------------------------------- #
PREFACE = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

FRAME_DATA = 0x0
FRAME_HEADERS = 0x1
FRAME_PRIORITY = 0x2
FRAME_RST_STREAM = 0x3
FRAME_SETTINGS = 0x4
FRAME_PUSH_PROMISE = 0x5
FRAME_PING = 0x6
FRAME_GOAWAY = 0x7
FRAME_WINDOW_UPDATE = 0x8
FRAME_CONTINUATION = 0x9

FRAME_NAME = {
    FRAME_DATA: "DATA", FRAME_HEADERS: "HEADERS", FRAME_PRIORITY: "PRIORITY",
    FRAME_RST_STREAM: "RST_STREAM", FRAME_SETTINGS: "SETTINGS",
    FRAME_PUSH_PROMISE: "PUSH_PROMISE", FRAME_PING: "PING", FRAME_GOAWAY: "GOAWAY",
    FRAME_WINDOW_UPDATE: "WINDOW_UPDATE", FRAME_CONTINUATION: "CONTINUATION",
}

FLAG_END_STREAM = 0x1   # DATA, HEADERS
FLAG_ACK = 0x1          # SETTINGS, PING
FLAG_END_HEADERS = 0x4  # HEADERS, CONTINUATION
FLAG_PADDED = 0x8       # DATA, HEADERS
FLAG_PRIORITY = 0x20    # HEADERS

SETTINGS_INITIAL_WINDOW_SIZE = 0x4

# gRPC/h2 error codes (RFC 7540 section 7).
ERR_NO_ERROR = 0x0
ERR_PROTOCOL_ERROR = 0x1
ERR_INTERNAL_ERROR = 0x2
ERR_FLOW_CONTROL_ERROR = 0x3
ERR_REFUSED_STREAM = 0x7
ERR_CANCEL = 0x8
ERR_ENHANCE_YOUR_CALM = 0xb


def build_frame(ftype, flags, stream_id, payload=b""):
    """Serialize one HTTP/2 frame. Length is implied by len(payload)."""
    length = len(payload)
    # 24-bit length, 8-bit type, 8-bit flags, 1-bit reserved + 31-bit stream id.
    header = struct.pack(">I", length)[1:] + bytes((ftype, flags)) + struct.pack(">I", stream_id & 0x7FFFFFFF)
    return header + payload


class Frame:
    __slots__ = ("ftype", "flags", "stream_id", "payload")

    def __init__(self, ftype, flags, stream_id, payload):
        self.ftype = ftype
        self.flags = flags
        self.stream_id = stream_id
        self.payload = payload

    @property
    def raw(self):
        return build_frame(self.ftype, self.flags, self.stream_id, self.payload)

    def __repr__(self):
        return (f"Frame({FRAME_NAME.get(self.ftype, hex(self.ftype))} "
                f"flags={self.flags:#x} stream={self.stream_id} len={len(self.payload)})")


class FrameParser:
    """Incremental HTTP/2 frame parser fed arbitrary byte chunks.

    Also strips the client connection preface (only ever sent c2s) so the first
    SETTINGS frame after it parses cleanly. Yields complete Frame objects.
    """

    def __init__(self, expect_preface=False):
        self.buf = bytearray()
        self.expect_preface = expect_preface
        self.preface_done = not expect_preface

    def feed(self, data):
        self.buf.extend(data)
        out = []
        if not self.preface_done:
            if len(self.buf) < len(PREFACE):
                return out, (b"" if not self.preface_done else None)
            if bytes(self.buf[:len(PREFACE)]) != PREFACE:
                raise ValueError("client preface mismatch")
            del self.buf[:len(PREFACE)]
            self.preface_done = True
        while len(self.buf) >= 9:
            length = (self.buf[0] << 16) | (self.buf[1] << 8) | self.buf[2]
            if len(self.buf) < 9 + length:
                break
            ftype = self.buf[3]
            flags = self.buf[4]
            stream_id = struct.unpack(">I", bytes(self.buf[5:9]))[0] & 0x7FFFFFFF
            payload = bytes(self.buf[9:9 + length])
            del self.buf[:9 + length]
            out.append(Frame(ftype, flags, stream_id, payload))
        return out, None


class Stats:
    def __init__(self):
        self.lock = threading.Lock()
        self.frames = {}
        self.injected = {}
        self.dropped = {}

    def _bump(self, d, k):
        with self.lock:
            d[k] = d.get(k, 0) + 1

    def seen(self, name):
        self._bump(self.frames, name)

    def inject(self, name):
        self._bump(self.injected, name)

    def drop(self, name):
        self._bump(self.dropped, name)

    def render(self):
        with self.lock:
            return {"forwarded": dict(self.frames), "injected": dict(self.injected),
                    "dropped": dict(self.dropped)}


class FaultEngine:
    """Decides, per frame and per direction, what to forward / drop / inject.

    `out.append(raw_bytes)` appends bytes to be written to the far peer.
    Returning the (possibly empty) list of byte chunks keeps HPACK state intact
    because we only ever reorder/duplicate *whole* frames, never partial header
    blocks. Fault selection is gated by direction, stream id, and a seeded RNG.
    """

    def __init__(self, opts, log, stats):
        self.opts = opts
        self.log = log
        self.stats = stats
        self.rng = random.Random(opts.seed)
        self.rng_lock = threading.Lock()
        # Per-connection mutable state.
        self.reorder_buf = {}   # direction -> list[Frame] held for reordering
        self.goaway_sent = {}   # direction -> bool
        self.ping_last = {}     # direction -> monotonic of last injected ping

    def _roll(self):
        with self.rng_lock:
            return self.rng.random() < self.opts.probability

    def _dir_match(self, direction):
        return self.opts.direction in ("both", direction)

    def _stream_match(self, stream_id):
        if self.opts.stream is None:
            return True
        return stream_id == self.opts.stream

    def _active(self, direction, stream_id):
        """A fault is eligible iff direction+stream match and the dice say go."""
        return (self.opts.fault != "none" and self._dir_match(direction)
                and self._stream_match(stream_id) and self._roll())

    # --------------------------------------------------------------------- #
    def process(self, frame, direction, peer_writer):
        """Return list of raw byte chunks to send to the far peer for `frame`.

        `peer_writer` is a callback to inject *reverse-direction* frames (e.g.
        a GOAWAY the client should see we fabricate toward the client even when
        reacting to an upstream frame). For simplicity most faults operate in
        the forward direction; reverse injection is used by rst-stream-flood.
        """
        self.stats.seen(f"{direction}:{FRAME_NAME.get(frame.ftype, hex(frame.ftype))}")
        fault = self.opts.fault

        # ---- flow control ------------------------------------------------ #
        if fault == "withhold-window-update" and frame.ftype == FRAME_WINDOW_UPDATE:
            if self._active(direction, frame.stream_id):
                self.stats.drop("WINDOW_UPDATE")
                self.log(f"[{direction}] DROP WINDOW_UPDATE stream={frame.stream_id} "
                         f"(flow-control starvation)")
                return []

        if fault == "zero-window-settings" and frame.ftype == FRAME_SETTINGS and not (frame.flags & FLAG_ACK):
            if self._active(direction, 0):
                mutated = self._settings_force_zero_window(frame.payload)
                self.log(f"[{direction}] REWRITE SETTINGS INITIAL_WINDOW_SIZE=0 "
                         f"(flow-control starvation)")
                self.stats.inject("SETTINGS(zero-window)")
                return [build_frame(FRAME_SETTINGS, frame.flags, 0, mutated)]

        # ---- stream lifecycle -------------------------------------------- #
        if fault == "rst-stream-flood" and frame.ftype in (FRAME_HEADERS, FRAME_DATA):
            if self._active(direction, frame.stream_id) and frame.stream_id != 0:
                out = [frame.raw]
                burst = max(1, self.opts.count)
                for _ in range(burst):
                    out.append(build_frame(FRAME_RST_STREAM, 0, frame.stream_id,
                                           struct.pack(">I", ERR_CANCEL)))
                self.stats.inject("RST_STREAM")
                self.log(f"[{direction}] FLOOD {burst}x RST_STREAM stream={frame.stream_id} "
                         f"(stream lifecycle / 'too many rst_stream')")
                return out

        if fault == "header-truncate" and frame.ftype == FRAME_HEADERS:
            if self._active(direction, frame.stream_id) and frame.stream_id != 0:
                self.stats.drop("HEADERS")
                self.log(f"[{direction}] DROP HEADERS stream={frame.stream_id} "
                         f"(stream lifecycle desync -- note: desyncs HPACK)")
                return []

        if fault == "trailer-inject" and frame.ftype == FRAME_DATA and (frame.flags & FLAG_END_STREAM):
            if self._active(direction, frame.stream_id) and frame.stream_id != 0:
                # Emit the DATA (minus END_STREAM) then a synthetic trailers
                # HEADERS frame carrying a single literal-without-indexing
                # header that needs no HPACK dynamic-table state. grpc-status=2.
                data_no_end = build_frame(FRAME_DATA, frame.flags & ~FLAG_END_STREAM,
                                          frame.stream_id, frame.payload)
                trailers = self._literal_header_block(b"grpc-status", b"2")
                hdr = build_frame(FRAME_HEADERS, FLAG_END_HEADERS | FLAG_END_STREAM,
                                  frame.stream_id, trailers)
                self.stats.inject("HEADERS(trailers)")
                self.log(f"[{direction}] INJECT trailers grpc-status=2 stream={frame.stream_id} "
                         f"(stream lifecycle)")
                return [data_no_end, hdr]

        # ---- connection liveness ----------------------------------------- #
        if fault == "goaway-midstream" and frame.ftype in (FRAME_HEADERS, FRAME_DATA):
            if frame.stream_id != 0 and not self.goaway_sent.get(direction) and self._active(direction, frame.stream_id):
                self.goaway_sent[direction] = True
                last = max(0, frame.stream_id - 2)
                goaway = build_frame(FRAME_GOAWAY, 0, 0,
                                     struct.pack(">II", last & 0x7FFFFFFF, ERR_NO_ERROR) + b"rechaos")
                self.stats.inject("GOAWAY")
                self.log(f"[{direction}] INJECT GOAWAY last_stream={last} mid-stream "
                         f"(connection liveness) -- forwarding original frame too")
                return [frame.raw, goaway]

        if fault == "drop-settings" and frame.ftype == FRAME_SETTINGS and not (frame.flags & FLAG_ACK):
            if self._active(direction, 0):
                self.stats.drop("SETTINGS")
                self.log(f"[{direction}] DROP initial SETTINGS (handshake stall)")
                return []

        if fault == "delay-settings" and frame.ftype == FRAME_SETTINGS and not (frame.flags & FLAG_ACK):
            if self._active(direction, 0):
                self.log(f"[{direction}] DELAY SETTINGS by {self.opts.delay_ms}ms (handshake stall)")
                time.sleep(self.opts.delay_ms / 1000.0)
                return [frame.raw]

        if fault == "ping-drop" and frame.ftype == FRAME_PING:
            if self._active(direction, 0):
                self.stats.drop("PING")
                self.log(f"[{direction}] DROP PING flags={frame.flags:#x} (keepalive starvation)")
                return []

        if fault == "ping-flood" and frame.ftype in (FRAME_HEADERS, FRAME_DATA):
            if self._active(direction, frame.stream_id):
                out = [frame.raw]
                burst = max(1, self.opts.count)
                for i in range(burst):
                    out.append(build_frame(FRAME_PING, 0, 0, struct.pack(">Q", i)))
                self.stats.inject("PING")
                self.log(f"[{direction}] FLOOD {burst}x PING (liveness / anti-abuse 'too many ping')")
                return out

        # ---- DATA manipulation ------------------------------------------- #
        if fault == "data-fragment" and frame.ftype == FRAME_DATA and frame.payload:
            if self._active(direction, frame.stream_id):
                return self._fragment_data(frame)

        if fault == "data-reorder" and frame.ftype == FRAME_DATA:
            if self._dir_match(direction) and self._stream_match(frame.stream_id) and frame.stream_id != 0:
                return self._reorder_data(frame, direction)

        # default: pass through untouched
        return [frame.raw]

    # --------------------------------------------------------------------- #
    def _fragment_data(self, frame):
        size = max(1, self.opts.fragment)
        chunks = [frame.payload[i:i + size] for i in range(0, len(frame.payload), size)]
        out = []
        for i, c in enumerate(chunks):
            last = i == len(chunks) - 1
            flags = frame.flags if last else (frame.flags & ~FLAG_END_STREAM)
            out.append(build_frame(FRAME_DATA, flags, frame.stream_id, c))
        self.stats.inject(f"DATA-fragment(x{len(chunks)})")
        self.log(f"[fragment] DATA stream={frame.stream_id} -> {len(chunks)} frames "
                 f"of <= {size}B (flow-control/reassembly)")
        return out

    def _reorder_data(self, frame, direction):
        buf = self.reorder_buf.setdefault(direction, [])
        # If this frame ends the stream, flush held frames in reverse order
        # (the reordering) followed by this one.
        if frame.flags & FLAG_END_STREAM:
            buf.append(frame)
            out = [f.raw for f in reversed(buf)]
            self.stats.inject(f"DATA-reorder(x{len(buf)})")
            self.log(f"[reorder] flush {len(buf)} DATA frames reversed stream={frame.stream_id}")
            buf.clear()
            return out
        buf.append(frame)
        if len(buf) >= max(2, self.opts.count):
            out = [f.raw for f in reversed(buf)]
            self.stats.inject(f"DATA-reorder(x{len(buf)})")
            self.log(f"[reorder] flush {len(buf)} DATA frames reversed stream={frame.stream_id}")
            buf.clear()
            return out
        return []  # held

    @staticmethod
    def _settings_force_zero_window(payload):
        """Rewrite any SETTINGS_INITIAL_WINDOW_SIZE entry to 0, else append one."""
        out = bytearray()
        found = False
        for i in range(0, len(payload) - len(payload) % 6, 6):
            ident = (payload[i] << 8) | payload[i + 1]
            if ident == SETTINGS_INITIAL_WINDOW_SIZE:
                out += struct.pack(">HI", SETTINGS_INITIAL_WINDOW_SIZE, 0)
                found = True
            else:
                out += payload[i:i + 6]
        if not found:
            out += struct.pack(">HI", SETTINGS_INITIAL_WINDOW_SIZE, 0)
        return bytes(out)

    @staticmethod
    def _literal_header_block(name, value):
        """HPACK 'literal header field never indexed' (RFC 7541 6.2.3) with
        no name reference -- requires zero dynamic-table state, so it is safe to
        inject without an HPACK codec. Byte layout: 0x10, len(name), name,
        len(value), value (all names/values < 127 bytes here)."""
        return (bytes([0x10, len(name)]) + name + bytes([len(value)]) + value)


class Pump(threading.Thread):
    """Reads one direction of a socket pair, parses frames, applies faults,
    and writes the result to the far socket."""

    def __init__(self, src, dst, direction, engine, log, expect_preface):
        super().__init__(daemon=True)
        self.src = src
        self.dst = dst
        self.direction = direction
        self.engine = engine
        self.log = log
        self.parser = FrameParser(expect_preface=expect_preface)
        # c2s must replay the client preface to upstream before any frame.
        self.send_preface = expect_preface

    def _peer_write(self, raw):
        try:
            self.src.sendall(raw)  # reverse injection goes back to source
        except OSError:
            pass

    def run(self):
        if self.send_preface:
            try:
                self.dst.sendall(PREFACE)
            except OSError:
                return
        try:
            while True:
                data = self.src.recv(65536)
                if not data:
                    break
                try:
                    frames, _ = self.parser.feed(data)
                except ValueError as e:
                    self.log(f"[{self.direction}] parse error: {e}; raw-forwarding remainder")
                    try:
                        self.dst.sendall(data)
                    except OSError:
                        break
                    continue
                for frame in frames:
                    chunks = self.engine.process(frame, self.direction, self._peer_write)
                    for raw in chunks:
                        try:
                            self.dst.sendall(raw)
                        except OSError:
                            return
        finally:
            for s in (self.src, self.dst):
                try:
                    s.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass


def handle_client(client_sock, opts, log, stats):
    up_host, up_port = opts.upstream
    try:
        upstream = socket.create_connection((up_host, up_port), timeout=opts.connect_timeout)
    except OSError as e:
        log(f"upstream connect failed: {e}")
        client_sock.close()
        return
    upstream.settimeout(None)
    client_sock.settimeout(None)
    engine = FaultEngine(opts, log, stats)
    c2s = Pump(client_sock, upstream, "c2s", engine, log, expect_preface=True)
    s2c = Pump(upstream, client_sock, "s2c", engine, log, expect_preface=False)
    c2s.start()
    s2c.start()
    c2s.join()
    s2c.join()
    for s in (client_sock, upstream):
        try:
            s.close()
        except OSError:
            pass


def serve(opts):
    def log(msg):
        if not opts.quiet:
            print(msg, file=sys.stderr, flush=True)

    stats = Stats()
    lhost, lport = opts.listen
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((lhost, lport))
    srv.listen(64)
    log(f"h2_fault_proxy listening on {lhost}:{lport} -> upstream {opts.upstream[0]}:{opts.upstream[1]} "
        f"fault={opts.fault} direction={opts.direction} p={opts.probability} seed={opts.seed}")

    deadline = time.monotonic() + opts.max_seconds if opts.max_seconds else None
    srv.settimeout(1.0)
    threads = []
    try:
        while True:
            if deadline and time.monotonic() >= deadline:
                log("max-seconds reached; shutting down")
                break
            try:
                client, addr = srv.accept()
            except socket.timeout:
                continue
            log(f"accept {addr}")
            t = threading.Thread(target=handle_client, args=(client, opts, log, stats), daemon=True)
            t.start()
            threads.append(t)
    except KeyboardInterrupt:
        log("interrupted")
    finally:
        srv.close()
        import json
        print(json.dumps({"stats": stats.render()}), flush=True)


def hostport(s):
    host, _, port = s.rpartition(":")
    if not host or not port:
        raise argparse.ArgumentTypeError(f"expected host:port, got {s!r}")
    return (host, int(port))


FAULTS = [
    "none", "withhold-window-update", "zero-window-settings", "rst-stream-flood",
    "goaway-midstream", "drop-settings", "delay-settings", "ping-flood",
    "ping-drop", "data-fragment", "data-reorder", "trailer-inject", "header-truncate",
]


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--listen", type=hostport, default=("127.0.0.1", 50061),
                   help="host:port to listen on (default 127.0.0.1:50061)")
    p.add_argument("--upstream", type=hostport, required=True,
                   help="upstream gRPC/h2c host:port (e.g. 127.0.0.1:50052)")
    p.add_argument("--fault", choices=FAULTS, default="none",
                   help="frame fault to inject (default none = transparent)")
    p.add_argument("--direction", choices=["c2s", "s2c", "both"], default="both",
                   help="which direction the fault applies to (c2s=client->upstream)")
    p.add_argument("--stream", type=int, default=None,
                   help="restrict fault to a single HTTP/2 stream id (default any)")
    p.add_argument("--probability", type=float, default=1.0,
                   help="per-eligible-frame injection probability (0..1)")
    p.add_argument("--seed", type=int, default=1337, help="RNG seed (deterministic)")
    p.add_argument("--count", type=int, default=50,
                   help="burst size for rst-stream-flood/ping-flood; buffer for data-reorder")
    p.add_argument("--fragment", type=int, default=16,
                   help="fragment size in bytes for data-fragment")
    p.add_argument("--delay-ms", type=int, default=2000,
                   help="delay for delay-settings fault")
    p.add_argument("--connect-timeout", type=float, default=10.0)
    p.add_argument("--max-seconds", type=float, default=0,
                   help="auto-shutdown after N seconds (0 = run until Ctrl-C)")
    p.add_argument("--quiet", action="store_true", help="suppress per-frame logging")
    opts = p.parse_args(argv)
    if not (0.0 <= opts.probability <= 1.0):
        p.error("--probability must be in [0,1]")
    serve(opts)


if __name__ == "__main__":
    main()
