#!/usr/bin/env python3
"""rechaos consistency oracle: model-based, HISTORY-level correctness checking.

The chaos monkey asserts *point* invariants (this read was torn, this upload
leaked). Those miss the subtle NativeLink failures that only appear across a
*concurrent history*: cross-node read-after-write divergence, stale reads after a
newer write has completed, partial-publication where a blob is readable on one
path and missing on another. This module records a concurrent operation history
and checks it against a formal model of correct content-addressed storage.

Modelled operations (each carries invocation + response timestamps and an
outcome):

  write(key, value)            CAS/ByteStream upload, or AC update
  read(key) -> value | MISSING CAS/ByteStream read, or AC get
  find_missing(key) -> present | missing   ContentAddressableStorage.FindMissingBlobs

Every key is treated as a *single register*:

  * For CAS/ByteStream, the register key is the digest "sha256:HEX/SIZE". The only
    value content-addressing permits under that key is the preimage that hashes to
    the digest, so the register is effectively write-once with a fixed legal value.
  * For the Action Cache, the register key is the action digest; its value is the
    ActionResult. AC is a mutable last-writer-wins register, which is exactly the
    object a per-key linearizability check models.

The model enforces three properties (see docs/consistency-oracle.md for the full
treatment):

  C1  Content-addressing: a successful read of a CAS digest D returns bytes that
      hash to D. (Checked structurally on every CAS/BS read outcome.)
  C2  Monotone availability: once any write of key K has *completed*, every later
      operation that *began after* that completion must observe K as present
      (read != MISSING, find_missing == present) -- unless an eviction is
      explicitly modelled for K in the interim.
  C3  Linearizability of the per-key register: the sub-history for each key must
      have a sequential witness -- a total order consistent with real-time
      (non-overlapping ops keep their order) in which every read returns the value
      of the most recent preceding write (or the MISSING sentinel if none). This
      is the property that catches a stale read served *after* a newer write has
      already been acknowledged.

C3 is decided with a Wing & Gong style backtracking linearization (sweep over the
history picking a linearizable op to "commit" next, undo on dead-end). Because
each key is an independent register the per-key histories are short and the search
is tractable; we also add the standard pruning (only minimal ops -- those with no
other op that must precede them -- are candidates).

This file is BOTH a library and a CLI:

  * Library: build an ``Oracle``, call ``record_*`` from concurrent workers
    (thread-safe), then ``check()`` -> list[Violation]. The chaos monkey can
    embed this directly.
  * CLI: ``consistency_oracle.py check HISTORY.jsonl`` checks a recorded history
    and prints precise violation witnesses; ``self-test`` runs the built-in unit
    tests; ``record-live`` records a tiny real history off a REAPI endpoint to
    sanity-check the recorder.

History JSONL format (one self-contained JSON object per line)::

  {"op":"write","key":"sha256:ab..f/11","value_hash":"ab..f","size":11,
   "inv":0.001,"res":0.004,"outcome":"ok","worker":"w0"}
  {"op":"read","key":"sha256:ab..f/11","inv":0.005,"res":0.007,
   "outcome":"ok","value_hash":"ab..f","size":11,"worker":"w1"}
  {"op":"read","key":"sha256:ab..f/11","inv":0.001,"res":0.002,"outcome":"missing"}
  {"op":"find_missing","key":"sha256:ab..f/11","inv":0.0,"res":0.0,"outcome":"present"}
  {"op":"evict","key":"sha256:ab..f/11","inv":9.0,"res":9.0}

Timestamps ``inv`` (invocation) and ``res`` (response) are floats in a single
monotonic clock (seconds); only their ordering matters. ``value_hash`` is the
SHA-256 hex of the bytes actually returned/written; storing the hash instead of
the bytes keeps histories small while preserving every equality the checks need.
"""
from __future__ import annotations

import argparse
import dataclasses
import hashlib
import itertools
import json
import math
import pathlib
import sys
import threading
import time
from typing import Dict, List, Optional

# --------------------------------------------------------------------------- #
# Outcomes / op kinds
# --------------------------------------------------------------------------- #
WRITE = "write"
READ = "read"
FIND_MISSING = "find_missing"
EVICT = "evict"

OK = "ok"
MISSING = "missing"       # read returned not-found
PRESENT = "present"       # find_missing says present
ABSENT = "absent"         # find_missing says missing
ERROR = "error"           # op failed with a transport/server error (inconclusive)

# MISSING is represented in the register-value domain by this sentinel so the
# linearization can treat "the register currently holds nothing" uniformly.
EMPTY = "∅"          # the empty set symbol; never a real value hash
EMPTY_HASH = hashlib.sha256(b"").hexdigest()
EMPTY_KEY = f"sha256:{EMPTY_HASH}/0"


