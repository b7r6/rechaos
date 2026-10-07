#!/usr/bin/env python3
"""rechaos process / network chaos adapter: the durability & recovery layer.

This is the kill / pause / partition primitive that was flagged as future work
for rechaos. Everything else in the tree injects faults *in the data path*
(REAPI gRPC, S3/H2 proxies). This module injects faults in the *process* path:
it stops, resumes, kills, restarts, and crash-loops a process so a harness can
verify that the system under test actually *recovers* from a server vanishing
mid-workload.

It is deliberately conservative. The whole point of a chaos tool is that you
can trust it not to take down something it was never asked to touch, so the
default posture is: only act on a process THIS tool launched. The dangerous
modes (acting on a pid you did not launch; touching the network stack) are
gated behind an explicit ``--i-understand`` opt-in and are a no-op without it.

What it will NOT do, ever:

  * No broad ``pkill`` / pattern kill. Signals go to exactly one pid, which is
    either a child this process launched or a pid you named with ``--pid``.
  * No signalling pid 1, pid 0, negative pids (process groups), or our own pid
    / parent pid. These are refused unconditionally.
  * No network faults unless ``--i-understand`` is passed. Network helpers only
    ever touch the loopback interface and refuse any other device.

Safety rails (see ``docs/process-chaos.md`` for the full rationale):

  * Launched children are tracked; signalling one is always allowed.
  * Signalling an arbitrary ``--pid`` requires ``--i-understand`` AND passes a
    sanity screen (not self/parent/init, must exist, must be signalable).
  * Network faults (loopback latency / loss / partition via ``tc`` / iptables)
    require ``--i-understand`` and are otherwise no-ops that print what they
    *would* have done.

Clock skew: deliberately NOT implemented here. Changing the host clock
(``date -s`` / ``adjtimex`` / ``libfaketime``) is global, non-isolated state
that affects every process on the box, including the harness and this tool's
own timers. rechaos targets ISOLATED local targets only, so clock skew belongs
in a VM / container / namespace layer, not a process-signalling adapter. The
``--clock-skew-note`` flag prints this guidance and exits.

Library API (import and drive from a harness):

    from process_chaos import ManagedProcess, ProcessState, NetworkFaults

    proc = ManagedProcess(["my-server", "--flag"])
    proc.start()
    proc.pause(); ...; proc.resume()          # SIGSTOP / SIGCONT
    proc.kill_and_restart()                    # SIGKILL then relaunch
    proc.crash_loop(interval_s=5, cycles=3)    # crash-at-interval
    proc.stop()                                # clean teardown
    print(proc.history)                        # list[Transition]

CLI examples (stdlib only; no ``nix develop`` needed):

    # launch a sleeper, pause 1s, resume, then exit
    python3 scripts/process_chaos.py launch -- sleep 600
    python3 scripts/process_chaos.py demo                 # full self-check
    python3 scripts/process_chaos.py pause-resume --hold 1 -- sleep 30
    python3 scripts/process_chaos.py kill-restart --cmd "sleep 30"
    python3 scripts/process_chaos.py crash-loop --interval 2 --cycles 3 --cmd "sleep 30"

    # act on a pid you did NOT launch (guarded):
    python3 scripts/process_chaos.py signal --pid 12345 --sig STOP --i-understand

    # network faults on loopback (guarded; no-op without --i-understand):
    python3 scripts/process_chaos.py net-latency --ms 100 --i-understand
    python3 scripts/process_chaos.py net-clear --i-understand

    python3 scripts/process_chaos.py --clock-skew-note
"""
import argparse
import dataclasses
import enum
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
import typing as t

# ────────────────────────────────────────────────────────────────────────────
# State model
# ────────────────────────────────────────────────────────────────────────────


