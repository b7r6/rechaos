#!/usr/bin/env python3
"""Bounded adapter checks against owned loopback peers; no live services."""
import argparse
import http.client
import http.server
import os
import pathlib
import socket
import struct
import sys
import threading
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import h2_fault_proxy as h2
import load_gen
import process_chaos as process
import s3_fault_proxy as s3
from integration import DATA, Fixture, contents, grpc, read, write


def h2_options(**overrides):
    opts = dict(fault="none", direction="both", probability=1.0, seed=7,
                stream=None, count=3, fragment=64, delay_ms=0, connect_timeout=3)
    opts.update(overrides)
    return argparse.Namespace(**opts)


def engine(**opts):
    return h2.FaultEngine(h2_options(**opts), lambda _: None, h2.Stats())


def frames(chunks):
    parsed, _ = h2.FrameParser().feed(b"".join(chunks))
    return parsed


class H2Contracts(unittest.TestCase):
    def test_parser_accepts_arbitrary_tcp_boundaries(self):
        raw = [h2.build_frame(h2.FRAME_SETTINGS, 0, 0, b""),
               h2.build_frame(h2.FRAME_DATA, h2.FLAG_END_STREAM, 1, b"payload")]
        parser = h2.FrameParser(expect_preface=True)
        seen = []
        for byte in h2.PREFACE + b"".join(raw):
            parsed, _ = parser.feed(bytes([byte]))
            seen.extend(frame.raw for frame in parsed)
        self.assertEqual(seen, raw)
        self.assertEqual(parser.buf, b"")

    def test_zero_probability_is_transparent_for_every_fault(self):
        inputs = [h2.Frame(h2.FRAME_SETTINGS, 0, 0, b""),
                  h2.Frame(h2.FRAME_WINDOW_UPDATE, 0, 1, struct.pack(">I", 1)),
                  h2.Frame(h2.FRAME_HEADERS, h2.FLAG_END_HEADERS, 1, b"header"),
                  h2.Frame(h2.FRAME_PING, 0, 0, b"12345678"),
                  h2.Frame(h2.FRAME_DATA, 0, 1, b"first"),
                  h2.Frame(h2.FRAME_DATA, h2.FLAG_END_STREAM, 1, b"last")]
        for fault in h2.FAULTS:
            with self.subTest(fault=fault):
                proxy = engine(fault=fault, probability=0)
                actual = [raw for frame in inputs
                          for raw in proxy.process(frame, "s2c", lambda _: None)]
                self.assertEqual(actual, [frame.raw for frame in inputs])

    def test_fragmentation_preserves_padded_data_and_end_stream(self):
        frame = h2.Frame(h2.FRAME_DATA, h2.FLAG_END_STREAM | h2.FLAG_PADDED,
                         1, b"\x02abcdef\0\0")
        output = frames(engine(fault="data-fragment", fragment=2).process(
            frame, "s2c", lambda _: None))
        def body(part):
            if part.flags & h2.FLAG_PADDED:
                return part.payload[1:len(part.payload) - part.payload[0]]
            return part.payload
        self.assertEqual(b"".join(map(body, output)), b"abcdef")
        self.assertTrue(output[-1].flags & h2.FLAG_END_STREAM)
        self.assertTrue(all(not f.flags & h2.FLAG_END_STREAM for f in output[:-1]))

    def test_reordering_keeps_stream_buffers_separate_and_end_last(self):
        proxy = engine(fault="data-reorder", count=4)
        def send(stream, data, end=False):
            frame = h2.Frame(h2.FRAME_DATA, int(end), stream, data)
            return frames(proxy.process(frame, "s2c", lambda _: None))
        self.assertEqual(send(1, b"a"), [])
        self.assertEqual(send(3, b"other"), [])
        self.assertEqual(send(1, b"b"), [])
        output = send(1, b"end", True)
        self.assertEqual([f.stream_id for f in output], [1, 1, 1])
        self.assertEqual([f.payload for f in output], [b"b", b"a", b"end"])
        self.assertEqual([f.payload for f in send(3, b"done", True)], [b"other", b"done"])

    def test_real_grpc_survives_transparent_and_fragmenting_proxy(self):
        fixture = Fixture()
        self.addCleanup(fixture.close)
        for fault in ("none", "data-fragment"):
            with self.subTest(fault=fault), socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                listener.listen(1)
                listener.settimeout(5)
                opts = h2_options(fault=fault, upstream=("127.0.0.1", fixture.port))
                thread = threading.Thread(target=lambda: h2.handle_client(
                    listener.accept()[0], opts, lambda _: None, h2.Stats()), daemon=True)
                thread.start()
                with grpc.insecure_channel(f"127.0.0.1:{listener.getsockname()[1]}") as channel:
                    grpc.channel_ready_future(channel).result(timeout=5)
                    self.assertEqual(write(channel).committed_size, len(DATA))
                    self.assertEqual(contents(read(channel)), DATA)
                thread.join(timeout=5)
                self.assertFalse(thread.is_alive(), "proxy did not release its connection")

    def test_reordering_flushes_data_before_grpc_trailers(self):
        proxy = engine(fault="data-reorder", count=4)
        data = h2.Frame(h2.FRAME_DATA, 0, 1, b"body")
        trailers = h2.Frame(h2.FRAME_HEADERS, h2.FLAG_END_STREAM | h2.FLAG_END_HEADERS,
                            1, b"trailers")
        self.assertEqual(proxy.process(data, "s2c", lambda _: None), [])
        self.assertEqual(proxy.process(trailers, "s2c", lambda _: None),
                         [data.raw, trailers.raw])


