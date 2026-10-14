#!/usr/bin/env python3
"""Contracts for scenario-step shrinking: the pure scheduler invariant
evaluator (scripts/scheduler_steps.py `evaluate`) and `rechaos minimize --steps`
driving a toy checker. No NativeLink or Redis is needed; the live rig is an
operational run, not a test fixture."""
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "test"))
import scheduler_steps as ss  # noqa: E402
from integration import binary  # noqa: E402

LIMITS = ss.Limits(queue_age_ms=5000, executing_ms=30000, workers=2, slots=4, memory_kb=20480)


def action(id, submit, executing=None, done=None, last=None, stage=None, status=None, message="",
           inputs_present=None, cpu=1, memory_kb=2048, detached=False):
    return {"id": id, "submit_ms": submit, "queued_ms": submit, "executing_ms": executing, "done_ms": done,
            "last_ms": last if last is not None else (done if done is not None else executing),
            "last_stage": stage or ("COMPLETED" if done is not None else ("EXECUTING" if executing is not None else "QUEUED")),
            "status": status or ("OK" if done is not None else None), "message": message, "exit_code": 0 if done else None,
            "operation": f"op-{id}", "detached": detached, "probes": [], "inputs_present": inputs_present,
            "missing": [], "requeues": [], "cpu": cpu, "memory_kb": memory_kb, "sleep_ms": 0}


def observations(actions):
    return {"version": 1, "limits": LIMITS.__dict__, "actions": actions, "controls": []}