# --------------------------------------------------------------------------- #
# Event model
# --------------------------------------------------------------------------- #
@dataclasses.dataclass
class Event:
    """One recorded operation with real-time invocation/response bounds.

    ``value`` holds the value in the register domain:
      * write: the value_hash being written (the legal preimage hash for CAS).
      * read ok: the value_hash returned.
      * read missing: EMPTY.
      * find_missing: EMPTY (it probes availability, not value).
    """
    op: str
    key: str
    inv: float
    res: float
    outcome: str
    value: str = EMPTY          # value_hash or EMPTY
    size: Optional[int] = None
    worker: Optional[str] = None
    seq: int = 0                # stable insertion order, tie-breaks equal stamps

    def __post_init__(self):
        outcomes = {WRITE: {OK, ERROR}, READ: {OK, MISSING, ERROR},
                    FIND_MISSING: {PRESENT, ABSENT, ERROR}, EVICT: {OK}}
        if self.op not in outcomes or self.outcome not in outcomes[self.op]:
            raise ValueError(f"invalid operation/outcome: {self.op}/{self.outcome}")
        if not isinstance(self.key, str) or not self.key:
            raise ValueError("history key must be a nonempty string")
        if self.key.startswith("sha256:"):
            hash_part, slash, size_part = self.key[7:].partition("/")
            if (len(hash_part) != 64 or any(c not in "0123456789abcdef" for c in hash_part)
                    or not slash or not size_part.isascii() or not size_part.isdigit()):
                raise ValueError("CAS key must be sha256:LOWERCASE_HEX/SIZE")
        if not all(math.isfinite(t) for t in (self.inv, self.res)) or self.inv > self.res:
            raise ValueError("history timestamps must be finite with inv <= res")
        if self.op == EVICT and self.inv != self.res:
            raise ValueError("eviction must be an instant")
        if self.size is not None and (type(self.size) is not int or self.size < 0):
            raise ValueError("size must be a nonnegative integer")
        if self.op in (READ, WRITE) and self.outcome == OK and (
                not isinstance(self.value, str) or not self.value or self.value == EMPTY):
            raise ValueError("successful reads and writes require a value_hash")

    # ---- serialization -------------------------------------------------- #
    def to_json(self) -> dict:
        d = {"op": self.op, "key": self.key, "inv": self.inv, "res": self.res,
             "outcome": self.outcome}
        if self.value != EMPTY:
            d["value_hash"] = self.value
        if self.size is not None:
            d["size"] = self.size
        if self.worker is not None:
            d["worker"] = self.worker
        return d

    @staticmethod
    def from_json(d: dict, seq: int) -> "Event":
        op = d["op"]
        outcome = d.get("outcome", OK)
        value = d.get("value_hash", EMPTY)
        # find_missing / read-missing / evict never carry a value in the register.
        if op in (FIND_MISSING, EVICT) or (op == READ and outcome == MISSING):
            value = EMPTY
        return Event(op=op, key=d["key"], inv=float(d["inv"]), res=float(d["res"]),
                     outcome=outcome, value=value, size=d.get("size"),
                     worker=d.get("worker"), seq=seq)


@dataclasses.dataclass
class Violation:
    """A precise, self-describing counterexample."""
    kind: str                       # "content-addressing" | "monotone-availability" | "linearizability"
    key: str
    message: str
    witnesses: List[dict]           # the offending events, JSON-serializable

    def to_json(self) -> dict:
        return {"kind": self.kind, "key": self.key, "message": self.message,
                "witnesses": self.witnesses}

    def __str__(self) -> str:
        head = f"[{self.kind}] key={self.key}: {self.message}"
        body = "\n".join("    witness: " + json.dumps(w, sort_keys=True) for w in self.witnesses)
        return head + ("\n" + body if body else "")