class ProcessState(enum.Enum):
    """Observable lifecycle state of a managed process."""

    NEW = "new"          # constructed, never started
    RUNNING = "running"  # started, scheduler-runnable (post-SIGCONT counts here)
    PAUSED = "paused"    # SIGSTOP delivered, not scheduled
    EXITED = "exited"    # terminated (clean, killed, or crashed)


@dataclasses.dataclass(frozen=True)
class Transition:
    """One observed state change, timestamped for a recovery timeline."""

    t_mono: float          # time.monotonic() at observation
    t_wall: float          # time.time() at observation
    frm: str               # prior state value
    to: str                # new state value
    action: str            # what caused it (start/pause/resume/kill/...)
    pid: t.Optional[int]   # pid involved, if any
    detail: str = ""       # free-form note (exit code, signal name, ...)

    def as_dict(self) -> dict:
        return dataclasses.asdict(self)


# ────────────────────────────────────────────────────────────────────────────
# Safety primitives
# ────────────────────────────────────────────────────────────────────────────


class ChaosSafetyError(RuntimeError):
    """Raised when a requested action is refused by a safety rail."""


# Signals this tool is willing to deliver, by friendly name.
_ALLOWED_SIGNALS: dict[str, int] = {
    "STOP": signal.SIGSTOP,
    "CONT": signal.SIGCONT,
    "TERM": signal.SIGTERM,
    "KILL": signal.SIGKILL,
    "INT": signal.SIGINT,
    "HUP": signal.SIGHUP,
}