class S3Contracts(unittest.TestCase):
    def setUp(self):
        self.requests = []
        requests = self.requests
        class Upstream(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                requests.append((self.command, self.path, dict(self.headers), body))
                payload = b"missing" if self.path == "/missing" else b"object bytes"
                self.send_response(404 if self.path == "/missing" else 200)
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("ETag", '"etag"')
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(payload)

            do_PUT = do_HEAD = do_GET

        self.upstream = self.start_server(Upstream)

    def start_server(self, handler):
        server = s3.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever,
                                  kwargs={"poll_interval": 0.01}, daemon=True)
        thread.start()
        def close():
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
        self.addCleanup(close)
        return server

    def proxy(self, *args):
        url = f"http://127.0.0.1:{self.upstream.server_port}"
        cfg = s3.FaultConfig(s3.build_parser().parse_args(["--upstream", url, *args]))
        handler = type("ConfiguredHandler", (s3.Handler,), {"cfg": cfg})
        return self.start_server(handler)

    def request(self, server, method, path, body=None, headers=None):
        client = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
        self.addCleanup(client.close)
        client.request(method, path, body=body, headers=headers or {})
        return client.getresponse()

    def test_forwarding_preserves_signed_headers_body_path_and_errors(self):
        server = self.proxy()
        signed = {"Host": "signed.example", "Authorization": "test-signature",
                  "x-amz-content-sha256": "test-digest"}
        response = self.request(server, "PUT", "/bucket/a%20b?part=1", b"upload", signed)
        self.assertEqual((response.status, response.read()), (200, b"object bytes"))
        method, path, headers, body = self.requests[-1]
        self.assertEqual((method, path, body), ("PUT", "/bucket/a%20b?part=1", b"upload"))
        for name, value in signed.items():
            self.assertEqual({k.lower(): v for k, v in headers.items()}[name.lower()], value)
        response = self.request(server, "GET", "/missing")
        self.assertEqual((response.status, response.read()), (404, b"missing"))
        response = self.request(server, "HEAD", "/bucket/key")
        self.assertEqual(response.getheader("Content-Length"), "12")
        self.assertEqual(response.read(), b"")

    def test_throttling_is_targeted_and_returns_valid_xml(self):
        server = self.proxy("--slowdown-ops", "GET", "--slowdown-prefix", "cas/")
        response = self.request(server, "GET", "/cas/a&b")
        self.assertEqual(response.status, 503)
        error = ET.fromstring(response.read())
        self.assertEqual(error.findtext("Code"), "SlowDown")
        self.assertEqual(error.findtext("Resource"), "cas/a&b")
        self.assertEqual(self.requests, [])
        response = self.request(server, "GET", "/other/key")
        self.assertEqual(response.read(), b"object bytes")
        self.assertEqual(len(self.requests), 1)

    def test_truncation_retains_full_length_and_closes_early(self):
        server = self.proxy("--truncate-ops", "GET", "--truncate-bytes", "3")
        response = self.request(server, "GET", "/bucket/key")
        self.assertEqual(response.getheader("Content-Length"), "12")
        with self.assertRaises(http.client.IncompleteRead) as caught:
            response.read()
        self.assertEqual(caught.exception.partial, b"obj")


class ProcessContracts(unittest.TestCase):
    def test_protected_and_unowned_targets_are_refused(self):
        for pid in (-1, 0, 1, os.getpid(), os.getppid()):
            with self.subTest(pid=pid), self.assertRaises(process.ChaosSafetyError):
                process.assert_pid_targetable(pid, owned=True, i_understand=True)
        with self.assertRaises(process.ChaosSafetyError):
            process.assert_pid_targetable(999999, owned=False, i_understand=False)

    def test_paused_child_death_is_observed(self):
        child = process.ManagedProcess([sys.executable, "-c", "import time; time.sleep(60)"])
        self.addCleanup(child.stop)
        child.start()
        child.pause()
        child._proc.kill()
        child._proc.wait(timeout=3)
        self.assertEqual(child.state, process.ProcessState.EXITED)


class LoadContracts(unittest.TestCase):
    def test_concurrent_mixed_workload_accounts_for_exact_operation_budget(self):
        fixture = Fixture()
        self.addCleanup(fixture.close)
        metrics = load_gen.run_load(load_gen.LoadConfig(
            port=fixture.port, clients=3, op_count=60, warmup=2,
            size_min=32, size_max=64, timeout=3))
        self.assertEqual(metrics["aggregate"]["count"], 60)
        self.assertEqual(metrics["aggregate"]["errors"], 0)
        self.assertEqual(sum(op["count"] for op in metrics["by_op"].values()), 60)
        self.assertTrue(all(op["count"] > 0 for op in metrics["by_op"].values()))


if __name__ == "__main__":
    unittest.main()