class EvaluatorContracts(unittest.TestCase):
    def sigs(self, actions):
        return ss.signatures(ss.evaluate(observations(actions), LIMITS))

    def test_fast_dispatch_is_clean(self):
        acts = [action(f"s{i}", i * 100, executing=i * 100 + 50, done=i * 100 + 600) for i in range(10)]
        self.assertEqual(self.sigs(acts), [])

    def test_starvation_needs_both_a_long_wait_and_an_overtake(self):
        smalls = [action(f"s{i}", i * 200, executing=i * 200 + 30, done=i * 200 + 2000) for i in range(40)]
        large = action("L", 1000, executing=12000, done=12600, memory_kb=16384)
        self.assertEqual(self.sigs(smalls + [large]), ["queue-starvation"])
        # Same wait, but nothing was dispatched after it: a stall, not starvation.
        alone = [action("L", 1000, executing=12000, done=12600, memory_kb=16384)]
        self.assertEqual(self.sigs(alone), ["dispatch-stall"])
        # A wait under the bound is never a finding, however many overtake it.
        quick = action("L", 1000, executing=4000, done=4600, memory_kb=16384)
        self.assertEqual(self.sigs(smalls + [quick]), [])

    def test_an_overtake_needs_a_margin(self):
        # Two actions that waited together and were dispatched 300 ms apart in the
        # "wrong" order are not a starvation finding; one second apart they are.
        first = action("a", 0, executing=20000, done=20500)
        wobble = action("b", 100, executing=19700, done=20200)
        self.assertEqual(self.sigs([first, wobble]), ["dispatch-stall"])   # waited with room, no overtake
        clear = action("c", 100, executing=18900, done=19400)
        # "a" was overtaken by "c"; "c" itself waited with room and no overtake.
        self.assertEqual(self.sigs([first, clear]), ["dispatch-stall", "queue-starvation"])

    def test_never_dispatched_action_counts_from_its_last_observation(self):
        smalls = [action(f"s{i}", i * 200, executing=i * 200 + 30, done=i * 200 + 2000) for i in range(40)]
        starved = action("L", 1000, last=20000, stage="QUEUED", status="DEADLINE_EXCEEDED", memory_kb=16384)
        self.assertEqual(self.sigs(smalls + [starved]), ["queue-starvation"])
        # Observed for less than the bound: no claim can be made.
        brief = action("L", 1000, last=3000, stage="QUEUED", status="CLIENT_CANCELLED", memory_kb=16384)
        self.assertEqual(self.sigs(smalls + [brief]), [])

    def test_stall_requires_room_in_the_fleet(self):
        # 8 slots; nine in flight at the bound means the fleet was full: not a stall.
        busy = [action(f"s{i}", 0, executing=10, last=9000, stage="EXECUTING") for i in range(9)]
        waiting = action("w", 100, last=9000, stage="QUEUED", status="DEADLINE_EXCEEDED")
        self.assertEqual(self.sigs(busy + [waiting]), [])
        # Three in flight: room for the waiting one, so it stalled.
        few = [action(f"s{i}", 0, executing=10, last=9000, stage="EXECUTING") for i in range(3)]
        self.assertEqual(self.sigs(few + [waiting]), ["dispatch-stall"])

    def test_stuck_executing_needs_the_bound_and_an_executing_last_stage(self):
        stuck = action("x", 0, executing=500, last=40000, stage="EXECUTING", detached=True)
        self.assertEqual(self.sigs([stuck]), ["stuck-executing"])
        short = action("x", 0, executing=500, last=20000, stage="EXECUTING", detached=True)
        self.assertEqual(self.sigs([short]), [])
        finished = action("x", 0, executing=500, done=40000)
        self.assertEqual(self.sigs([finished]), [])

    def test_failures_are_attributed_only_with_inputs_present(self):
        evicted = action("e", 0, executing=100, done=400, status="FAILED_PRECONDITION",
                         message="Could not make hardlink from a to b, file was likely evicted from cache.",
                         inputs_present=True)
        self.assertEqual(self.sigs([evicted]), ["input-evicted-failure"])
        other = action("o", 0, executing=100, done=400, status="INTERNAL", message="boom", inputs_present=True)
        self.assertEqual(self.sigs([other]), ["action-failed-inputs-present:INTERNAL"])
        absent = action("a", 0, executing=100, done=400, status="FAILED_PRECONDITION",
                        message="evicted", inputs_present=False)
        self.assertEqual(self.sigs([absent]), [])
        client = action("c", 0, executing=100, last=400, stage="EXECUTING", status="DEADLINE_EXCEEDED",
                        inputs_present=True)
        self.assertEqual(self.sigs([client]), [])

    def test_a_generic_failure_inside_a_fault_window_is_the_faults_own_effect(self):
        refused = action("r", 1500, done=1600, status="UNKNOWN", message="OOM command not allowed", inputs_present=True)
        obs = observations([refused])
        obs["controls"] = [{"step": "store-full", "start_ms": 1000, "end_ms": 5000}]
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), [])
        obs["controls"] = []
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), ["action-failed-inputs-present:UNKNOWN"])
        # An eviction failure is attributed by its message whatever the window.
        evicted = action("e", 1500, done=1600, status="FAILED_PRECONDITION", message="likely evicted from cache",
                         inputs_present=True)
        obs = observations([evicted])
        obs["controls"] = [{"step": "store-full", "start_ms": 1000, "end_ms": 5000}]
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), ["input-evicted-failure"])

    def test_time_inside_a_control_fault_window_does_not_count(self):
        # A 4 s store pause from 1 s to 5 s: an action submitted at 0 and dispatched
        # at 7 s waited 7 s on the clock but only 3 s outside the fault.
        smalls = [action(f"s{i}", 500 + i * 100, executing=5100 + i * 100, done=6000 + i * 100) for i in range(5)]
        late = action("L", 0, executing=7000, done=7500, memory_kb=16384)
        obs = observations(smalls + [late])
        obs["controls"] = [{"step": "store-pause", "start_ms": 1000, "end_ms": 5000}]
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), [])
        # Without the fault window the same timings are a starvation finding.
        obs["controls"] = []
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), ["queue-starvation"])
        # The executing bound is discounted the same way: 30 s bound, 10 s of it faulted.
        stuck = action("x", 0, executing=500, last=35000, stage="EXECUTING", detached=True)
        obs = observations([stuck])
        obs["controls"] = [{"step": "store-full", "start_ms": 1000, "end_ms": 11000}]
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), [])
        obs["controls"] = [{"step": "store-full", "start_ms": 1000, "end_ms": 4000}]
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), ["stuck-executing"])

    def test_store_throttle_findings(self):
        # A 45 s throttle (well under the 600 s download budget): an action whose
        # input fetch failed inside it is a give-up; one that bounced back to the
        # queue inside it is a re-dispatch; both are quiet without the window.
        windows = [{"step": "store-throttle", "start_ms": 1000, "end_ms": 46000}]
        gave_up = action("g", 0, executing=200, done=39000, status="ABORTED",
                         message="Failed to start download from Azure: ServerBusy ... On attempt 7",
                         inputs_present=True)
        bounced = action("b", 0, executing=300, done=50000)
        bounced["requeues"] = [39100]
        obs = observations([gave_up, bounced])
        obs["controls"] = windows
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)),
                         ["store-throttle-giveup", "store-throttle-redispatch"])
        obs["controls"] = []
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), ["action-failed-inputs-present:ABORTED"])
        # A throttle longer than the download budget makes giving up legitimate.
        long = ss.Limits(**{**LIMITS.__dict__, "download_budget_ms": 30000})
        obs["controls"] = windows
        self.assertEqual(ss.signatures(ss.evaluate(obs, long)), [])
        # A worker retrying a fetch under a throttle is legitimately EXECUTING:
        # the throttle is discounted from the executing bound.
        retrying = action("r", 0, executing=500, last=40000, stage="EXECUTING", detached=True)
        obs = observations([retrying])
        obs["controls"] = windows
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), [])
        # A throttle holds every slot with a retrying fetch: like any control
        # window it is discounted from the queue-age bound.
        smalls = [action(f"s{i}", 500 + i * 100, executing=600 + i * 100, done=2000 + i * 100) for i in range(5)]
        late = action("L", 0, executing=7000, done=7500, memory_kb=16384)
        obs = observations(smalls + [late])
        obs["controls"] = windows
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), [])
        obs["controls"] = []
        self.assertEqual(ss.signatures(ss.evaluate(obs, LIMITS)), ["queue-starvation"])

    def test_evaluation_is_deterministic_and_sorted(self):
        smalls = [action(f"s{i}", i * 200, executing=i * 200 + 30, done=i * 200 + 2000) for i in range(20)]
        large = action("L", 1000, executing=12000, done=12600, memory_kb=16384)
        stuck = action("x", 0, executing=500, last=40000, stage="EXECUTING", detached=True)
        first = ss.evaluate(observations(smalls + [large, stuck]), LIMITS)
        second = ss.evaluate(observations(list(reversed(smalls + [large, stuck]))), LIMITS)
        self.assertEqual(first, second)
        self.assertEqual([f["signature"] for f in first], ["queue-starvation", "stuck-executing"])

    def test_step_validation_refuses_what_the_rig_cannot_replay(self):
        memory_rig = {"redis": None, "workers": 2}
        self.assertEqual(ss.validate_steps([{"step": "store-full", "at_ms": 0, "for_ms": 10}], memory_rig),
                         ["step 0: store-full needs a redis-backed rig"])
        self.assertEqual(ss.validate_steps([{"step": "nonsense"}], memory_rig), ["step 0: unknown step kind 'nonsense'"])
        self.assertEqual(ss.validate_steps([{"step": "worker-pause", "worker": 5}], memory_rig),
                         ["step 0: worker index out of range"])
        ok = [{"step": "blob", "id": "t", "bytes": 10}, {"step": "action", "id": "a", "at_ms": 0, "cpu": 1,
                                                          "memory_kb": 1, "sleep_ms": 0}]
        self.assertEqual(ss.validate_steps(ok, memory_rig), [])
        throttle = [{"step": "store-throttle", "at_ms": 0, "for_ms": 60000}]
        self.assertEqual(ss.validate_steps(throttle, memory_rig),
                         ["step 0: store-throttle needs a rig whose CAS sits behind the fault proxy"])
        store_rig = {"redis": None, "workers": 2, "object_store": {"dialect": "azure"},
                     "scheduler": {"max_action_executing_timeout_s": 20}}
        self.assertEqual(len(ss.validate_steps(throttle, store_rig)), 1)
        store_rig["scheduler"]["max_action_executing_timeout_s"] = 0
        self.assertEqual(ss.validate_steps(throttle, store_rig), [])