def _pid_alive(pid: int) -> bool:
    """True if ``pid`` exists and is signalable by us (signal 0 probe)."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        # Exists but we may not own it; existence is what we report here.
        return True
    return True


def assert_pid_targetable(pid: int, *, owned: bool, i_understand: bool) -> None:
    """Refuse to signal dangerous or unauthorized pids.

    ``owned`` is True for processes this tool launched (always allowed).
    For any other pid, ``i_understand`` must be True and a sanity screen runs.
    """
    if pid is None or pid <= 1:
        # pid <= 0 targets process groups / everything; pid 1 is init.
        raise ChaosSafetyError(f"refusing to signal pid {pid!r} (init/group/invalid)")
    if pid == os.getpid():
        raise ChaosSafetyError("refusing to signal our own pid")
    if pid == os.getppid():
        raise ChaosSafetyError("refusing to signal our parent pid")
    if owned:
        return
    if not i_understand:
        raise ChaosSafetyError(
            f"refusing to signal pid {pid} that this tool did not launch; "
            "pass --i-understand to override for an ISOLATED local target")
    if not _pid_alive(pid):
        raise ChaosSafetyError(f"pid {pid} does not exist (nothing to signal)")


def resolve_signal(name: str) -> int:
    """Map a friendly signal name (STOP/CONT/TERM/KILL/...) to its number."""
    key = name.upper().removeprefix("SIG")
    if key not in _ALLOWED_SIGNALS:
        raise ChaosSafetyError(
            f"signal {name!r} not allowed; choose from {sorted(_ALLOWED_SIGNALS)}")
    return _ALLOWED_SIGNALS[key]


# ────────────────────────────────────────────────────────────────────────────
# Managed process
# ────────────────────────────────────────────────────────────────────────────


class ManagedProcess:
    """A single child process this tool owns and can safely fault-inject.

    The command is captured once so kill+restart relaunches an identical
    process. All state changes append to ``history`` (a list of Transition),
    which is the recovery timeline a harness asserts against.
    """

    def __init__(
        self,
        cmd: t.Sequence[str],
        *,
        env: t.Optional[dict] = None,
        cwd: t.Optional[str] = None,
        name: t.Optional[str] = None,
    ) -> None:
        if not cmd:
            raise ValueError("cmd must be a non-empty argv list")
        self.cmd: list[str] = list(cmd)
        self.env = env
        self.cwd = cwd
        self.name = name or self.cmd[0]
        self._proc: t.Optional[subprocess.Popen] = None
        self._state = ProcessState.NEW
        self.history: list[Transition] = []

    # -- introspection -------------------------------------------------------

    @property
    def pid(self) -> t.Optional[int]:
        return self._proc.pid if self._proc else None

    @property
    def state(self) -> ProcessState:
        """Current state, refreshed against the OS before reporting.

        A paused process whose underlying pid has died (e.g. killed by someone
        else) is reported as EXITED; otherwise PAUSED is sticky because a
        SIGSTOP'd process does not report exit via poll().
        """
        if self._proc is not None:
            if self._proc.poll() is not None:
                self._set_state(ProcessState.EXITED, "observe",
                                detail=f"exitcode={self._proc.returncode}")
        return self._state

    def _set_state(self, new: ProcessState, action: str, detail: str = "") -> None:
        if new is self._state:
            return
        self.history.append(Transition(
            t_mono=time.monotonic(), t_wall=time.time(),
            frm=self._state.value, to=new.value,
            action=action, pid=self.pid, detail=detail))
        self._state = new

    # -- lifecycle -----------------------------------------------------------

    def start(self) -> int:
        """Launch (or relaunch) the child. Returns the new pid."""
        if self._proc is not None and self._proc.poll() is None:
            raise ChaosSafetyError("process already running; stop it first")
        self._proc = subprocess.Popen(
            self.cmd, env=self.env, cwd=self.cwd,
            stdin=subprocess.DEVNULL)
        self._state = ProcessState.NEW  # reset so transition is recorded
        self._set_state(ProcessState.RUNNING, "start",
                        detail=f"cmd={shlex.join(self.cmd)}")
        return self._proc.pid

    def _signal(self, sig: int, action: str) -> None:
        if self._proc is None:
            raise ChaosSafetyError("no process to signal (not started)")
        pid = self._proc.pid
        assert_pid_targetable(pid, owned=True, i_understand=True)
        os.kill(pid, sig)

    def pause(self) -> None:
        """SIGSTOP: freeze the process (it stops being scheduled)."""
        self._signal(signal.SIGSTOP, "pause")
        self._set_state(ProcessState.PAUSED, "pause", detail="SIGSTOP")

    def resume(self) -> None:
        """SIGCONT: unfreeze a previously paused process."""
        self._signal(signal.SIGCONT, "resume")
        self._set_state(ProcessState.RUNNING, "resume", detail="SIGCONT")

    def terminate(self, *, timeout_s: float = 5.0) -> t.Optional[int]:
        """SIGTERM then, if it lingers, SIGKILL. Returns exit code."""
        if self._proc is None or self._proc.poll() is not None:
            self._set_state(ProcessState.EXITED, "terminate", detail="already gone")
            return self._proc.returncode if self._proc else None
        # A stopped process won't react to SIGTERM until continued.
        if self._state is ProcessState.PAUSED:
            self._signal(signal.SIGCONT, "resume")
        self._signal(signal.SIGTERM, "terminate")
        code = self._wait(timeout_s)
        if code is None:
            self._signal(signal.SIGKILL, "kill")
            code = self._wait(timeout_s)
        self._set_state(ProcessState.EXITED, "terminate", detail=f"exitcode={code}")
        return code

    def kill(self, *, timeout_s: float = 5.0) -> t.Optional[int]:
        """SIGKILL: hard, unclean termination (simulates a crash)."""
        if self._proc is None or self._proc.poll() is not None:
            self._set_state(ProcessState.EXITED, "kill", detail="already gone")
            return self._proc.returncode if self._proc else None
        if self._state is ProcessState.PAUSED:
            self._signal(signal.SIGCONT, "resume")
        self._signal(signal.SIGKILL, "kill")
        code = self._wait(timeout_s)
        self._set_state(ProcessState.EXITED, "kill", detail=f"exitcode={code}")
        return code

    def _wait(self, timeout_s: float) -> t.Optional[int]:
        try:
            return self._proc.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            return None

    def kill_and_restart(
        self, *, down_s: float = 0.0, timeout_s: float = 5.0) -> int:
        """Crash (SIGKILL) then relaunch after ``down_s`` seconds down.

        Models an operator / supervisor restart after a crash. Returns the new
        pid. The down window lets a harness observe the system during outage.
        """
        self.kill(timeout_s=timeout_s)
        if down_s > 0:
            time.sleep(down_s)
        return self.start()

    def crash_loop(
        self, *, interval_s: float, cycles: int,
        down_s: float = 0.0, timeout_s: float = 5.0) -> int:
        """Crash-at-interval: run ``cycles`` of (up for interval, SIGKILL, restart).

        Returns the pid of the final live process. A harness drives a workload
        concurrently and checks it survives repeated backend crashes.
        """
        if cycles < 1:
            raise ValueError("cycles must be >= 1")
        if self._proc is None or self._proc.poll() is not None:
            self.start()
        for i in range(cycles):
            time.sleep(interval_s)
            self.kill(timeout_s=timeout_s)
            if down_s > 0:
                time.sleep(down_s)
            self.start()
        return self._proc.pid

    def stop(self, *, timeout_s: float = 5.0) -> t.Optional[int]:
        """Clean teardown (SIGTERM escalating to SIGKILL). Idempotent."""
        return self.terminate(timeout_s=timeout_s)

    def __enter__(self) -> "ManagedProcess":
        if self._proc is None:
            self.start()
        return self

    def __exit__(self, *exc) -> None:
        self.stop()


# ────────────────────────────────────────────────────────────────────────────
# External pid faults (guarded)
# ────────────────────────────────────────────────────────────────────────────


def signal_external_pid(pid: int, sig_name: str, *, i_understand: bool) -> None:
    """Deliver one signal to a pid this tool did not launch. Guarded.

    Requires ``i_understand`` and passes the same sanity screen as owned pids
    minus the ownership exemption. Never touches process groups or init.
    """
    assert_pid_targetable(pid, owned=False, i_understand=i_understand)
    os.kill(pid, resolve_signal(sig_name))


# ────────────────────────────────────────────────────────────────────────────
# Network faults (loopback only, guarded)
# ────────────────────────────────────────────────────────────────────────────

_LOOPBACK = "lo"


class NetworkFaults:
    """Loopback-only network fault helpers via ``tc`` / iptables wrappers.

    Every method is a NO-OP unless ``i_understand`` is True, in which case it
    prints the command it *would* run and returns without touching anything.
    All operations are hard-pinned to the loopback device (``lo``); any other
    device is refused. Requires root to actually apply (checked, not assumed).

    This class never shells out to a mutating command unless ``i_understand``
    is set AND ``apply`` is True, so importing it is always side-effect-free.
    """

    def __init__(self, *, i_understand: bool = False, device: str = _LOOPBACK,
                 apply: bool = True) -> None:
        if device != _LOOPBACK:
            raise ChaosSafetyError(
                f"network faults are loopback-only; refusing device {device!r}")
        self.i_understand = i_understand
        self.device = device
        self.apply = apply

    def _run(self, argv: list[str]) -> dict:
        """Execute (or describe) a privileged command under the opt-in gate."""
        line = shlex.join(argv)
        if not self.i_understand:
            return {"skipped": True, "reason": "no --i-understand opt-in",
                    "would_run": line}
        tool = argv[0]
        if shutil.which(tool) is None:
            return {"skipped": True, "reason": f"{tool} not found on PATH",
                    "would_run": line}
        if os.geteuid() != 0:
            return {"skipped": True, "reason": "requires root (euid != 0)",
                    "would_run": line}
        if not self.apply:
            return {"skipped": True, "reason": "apply=False (dry run)",
                    "would_run": line}
        res = subprocess.run(argv, capture_output=True, text=True)
        return {"skipped": False, "ran": line, "rc": res.returncode,
                "stdout": res.stdout.strip(), "stderr": res.stderr.strip()}

    def latency(self, ms: int, jitter_ms: int = 0) -> dict:
        """Add fixed (+jitter) egress delay on loopback via ``tc netem``."""
        spec = ["tc", "qdisc", "add", "dev", self.device, "root", "netem",
                "delay", f"{ms}ms"]
        if jitter_ms:
            spec.append(f"{jitter_ms}ms")
        return self._run(spec)

    def loss(self, percent: float) -> dict:
        """Drop ``percent`` of loopback packets via ``tc netem loss``."""
        return self._run(["tc", "qdisc", "add", "dev", self.device, "root",
                           "netem", "loss", f"{percent}%"])

    def partition(self, port: int) -> dict:
        """Partition a loopback TCP port by DROPping its packets via iptables.

        Targets only loopback traffic to the named port. This models a network
        partition to a locally-bound service without affecting other sockets.
        """
        return self._run(["iptables", "-A", "INPUT", "-i", self.device,
                           "-p", "tcp", "--dport", str(port), "-j", "DROP"])

    def clear(self) -> dict:
        """Remove any tc netem qdisc installed on loopback (best effort)."""
        return self._run(["tc", "qdisc", "del", "dev", self.device, "root"])

    def clear_partition(self, port: int) -> dict:
        """Remove the loopback-port DROP rule installed by ``partition``."""
        return self._run(["iptables", "-D", "INPUT", "-i", self.device,
                           "-p", "tcp", "--dport", str(port), "-j", "DROP"])


# ────────────────────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────────────────────

_CLOCK_SKEW_NOTE = """\
clock-skew is intentionally NOT implemented in process_chaos.py.

