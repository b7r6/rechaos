# Invariants catalog

This is the citable catalog of the correctness and liveness invariants rechaos
asserts. Each invariant is checked by the continuous chaos monkey
([`scripts/chaos-monkey.py`](../scripts/chaos-monkey.py)) against a live
REAPI/NativeLink endpoint — under both faulted proxy traffic and hostile direct
clients. A violation is deduplicated by a stable **signature** and frozen as a
replayable reproducer.

Each entry below gives: the exact statement, the REAPI/ByteStream clause it
derives from, how it is checked (with the chaos-monkey check and finding
signature), and what a violation looks like. Signatures and behavior are
cross-checked against the script so the names here match what the corpus emits.

For the design context behind these checks — the pure decision core, the oracle,
and replayable reproduction — see [`ARCHITECTURE.md`](ARCHITECTURE.md). For the
fault policies that produce the faulted traffic, see
[`fault-dsl.md`](fault-dsl.md); for the recorded reproducer format, see
[`timeline-format.md`](timeline-format.md).

## Correctness invariants

### 1. An `OK` Read returns bytes matching the requested digest

- **Statement.** If `ByteStream.Read` on a content-addressed resource terminates
  with status `OK`, the concatenated response bytes must hash to the digest named
  in the `resource_name`.
- **Derives from.** REAPI/ByteStream content-addressing: a CAS blob is named by
  the digest of its content, so a successful read of that name must return
  exactly that content. A torn or partial read served as `OK` breaks
  content-addressing.
- **How checked.** `check_read_integrity` reads the blob and flags any result
  where `status == "OK"` but the returned bytes do not match the requested
  digest. Run on gateway reads (`phase "proxy"`) and, critically, on the
  upstream directly *after* a faulted read (`phase "proxy-after"`), to confirm
  the fault did not corrupt what the server subsequently serves. `range-read` in
  the direct harness applies the same rule to ranged reads (offsets/limits,
  including offsets past EOF).
- **Signatures.** `torn-read:<phase>`; `range-wrong-bytes` for the ranged case.
- **Violation looks like.** A `Read` that returns `OK` with content whose SHA-256
  differs from the requested hash — a torn read, a stale/wrong blob served under
  the right name, or wrong bytes returned for a valid range.

### 2. A partial/aborted upload must not become a readable mismatching blob

- **Statement.** An upload that was faulted, cancelled, or short must not leave a
  blob that is readable under its advertised digest but whose stored bytes do not
  match that digest.
- **Derives from.** ByteStream `Write` + CAS semantics: a blob only becomes
  valid once fully written and its content matches its digest. A half-written
  object published under the full digest is a content-addressing violation.
