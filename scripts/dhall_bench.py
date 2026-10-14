#!/usr/bin/env python3
"""Measure what Dhall costs rechaos, per operation and per input size, for any
Dhall implementation that exposes a type-check and a render-to-JSON command.

The harness separates what a slow number can mean:

  startup     the implementation on a trivial expression ({=}); binary and
              runtime cost, paid once per invocation
  type        `dhall type` on a file; parse + import resolution + type-check
  json        `dhall-to-json` on a file; parse + type-check + normalize + emit
  flake-gate  the whole `dhall` flake check, which is what CI pays

over the repository's own files plus generated inputs that grow with the two
sizes that matter: steps per scenario (a frozen witness is a literal step list;
an authored one is built with Natural/fold) and workers per fleet (every worker
config is rendered on each rig start). Each measurement is a fresh process;
wall time and peak RSS come from the child's rusage. Medians over --repeat.

    nix develop --command python3 scripts/dhall_bench.py                # reference (dhall + dhall-json)
    python3 scripts/dhall_bench.py --type-cmd 'fastdhall type {file}' \\
        --json-cmd 'fastdhall to-json {file}' --label fast --compare    # a candidate, checked for equal JSON

`--compare` renders every input with both the candidate and the reference and
fails if any JSON differs (after parsing), so a faster implementation is only
reported if it is also the same implementation on these inputs.
"""
import argparse
import json
import pathlib
import shlex
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
DHALL = ROOT / "dhall"
STEP_SIZES = [10, 100, 1000, 10000]
WORKER_SIZES = [1, 4, 16, 64]


