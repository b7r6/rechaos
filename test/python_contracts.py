#!/usr/bin/env python3
"""Regressions for evidence and verdict contracts; no external services."""
import argparse
import json
import itertools
import random
import pathlib
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import consistency_oracle as co
import reapi_differential as diff
import build_trace as bt
import check_lean
import conformance_report as card
import load_gen
from integration import Fixture, binary


class DifferentialContracts(unittest.TestCase):
    def run_probe(self, addresses, observations):
        endpoints = []
        def endpoint(address):
            ep = Mock(address=address)
            endpoints.append(ep)
            return ep
        probe = diff.Probe("probe", Mock(side_effect=observations), lambda raw: raw)
        with patch.object(diff, "Endpoint", side_effect=endpoint), \
                patch.object(diff, "build_probes", return_value=[probe]):
            report = diff.DifferentialHarness(addresses, sizes=[1]).run()
        for ep in endpoints:
            ep.channel.close.assert_called_once()
        return report, probe.run

    def test_duplicate_addresses_are_independent_observations(self):
        report, run = self.run_probe(["same:1", "same:1"],
                                    [{"status": "OK"}, {"status": "NOT_FOUND"}])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(len(report.probes[0].observations), 2)
        self.assertEqual(report.verdict, "diverge")

    def test_harness_errors_cannot_agree(self):
        report, _ = self.run_probe(["a:1", "b:1"], [ValueError("broken")] * 2)
        self.assertEqual(report.verdict, "error")

    def test_unreachable_endpoints_cannot_agree(self):
        report, _ = self.run_probe(["a:1", "b:1"], [{"status": "UNAVAILABLE"}] * 2)
        self.assertEqual(report.verdict, "error")

    def test_run_identity_is_preserved(self):
        with patch.object(diff, "build_probes", return_value=[]), \
                patch.object(diff, "Endpoint", return_value=Mock()):
            report = diff.DifferentialHarness(["a:1", "b:1"], sizes=[1], run_id="custom").run()
        self.assertEqual(report.to_dict()["runId"], "custom")

    def test_missing_is_a_set(self):
        item = {"hash": "a", "size": 1}
        self.assertEqual(diff.normalize_missing({"status": "OK", "missing": [item, item]}),
                         diff.normalize_missing({"status": "OK", "missing": [item]}))