def random_observations(rng, with_controls=True):
    """A random but well-formed observations document: a handful of actions at
    every stage of life, optional control windows, limits in range."""
    n = rng.randint(1, 9)
    acts = []
    for i in range(n):
        submit = rng.choice([None, rng.randint(0, 20000)])
        if submit is None:
            acts.append(action(f"a{i}", 0) | {"submit_ms": None, "queued_ms": None})
            continue
        shape = rng.choice(["fast", "slow", "stuck", "failed", "queued", "evicted", "throttled"])
        executing = None if shape == "queued" else submit + rng.randint(0, 25000)
        done = None if shape in ("stuck", "queued") else (executing or submit) + rng.randint(0, 30000)
        last = done if done is not None else (executing or submit) + rng.randint(0, 50000)
        stage = "COMPLETED" if done is not None else ("EXECUTING" if executing is not None else "QUEUED")
        status = {"fast": "OK", "slow": "OK", "stuck": None, "queued": rng.choice([None, "DEADLINE_EXCEEDED"]),
                  "failed": rng.choice(["INTERNAL", "FAILED_PRECONDITION", "UNKNOWN", "CANCELLED"]),
                  "evicted": "FAILED_PRECONDITION", "throttled": rng.choice(["ABORTED", "INTERNAL"])}[shape]
        message = {"evicted": "Could not make hardlink, file was likely evicted from cache",
                   "throttled": "Failed to start download from Azure: ServerBusy On attempt 7",
                   "failed": rng.choice(["boom", "OOM command not allowed", "channel closed"])}.get(shape, "")
        a = action(f"a{i}", submit, executing=executing, done=done, last=last, stage=stage, status=status,
                   message=message, inputs_present=rng.choice([None, True, False]),
                   cpu=rng.randint(1, 2), memory_kb=rng.choice([512, 2048, 16384]), detached=rng.random() < 0.3)
        a["requeues"] = sorted(rng.randint(0, 60000) for _ in range(rng.choice([0, 0, 1, 2])))
        a["probes"] = [{} for _ in range(rng.randint(0, 3))]
        a["exit_code"] = rng.choice([None, 0, 1])
        # The two keys both readers treat as optional: sometimes absent entirely.
        if rng.random() < 0.25:
            del a["inputs_present"]
        if rng.random() < 0.25:
            del a["requeues"]
        acts.append(a)
    controls = []
    if with_controls:
        for _ in range(rng.choice([0, 1, 2])):
            start = rng.randint(0, 30000)
            controls.append({"step": rng.choice(["store-full", "store-pause", "worker-pause", "store-throttle"]),
                             "start_ms": start, "end_ms": start + rng.choice([0, 100, 5000, 70000])})
    limits = {"queue_age_ms": rng.choice([3000, 5000, 8000]), "executing_ms": rng.choice([15000, 30000]),
              "workers": rng.randint(1, 3), "slots": rng.randint(1, 4), "memory_kb": 20480,
              "settle_ms": 3000, "download_budget_ms": rng.choice([30000, 600000])}
    return {"version": 1, "limits": limits, "actions": acts, "controls": controls}