# --------------------------------------------------------------------------- #
# Oracle: recorder + checker
# --------------------------------------------------------------------------- #
class Oracle:
    """Thread-safe recorder of a concurrent history plus the model checker.

    Usage from the chaos monkey::

        oracle = Oracle(clock=time.monotonic)
        with oracle.op(READ, key) as rec:          # captures inv/res around the call
            data = do_read(...)
            rec(outcome=OK, value_hash=sha256hex(data), size=len(data))
        ...
        violations = oracle.check()
    """

    def __init__(self, clock=time.monotonic):
        self._clock = clock
        self._events: List[Event] = []
        self._lock = threading.Lock()
        self._seq = itertools.count()

    # ---- recording ------------------------------------------------------ #
    def _add(self, ev: Event) -> Event:
        with self._lock:
            ev.seq = next(self._seq)
            self._events.append(ev)
        return ev

    def record(self, op: str, key: str, inv: float, res: float, outcome: str,
               value_hash: str = EMPTY, size: Optional[int] = None,
               worker: Optional[str] = None) -> Event:
        """Record a fully-specified, already-timed event."""
        return self._add(Event(op=op, key=key, inv=inv, res=res, outcome=outcome,
                               value=value_hash, size=size, worker=worker))

    def op(self, op: str, key: str, worker: Optional[str] = None):
        """Context manager timing a real operation.

        Inside the block call the returned callback with the result::

            with oracle.op(WRITE, key, worker="w0") as rec:
                upload(bytes)
                rec(outcome=OK, value_hash=h, size=n)
        """
        return _OpRecorder(self, op, key, worker)

    # convenience wrappers mirroring the monkey's REAPI verbs ------------- #
    def record_write(self, key, inv, res, value_hash, size=None, worker=None, outcome=OK):
        return self.record(WRITE, key, inv, res, outcome, value_hash, size, worker)

    def record_read(self, key, inv, res, outcome, value_hash=EMPTY, size=None, worker=None):
        return self.record(READ, key, inv, res, outcome, value_hash, size, worker)

    def record_find_missing(self, key, inv, res, outcome, worker=None):
        return self.record(FIND_MISSING, key, inv, res, outcome, worker=worker)

    def record_evict(self, key, at, worker=None):
        return self.record(EVICT, key, at, at, OK, worker=worker)

    def events(self) -> List[Event]:
        with self._lock:
            return list(self._events)

    # ---- persistence ---------------------------------------------------- #
    def dump(self, path) -> None:
        with open(path, "w", encoding="utf-8") as fh:
            for ev in self.events():
                fh.write(json.dumps(ev.to_json(), sort_keys=True) + "\n")

    @staticmethod
    def load(path) -> "Oracle":
        oracle = Oracle()
        evs = []
        for i, line in enumerate(_read_lines(path)):
            line = line.strip()
            if not line:
                continue
            evs.append(Event.from_json(json.loads(line), seq=i))
        oracle._events = evs
        oracle._seq = itertools.count(len(evs))
        return oracle

    # ---- checking ------------------------------------------------------- #
    def check(self, key_legal_value=None) -> List[Violation]:
        """Run all model checks, returning every violation found.

        ``key_legal_value`` optionally maps a CAS key -> the single value_hash
        that content-addressing permits for it (normally the key's own digest
        hash). When omitted it is derived from the key string ("sha256:HEX/SIZE"
        -> HEX), which is exactly the content-addressing rule for CAS/ByteStream.
        AC keys (which do not encode their value) are simply skipped by C1.
        """
        evs = self.events()
        if any(e.op == WRITE and e.outcome == ERROR for e in evs):
            raise ValueError("unresolved failed writes may have committed; resolve their outcomes before checking")
        violations: List[Violation] = []
        violations += check_content_addressing(evs, key_legal_value)
        by_key: Dict[str, List[Event]] = {}
        for ev in evs:
            by_key.setdefault(ev.key, []).append(ev)
        for key, kevs in by_key.items():
            violations += check_monotone_availability(key, kevs)
            violations += check_linearizability(key, kevs)
        return violations


class _OpRecorder:
    def __init__(self, oracle: Oracle, op: str, key: str, worker: Optional[str]):
        self._oracle, self._op, self._key, self._worker = oracle, op, key, worker
        self._result = None

    def __enter__(self):
        self._inv = self._oracle._clock()

        def record_result(outcome=OK, value_hash=EMPTY, size=None):
            self._result = (outcome, value_hash, size)
        return record_result

    def __exit__(self, exc_type, exc, tb):
        res = self._oracle._clock()
        if exc_type is not None and self._result is None:
            self._result = (ERROR, EMPTY, None)
        outcome, value_hash, size = self._result or (ERROR, EMPTY, None)
        self._oracle.record(self._op, self._key, self._inv, res, outcome,
                            value_hash, size, self._worker)
        return False  # never swallow exceptions


# --------------------------------------------------------------------------- #
# C1: content-addressing
# --------------------------------------------------------------------------- #
def _legal_value_for_key(key: str) -> Optional[str]:
    """For a CAS/ByteStream key "sha256:HEX/SIZE", the only legal value is HEX.

    Returns None for keys that do not encode a content hash (e.g. AC keys), which
    means content-addressing is not applicable and C1 is skipped for them.
    """
    if key.startswith("sha256:"):
        rest = key[len("sha256:"):]
        h = rest.split("/", 1)[0]
        if len(h) == 64 and all(c in "0123456789abcdef" for c in h.lower()):
            return h.lower()
    return None


