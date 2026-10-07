# Consistency oracle

The chaos monkey ([`scripts/chaos-monkey.py`](../scripts/chaos-monkey.py))
asserts **point** invariants: *this* read was torn, *this* upload leaked a
mismatching blob (see [`invariants.md`](invariants.md)). Those are necessary but
not sufficient. The subtle NativeLink failures we care about are
**history-level**: they are invisible in any single operation and show up only
when a *concurrent history* of operations is examined as a whole. Two we have
observed:

- **cross-node read-after-write divergence** — a client writes value V2 and gets
  an ack; a later read, served by a different node, still returns the older V1.
  Every individual op looks fine; the *history* is not linearizable.
- **partial publication** — a blob is acknowledged as written, then a subsequent
  `FindMissingBlobs` or `Read` reports it absent, with no eviction to explain the
  disappearance.

[`scripts/consistency_oracle.py`](../scripts/consistency_oracle.py) records a
concurrent operation history over CAS / Action Cache / ByteStream and checks it
against a **model of correct content-addressed semantics**. It is both a library
the monkey can embed and a standalone CLI that checks recorded histories and
emits precise violation witnesses.

## The model

Every operation targets a **key**, and each key is modelled as a single
**register**:

| Surface | Register key | Legal value |
|---|---|---|
| CAS / ByteStream blob | `sha256:HEX/SIZE` (the digest) | the one preimage whose SHA-256 is `HEX` — the register is write-once with a fixed legal value |
| Action Cache entry | the action digest (e.g. `ac:HEX`) | the `ActionResult`; a mutable **last-writer-wins** register |

Modelled operations, each carrying an **invocation** timestamp `inv` (when the
client issued the RPC) and a **response** timestamp `res` (when it completed),
plus an outcome:

- `write(key, value)` — a CAS/ByteStream upload, or an AC update.
- `read(key) -> value | MISSING` — a CAS/ByteStream read, or an AC get.
- `find_missing(key) -> present | absent` — `ContentAddressableStorage.FindMissingBlobs`.
- `evict(key)` — a *modelled* eviction instant (the register becomes empty). Used
  to tell the oracle an eviction is expected so it does not flag the resulting
  absence; emit it only when you have actually driven/observed an eviction.

`value` is represented by the **SHA-256 hex of the bytes** written or returned
(`value_hash`), not the raw bytes. For CAS this is by definition the digest; for
AC it is a stable fingerprint of the `ActionResult`. Storing the hash keeps
histories small while preserving every equality the checks need. The sentinel
`∅` (`EMPTY`) is the register's "not present / never written" value.

The `inv`/`res` pair defines each op's **real-time interval**. Op *a* is forced
before op *b* iff `a.res < b.inv` (they do not overlap and *a* finished first).
Overlapping ops are concurrent and may be ordered either way.

The history must include all writes and evictions for the keys under test,
starting from known-empty registers (except the REAPI empty CAS blob, which is
always present). Use fresh keys or include setup writes. Hidden writers,
unobserved eviction, pre-existing AC state, partial/range reads, or unresolved
failed writes invalidate that interpretation. Failed writes may have committed;
the checker rejects such histories as inconclusive until outcomes are resolved.
Malformed timestamps, operations, outcomes, and missing successful-value
fingerprints are rejected. CLI exit 2 means invalid/inconclusive input.

This is a selected consistency model, not the full REAPI specification. The
vendored protocol leaves CAS lifetimes implementation-specific and permits
semantically equivalent AC result rewrites. A violation of the model needs those
assumptions checked before attributing a protocol defect to a server.

## The checks

### C1 — content-addressing

> A successful read of a content-addressed digest D returns bytes that hash to D.