def named_fixtures():
    """The catalog's named cases, one observations document each, so the
    differential contract covers them as well as the random documents."""
    smalls = [action(f"s{i}", i * 200, executing=i * 200 + 30, done=i * 200 + 2000) for i in range(40)]
    docs = {
        "starvation": observations(smalls + [action("L", 1000, executing=12000, done=12600, memory_kb=16384)]),
        "stall": observations([action("L", 1000, executing=12000, done=12600, memory_kb=16384)]),
        "stuck": observations([action("x", 0, executing=500, last=40000, stage="EXECUTING", detached=True)]),
        "evicted": observations([action("e", 0, executing=100, done=400, status="FAILED_PRECONDITION",
                                        message="Could not make hardlink, file was likely evicted from cache.",
                                        inputs_present=True)]),
        "refused-in-window": observations([action("r", 1500, done=1600, status="UNKNOWN",
                                                  message="OOM command not allowed", inputs_present=True)]),
        "throttle": observations([action("g", 0, executing=200, done=39000, status="ABORTED",
                                         message="Failed to start download from Azure: ServerBusy ... On attempt 7",
                                         inputs_present=True)]),
    }
    docs["refused-in-window"]["controls"] = [{"step": "store-full", "start_ms": 1000, "end_ms": 5000}]
    docs["throttle"]["controls"] = [{"step": "store-throttle", "start_ms": 1000, "end_ms": 46000}]
    return docs