Skewing the host clock (date -s / adjtimex / settimeofday / libfaketime) is
GLOBAL, non-isolated state. It affects every process on the machine, including
the rechaos harness, this tool's own time.monotonic()/sleep timers, TLS cert
validity, and any co-located service. rechaos targets ISOLATED local targets
only, so a safe clock-skew injection belongs one layer down, where the clock is
actually isolated:

  * run the target in a container / microVM and skew only that namespace, or
  * preload libfaketime into ONLY the target process:
      FAKETIME="+10m" LD_PRELOAD=/path/libfaketime.so <target>
    (per-process, does not move the host clock), or
  * use a time namespace (CLONE_NEWTIME / unshare --time) for the target.

Injecting skew from here would corrupt the measurement apparatus itself, so it
is deliberately out of scope for this process/network adapter.
"""


def _emit(obj: dict) -> None:
    print(json.dumps(obj, indent=2, sort_keys=True))


def _history_json(proc: ManagedProcess) -> list[dict]:
    return [tr.as_dict() for tr in proc.history]


def _split_cmd(args: argparse.Namespace) -> list[str]:
    """Resolve a command from either ``-- argv...`` or ``--cmd "str"``."""
    if getattr(args, "argv", None):
        argv = list(args.argv)
        if argv and argv[0] == "--":
            argv = argv[1:]
        if argv:
            return argv
    if getattr(args, "cmd", None):
        return shlex.split(args.cmd)
    raise SystemExit("no command given; use --cmd \"...\" or -- argv...")


def cmd_launch(args: argparse.Namespace) -> int:
    proc = ManagedProcess(_split_cmd(args))
    proc.start()
    print(f"launched pid={proc.pid} state={proc.state.value} "
          f"cmd={shlex.join(proc.cmd)}", file=sys.stderr)
    if args.hold > 0:
        time.sleep(args.hold)
    code = proc.stop()
    _emit({"pid_was": proc.history[0].pid, "final_state": proc.state.value,
           "exit_code": code, "history": _history_json(proc)})
    return 0


def cmd_pause_resume(args: argparse.Namespace) -> int:
    proc = ManagedProcess(_split_cmd(args))
    proc.start()
    s0 = proc.state.value
    proc.pause()
    s1 = proc.state.value
    time.sleep(args.hold)
    proc.resume()
    s2 = proc.state.value
    proc.stop()
    _emit({"states": [s0, s1, s2], "final_state": proc.state.value,
           "history": _history_json(proc)})
    return 0 if [s0, s1, s2] == ["running", "paused", "running"] else 1


def cmd_kill_restart(args: argparse.Namespace) -> int:
    proc = ManagedProcess(_split_cmd(args))
    proc.start()
    pid0 = proc.pid
    proc.kill_and_restart(down_s=args.down)
    pid1 = proc.pid
    proc.stop()
    recovered = pid0 != pid1 and pid1 is not None
    _emit({"pid_before": pid0, "pid_after": pid1, "recovered": recovered,
           "history": _history_json(proc)})
    return 0 if recovered else 1


def cmd_crash_loop(args: argparse.Namespace) -> int:
    proc = ManagedProcess(_split_cmd(args))
    proc.start()
    proc.crash_loop(interval_s=args.interval, cycles=args.cycles, down_s=args.down)
    proc.stop()
    kills = sum(1 for tr in proc.history if tr.action == "kill")
    starts = sum(1 for tr in proc.history if tr.action == "start")
    _emit({"cycles": args.cycles, "kills_observed": kills,
           "starts_observed": starts, "history": _history_json(proc)})
    return 0 if kills >= args.cycles else 1


def cmd_signal(args: argparse.Namespace) -> int:
    try:
        signal_external_pid(args.pid, args.sig, i_understand=args.i_understand)
    except ChaosSafetyError as exc:
        _emit({"ok": False, "error": str(exc)})
        return 2
    _emit({"ok": True, "pid": args.pid, "signal": args.sig.upper()})
    return 0


def _net_cmd(args: argparse.Namespace, fn) -> int:
    nf = NetworkFaults(i_understand=args.i_understand, apply=not args.dry_run)
    result = fn(nf)
    _emit(result)
    return 0


def cmd_net_latency(args):
    return _net_cmd(args, lambda nf: nf.latency(args.ms, args.jitter))


def cmd_net_loss(args):
    return _net_cmd(args, lambda nf: nf.loss(args.percent))


def cmd_net_partition(args):
    return _net_cmd(args, lambda nf: nf.partition(args.port))


def cmd_net_clear(args):
    return _net_cmd(args, lambda nf: nf.clear())


def cmd_demo(args: argparse.Namespace) -> int:
    """Self-check: launch a sleeper, exercise every owned-process primitive."""
    sleeper = [sys.executable, "-c", "import time; time.sleep(600)"]
    proc = ManagedProcess(sleeper, name="demo-sleeper")
    steps: list[dict] = []

    pid0 = proc.start()
    steps.append({"step": "start", "pid": pid0, "state": proc.state.value})

    proc.pause()
    steps.append({"step": "pause", "pid": proc.pid, "state": proc.state.value})
    time.sleep(0.2)

    proc.resume()
    steps.append({"step": "resume", "pid": proc.pid, "state": proc.state.value})
    time.sleep(0.2)

    proc.kill_and_restart(down_s=0.2)
    pid1 = proc.pid
    steps.append({"step": "kill_and_restart", "pid": pid1,
                  "state": proc.state.value, "pid_changed": pid0 != pid1})

    code = proc.stop()
    steps.append({"step": "stop", "exit_code": code, "state": proc.state.value})

    ok = (pid0 is not None and pid1 is not None and pid0 != pid1
          and proc.state is ProcessState.EXITED)
    _emit({"ok": ok, "steps": steps, "history": _history_json(proc)})
    return 0 if ok else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="process_chaos.py",
        description="rechaos process/network chaos adapter (ISOLATED local "
                    "targets only).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)
    p.add_argument("--clock-skew-note", action="store_true",
                   help="print why clock-skew is out of scope here, then exit")
    sub = p.add_subparsers(dest="command")

    def add_cmd_source(sp):
        sp.add_argument("--cmd", help="command to launch, as one shell-quoted string")
        sp.add_argument("argv", nargs=argparse.REMAINDER,
                        help="command after -- (preferred over --cmd)")

    sp = sub.add_parser("launch", help="launch a child, optionally hold, then stop")
    add_cmd_source(sp)
    sp.add_argument("--hold", type=float, default=0.0,
                    help="seconds to keep the child alive before stopping")
    sp.set_defaults(func=cmd_launch)

    sp = sub.add_parser("pause-resume", help="SIGSTOP then SIGCONT a launched child")
    add_cmd_source(sp)
    sp.add_argument("--hold", type=float, default=1.0,
                    help="seconds to stay paused")
    sp.set_defaults(func=cmd_pause_resume)

    sp = sub.add_parser("kill-restart", help="SIGKILL a launched child, relaunch it")
    add_cmd_source(sp)
    sp.add_argument("--down", type=float, default=0.0,
                    help="seconds down between kill and restart")
    sp.set_defaults(func=cmd_kill_restart)

    sp = sub.add_parser("crash-loop", help="crash-at-interval against a launched child")
    add_cmd_source(sp)
    sp.add_argument("--interval", type=float, required=True,
                    help="seconds of uptime between crashes")
    sp.add_argument("--cycles", type=int, required=True,
                    help="number of crash+restart cycles")
    sp.add_argument("--down", type=float, default=0.0,
                    help="seconds down between kill and restart")
    sp.set_defaults(func=cmd_crash_loop)

    sp = sub.add_parser("signal",
                        help="signal a pid you did NOT launch (requires --i-understand)")
    sp.add_argument("--pid", type=int, required=True, help="target pid")
    sp.add_argument("--sig", default="TERM",
                    help="signal name: STOP/CONT/TERM/KILL/INT/HUP")
    sp.add_argument("--i-understand", action="store_true", dest="i_understand",
                    help="acknowledge this targets a pid this tool did not launch")
    sp.set_defaults(func=cmd_signal)

    def add_net_opts(sp):
        sp.add_argument("--i-understand", action="store_true", dest="i_understand",
                        help="opt in; without this the command is a no-op")
        sp.add_argument("--dry-run", action="store_true",
                        help="never apply, only print the command that would run")

    sp = sub.add_parser("net-latency", help="loopback egress latency via tc netem")
    sp.add_argument("--ms", type=int, required=True, help="delay in milliseconds")
    sp.add_argument("--jitter", type=int, default=0, help="jitter in milliseconds")
    add_net_opts(sp)
    sp.set_defaults(func=cmd_net_latency)

    sp = sub.add_parser("net-loss", help="loopback packet loss via tc netem")
    sp.add_argument("--percent", type=float, required=True, help="loss percent")
    add_net_opts(sp)
    sp.set_defaults(func=cmd_net_loss)

    sp = sub.add_parser("net-partition",
                        help="DROP a loopback TCP port via iptables")
    sp.add_argument("--port", type=int, required=True, help="loopback TCP port")
    add_net_opts(sp)
    sp.set_defaults(func=cmd_net_partition)

    sp = sub.add_parser("net-clear", help="remove loopback tc netem qdisc")
    add_net_opts(sp)
    sp.set_defaults(func=cmd_net_clear)

    sp = sub.add_parser("demo", help="self-check: full lifecycle on a dummy sleeper")
    sp.set_defaults(func=cmd_demo)

    return p


def main(argv: t.Optional[list[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.clock_skew_note:
        print(_CLOCK_SKEW_NOTE)
        return 0
    if not getattr(args, "func", None):
        parser.print_help()
        return 0
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
