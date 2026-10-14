#!/usr/bin/env python3
"""Contracts for the object-store dialects of scripts/s3_fault_proxy.py: each
hyperscaler's throttle must be byte-faithful (status, headers, body), request
classification must follow the dialect's URL shapes, and the control endpoint
must switch a sustained throttle on and off and account for every request."""
import http.client
import http.server
import json
import pathlib
import sys
import threading
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import s3_fault_proxy as s3  # noqa: E402


class DialectContracts(unittest.TestCase):
    def setUp(self):
        self.requests = []
        requests = self.requests
        s3.Control.reset()
        s3.Control.forced = None

        class Upstream(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                self.rfile.read(int(self.headers.get("Content-Length", 0)))
                requests.append((self.command, self.path))
                payload = b"object bytes"
                self.send_response(200)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(payload)

            do_PUT = do_HEAD = do_DELETE = do_POST = do_GET

        self.upstream = self.start_server(Upstream)

    def start_server(self, handler):
        server = s3.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
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
        control = type("ConfiguredControl", (s3.ControlHandler,), {"cfg": cfg})
        return self.start_server(handler), self.start_server(control)

    def request(self, server, method, path, body=None, headers=None):
        client = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
        self.addCleanup(client.close)
        client.request(method, path, body=body, headers=headers or {})
        return client.getresponse()

    def control(self, server, method, path, payload=None):
        response = self.request(server, method, path, body=json.dumps(payload).encode() if payload else None,
                                headers={"Content-Type": "application/json"})
        return response.status, json.loads(response.read())

    # -- Azure ------------------------------------------------------------- #
    def test_azure_throttle_is_server_busy_with_egress_message(self):
        server, _ = self.proxy("--dialect", "azure", "--slowdown-ops", "GET")
        response = self.request(server, "GET", "/devstoreaccount1/cas/blobs/abc")
        self.assertEqual(response.status, 503)
        self.assertEqual(response.getheader("x-ms-error-code"), "ServerBusy")
        self.assertEqual(response.getheader("Retry-After"), "1")
        self.assertTrue(response.getheader("x-ms-request-id"))
        error = ET.fromstring(response.read())
        self.assertEqual(error.findtext("Code"), "ServerBusy")
        self.assertTrue(error.findtext("Message").startswith("Egress is over the account limit."))
        self.assertIn("RequestId:", error.findtext("Message"))
        self.assertEqual(self.requests, [])

    def test_azure_classification_and_key_strip(self):
        self.assertEqual(s3.classify("GET", "/acct/cas/key", "", "azure"), "GET")
        self.assertEqual(s3.classify("GET", "/acct/cas", "restype=container&comp=list", "azure"), s3.LIST)
        self.assertEqual(s3.classify("PUT", "/acct/cas/key", "comp=block&blockid=AAA", "azure"), "PUT")
        self.assertEqual(s3.classify("HEAD", "/acct/cas/key", "", "azure"), "HEAD")
        self.assertEqual(s3.object_key("/acct/cas/blobs/abc", 2, "azure"), "blobs/abc")
        server, _ = self.proxy("--dialect", "azure", "--slowdown-ops", "GET", "--slowdown-prefix", "blobs/")
        self.assertEqual(self.request(server, "GET", "/acct/cas/blobs/abc").status, 503)
        self.assertEqual(self.request(server, "GET", "/acct/cas/other/abc").status, 200)

    def test_azure_other_limits_are_selectable(self):
        server, _ = self.proxy("--dialect", "azure", "--slowdown-ops", "PUT",
                               "--slowdown-message", "Ingress is over the account limit.")
        response = self.request(server, "PUT", "/acct/cas/key", body=b"x")
        self.assertEqual(response.getheader("x-ms-error-code"), "ServerBusy")
        self.assertIn("Ingress is over the account limit.", response.read().decode())

    # -- GCS --------------------------------------------------------------- #
    def test_gcs_throttle_is_json_with_reason(self):
        server, _ = self.proxy("--dialect", "gcs", "--slowdown-ops", "GET")
        response = self.request(server, "GET", "/storage/v1/b/cas/o/blobs%2Fabc?alt=media")
        self.assertEqual(response.status, 503)
        self.assertTrue(response.getheader("Content-Type").startswith("application/json"))
        body = json.loads(response.read())
        self.assertEqual(body["error"]["code"], 503)
        self.assertEqual(body["error"]["errors"][0]["reason"], "backendError")
        server, _ = self.proxy("--dialect", "gcs", "--slowdown-ops", "GET", "--slowdown-status", "429",
                               "--slowdown-code", "rateLimitExceeded")
        response = self.request(server, "GET", "/download/storage/v1/b/cas/o/blobs%2Fabc?alt=media")
        self.assertEqual(response.status, 429)
        self.assertEqual(json.loads(response.read())["error"]["errors"][0]["domain"], "usageLimits")

    def test_gcs_classification_and_key(self):
        self.assertEqual(s3.classify("GET", "/storage/v1/b/cas/o/x", "alt=media", "gcs"), "GET")
        self.assertEqual(s3.classify("GET", "/download/storage/v1/b/cas/o/x", "", "gcs"), "GET")
        self.assertEqual(s3.classify("GET", "/storage/v1/b/cas/o/x", "", "gcs"), "HEAD")
        self.assertEqual(s3.classify("GET", "/storage/v1/b/cas/o", "prefix=blobs", "gcs"), s3.LIST)
        self.assertEqual(s3.classify("POST", "/upload/storage/v1/b/cas/o", "uploadType=media&name=x", "gcs"), "PUT")
        self.assertEqual(s3.object_key("/storage/v1/b/cas/o/blobs%2Fabc", 0, "gcs"), "blobs/abc")

    # -- S3 stays as it was ------------------------------------------------- #
    def test_s3_default_shape_is_unchanged(self):
        server, _ = self.proxy("--slowdown-ops", "GET")
        response = self.request(server, "GET", "/cas/key")
        self.assertEqual(response.status, 503)
        self.assertTrue(response.getheader("x-amz-request-id"))
        error = ET.fromstring(response.read())
        self.assertEqual(error.findtext("Code"), "SlowDown")
        self.assertEqual(error.findtext("Resource"), "cas/key")

    # -- control endpoint --------------------------------------------------- #
    def test_control_switches_a_sustained_throttle_and_accounts_for_requests(self):
        server, control = self.proxy("--dialect", "azure")
        self.assertEqual(self.request(server, "GET", "/acct/cas/k1").status, 200)
        status, body = self.control(control, "POST", "/throttle", {"on": True, "ops": "GET", "retry_after": 2})
        self.assertEqual((status, body["throttle"]["code"], body["throttle"]["ops"]), (200, "ServerBusy", ["GET"]))
        response = self.request(server, "GET", "/acct/cas/k1")
        self.assertEqual((response.status, response.getheader("Retry-After")), (503, "2"))
        self.assertEqual(response.getheader("x-rechaos-fault"), "slowdown:ServerBusy:control")
        response.read()
        # Other operations are untouched while the throttle targets GET.
        self.assertEqual(self.request(server, "PUT", "/acct/cas/k2", body=b"x").status, 200)
        self.control(control, "POST", "/throttle", {"on": False})
        self.assertEqual(self.request(server, "GET", "/acct/cas/k1").status, 200)
        status, stats = self.control(control, "GET", "/stats")
        self.assertEqual(stats["requests"], 4)
        self.assertIsNone(stats["throttle"])
        k1 = next(k for k in stats["top_keys"] if k["key"] == "k1")
        self.assertEqual((k1["requests"], k1["throttled"], k1["served"]), (3, 1, 2))
        self.control(control, "POST", "/reset")
        self.assertEqual(self.control(control, "GET", "/stats")[1]["requests"], 0)
        self.assertEqual(self.control(control, "POST", "/throttle", {"ops": "bogus"})[0], 400)


if __name__ == "__main__":
    unittest.main()