def check_content_addressing(events: List[Event],
                             key_legal_value=None) -> List[Violation]:
    """C1: every successful CAS read returns bytes whose hash equals the digest.

    A read recorded with outcome==ok on a content-addressed key must carry a
    value_hash equal to the key's digest. We also verify writes: a write of a CAS
    key must claim the key's own digest (a write under the wrong name is itself a
    content-addressing bug in the driver or the server's accept path).
    """
    out: List[Violation] = []
    for ev in events:
        if ev.op not in (READ, WRITE):
            continue
        legal = None
        if key_legal_value is not None:
            legal = key_legal_value.get(ev.key)
        if legal is None:
            legal = _legal_value_for_key(ev.key)
        if legal is None:
            continue  # not content-addressed; C1 N/A
        if ev.outcome == OK and ev.size is not None and ev.key.startswith("sha256:"):
            try:
                expected_size = int(ev.key.split("/", 1)[1])
            except (ValueError, IndexError):
                raise ValueError(f"invalid CAS key: {ev.key}") from None
            if ev.size != expected_size:
                out.append(Violation("content-addressing", ev.key,
                                     f"reported size {ev.size} differs from digest size {expected_size}",
                                     [ev.to_json()]))
        if ev.op == READ and ev.outcome == OK:
            if ev.value != legal:
                out.append(Violation(
                    "content-addressing", ev.key,
                    f"OK read returned bytes hashing to {ev.value!r} but the "
                    f"digest requires {legal!r}",
                    [ev.to_json()]))
        elif ev.op == WRITE and ev.outcome == OK:
            if ev.value != EMPTY and ev.value != legal:
                out.append(Violation(
                    "content-addressing", ev.key,
                    f"write committed value hashing to {ev.value!r} under a "
                    f"digest that requires {legal!r}",
                    [ev.to_json()]))
    return out


# --------------------------------------------------------------------------- #
# C2: monotone availability
# --------------------------------------------------------------------------- #
def check_monotone_availability(key: str, events: List[Event]) -> List[Violation]:
    """C2: once a write completes, later-starting ops must observe K present.

    For a completed write W and observation O with W.res < O.inv, presence
    is forced if no eviction overlaps W or occurs before O completes. An
    eviction after O starts may explain an absent result. A subsequent write
    restores the obligation. O must then observe K present:
        read  -> outcome != missing
        find_missing -> outcome != absent
    A violation is a read-after-write that sees the key vanish with no eviction to
    explain it -- the partial-publication / disappearing-blob signature.
    """
    out: List[Violation] = []
    writes = [e for e in events if e.op == WRITE and e.outcome == OK]
    if not writes:
        return out
    evictions = sorted(e.inv for e in events if e.op == EVICT)
    for ev in events:
        if ev.op == READ and ev.outcome == MISSING:
            observed_absent = True
        elif ev.op == FIND_MISSING and ev.outcome == ABSENT:
            observed_absent = True
        else:
            observed_absent = False
        if not observed_absent:
            continue
        # An eviction can linearize during the write or the observation. Only a
        # completed write with no such eviction forces this observation present.
        forcing = [w for w in writes if w.res < ev.inv
                   and not any(w.inv <= t <= ev.res for t in evictions)]
        if not forcing:
            continue
        witness = max(forcing, key=lambda e: (e.res, e.seq))
        out.append(Violation(
            "monotone-availability", key,
            f"op began at inv={ev.inv} observed key ABSENT, but a write "
            f"completed at res={witness.res} with no overlapping or subsequent modelled eviction",
            [witness.to_json(), ev.to_json()]))
    return out


# --------------------------------------------------------------------------- #
# C3: linearizability (Wing & Gong sweep with backtracking)
# --------------------------------------------------------------------------- #
class _LinearOp:
    """A register op for the linearization search."""
    __slots__ = ("kind", "value", "inv", "res", "ev")

    def __init__(self, kind, value, inv, res, ev):
        self.kind = kind        # WRITE | READ
        self.value = value      # value written, or value read (EMPTY == MISSING)
        self.inv, self.res = inv, res
        self.ev = ev            # source Event for witness reporting