class HaskellEvaluatorContracts(unittest.TestCase):
    """`rechaos evaluate` is the pure-core port of the Python evaluator; until
    the Python engine is retired, the two must agree on every observation."""

    def haskell(self, obs, extra=()):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "observations.json"
            path.write_text(json.dumps(obs))
            result = subprocess.run([binary(), "evaluate", str(path), *extra], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)

    def test_agrees_with_python_on_random_observations(self):
        import random
        rng = random.Random(20261014)
        agreed = 0
        for case in range(120):
            obs = random_observations(rng)
            expected = ss.evaluate(obs)
            report = self.haskell(obs)
            self.assertEqual(json.loads(json.dumps(report["findings"])), json.loads(json.dumps(expected)),
                             f"case {case}: {json.dumps(obs)[:800]}")
            self.assertEqual(report["signatures"], ss.signatures(expected))
            agreed += bool(expected)
        self.assertGreater(agreed, 20, "the random cases must exercise findings, not only silence")

    def test_agrees_with_python_on_the_named_fixtures(self):
        for name, obs in named_fixtures().items():
            expected = ss.evaluate(obs)
            report = self.haskell(obs)
            self.assertEqual(json.loads(json.dumps(report["findings"])), json.loads(json.dumps(expected)), name)
            self.assertTrue(expected or name == "refused-in-window", f"{name} should produce a finding")

    def test_limit_overrides_apply(self):
        smalls = [action(f"s{i}", i * 200, executing=i * 200 + 30, done=i * 200 + 2000) for i in range(40)]
        large = action("L", 1000, executing=12000, done=12600, memory_kb=16384)
        obs = observations(smalls + [large])
        self.assertEqual(self.haskell(obs)["signatures"], ["queue-starvation"])
        self.assertEqual(self.haskell(obs, ["--queue-age-ms", "20000"])["signatures"], [])

    def test_unreadable_observations_fail_closed(self):
        complete = action("x", 0, executing=10, done=20)
        for document, missing in (({"actions": [complete]}, "limits"),
                                  ({"limits": LIMITS.__dict__, "actions": [{"id": "x"}]}, "submit_ms"),
                                  ({"limits": LIMITS.__dict__, "actions": [{k: v for k, v in complete.items() if k != "memory_kb"}]}, "memory_kb")):
            with tempfile.TemporaryDirectory() as tmp:
                path = pathlib.Path(tmp) / "observations.json"
                path.write_text(json.dumps(document))
                result = subprocess.run([binary(), "evaluate", str(path)], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, missing)
                self.assertIn(missing, result.stderr)

    def test_python_reader_rejects_what_the_haskell_reader_rejects(self):
        # The Haskell reader is opaque about step kinds (that is the engine's
        # business); both readers agree on the weaker declaration rules.
        bad = [{"step": "x", "weaker": {"n": 0}}, {"step": "x", "n": 1, "weaker": {"n": 5}},
               {"step": "x", "n": -1, "weaker": {"n": 0}}, {"step": "x", "n": 1, "weaker": 3}]
        for step in bad:
            with tempfile.TemporaryDirectory() as tmp:
                path = pathlib.Path(tmp) / "steps.jsonl"
                path.write_text(json.dumps(step) + "\n")
                with self.assertRaises(ss.StepError):
                    ss.read_steps(path)
                result = subprocess.run([binary(), "validate-steps", str(path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, step)
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "steps.json"
            path.write_text(json.dumps([{"step": "a", "n": 4, "weaker": {"n": 1}}, {"step": "b"}]) + "\n\n")
            self.assertEqual(len(ss.read_steps(path)), 2)
            result = subprocess.run([binary(), "validate-steps", str(path)], capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout), {"verdict": "valid", "steps": 2})

    def test_validate_steps(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "steps.jsonl"
            path.write_text(json.dumps({"step": "action", "id": "a", "sleep_ms": 4, "weaker": {"sleep_ms": 0}}) + "\n")
            result = subprocess.run([binary(), "validate-steps", str(path)], capture_output=True, text=True)
            self.assertEqual((result.returncode, json.loads(result.stdout)), (0, {"verdict": "valid", "steps": 1}))
            path.write_text(json.dumps({"step": "action", "weaker": {"sleep_ms": 0}}) + "\n")
            result = subprocess.run([binary(), "validate-steps", str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("declared field is absent", result.stderr)


# A toy checker for `rechaos minimize --steps`: the "failure" is present when a
# step with key == "needle" survives AND the summed "load" of the surviving
# steps is at least a threshold. This exercises both deletion and the declared
# `weaker` halving in one search.
CHECKER = r'''
import json, os
steps = [json.loads(l) for l in open(os.environ["RECHAOS_STEPS"]) if l.strip()]
needle = any(s.get("key") == "needle" for s in steps)
load = sum(s.get("load", 0) for s in steps)
v = {"verdict": "triggers", "signature": "toy"} if needle and load >= 5 else {"verdict": "does-not-trigger"}
open(os.environ["RECHAOS_VERDICT"], "w").write(json.dumps(v))
'''


class MinimizeStepsContracts(unittest.TestCase):
    def run_minimize(self, steps, extra=()):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            (tmp / "steps.jsonl").write_text("".join(json.dumps(s) + "\n" for s in steps))
            (tmp / "check.py").write_text(CHECKER)
            cmd = [binary(), "minimize", "--steps", str(tmp / "steps.jsonl"), "--output", str(tmp / "min.jsonl"),
                   "--check", f"{sys.executable} -I {tmp / 'check.py'}", "--signature", "toy",
                   "--repetitions", "1", "--trial-timeout", "20", *extra]
            result = subprocess.run(cmd, capture_output=True, text=True)
            out = [json.loads(l) for l in (tmp / "min.jsonl").read_text().splitlines()] if (tmp / "min.jsonl").exists() else None
            trials = (tmp / "min.jsonl.trials.jsonl").read_text() if (tmp / "min.jsonl.trials.jsonl").exists() else ""
            return result, out, trials

    def test_steps_shrink_by_deletion_and_declared_halving(self):
        steps = ([{"step": "noise", "n": i} for i in range(6)]
                 + [{"step": "x", "key": "needle"}]
                 + [{"step": "load", "load": 64, "weaker": {"load": 0}}]
                 + [{"step": "noise", "n": 99}])
        result, out, trials = self.run_minimize(steps)
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = json.loads(result.stdout)
        self.assertEqual(summary["status"], "complete")
        self.assertEqual(summary["steps"], 2)
        self.assertEqual(sorted(s["step"] for s in out), ["load", "x"])
        load = next(s for s in out if s["step"] == "load")
        # 64 -> 32 -> 16 -> 8 -> 4 (does not trigger): 8 is the 1-minimal intensity.
        self.assertEqual(load["load"], 8)
        self.assertIn('"steps":', trials)

    def test_steps_that_never_reproduce_fail_loudly(self):
        result, out, _ = self.run_minimize([{"step": "noise", "load": 9}])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not repeatedly reproduce", result.stderr)
        self.assertIsNone(out)

    def test_malformed_weaker_is_rejected_before_any_trial(self):
        bad = [{"step": "x", "key": "needle", "load": 9, "weaker": {"load": 20}}]
        result, out, _ = self.run_minimize(bad)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("value is below its floor", result.stderr)
        missing = [{"step": "x", "key": "needle", "load": 9, "weaker": {"absent": 0}}]
        result, _, _ = self.run_minimize(missing)
        self.assertIn("declared field is absent", result.stderr)

    def test_checker_without_a_verdict_is_unknown_not_a_reproduction(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            (tmp / "steps.jsonl").write_text(json.dumps({"step": "x", "key": "needle", "load": 9}) + "\n")
            cmd = [binary(), "minimize", "--steps", str(tmp / "steps.jsonl"), "--output", str(tmp / "min.jsonl"),
                   "--check", "true", "--signature", "toy", "--repetitions", "1", "--trial-timeout", "5"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((tmp / "min.jsonl").exists())


if __name__ == "__main__":
    unittest.main()
