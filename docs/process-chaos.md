# Process & network chaos: the durability / recovery adapter

`scripts/process_chaos.py` is the kill / pause / partition primitive that was
flagged as future work for rechaos. Every other fault injector in this tree
works **in the data path** &mdash; the `rechaos serve` gRPC gateway, the
`s3_fault_proxy.py` egress proxy, the `h2_fault_proxy.py` HTTP/2 proxy. This
adapter works **in the process path**: it stops, resumes, kills, restarts, and
crash-loops a process so a harness can verify that the system under test
actually *recovers* when a server vanishes mid-workload.

It is stdlib-only (`signal`, `subprocess`, `os`, `argparse`, `tc`/`iptables`
wrappers) and needs no `nix develop` shell &mdash; it does not speak REAPI and
has no third-party dependencies.

> **Scope: ISOLATED local targets only.** This tool is for a NativeLink / REAPI
> instance you launched yourself on this machine, a dummy process, or a pid you
> explicitly name. It is not a cluster tool and has no remote capability.

## Why this exists (what it breaks)

The gateway and proxies can tear reads, writes, and object-store egress, but
they can never answer *"what happens when the server process itself dies, hangs,
or gets partitioned, and does the client / supervisor recover?"* That is the
durability / recovery layer. `process_chaos.py` injects:

- **Pause / resume** (`SIGSTOP` / `SIGCONT`) &mdash; freeze the process so it is
  reachable on the socket but never scheduled. Models a GC pause, a `ptrace`
  stall, a hung thread, or CPU starvation. Deadline / keepalive handling on the
  client is what this stresses.
- **Kill + restart** (`SIGKILL` / `SIGTERM` then relaunch) &mdash; a crash
  followed by an operator or supervisor restart. The optional *down window* lets
  the harness observe the system during the outage before recovery.
- **Crash-at-interval** (`crash-loop`) &mdash; repeated crash + restart cycles
  while a workload runs concurrently, to check the client survives a flapping
  backend rather than just one clean restart.
- **Network faults on loopback** (`tc netem` latency / loss, `iptables` port
  partition) &mdash; degrade or sever the local socket. **Guarded** (see below).

## Safety rails

A chaos tool is only useful if you can trust it not to take down something it
was never asked to touch. The default posture is: **only act on a process this
tool launched.**

| Action | Allowed when |
| --- | --- |
| Signal a child this tool launched | always |
| Signal an arbitrary `--pid` | only with `--i-understand` **and** it passes the sanity screen |
| Network fault (latency/loss/partition) | only with `--i-understand`; otherwise a printed no-op |
| Signal pid &le; 1 (init / process group / invalid) | **never** |
| Signal our own pid or parent pid | **never** |
| Broad / pattern kill (`pkill -f`, kill by name) | **not implemented at all** |

Concretely:

- **No pattern kill.** Every signal goes to exactly one integer pid. There is no
  code path that matches process names or command lines, so the tool can never
  reap a bystander.
- **No process groups.** `pid <= 0` targets a group or every process; it is
  refused unconditionally before any `os.kill`.
- **Self / parent / init refused.** Signalling our own pid, our parent (which in
  a shell is typically the invoking shell), or pid 1 is always refused.
- **Arbitrary pid is gated.** `signal --pid N` requires `--i-understand`,
  confirms the pid exists (`signal 0` probe), and still applies every rule
  above. The flag is a deliberate acknowledgement that you are targeting
  something this tool did not spawn, on an isolated local box.
- **Network faults are opt-in no-ops.** Without `--i-understand` the `net-*`
  subcommands print the exact command they *would* run and change nothing. With
  the opt-in they additionally require the tool to be present on `PATH` and
  `euid == 0`, and they are **hard-pinned to the loopback device (`lo`)** &mdash;
  any other device is refused in the constructor. Importing `NetworkFaults` is
  always side-effect-free.

## Clock skew (deliberately out of scope)

Clock-skew injection is **intentionally not implemented** in this adapter. Run
`python3 scripts/process_chaos.py --clock-skew-note` for the full rationale. In
short: changing the host clock (`date -s`, `adjtimex`, `settimeofday`,
`libfaketime` on the host) is **global, non-isolated** state. It would move the
clock for every process on the box, including the rechaos harness and this
tool's own `time.monotonic()` / `sleep` timers, corrupting the very measurement
apparatus. rechaos targets isolated local targets only, so safe clock skew
belongs one layer down where the clock is actually isolated:

- a container / microVM skewed in its own namespace, or
- `FAKETIME=... LD_PRELOAD=libfaketime.so <target>` scoped to **only** the
  target process, or
- a time namespace (`unshare --time` / `CLONE_NEWTIME`) for the target.

## CLI

All subcommands that launch a process accept the command either as `-- argv...`
(preferred) or as a single shell-quoted `--cmd "..."` string.