def check_linearizability(key: str, events: List[Event]) -> List[Violation]:
    """C3: the per-key register sub-history is linearizable.

    We model each key as a single mutable register whose legal operations are
    write(v) and read -> v (with EMPTY meaning "not present / never written").
    An eviction is an implicit write(EMPTY) at its instant. find_missing checks
    presence at its own linearization point. The empty CAS blob starts present
    and cannot be evicted. Other keys must start empty or include setup writes.

    A history is linearizable iff there is a permutation of its operations that
    (a) respects real-time order -- if a.res < b.inv then a precedes b -- and
    (b) is a legal sequential register run -- every read returns the value of the
    immediately preceding write (EMPTY if none precede it).

    Decision procedure (Wing & Gong / Lowe sweep):
      maintain a set of not-yet-linearized ops and the current register value;
      a candidate to commit next must be "minimal" (no pending op is forced to
      precede it, i.e. no pending op has res < candidate.inv) and, if it is a
      read, its observed value must equal the current register value. Commit it
      (updating the register for writes / evicts), recurse; on dead-end, undo and
      try the next candidate. If every op commits, the history is linearizable.
    """
    ops: List[_LinearOp] = []
    for ev in events:
        if ev.op == WRITE and ev.outcome == OK:
            ops.append(_LinearOp(WRITE, ev.value, ev.inv, ev.res, ev))
        elif ev.op == EVICT and key != EMPTY_KEY:
            ops.append(_LinearOp(WRITE, EMPTY, ev.inv, ev.res, ev))
        elif ev.op == READ and ev.outcome in (OK, MISSING):
            val = ev.value if ev.outcome == OK else EMPTY
            ops.append(_LinearOp(READ, val, ev.inv, ev.res, ev))
        elif ev.op == FIND_MISSING and ev.outcome in (PRESENT, ABSENT):
            ops.append(_LinearOp(FIND_MISSING, ev.outcome, ev.inv, ev.res, ev))
        # Failed reads do not constrain the register value.
    if not ops:
        return []

    # Stable order for determinism and for the "minimal" test.
    ops.sort(key=lambda o: (o.inv, o.res, o.ev.seq))
    n = len(ops)
    predecessors = [sum(1 << j for j, other in enumerate(ops)
                        if j != i and other.res < op.inv)
                    for i, op in enumerate(ops)]
    # Iterative search avoids Python's recursion limit on sequential histories.
    # Each edge removes one operation, so revisiting a state adds no witnesses.
    seen = set()
    stack = [((1 << n) - 1, EMPTY_HASH if key == EMPTY_KEY else EMPTY)]
    while stack:
        remaining, register_val = stack.pop()
        if remaining == 0:
            return []
        state = (remaining, register_val)
        if state in seen:
            continue
        seen.add(state)
        for i in range(n - 1, -1, -1):
            bit = 1 << i
            if not remaining & bit or predecessors[i] & remaining:
                continue
            op = ops[i]
            if op.kind in (READ, FIND_MISSING):
                legal = (op.value == register_val if op.kind == READ else
                         (register_val != EMPTY) == (op.value == PRESENT))
                if not legal:
                    continue
                stack.append((remaining ^ bit, register_val))
            else:  # WRITE / evict
                stack.append((remaining ^ bit, op.value))

    # Not linearizable: build an explanatory witness.
    witness = _diagnose_nonlinearizable(key, ops)
    return [witness]


def _diagnose_nonlinearizable(key: str, ops: List[_LinearOp]) -> Violation:
    """Produce a human-legible reason for non-linearizability.

    Common concrete case we want named precisely: a stale read -- a read that
    returns value V even though a write of a *newer* value W completed (W.res)
    before the read was invoked (read.inv), and no write of V happened at or after
    W completed. That is the cross-node read-after-write divergence signature.
    """
    reads = [o for o in ops if o.kind == READ]
    writes = [o for o in ops if o.kind == WRITE]
    for r in reads:
        rv = r.value  # the value the read claims to observe
        if rv == EMPTY:
            # Read-of-missing contradictions are primarily C2's domain; skip here.
            continue
        # A write of rv that could justify it must start before the read ends.
        justifying = [w for w in writes if w.value == rv and w.inv < r.res]
        if not justifying:
            return Violation(
                "linearizability", key,
                f"read observed value {rv!r} that was never written before it "
                f"completed (read inv={r.inv} res={r.res}); no write of that "
                f"value is real-time compatible",
                [r.ev.to_json()])
        # Stale-read case: some write of a DIFFERENT value completed before this
        # read began, and no write of rv happened at or after that completion.
        for w in writes:
            if w.value == rv:
                continue
            if w.res <= r.inv:
                later_rv = [j for j in writes if j.value == rv and j.res >= w.res]
                if not later_rv:
                    return Violation(
                        "linearizability", key,
                        f"stale read: returned {rv!r} after a newer write of "
                        f"{w.value!r} had already completed (write res={w.res} "
                        f"<= read inv={r.inv}) and no write of {rv!r} followed it",
                        [w.ev.to_json(), r.ev.to_json()])
    # Fallback: report the whole key history ordered by invocation.
    return Violation(
        "linearizability", key,
        "no real-time-consistent sequential witness exists for this key's history",
        [o.ev.to_json() for o in ops])


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def cas_key(data: bytes) -> str:
    """The content-addressed register key for a CAS/ByteStream blob."""
    return f"sha256:{sha256_hex(data)}/{len(data)}"