- **How checked.** `check_absent` reads the blob back and flags `status == "OK"
  with matches is False` (genuine content mismatch — *not* mere presence, since a
  fully-written blob is legitimately present in a content-addressed store even if
  the client's ack was lost). Driven after faulted/failed proxy writes
  (`check_absent("proxy", ...)`) and after direct `short-upload`,
  `empty-finish`, and `cancel-write` scenarios.
- **Signature.** `incomplete-upload-readable:<tag>`.
- **Violation looks like.** After a truncated/cancelled upload, reading the
  digest returns `OK` with bytes that do not hash to that digest.

### 3. `committed_size` equals the advertised size on a successful Write

- **Statement.** A `ByteStream.Write` that completes with `OK` must report a
  `committed_size` equal to the resource's advertised total size.
- **Derives from.** ByteStream `WriteResponse.committed_size`: on a successful
  write it is the number of bytes committed, which for a complete write equals
  the resource size.
- **How checked.** `check_committed` flags any `OK` write whose
  `committed_size` is neither `None` nor the advertised `blob.size`. Applied to
  proxy writes and to each writer in the direct `concurrent-writers` scenario.
- **Signature.** `wrong-committed-size`.
- **Violation looks like.** A write returns `OK` but `committed_size` disagrees
  with the bytes the client advertised (over- or under-report of commitment).

### 4. `FindMissingBlobs` is consistent

- **Statement.** `FindMissingBlobs` must return exactly the set of queried
  digests that are absent — no present blob reported missing, no absent blob
  reported present — and must not report a digest present whose stored bytes do
  not match it.
- **Derives from.** REAPI `ContentAddressableStorage.FindMissingBlobs`: the
  response lists precisely those requested digests not present in the CAS.
- **How checked.** The proxy `missing` iteration seeds known-present and
  known-absent blobs, then asserts the returned missing set equals the expected
  absent set (`fmb-wrong-set`). `check_absent` additionally asserts that a blob
  whose stored bytes are corrupt is not reported present by `FindMissingBlobs`
  (`fmb-present-phantom`).
- **Signatures.** `fmb-wrong-set`; `fmb-present-phantom`.
- **Violation looks like.** A present blob returned as missing, an absent blob
  omitted from the missing set, or a corrupt blob advertised as present.

### 5. `QueryWriteStatus` does not over-report

- **Statement.** `QueryWriteStatus` must not report a `committed_size` exceeding
  the bytes the client actually sent, and must not report `complete` for an
  upload that is not complete.
- **Derives from.** ByteStream `QueryWriteStatus`: `committed_size` is the number
  of bytes committed for the resource; `complete` means the whole resource was
  written.
- **How checked.** `check_query_sane` compares the queried `committed_size`
  against the bytes actually uploaded (flags over-count) and checks that
  `complete` is not set while `uploaded != blob.size`. Driven by the direct
  `short-upload`, `empty-finish`, and `resume` scenarios.
- **Signatures.** `query-overcount`; `query-false-complete`.
- **Violation looks like.** A status query claims more committed bytes than were
  sent, or claims an incomplete upload is complete (which would let a client
  skip finishing a write).

## Liveness invariants

### 6. Recovery after a fault

- **Statement.** After every fault iteration, a known-good blob must still
  round-trip `OK` within its deadline, and the endpoint's metrics must remain
  reachable.
- **Derives from.** Liveness: an injected fault on one RPC must not wedge the
  server for subsequent, unrelated, well-formed traffic (no hang, crash, or
  persistent corruption).
- **How checked.** `recovery` reads the persistent `health` blob after each
  iteration and flags a non-`OK`/non-matching read; if the Prometheus endpoint
  was reachable at startup and later stops responding, that too is flagged
  (possible crash/hang).
- **Signatures.** `recovery-failed`; `endpoint-metrics-unreachable`.
- **Violation looks like.** The health blob fails to read cleanly after a fault,
  or the metrics endpoint goes silent — a fault that escaped its RPC.

### 7. Awaited-action store does not leak (queue-GC)

- **Statement.** With `--execution`, terminal and abandoned scheduler entries
  must be garbage-collected: the awaited-action store must not grow without
  bound, and after all clients leave and the abandon+retain window elapses, the
  store must drain.
- **Derives from.** REAPI `Execution`/`WaitExecution` liveness: operations that
  complete, are cancelled, or are abandoned by their clients must eventually be
  reclaimed; a store that never drains is a resource leak (the P0 signature this
  harness was built to catch).
- **How checked.** Two detectors over Prometheus scrapes. `scheduler_leak_check`
  is a rising-floor detector: if the **minimum** non-queued residue (store ops
  minus queued-set slots) over successive windows keeps climbing, GC is not
  keeping pace. `drain_check` is the definitive end-of-campaign test: stop
  creating work, wait past the abandon+retain window, and confirm the store
  drained; a throwaway "touch" execution distinguishes access-triggered GC (no
  background timer) from a true leak.
- **Signatures.** `scheduler-queue-leak-rising`; `scheduler-queue-leak`.
- **Violation looks like.** The non-queued residue floor climbs across the run,
  or the store still holds entries after a full quiet drain with no clients
  present.

## Meta: iteration integrity

The harness also treats an iteration that crashes before completing its checks as
a signal in its own right (`iteration-exception:<mode>:<ExceptionType>`), on the
principle that an invariant check that cannot run is not a passing check. Findings
are deduplicated by signature; the first occurrence of each signature freezes a
reproducer (for proxy findings: the `policy.json` plus the recorded
`timeline.jsonl` and its outcomes sidecar; for direct findings: the seed and
scenario), which replays through `rechaos serve --replay` and shrinks through
`rechaos minimize`.