```sh
# self-check: launch a dummy sleeper and run every owned-process primitive
python3 scripts/process_chaos.py demo

# launch, hold alive, clean stop
python3 scripts/process_chaos.py launch --hold 5 -- sleep 600

# SIGSTOP for 2s then SIGCONT (reports running -> paused -> running)
python3 scripts/process_chaos.py pause-resume --hold 2 -- sleep 30

# crash (SIGKILL) and relaunch, with a 1s down window
python3 scripts/process_chaos.py kill-restart --down 1 --cmd "sleep 30"

# crash-at-interval: 3 cycles, 5s uptime each
python3 scripts/process_chaos.py crash-loop --interval 5 --cycles 3 --cmd "sleep 30"

# signal a pid this tool did NOT launch (guarded)
python3 scripts/process_chaos.py signal --pid 12345 --sig STOP --i-understand

# loopback network faults (no-op without --i-understand; need root to apply)
python3 scripts/process_chaos.py net-latency --ms 100 --jitter 20 --i-understand
python3 scripts/process_chaos.py net-loss --percent 10 --i-understand
python3 scripts/process_chaos.py net-partition --port 50052 --i-understand
python3 scripts/process_chaos.py net-clear --i-understand

# why clock skew is not here
python3 scripts/process_chaos.py --clock-skew-note
```

Every subcommand prints a JSON report to stdout (the transition `history` is
included) and exits non-zero if the expected transitions were not observed, so
it drops cleanly into a CI check or a shell `&&` chain.

## Library API

A harness imports the module and drives faults around its own workload. The
`history` list is the recovery timeline to assert against; each entry records
`frm`/`to` states, the `action`, the `pid`, a monotonic + wall timestamp, and a
`detail` (exit code, signal name).

```python
import sys
sys.path.insert(0, "scripts")
from process_chaos import ManagedProcess, ProcessState, NetworkFaults

# Launch the isolated local target you want to fault-inject.
server = ManagedProcess(["my-reapi-server", "--port", "50052"])
server.start()

# ... start a workload against it in another thread ...

# Inject a pause mid-workload, then recover.
server.pause()                      # SIGSTOP  -> ProcessState.PAUSED
# ... assert the client sees a stall / deadline, not corruption ...
server.resume()                     # SIGCONT  -> ProcessState.RUNNING

# Crash and restart, holding the outage open for 2s.
server.kill_and_restart(down_s=2)   # SIGKILL, wait, relaunch (new pid)

# Or crash-loop while the workload runs.
server.crash_loop(interval_s=5, cycles=3)

server.stop()                       # SIGTERM -> (escalate SIGKILL) -> EXITED

for tr in server.history:
    print(tr.frm, "->", tr.to, tr.action, tr.pid, tr.detail)
```

`ManagedProcess` is also a context manager (`with ManagedProcess(cmd) as p:`)
that starts on entry and guarantees a clean stop on exit.

### States

`ProcessState` is the observable lifecycle: `NEW` (constructed, not started),
`RUNNING` (started or resumed), `PAUSED` (`SIGSTOP` delivered), `EXITED`
(terminated by any means). Reading `.state` refreshes against the OS, so a
process that died while we thought it was running is reported `EXITED`; `PAUSED`
is sticky because a stopped process does not report exit via `poll()`.

### Network faults from the library

```python
nf = NetworkFaults(i_understand=True)   # loopback only; refuses any other device
nf.latency(ms=100, jitter_ms=20)        # tc qdisc add dev lo root netem delay ...
nf.loss(percent=10)                     # tc qdisc add dev lo root netem loss ...
nf.partition(port=50052)                # iptables -A INPUT -i lo ... --dport ... DROP
nf.clear()                              # tc qdisc del dev lo root
nf.clear_partition(port=50052)          # remove the DROP rule
```

Each method returns a dict describing what it did or why it was skipped
(`{"skipped": true, "reason": "...", "would_run": "..."}`). Constructing
`NetworkFaults()` without `i_understand=True` yields a harness that only ever
describes commands, never runs them. Use `apply=False` for an explicit dry run.

## Validation performed

The module was validated end to end without touching NativeLink or any process
it did not spawn:

- `demo` launches a Python sleeper, pauses it, resumes it, kills + restarts it
  (new pid observed), and stops it &mdash; reporting every transition.
- The OS state was cross-checked against `/proc/<pid>/stat`: `R`/`S` while
  running, `T` (stopped) after `pause()`, `S` again after `resume()`.
- `pause-resume`, `kill-restart`, and `crash-loop` CLIs report the expected
  `running -> paused -> running`, pid-change-on-restart, and
  kills-per-cycle counts respectively.
- Safety rails: refusing a pid without `--i-understand`, refusing pid 1 even
  with the opt-in, refusing our own / parent pid, and the loopback network
  helpers no-op'ing without the opt-in (and skipping on non-root with it).