class ConsistencyContracts(unittest.TestCase):
    key = "sha256:" + "a" * 64 + "/10"
    value = "a" * 64

    def test_rewrite_restores_availability_after_eviction(self):
        oracle = co.Oracle()
        oracle.record_write(self.key, 0, 1, self.value, 10)
        oracle.record_evict(self.key, 2)
        oracle.record_write(self.key, 3, 4, self.value, 10)
        oracle.record_find_missing(self.key, 5, 6, co.ABSENT)
        self.assertTrue(oracle.check())

    def test_eviction_overlapping_read_can_explain_absence(self):
        oracle = co.Oracle()
        oracle.record_write(self.key, 0, 1, self.value, 10)
        oracle.record_read(self.key, 2, 4, co.MISSING)
        oracle.record_evict(self.key, 3)
        self.assertEqual(oracle.check(), [])

    def test_find_missing_observations_share_the_register_history(self):
        oracle = co.Oracle()
        oracle.record_write(self.key, 0, 4, self.value, 10)
        oracle.record_find_missing(self.key, 1, 2, co.PRESENT)
        oracle.record_find_missing(self.key, 3, 3.5, co.ABSENT)
        self.assertTrue(oracle.check())

    def test_hash_does_not_excuse_wrong_size(self):
        oracle = co.Oracle()
        oracle.record_write(self.key, 0, 1, self.value, 10)
        oracle.record_read(self.key, 2, 3, co.OK, self.value, 9)
        self.assertTrue(any(v.kind == "content-addressing" for v in oracle.check()))

    def test_malformed_history_is_rejected(self):
        for changes in ({"op": "typo"}, {"res": -1}, {"inv": float("nan")},
                        {"outcome": "typo"}, {"value_hash": co.EMPTY}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                co.Event.from_json({"op": "read", "key": self.key, "inv": 0,
                                    "res": 1, "outcome": "ok", "value_hash": self.value,
                                    **changes}, seq=0)

    def test_unresolved_write_is_inconclusive(self):
        oracle = co.Oracle()
        oracle.record_write(self.key, 0, 1, self.value, outcome=co.ERROR)
        oracle.record_read(self.key, 2, 3, co.OK, self.value, 10)
        with self.assertRaises(ValueError):
            oracle.check()

    def test_empty_cas_blob_is_present_without_upload(self):
        oracle = co.Oracle()
        oracle.record_read(co.EMPTY_KEY, 0, 1, co.OK, co.EMPTY_HASH, 0)
        oracle.record_find_missing(co.EMPTY_KEY, 2, 3, co.PRESENT)
        self.assertEqual(oracle.check(), [])
        oracle.record_evict(co.EMPTY_KEY, 4)
        oracle.record_find_missing(co.EMPTY_KEY, 5, 6, co.ABSENT)
        self.assertTrue(oracle.check())

    def test_action_paths_and_executable_bits_are_observed(self):
        result = diff.re.ActionResult(output_files=[diff.re.OutputFile(
            path="a", digest=diff.re.Digest(hash=self.value, size_bytes=10))])
        original = diff.action_observation(result)
        result.output_files[0].path = "b"
        self.assertNotEqual(original, diff.action_observation(result))
        result.output_files[0].path = "a"
        result.output_files[0].is_executable = True
        self.assertNotEqual(original, diff.action_observation(result))

    def test_sequential_history_exceeding_recursion_limit(self):
        oracle = co.Oracle()
        oracle.record_write(self.key, 0, 1, self.value, 10)
        for i in range(1200):
            oracle.record_read(self.key, 2 + i * 2, 3 + i * 2, co.OK, self.value, 10)
        self.assertEqual(oracle.check(), [])

    def test_small_histories_against_exhaustive_sequential_witnesses(self):
        rng = random.Random(781)
        for _ in range(100):
            events = []
            for i in range(5):
                inv = rng.randrange(5)
                res = inv + rng.randrange(3)
                op = rng.choice([co.WRITE, co.READ, co.FIND_MISSING, co.EVICT])
                outcome = (rng.choice([co.PRESENT, co.ABSENT]) if op == co.FIND_MISSING else
                           rng.choice([co.OK, co.MISSING]) if op == co.READ else co.OK)
                events.append(co.Event(op, "ac:test", inv, inv if op == co.EVICT else res,
                                       outcome, rng.choice(["v1", "v2"]), seq=i))
            def legal(order):
                positions = {e.seq: i for i, e in enumerate(order)}
                if any(a.res < b.inv and positions[a.seq] > positions[b.seq]
                       for a in events for b in events):
                    return False
                value = co.EMPTY
                for e in order:
                    if e.op == co.WRITE:
                        value = e.value
                    elif e.op == co.EVICT:
                        value = co.EMPTY
                    elif e.op == co.FIND_MISSING:
                        if (e.outcome == co.PRESENT) != (value != co.EMPTY):
                            return False
                    elif (e.value if e.outcome == co.OK else co.EMPTY) != value:
                        return False
                return True
            expected = any(legal(order) for order in itertools.permutations(events))
            with self.subTest(events=events):
                self.assertEqual(not co.check_linearizability("ac:test", events), expected)
                if expected:
                    self.assertEqual(co.check_monotone_availability("ac:test", events), [])


def graph_args(**kwargs):
    return argparse.Namespace(seed=41, graph_id="regression", instance="main",
                              targets=4, layers=2, shared_inputs=1, max_inputs=3,
                              max_deps=2, concurrency=2, execute=False, **kwargs)


class BuildTraceContracts(unittest.TestCase):
    def setUp(self):
        self.args = graph_args()
        with patch.object(bt, "_pick_size", return_value=32):
            self.graph = bt.BuildGraph.synthesize(self.args)

    def test_graph_descriptor_reconstructs_every_blob(self):
        restored = bt.BuildGraph.from_descriptor(json.loads(json.dumps(self.graph.descriptor())))
        self.assertEqual(restored.descriptor(), self.graph.descriptor())
        for original, replayed in zip(self.graph.targets, restored.targets):
            self.assertEqual(original.output.data, replayed.output.data)
            self.assertEqual([b.data for b in original.inputs], [b.data for b in replayed.inputs])

    def test_graph_corruption_fails_before_replay(self):
        descriptor = self.graph.descriptor()
        descriptor["shared"][0]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            bt.BuildGraph.from_descriptor(descriptor)

    def test_recording_detects_missing_tail_and_changed_outcomes(self):
        rows = [{"seq": 0, "method": bt.WRITE, "request": {}, "response": {"committedBytes": 32}}]
        descriptor = bt.recorded_graph(self.graph, rows, {"errors": []})
        bt.verify_recording(descriptor, rows)
        for changed in ([], [{**rows[0], "response": {"committedBytes": 0}}]):
            with self.assertRaises(ValueError):
                bt.verify_recording(descriptor, changed)
        descriptor["recording"]["successful"] = False
        with self.assertRaises(ValueError):
            bt.verify_recording(descriptor, rows)

    def test_action_digest_depends_on_inputs(self):
        target = self.graph.targets[0]
        first = bt.build_action_blobs(None, self.graph, target)[-1].hash
        target.inputs = [bt.Blob("main", "other", "changed-input", 32)]
        second = bt.build_action_blobs(None, self.graph, target)[-1].hash
        self.assertNotEqual(first, second)

    def test_wrong_committed_size_is_a_driver_error(self):
        client = Mock()
        client.find_missing.side_effect = lambda blobs: {(b.hash, b.size) for b in blobs}
        client.upload.return_value = 0
        client.get_action_result.return_value = (None, bt.grpc.StatusCode.NOT_FOUND)
        driver = bt.Driver(client, self.graph, self.args)
        driver.run_target(self.graph.targets[0])
        self.assertTrue(driver.errors)
        client.update_action_result.assert_not_called()

    def test_ac_transport_error_is_not_a_cache_miss(self):
        client = Mock()
        client.find_missing.return_value = set()
        client.get_action_result.return_value = (None, bt.grpc.StatusCode.UNAVAILABLE)
        driver = bt.Driver(client, self.graph, self.args)
        driver.run_target(self.graph.targets[0])
        self.assertTrue(driver.errors)
        client.update_action_result.assert_not_called()

    def test_empty_cached_result_cannot_pass(self):
        client = Mock()
        client.find_missing.return_value = set()
        client.get_action_result.return_value = (bt.re.ActionResult(), None)
        driver = bt.Driver(client, self.graph, self.args)
        driver.run_target(self.graph.targets[0])
        self.assertTrue(driver.errors)

    def test_unknown_trace_method_is_not_reported_as_replayed(self):
        replay = bt.Replayer(Mock(), self.graph,
                             [{"seq": 0, "method": "unknown", "request": {}, "response": {}}])
        self.assertTrue(replay.run()["mismatches"])

    def test_real_wire_record_replay_and_duplicate_endpoint_comparison(self):
        fixture = Fixture()
        client = bt.Client("127.0.0.1", fixture.port, "main")
        try:
            trace = []
            driver = bt.Driver(client, self.graph, self.args, trace=trace)
            self.assertEqual(driver.drive()["errors"], [])
            self.assertEqual([r["seq"] for r in trace], list(range(len(trace))))
            graph = bt.BuildGraph.from_descriptor(json.loads(json.dumps(self.graph.descriptor())))
            descriptor = bt.recorded_graph(self.graph, trace, {"errors": []})
            bt.verify_recording(descriptor, trace)
            self.assertEqual(bt.BuildGraph.from_descriptor(descriptor).descriptor(), graph.descriptor())
            replay = bt.Replayer(client, graph, trace).run()
            self.assertEqual(replay["mismatches"], [])
            self.assertEqual(replay["replayed"], len(trace))
            address = f"127.0.0.1:{fixture.port}"
            report = diff.DifferentialHarness([address, address], sizes=[1, 17]).run()
            self.assertEqual(report.verdict, "agree")
            self.assertTrue(all(len(p.observations) == 2 for p in report.probes))
        finally:
            client.channel.close()
            fixture.close()


class LeanGateContracts(unittest.TestCase):
    def test_comments_strings_and_nested_comments_are_not_proof_holes(self):
        self.assertEqual(check_lean.forbidden('/- sorry /- admit -/ axiom -/\n-- sorry\n#eval "axiom"'), [])

    def test_all_forbidden_declarations_are_rejected(self):
        self.assertEqual(check_lean.forbidden('theorem x : True := by sorry\naxiom y : False\nexample : True := by admit'),
                         [(1, "sorry"), (2, "axiom"), (3, "admit")])


class LoadContracts(unittest.TestCase):
    def test_tiny_blobs_include_entropy_instead_of_a_constant_prefix(self):
        tokens = [Mock(bytes=b"a" * 16), Mock(bytes=b"b" * 16)]
        with patch.object(load_gen.uuid, "uuid4", side_effect=tokens):
            rng = random.Random(4)
            self.assertNotEqual(load_gen._make_blob(rng, 1), load_gen._make_blob(rng, 1))


class ScorecardContracts(unittest.TestCase):
    def test_entire_probe_battery_against_verifying_fixture(self):
        fixture = Fixture()
        harness = card.Harness(f"127.0.0.1:{fixture.port}", "main", 17)
        try:
            ctx = {}
            checks = [check for probe in card.PROBES for check in probe(harness, ctx)]
            self.assertFalse([check.as_dict() for check in checks if check.status == card.FAIL])
            self.assertTrue(any(check.status == card.PASS for check in checks))
        finally:
            harness.close()
            fixture.close()

    def test_integrity_rejects_any_wrong_bytes(self):
        harness = card.Harness("localhost:1", "main", 1)
        try:
            harness.write = Mock(return_value=("upload", 777))
            harness.read = Mock(return_value=b"unrelated corruption")
            self.assertEqual(card.probe_integrity(harness, {})[0].status, card.FAIL)
        finally:
            harness.close()

    def test_integrity_transport_failure_is_inconclusive(self):
        class Unavailable(card.grpc.RpcError):
            def code(self):
                return card.grpc.StatusCode.UNAVAILABLE
        harness = card.Harness("localhost:1", "main", 1)
        try:
            harness.write = Mock(return_value=("upload", 777))
            harness.read = Mock(side_effect=Unavailable())
            self.assertEqual(card.probe_integrity(harness, {})[0].status, card.SKIP)
        finally:
            harness.close()

    def test_ac_probe_uploads_required_action_and_command(self):
        fixture = Fixture()
        harness = card.Harness(f"127.0.0.1:{fixture.port}", "main", 1)
        try:
            self.assertEqual([c.status for c in card.probe_action_cache(harness, {})], [card.PASS, card.PASS])
        finally:
            harness.close()
            fixture.close()


class CliContracts(unittest.TestCase):
    def test_unreadable_tree_has_machine_readable_inconclusive_verdict(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([binary(), "oracle", directory, directory + "/absent"],
                                    text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout), {"verdict": "inconclusive"})

    def minimize(self, unknown):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source = json.loads((ROOT / "test/golden/schedule.jsonl").read_text().splitlines()[0])
            source["injection"] = {"kind": "delay", "micros": 0}
            timeline = root / "timeline.jsonl"
            timeline.write_text(json.dumps(source) + "\n")
            checker = root / "checker.py"
            checker.write_text('import json, os, pathlib\n'
                               'has_fault = bool(pathlib.Path(os.environ["RECHAOS_TIMELINE"]).read_text().strip())\n'
                               'verdict = {"verdict": "triggers", "signature": "test"} if has_fault else '
                               + repr({"verdict": "unknown" if unknown else "does-not-trigger"}) + '\n'
                               'pathlib.Path(os.environ["RECHAOS_VERDICT"]).write_text(json.dumps(verdict))\n')
            result = subprocess.run([binary(), "minimize", "--timeline", str(timeline),
                                     "--output", str(root / "minimal.jsonl"), "--signature", "test",
                                     "--check", shlex.join([sys.executable, str(checker)]),
                                     "--repetitions", "1", "--max-trials", "1"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)

    def test_minimizer_does_not_claim_minimality_after_unknown(self):
        self.assertEqual(self.minimize(True)["status"], "inconclusive")

    def test_minimizer_finishing_on_last_trial_is_complete(self):
        self.assertEqual(self.minimize(False)["status"], "complete")


if __name__ == "__main__":
    unittest.main()
