# The rechaos formal REAPI specification

`lean/Rechaos/Spec.lean` (namespace `Rechaos.Spec`) is a machine-checked statement
of what a correct Remote Execution API (REAPI) server must do. It models the
content-addressed store as a finite association map `digest ⇀ bytes` and the REAPI
surface as a labelled transition system (LTS), then **proves** the structural laws
that any conforming CAS / Action Cache / ByteStream server is obliged to uphold.

This spec is the formal backing for the runtime model checker
`scripts/consistency_oracle.py`. The oracle records a concurrent history off a live
server and checks it against the *same* properties; the Lean theorems establish
that those properties are internally consistent and that they are exactly the laws
a correct store satisfies. A server is *graded* against this spec: every oracle
violation is a counterexample to one of the theorems below holding of that server.

Everything in the module is proved with no `sorry`, no `admit`, and no new `axiom`
(the theorems depend only on `propext`). The model abstracts over the concrete
digest key type `κ`, content value type `α`, and the hash function `hash : α → κ`,
so no `UInt64` arithmetic is forced in the kernel — the laws are structural.

## The model

| Lean construct | Meaning |
| --- | --- |
| `Store κ α := List (κ × α)` | the content-addressed store: a finite assoc map, first binding wins (last-writer-wins on `cons`) |
| `lookup st d` | fetch the content bound to digest `d`, or `none` (the CAS/AC not-found response) |
| `present st d` | `d` has a binding (FindMissingBlobs "not missing"; oracle `present`) |
| `Op κ α` | an REAPI operation label: `write`, `read`, `findMissing`, `updateActionResult`, `getActionResult` |
| `Obs κ α` | the server's observable response: `acked`, `got v`, `notFound`, `missing ds` |
| `valid hash d b := hash b = d` | a write is content-addressing-conforming iff the bytes hash to the digest |
| `step hash st op` | the LTS transition: next state × observation |
| `run hash st ops` | fold `step` over an op sequence (a "history") |
| `integral hash st` | every binding's content hashes to its key (the store well-formedness invariant) |

### Op ↔ REAPI method

| `Op` constructor | REAPI RPC |
| --- | --- |
| `write d b` | `ContentAddressableStorage.BatchUpdateBlobs` / `ByteStream.Write` |
| `read d` | `ContentAddressableStorage.BatchReadBlobs` / `ByteStream.Read` |
| `findMissing ds` | `ContentAddressableStorage.FindMissingBlobs` |
| `updateActionResult k r` | `ActionCache.UpdateActionResult` |
| `getActionResult k` | `ActionCache.GetActionResult` |

A `write` with mismatched hash is **rejected** by `step` (the store is unchanged),
modelling a conforming server returning `INVALID_ARGUMENT` rather than storing bytes
under the wrong name. `updateActionResult` always binds (AC is a mutable
last-writer-wins register whose key does not encode its value).

## The four laws (theorems) and their oracle mapping

The oracle enforces three named properties — **C1** content-addressing, **C2**
monotone availability, **C3** per-key linearizability. Each spec theorem is the
formal statement one of those checks presupposes.

### Law 1 — Content integrity (oracle C1)

> Any readable blob's bytes hash to its digest.

- `integral` — the store-level invariant: `∀ d b, (d, b) ∈ st → hash b = d`.
- `step_preserves_integral_cas`, `step_read_preserves_integral`,
  `step_findMissing_preserves_integral` — the CAS fragment (write/read/find)
  preserves `integral`; writes are gated on `hash b = d`, so a fresh binding is
  integral by construction and a rejected write leaves the store untouched.
- `read_content_integrity` — the observable form: in an integral store, any `read`
  that returns content returns content that hashes to the requested digest.

**Oracle:** `check_content_addressing` (`consistency_oracle.py`). For a CAS key
`"sha256:HEX/SIZE"`, an `ok` read must carry `value_hash == HEX`, and a committed
write must claim the key's own digest. `read_content_integrity` is exactly the
invariant that check asserts of the server on every read; `integral` is the store
state it presupposes, and `step_preserves_integral_cas` proves that a server that
only accepts valid writes can never leave that state. AC keys do not encode their
value and are skipped by C1 — mirrored here by `integral` ranging over CAS bindings
and AC being governed by Law 4 instead.