def _read_lines(path):
    if str(path) == "-":
        return sys.stdin.read().splitlines()
    return pathlib.Path(path).read_text(encoding="utf-8").splitlines()


# --------------------------------------------------------------------------- #
# Built-in unit tests (pure logic, no server)
# --------------------------------------------------------------------------- #
def _ev(op, key, inv, res, outcome=OK, value=EMPTY, size=None, worker=None):
    return Event(op=op, key=key, inv=inv, res=res, outcome=outcome, value=value,
                 size=size, worker=worker)


def _oracle_from(events: List[Event]) -> Oracle:
    o = Oracle()
    for i, e in enumerate(events):
        e.seq = i
        o._events.append(e)
    o._seq = itertools.count(len(events))
    return o


def run_self_test(verbose=True) -> bool:
    """Returns True if all cases pass. Each case prints PASS/FAIL."""
    HA = "a" * 64  # stand-in digest hashes
    HB = "b" * 64
    KA = f"sha256:{HA}/10"   # CAS key whose only legal value is HA
    passed = []

    def case(name, ok):
        passed.append(ok)
        if verbose:
            print(f"  [{'PASS' if ok else 'FAIL'}] {name}")

    # 1. Known-LINEARIZABLE history: write then disjoint reads all see the value.
    h1 = [
        _ev(WRITE, KA, 0.0, 1.0, OK, HA, 10, "w0"),
        _ev(READ, KA, 1.1, 1.2, OK, HA, 10, "w1"),
        _ev(READ, KA, 2.0, 2.1, OK, HA, 10, "w2"),
        _ev(FIND_MISSING, KA, 1.5, 1.6, PRESENT, worker="w3"),
    ]
    v1 = _oracle_from(h1).check()
    case("linearizable history passes (no violations)", v1 == [])

    # 1b. Concurrent linearizable: a read overlapping the write may see old or new.
    h1b = [
        _ev(READ, KA, 0.0, 0.3, MISSING, worker="r0"),   # overlaps write, sees empty
        _ev(WRITE, KA, 0.1, 1.0, OK, HA, 10, "w0"),
        _ev(READ, KA, 0.2, 0.9, OK, HA, 10, "r1"),       # overlaps write, sees new
    ]
    v1b = _oracle_from(h1b).check()
    case("concurrent read sees either value -> linearizable", v1b == [])

    # 2. STALE READ after a completed newer write (AC-style mutable register).
    #    AC key does not encode its value, so C1 is N/A; C3 must catch it.
    ACK = "ac:" + HA
    h2 = [
        _ev(WRITE, ACK, 0.0, 1.0, OK, "v1", worker="w0"),
        _ev(WRITE, ACK, 1.1, 2.0, OK, "v2", worker="w1"),   # newer write completes at 2.0
        _ev(READ, ACK, 3.0, 3.1, OK, "v1", worker="r0"),    # reads OLD value after 2.0
    ]
    v2 = _oracle_from(h2).check()
    stale = [v for v in v2 if v.kind == "linearizability"]
    case("stale read after completed newer write is caught", len(stale) == 1)
    if verbose and stale:
        print("        witness:", stale[0].message)

    # 3. READ of never-written bytes (linearizability: value never written).
    h3 = [
        _ev(WRITE, ACK, 0.0, 1.0, OK, "v1", worker="w0"),
        _ev(READ, ACK, 2.0, 2.1, OK, "ghost", worker="r0"),  # value never written
    ]
    v3 = _oracle_from(h3).check()
    ghost = [v for v in v3 if v.kind == "linearizability"]
    case("read of never-written value is caught", len(ghost) == 1)
    if verbose and ghost:
        print("        witness:", ghost[0].message)

    # 4. OK CAS read with WRONG hash (content-addressing).
    h4 = [
        _ev(WRITE, KA, 0.0, 1.0, OK, HA, 10, "w0"),
        _ev(READ, KA, 2.0, 2.1, OK, HB, 10, "r0"),  # returned bytes hash to HB != HA
    ]
    v4 = _oracle_from(h4).check()
    ca = [v for v in v4 if v.kind == "content-addressing"]
    case("OK read with wrong hash is caught (content-addressing)", len(ca) == 1)
    if verbose and ca:
        print("        witness:", ca[0].message)

    # 5. MONOTONE AVAILABILITY: read MISSING after a completed write, no eviction.
    h5 = [
        _ev(WRITE, KA, 0.0, 1.0, OK, HA, 10, "w0"),
        _ev(READ, KA, 2.0, 2.1, MISSING, worker="r0"),  # vanished with no eviction
    ]
    v5 = _oracle_from(h5).check()
    mono = [v for v in v5 if v.kind == "monotone-availability"]
    case("read-missing after completed write (no eviction) is caught", len(mono) == 1)

    # 5b. Same, but WITH a modelled eviction -> legal, no violation.
    h5b = [
        _ev(WRITE, KA, 0.0, 1.0, OK, HA, 10, "w0"),
        _ev(EVICT, KA, 1.5, 1.5, OK, worker="gc"),
        _ev(READ, KA, 2.0, 2.1, MISSING, worker="r0"),
    ]
    v5b = _oracle_from(h5b).check()
    case("read-missing after modelled eviction is NOT a violation",
         not any(v.kind == "monotone-availability" for v in v5b))

    # 6. find_missing ABSENT after completed write (partial-publication).
    h6 = [
        _ev(WRITE, KA, 0.0, 1.0, OK, HA, 10, "w0"),
        _ev(FIND_MISSING, KA, 2.0, 2.1, ABSENT, worker="r0"),
    ]
    v6 = _oracle_from(h6).check()
    case("find_missing ABSENT after completed write is caught",
         any(v.kind == "monotone-availability" for v in v6))

    # 7. Round-trip: dump/load preserves the history and verdict.
    import tempfile
    o7 = _oracle_from(h2)
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as tf:
        tmp = tf.name
    o7.dump(tmp)
    reloaded = Oracle.load(tmp)
    pathlib.Path(tmp).unlink()
    case("dump/load round-trips and preserves the stale-read verdict",
         len([v for v in reloaded.check() if v.kind == "linearizability"]) == 1)

    # 8. Larger linearizable concurrent register run (AC LWW, overlapping ops).
    h8 = [
        _ev(WRITE, ACK, 0.0, 1.0, OK, "v1", worker="w0"),
        _ev(READ, ACK, 1.1, 1.2, OK, "v1", worker="r0"),
        _ev(WRITE, ACK, 1.0, 2.0, OK, "v2", worker="w1"),   # overlaps r0 end
        _ev(READ, ACK, 2.1, 2.2, OK, "v2", worker="r1"),
        _ev(READ, ACK, 1.5, 2.5, OK, "v2", worker="r2"),    # overlaps w1, sees new
    ]
    v8 = _oracle_from(h8).check()
    case("overlapping LWW register run is linearizable", v8 == [])

    ok = all(passed)
    if verbose:
        print(f"\n  {sum(passed)}/{len(passed)} cases passed.")
    return ok