For a CAS/ByteStream key `sha256:HEX/SIZE`, the only legal value is `HEX`. Any
`read` with outcome `ok` whose `value_hash != HEX` is a violation (a torn read, a
stale/wrong blob under the right name, wrong bytes for a full-blob read). Writes are
checked symmetrically: a committed write must claim the key's own digest. AC keys
do not encode their value, so C1 is skipped for them (C3 covers AC). If a byte
size is recorded, it must also match the size in the CAS key. Implemented
in `check_content_addressing`.

### C2 — monotone availability

> Once any write of key K has **completed**, every operation that **begins after**
> that completion must observe K as present — unless an eviction is modelled in
> the interim.

For each absence observation, check completed writes that finished before it
began. A write forces presence if no modelled eviction overlaps that write or
falls between its invocation and the observation's response. An eviction during
the observation can explain absence. A later completed write restores the
presence obligation; an older eviction cannot excuse absence forever. C3 also
checks the joint ordering of writes, reads, presence probes, and evictions.

### C3 — linearizability of the per-key register

> The sub-history for each key has a sequential witness: a total order consistent
> with real time in which every read returns the value of the most recent
> preceding write (or `∅` if none).

This is the property that catches the **stale read after a completed newer
write** — the cross-node divergence signature — and reads of values that were
never written. Implemented in `check_linearizability`, with a human-legible
reason produced by `_diagnose_nonlinearizable`.

## The linearizability algorithm

We use a **Wing & Gong** style sweep with backtracking (equivalently, the Lowe
"linearize one minimal operation at a time" procedure). Because each key is an
independent single register, the per-key histories are short and the search is
tractable.

Setup. From a key's events we build register operations:

- `write(v)` from each completed write; an `evict` becomes an implicit
  `write(∅)` at its instant (it empties the register).
- `read -> v` from each read (`v = ∅` for a `missing` read).
- `find_missing` constrains whether the register is empty at its linearization
  point, so presence probes share the same ordering as reads and writes.
- Failed reads do not constrain the value. Failed writes require outcome
  resolution before checking.

Decision procedure (`search`), maintaining a set of not-yet-linearized ops and
the current register value (initially `∅`):

1. **Minimality.** A pending op *i* may be linearized next only if no *other*
   pending op *j* is forced before it, i.e. no pending *j* has `j.res < i.inv`.
   (`minimal_candidates`.) This is the real-time constraint: an op that provably
   finished before *i* started cannot come after *i*.
2. **Legality.** If the candidate is a **read**, its observed value must equal the
   current register value; otherwise it cannot be committed now. A **write**
   (or evict) is always legal to commit and sets the register to its value.
3. **Commit & recurse.** Tentatively commit a candidate, recurse on the smaller
   problem. If the recursion succeeds the whole history is linearizable.
4. **Backtrack.** On a dead end, undo and try the next candidate. We **memoize**
   visited `(remaining-op-set, register-value)` states so the search does not
   re-explore an equivalent state — this keeps it fast on concurrent runs.

If every op commits, the history is **linearizable** and C3 passes. If the search
exhausts all orderings, the history is **not** linearizable and we emit a
witness. `_diagnose_nonlinearizable` names the concrete cause when it can:

- **stale read** — a read returned V after a write of a *different* value W had
  already completed before the read began (`W.res <= read.inv`) and no write of V
  happened at or after W completed. Witness: the newer write + the stale read.
- **phantom read** — a read returned a value for which *no* write is even
  real-time compatible (no write of that value started before the read ended).
  Witness: the read.
- otherwise a fallback witness listing the key's history in invocation order.

Soundness/complexity notes. The real-time precedence check makes the procedure
**sound** (it accepts only histories with a genuine real-time-respecting
sequential witness) and **complete** for a single register (it explores every
admissible linearization point via backtracking). Worst case is exponential in
the number of mutually concurrent operations on one key. The iterative search
avoids Python recursion limits, but no general time or memory bound is promised.
A successful check establishes existence of a witness for the recorded history
under the stated model and assumptions, not correctness on future histories.

## Feeding it histories

### History JSONL format

One self-contained JSON object per line. Fields:

| Field | Meaning |
|---|---|
| `op` | `write` \| `read` \| `find_missing` \| `evict` |
| `key` | register key (`sha256:HEX/SIZE` for CAS, e.g. `ac:HEX` for AC) |
| `inv`, `res` | invocation / response timestamps (float seconds, one clock; only ordering matters) |
| `outcome` | `ok` \| `missing` \| `present` \| `absent` \| `error` |
| `value_hash` | SHA-256 hex of bytes written/returned (omit for missing/find_missing/evict) |
| `size` | optional byte length |
| `worker` | optional worker/thread id, for legibility |

Example:

```json
{"op":"write","key":"ac:deadbeef","value_hash":"v1","inv":0.0,"res":1.0,"outcome":"ok","worker":"w0"}
{"op":"write","key":"ac:deadbeef","value_hash":"v2","inv":1.1,"res":2.0,"outcome":"ok","worker":"w1"}
{"op":"read","key":"ac:deadbeef","value_hash":"v1","inv":3.0,"res":3.1,"outcome":"ok","worker":"r0"}
```

### Library API (embed in the chaos monkey)

```python
from consistency_oracle import Oracle, WRITE, READ, FIND_MISSING, OK, MISSING, PRESENT, ABSENT, cas_key, sha256_hex

oracle = Oracle()                       # thread-safe; share across workers

# Time an op with the context manager (captures inv/res around the real call):
key = cas_key(data)
with oracle.op(WRITE, key, worker="w0") as rec:
    upload(data)
    rec(outcome=OK, value_hash=sha256_hex(data), size=len(data))

with oracle.op(READ, key, worker="r1") as rec:
    got = download(key)
    rec(outcome=OK, value_hash=sha256_hex(got), size=len(got)) if got else rec(outcome=MISSING)

# Or record a pre-timed event directly (e.g. when re-timing from a gateway timeline):
oracle.record_read(key, inv=..., res=..., outcome=OK, value_hash=..., size=...)

violations = oracle.check()             # -> list[Violation]; empty == consistent
oracle.dump("history.jsonl")            # freeze the history for replay
```

`Violation` has `.kind` (`content-addressing` / `monotone-availability` /
`linearizability`), `.key`, `.message`, `.witnesses` (JSON-serializable offending
events), and a legible `str()`.

### CLI

```sh
# Check a recorded history; exit 0 == consistent, 1 == violations found.
nix develop --command python3 scripts/consistency_oracle.py check history.jsonl
nix develop --command python3 scripts/consistency_oracle.py check --json history.jsonl
cat history.jsonl | nix develop --command python3 scripts/consistency_oracle.py check -

# Run the built-in unit tests (pure logic, no server).
nix develop --command python3 scripts/consistency_oracle.py self-test

# Record a tiny real history off a live REAPI endpoint to sanity-check the
# recorder (configurable target; sends only REAPI traffic, never reconfigures).
nix develop --command python3 scripts/consistency_oracle.py record-live \
    --host 127.0.0.1 --port 50052 --instance main --blobs 3 --out history.jsonl
```

## Validation

`self-test` runs ten cases, all passing:

- a known-**linearizable** history passes (including concurrent reads overlapping
  a write, which may legally see either value);
- a **stale read after a completed newer write** is caught, with the newer-write +
  stale-read witness;
- a **read of never-written bytes** is caught (phantom read witness);
- an **`OK` read with the wrong hash** is caught by content-addressing;
- a **read/`find_missing` showing absence after a completed write** is caught by
  monotone availability, while the same under a **modelled eviction** is *not*
  flagged;
- `dump`/`load` round-trips a history and preserves the verdict.

The recorder was additionally sanity-checked by recording a real 9-op concurrent
history (3 writes, then concurrent reads + `FindMissingBlobs`) off a live
NativeLink at `127.0.0.1:50052`; the checker reported no violations, as expected
for a healthy endpoint.