### Law 2 — Write-then-read availability (oracle C2 + the C3 read-latest edge)

> After a completed valid `Write(D, b)` with `hash(b) = D`, `Read(D)` yields `b`
> (absent eviction).

- `write_then_read` — `(step (step st (write d b)).1 (read d)).2 = got b`, given
  `valid hash d b`.
- `write_then_present` — after a valid write, `present` holds for the digest.

**Oracle:** `check_monotone_availability` (C2). Once a write of `K` *completes* at
`t*`, every later-*starting* op must observe `K` present (read `!= MISSING`,
find_missing `!= absent`) unless an eviction is modelled in `[t*, op.inv]`. The
"absent eviction" caveat in the law corresponds to the oracle's eviction carve-out.
This is also the read-returns-the-latest-write edge that
`check_linearizability` (C3) enforces for a CAS register: immediately after a
write, the register's value is the written bytes.

### Law 3 — FindMissingBlobs soundness and completeness (oracle C2 / state model)

> `FindMissingBlobs(ds)` returns exactly the queried digests that are absent.

- `findMissingResult st ds` — the response: `ds` filtered to the absent digests.
- `findMissing_sound` — every reported digest was queried **and** is genuinely
  absent (a server must not report a present blob as missing).
- `findMissing_complete` — every queried digest that is genuinely absent **is**
  reported (a server must not omit a truly-missing blob).
- `findMissing_iff` — the exact characterisation: `d ∈ findMissingResult st ds ↔
  (d ∈ ds ∧ ¬ present st d)`.
- `present_not_findMissing` — corollary: a present digest is never reported missing.

**Oracle:** the `find_missing` operation drives C2. A `find_missing` returning
`absent` for a key after a completed write is a monotone-availability violation —
precisely a failure of `present_not_findMissing` / completeness against the true
state. The soundness direction backs the oracle's assumption that an `absent`
answer is trustworthy evidence the blob is gone (so a subsequent `MISSING` read is
consistent, not a torn read).

### Law 4 — Action Cache monotonicity under last-writer (oracle C3 for AC keys)

> For an AC key, a `GetActionResult` after an `UpdateActionResult` reflects the
> most recent write.

- `update_then_get` — `Get(k)` immediately after `Update(k, r)` returns `r`.
- `update_then_present` — after an update, the key is present.
- `lastWriterWins` — after two successive updates of the same key, `lookup` yields
  the *second* result; a later write is never masked by an earlier one.
- `update_other_key_stable` — an update of a different key does not disturb an
  earlier key's binding (per-key registers are independent).

**Oracle:** `check_linearizability` (C3) treats each AC key as a mutable
last-writer-wins register and requires a sequential witness in which every read
returns the value of the most recent preceding write. `update_then_get` and
`lastWriterWins` are the sequential-register semantics that witness must satisfy;
`update_other_key_stable` justifies the oracle's per-key decomposition
(`by_key` in `Oracle.check`), which is what keeps the linearization search
tractable.

## Grading a server

To grade a server `S`:

1. Record a concurrent history `H` of REAPI calls against `S`
   (`consistency_oracle.py record-live` or an embedded `Oracle`).
2. Run `consistency_oracle.py check H.jsonl`.
3. Each reported `Violation` is a concrete counterexample to the corresponding
   spec law holding of `S`:
   - `content-addressing` ⟹ Law 1 (`read_content_integrity` / `integral`),
   - `monotone-availability` ⟹ Law 2 / Law 3 (`write_then_present`,
     `present_not_findMissing`),
   - `linearizability` ⟹ Law 2 / Law 4 (`write_then_read`, `update_then_get`,
     `lastWriterWins`).

A server with no violations across a sufficiently rich history exhibits, on that
history, exactly the behaviour the Lean LTS is proved to have. The spec is the
"what correct means"; the oracle is the "did this server do it".

## Rebuilding / checking the proofs

```
cd lean && nix shell nixpkgs#lean4 --command lake build      # green = proofs check
grep -rnE '(^|[^`])(sorry|admit)' lean/Rechaos               # must be empty
nix flake check                                              # lean gate includes Spec
```

`lean/lakefile.toml` globs `Rechaos.+`, so `Rechaos.Spec` is built and gated
automatically with the rest of the verified core.