# --------------------------------------------------------------------------- #
# Optional: record a tiny real history off a live REAPI endpoint
# --------------------------------------------------------------------------- #
def _import_reapi_bindings():
    """Locate the generated gRPC/proto bindings (either sys.path convention)."""
    ROOT = pathlib.Path(__file__).resolve().parents[1]
    for cand in (ROOT / ".build/python", ROOT / "test"):
        if cand.exists():
            sys.path.insert(0, str(cand))
    # Also try the shared checkout if we are in a worktree lacking .build.
    for parent in ROOT.parents:
        shared = parent / ".build/python"
        if shared.exists():
            sys.path.insert(0, str(shared))
            break
    import grpc  # noqa: E402
    from build.bazel.remote.execution.v2 import remote_execution_pb2 as re_pb  # noqa: E402
    from google.bytestream import bytestream_pb2 as bs  # noqa: E402
    return grpc, re_pb, bs


def record_live_history(host: str, port: int, instance: str, out_path: str,
                        n_blobs: int = 3) -> None:
    """Sanity-check the recorder against a live REAPI/NativeLink endpoint.

    Writes n small blobs, then concurrently reads them back and FindMissingBlobs,
    recording the full history, then dumps it and runs the checks. This does not
    reconfigure or disturb the server -- it only sends REAPI traffic.
    """
    import concurrent.futures as cf
    import uuid
    grpc, re_pb, bs = _import_reapi_bindings()

    pre = f"{instance}/" if instance else ""
    ch = grpc.insecure_channel(f"{host}:{port}")
    grpc.channel_ready_future(ch).result(timeout=10)
    do_write = ch.stream_unary("/google.bytestream.ByteStream/Write",
        request_serializer=bs.WriteRequest.SerializeToString,
        response_deserializer=bs.WriteResponse.FromString)
    do_read = ch.unary_stream("/google.bytestream.ByteStream/Read",
        request_serializer=bs.ReadRequest.SerializeToString,
        response_deserializer=bs.ReadResponse.FromString)
    do_fmb = ch.unary_unary(
        "/build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs",
        request_serializer=re_pb.FindMissingBlobsRequest.SerializeToString,
        response_deserializer=re_pb.FindMissingBlobsResponse.FromString)

    oracle = Oracle(clock=time.monotonic)
    blobs = [f"rechaos-oracle-{uuid.uuid4()}-{i}".encode() for i in range(n_blobs)]

    def write_blob(i, data):
        h, n = sha256_hex(data), len(data)
        key = cas_key(data)
        name = f"{pre}uploads/{uuid.uuid4()}/blobs/{h}/{n}"
        with oracle.op(WRITE, key, worker=f"w{i}") as rec:
            do_write(iter([bs.WriteRequest(resource_name=name, write_offset=0,
                                           data=data, finish_write=True)]), timeout=10)
            rec(outcome=OK, value_hash=h, size=n)

    def read_blob(i, data):
        h, n = sha256_hex(data), len(data)
        key = cas_key(data)
        name = f"{pre}blobs/{h}/{n}"
        with oracle.op(READ, key, worker=f"r{i}") as rec:
            got = b"".join(m.data for m in do_read(bs.ReadRequest(resource_name=name), timeout=10))
            if got:
                rec(outcome=OK, value_hash=sha256_hex(got), size=len(got))
            else:
                rec(outcome=MISSING)

    def fmb_blob(i, data):
        h, n = sha256_hex(data), len(data)
        key = cas_key(data)
        with oracle.op(FIND_MISSING, key, worker=f"f{i}") as rec:
            resp = do_fmb(re_pb.FindMissingBlobsRequest(
                instance_name=instance, digest_function=re_pb.DigestFunction.SHA256,
                blob_digests=[re_pb.Digest(hash=h, size_bytes=n)]), timeout=10)
            absent = any(d.hash == h for d in resp.missing_blob_digests)
            rec(outcome=ABSENT if absent else PRESENT)

    for i, data in enumerate(blobs):
        write_blob(i, data)
    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        futs = []
        for i, data in enumerate(blobs):
            futs.append(pool.submit(read_blob, i, data))
            futs.append(pool.submit(fmb_blob, i, data))
        for f in futs:
            f.result()

    oracle.dump(out_path)
    vs = oracle.check()
    print(f"recorded {len(oracle.events())} ops -> {out_path}")
    if vs:
        print(f"{len(vs)} violation(s) against live endpoint:")
        for v in vs:
            print(v)
    else:
        print("no violations (live endpoint behaved consistently)")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _cmd_check(args) -> int:
    oracle = Oracle.load(args.history)
    violations = oracle.check()
    if args.json:
        print(json.dumps([v.to_json() for v in violations], indent=2, sort_keys=True))
    else:
        if not violations:
            print(f"OK: {len(oracle.events())} ops, no consistency violations.")
        else:
            print(f"FOUND {len(violations)} violation(s) in {len(oracle.events())} ops:\n")
            for v in violations:
                print(v)
                print()
    return 1 if violations else 0