def log(message):
    print(message, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Generated inputs.
# ---------------------------------------------------------------------------
def literal_scenario(n):
    """A frozen witness: n literal action steps, the shape minimize --steps writes."""
    steps = ",\n".join(
        f'  Step.Type.Action {{ id = "s{i}", at_ms = {i * 100}, cpu = 1, memory_kb = 2048, sleep_ms = 500, '
        f'inputs = [] : List Text, detach = False, timeout_ms = None Natural, '
        f'weaker = Floors.Action::{{ sleep_ms = Some 0 }} }}'
        for i in range(n))
    return (f"let Step = {DHALL}/Step.dhall\nlet Floors = {DHALL}/Floors.dhall\n"
            f"let Scenario = {DHALL}/Scenario.dhall\n"
            f"in  Scenario.render\n[\n{steps}\n]\n")


def generated_scenario(n):
    """An authored witness: n steps built with Natural/fold, as a human would write it."""
    return (f"let Step = {DHALL}/Step.dhall\nlet Scenario = {DHALL}/Scenario.dhall\n"
            "let indexes = Natural/fold " + str(n) + " (List Natural) "
            "(λ(acc : List Natural) → [ List/length Natural acc ] # acc) ([] : List Natural)\n"
            "let steps = List/fold Natural indexes (List Step.Type) "
            "(λ(i : Natural) → λ(acc : List Step.Type) → "
            '[ Step.action ("s" ++ Natural/show i) (i * 100) 2048 500 ([] : List Text) ] # acc) '
            "([] : List Step.Type)\n"
            "in  Scenario.render steps\n")


def fleet(workers):
    """A fleet config render: one scheduler config and `workers` worker configs."""
    items = ",\n".join(f"  NativeLink.workerConfig rig state ports {i}" for i in range(workers))
    return (f"let Rig = {DHALL}/Rig.dhall\nlet NativeLink = {DHALL}/NativeLink.dhall\n"
            f"let rig = Rig::{{ workers = {workers} }}\n"
            'let state = "/tmp/rechaos/fleet"\n'
            "let ports = { port = 50090, worker_api_port = 50062, redis_port = 6379, proxy_port = 0 }\n"
            f"in  {{ server = NativeLink.serverConfig rig state ports, workers = [\n{items}\n] }}\n")


def inputs(workdir, step_sizes, worker_sizes):
    """(name, path, kind, size) for every input: repo files first, then generated."""
    out = []
    # Module files evaluate to records of types and functions: type-check only.
    for path in sorted(DHALL.glob("*.dhall")):
        out.append((str(path.relative_to(ROOT)), path, "module", None))
    for path in sorted((DHALL / "examples").glob("*.dhall")):
        out.append((str(path.relative_to(ROOT)), path, "repo", None))
    for n in step_sizes:
        p = workdir / f"literal-{n}.dhall"
        p.write_text(literal_scenario(n))
        out.append((f"literal scenario, {n} steps", p, "literal-steps", n))
        p = workdir / f"generated-{n}.dhall"
        p.write_text(generated_scenario(n))
        out.append((f"generated scenario, {n} steps", p, "generated-steps", n))
    for w in worker_sizes:
        p = workdir / f"fleet-{w}.dhall"
        p.write_text(fleet(w))
        out.append((f"fleet config, {w} workers", p, "fleet", w))
    trivial = workdir / "trivial.dhall"
    trivial.write_text("{=}\n")
    return trivial, out


# ---------------------------------------------------------------------------
# Measurement: one fresh process per sample, rusage from the child.
# ---------------------------------------------------------------------------
RUNNER = r'''
import json, resource, subprocess, sys, time
argv = json.loads(sys.argv[1])
t0 = time.monotonic()
proc = subprocess.run(argv, capture_output=True)
wall = time.monotonic() - t0
ru = resource.getrusage(resource.RUSAGE_CHILDREN)
sys.stdout.buffer.write(json.dumps({"wall": wall, "rss_kb": ru.ru_maxrss, "user": ru.ru_utime,
                                    "sys": ru.ru_stime, "code": proc.returncode,
                                    "stdout": proc.stdout.decode(errors="replace"),
                                    "stderr": proc.stderr.decode(errors="replace")[-2000:]}).encode())
'''


def sample(argv, timeout):
    try:
        out = subprocess.run([sys.executable, "-I", "-c", RUNNER, json.dumps(argv)], capture_output=True,
                             timeout=timeout, check=True)
    except subprocess.TimeoutExpired:
        return {"wall": None, "rss_kb": None, "code": None, "timeout": True, "stdout": "", "stderr": ""}
    return json.loads(out.stdout)


def measure(template, path, repeat, timeout):
    argv = [a.replace("{file}", str(path)) for a in shlex.split(template)]
    samples = [sample(argv, timeout) for _ in range(repeat)]
    ok = [s for s in samples if s.get("code") == 0]
    if not ok:
        first = samples[0]
        return {"status": "timeout" if first.get("timeout") else f"exit {first.get('code')}",
                "stderr": first.get("stderr", "")[-600:], "samples": len(samples)}
    return {"status": "ok", "samples": len(ok),
            "wall_median": statistics.median(s["wall"] for s in ok),
            "wall_min": min(s["wall"] for s in ok),
            "rss_kb_max": max(s["rss_kb"] for s in ok),
            "user": statistics.median(s["user"] for s in ok),
            "stdout": ok[0]["stdout"]}


def fmt(seconds):
    if seconds is None:
        return "-"
    return f"{seconds * 1000:.0f} ms" if seconds < 10 else f"{seconds:.1f} s"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--type-cmd", default="dhall type --quiet --file {file}",
                   help="type-check command template; {file} is the input")
    p.add_argument("--json-cmd", default="dhall-to-json --file {file}",
                   help="render-to-JSON command template; {file} is the input")
    p.add_argument("--label", default="reference", help="name of the implementation under test")
    p.add_argument("--reference-json-cmd", default="dhall-to-json --file {file}",
                   help="the reference renderer, for --compare")
    p.add_argument("--compare", action="store_true", help="require JSON equality with the reference on every input")
    p.add_argument("--repeat", type=int, default=5)
    p.add_argument("--timeout", type=float, default=300.0, help="seconds per sample before giving up")
    p.add_argument("--step-sizes", default=",".join(map(str, STEP_SIZES)))
    p.add_argument("--worker-sizes", default=",".join(map(str, WORKER_SIZES)))
    p.add_argument("--skip-type", action="store_true", help="measure only the JSON render")
    p.add_argument("--flake-gate", action="store_true",
                   help="also time `nix build --rebuild .#checks.<system>.dhall` (what CI pays)")
    p.add_argument("--output", default="runs/dhall-bench.json")
    args = p.parse_args()

    for tool in (shlex.split(args.type_cmd)[0], shlex.split(args.json_cmd)[0]):
        if not shutil.which(tool):
            sys.exit(f"{tool}: not on PATH (run inside `nix develop`, or pass --type-cmd/--json-cmd)")
    step_sizes = [int(x) for x in args.step_sizes.split(",") if x]
    worker_sizes = [int(x) for x in args.worker_sizes.split(",") if x]
    report = {"version": 1, "label": args.label, "type_cmd": args.type_cmd, "json_cmd": args.json_cmd,
              "repeat": args.repeat, "results": []}
    with tempfile.TemporaryDirectory(prefix="rechaos-dhall-bench-") as tmp:
        workdir = pathlib.Path(tmp)
        trivial, cases = inputs(workdir, step_sizes, worker_sizes)
        startup = measure(args.json_cmd, trivial, args.repeat, args.timeout)
        report["startup"] = startup
        log(f"[{args.label}] startup ({shlex.split(args.json_cmd)[0]} on {{=}}): {fmt(startup.get('wall_median'))}")
        for name, path, kind, size in cases:
            row = {"input": name, "kind": kind, "size": size}
            if not args.skip_type:
                row["type"] = measure(args.type_cmd, path, args.repeat, args.timeout)
                row["type"].pop("stdout", None)
            if kind == "module":
                row["json"] = {"status": "n/a"}
                rendered = None
            else:
                row["json"] = measure(args.json_cmd, path, args.repeat, args.timeout)
                rendered = row["json"].pop("stdout", None)
            if args.compare and row["json"]["status"] == "ok" and rendered is not None:
                ref = measure(args.reference_json_cmd, path, 1, args.timeout)
                same = ref["status"] == "ok" and json.loads(ref["stdout"]) == json.loads(rendered)
                row["json"]["equals_reference"] = same
                if not same:
                    log(f"  !! {name}: JSON differs from the reference")
            log(f"  {name}: type {fmt(row.get('type', {}).get('wall_median'))}, "
                f"json {fmt(row['json'].get('wall_median'))}"
                + (f", rss {row['json']['rss_kb_max'] // 1024} MB" if row["json"]["status"] == "ok" else
                   f" ({row['json']['status']})"))
            report["results"].append(row)
    if args.flake_gate:
        system = subprocess.run(["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"],
                                capture_output=True, text=True).stdout.strip() or "x86_64-linux"
        t0 = time.monotonic()
        gate = subprocess.run(["nix", "build", "--rebuild", "--no-link", f".#checks.{system}.dhall"],
                              capture_output=True, text=True, cwd=ROOT)
        report["flake_gate"] = {"wall": time.monotonic() - t0, "code": gate.returncode}
        log(f"[{args.label}] flake gate (rebuild): {fmt(report['flake_gate']['wall'])}")
    out = ROOT / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    # Human table on stdout: data, one row per input.
    print(f"| input | type | json | peak RSS |{' equal |' if args.compare else ''}")
    print(f"|---|---|---|---|{'---|' if args.compare else ''}")
    print(f"| startup ({{=}}) | - | {fmt(startup.get('wall_median'))} | "
          f"{(startup.get('rss_kb_max') or 0) // 1024} MB |{' |' if args.compare else ''}")
    for row in report["results"]:
        j = row["json"]
        cell = fmt(j.get("wall_median")) if j["status"] == "ok" else j["status"]
        rss = f"{j['rss_kb_max'] // 1024} MB" if j["status"] == "ok" else "-"
        if j["status"] == "n/a":
            cell = "-"
        t = row.get("type", {})
        tcell = fmt(t.get("wall_median")) if t.get("status") == "ok" else t.get("status", "-")
        eq = ("" if not args.compare else
              (" - |" if "equals_reference" not in j else (" yes |" if j["equals_reference"] else " NO |")))
        print(f"| {row['input']} | {tcell} | {cell} | {rss} |{eq}")
    if args.compare and any(not r["json"].get("equals_reference", True) for r in report["results"]):
        sys.exit("candidate output differs from the reference on at least one input")
    return 0


if __name__ == "__main__":
    sys.exit(main())