def _cmd_self_test(args) -> int:
    print("consistency_oracle self-test:")
    ok = run_self_test(verbose=True)
    return 0 if ok else 1


def _cmd_record_live(args) -> int:
    record_live_history(args.host, args.port, args.instance, args.out, args.blobs)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="consistency_oracle.py",
        description="Model-based consistency oracle for REAPI CAS/AC/ByteStream histories.")
    sub = p.add_subparsers(dest="cmd", required=True)

    pc = sub.add_parser("check", help="check a recorded history JSONL file")
    pc.add_argument("history", help="path to history JSONL ('-' for stdin)")
    pc.add_argument("--json", action="store_true", help="emit violations as JSON")
    pc.set_defaults(func=_cmd_check)

    ps = sub.add_parser("self-test", help="run built-in unit tests (no server)")
    ps.set_defaults(func=_cmd_self_test)

    pr = sub.add_parser("record-live",
                        help="record a tiny real history off a REAPI endpoint")
    pr.add_argument("--host", default="127.0.0.1")
    pr.add_argument("--port", type=int, default=50052)
    pr.add_argument("--instance", default="main")
    pr.add_argument("--blobs", type=int, default=3)
    pr.add_argument("--out", default="consistency-history.jsonl")
    pr.set_defaults(func=_cmd_record_live)
    return p


def main(argv=None) -> int:
    # Back-compat shorthand: `--self-test` with no subcommand.
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv == ["--self-test"]:
        argv = ["self-test"]
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"consistency oracle: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
