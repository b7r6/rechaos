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

## Scheduler liveness invariants (fleet rig)

Invariants 8 through 11 are checked by the chaos monkey's scheduler mode
(`--rig`) and by `scripts/scheduler_steps.py` directly. They need a fleet with
real workers, which [`scripts/fleet_rig.py`](../scripts/fleet_rig.py) starts
locally; the bounds come from the rig manifest (the scheduler's own timeouts)
and from the scenario (the queue-age bound, carried on the checker command line
so a frozen witness evaluates identically). Every finding freezes its
step list as a witness that `rechaos minimize --steps` shrinks; see
[`scheduler-chaos.md`](scheduler-chaos.md).

### 8. No action starves while later submissions are dispatched past it

- **Statement.** An action must not wait longer than the queue-age bound while
  the scheduler dispatches actions submitted after it. The bound is the longest
  action in the scenario's base stream plus a dispatch margin: within that time
  a fair scheduler can drain a slot (or hold one back) for the waiting action.
- **Derives from.** REAPI `Execution` liveness and the scheduler's own
  contract that a queued action eventually runs on a worker that satisfies its
  platform properties. A `minimum` property such as `memory_kb` names a resource
  the scheduler debits per running action; an action that fits only a nearly
  empty worker must still get one.
- **How checked.** `Rechaos.Core.Scenario.evaluate` (mirrored by the Python engine's `evaluate`) takes, per action, the
  time from `Execute` submission to the first `EXECUTING` stage (or, if never
  dispatched, to the last observation of the operation), minus any of that
  time spent inside a control-fault window. It flags an action
  whose wait exceeds the bound **and** that at least one later-submitted action
  overtook (reached `EXECUTING` before it). The second condition separates a
  scheduling decision from a merely overloaded fleet.
- **Signature.** `queue-starvation`.
- **Violation looks like.** An action asking for most of a worker's memory,
  queued behind a continuous stream of small ones: every freed slot goes to the next small
  action, the large one waits until the stream ends. Reproduced on
  upstream v1.7.6; quiet on post-fix `main` once the opt-in
  `reservation_hold` (NativeLink #2933) is enabled.

### 9. No action stalls while the fleet has room for it

- **Statement.** An action must not wait longer than the queue-age bound when,
  at the moment the bound elapses, everything in flight fits the fleet's
  declared capacity (slots and `memory_kb` per worker) with room to spare.
- **Derives from.** The same liveness contract as invariant 8, in the case
  where no overtake explains the wait: capacity exists, nothing is dispatched.
  This is the shape a leaked worker slot or a scheduler that lost track of a
  worker produces.
- **How checked.** `evaluate` flags a wait past the bound with no overtaking
  action when the actions in flight at the bound sum to at most the fleet's
  slots, each fits one worker's `memory_kb`, and their memory sums to at most
  the fleet's. Demand is computed from the scenario's own declarations, so it
  is deterministic.
- **Signature.** `dispatch-stall`.
- **Violation looks like.** After a control-plane fault, the trailing probe
  actions (one per slot) queue indefinitely although the workers are idle.

### 10. No operation stays `EXECUTING` past the scheduler's own timeout

- **Statement.** An operation observed in `EXECUTING` must leave that stage
  (complete, fail, or be requeued) within `max_action_executing_timeout_s +
  worker_timeout_s` plus a margin, whether or not a client is attached.
- **Derives from.** `WaitExecution` liveness and the scheduler's configured
  `max_action_executing_timeout_s`: an executing action with no worker update
  is to be timed out and requeued. A record that outlives both the action and
  the worker's slot is a lost result.
- **How checked.** Scenario actions marked `detach` cancel their `Execute`
  stream at the first `EXECUTING` and are re-attached with `WaitExecution`
  once per second until done or the bound elapses (extended by any fault
  window that overlapped). `evaluate` flags an operation whose last observed
  stage is still `EXECUTING` once the bound has elapsed outside fault windows.
- **Signature.** `stuck-executing`.
- **Violation looks like.** A `store-full` step caps the scheduler's Redis at
  its current `used_memory` (writes answer `OOM`) while actions finish; the
  worker reports their results, the write is refused, the record stays
  `EXECUTING` for the whole bound while new work still flows. Reproduced on
  upstream v1.7.6 with the Redis backend; quiet on post-fix
  `main` (NativeLink #2923, #2925).

### 11. An action does not fail on its worker's own cache while its inputs are present

- **Statement.** An action whose inputs are all present in the CAS must not
  fail with a server-side status; in particular it must not fail because the
  worker's local input cache evicted a file between lookup and staging.
- **Derives from.** REAPI execution semantics: the CAS is the source of truth
  for inputs; a worker-local cache is an implementation detail and its
  eviction is never the client's fault.
- **How checked.** For every action that completes with a non-`OK` status not
  attributable to the client (`CANCELLED`, `DEADLINE_EXCEEDED`, `UNAVAILABLE`
  are excluded), the engine runs `FindMissingBlobs` over the action's input
  blobs, root directory, and command. With nothing missing, a message matching
  `evict` or `hard link` is `input-evicted-failure`; any other status is
  `action-failed-inputs-present:<CODE>` so that unexpected server-side failures
  are still surfaced under a stable name, unless the failure was answered while
  a control fault was active (a store refusing a new action with `OOM` is that
  fault's own honest effect, not a scheduler bug).
- **Signatures.** `input-evicted-failure`; `action-failed-inputs-present:<CODE>`.
- **Violation looks like.** `FAILED_PRECONDITION: Could not make hardlink ...
  file was likely evicted from cache` on a worker whose cache sits at 87% of
  `max_bytes` under concurrent staging of shared inputs. Reproduced on
  upstream v1.7.6; quiet on post-fix `main` (NativeLink #2926,
  #2928).

## Object-store dialect invariants (fleet rig with a cloud CAS)

Invariants 12 and 13 need a rig whose CAS slow tier sits behind the dialect
fault proxy (`fleet_rig.py --cas-backend azure|s3`), so that a sustained
account-level throttle in the hyperscaler's exact shape (Azure `503
ServerBusy` with `x-ms-error-code` and "Egress is over the account limit.",
S3 `503 SlowDown`, GCS `503`/`429` JSON) reaches NativeLink's own object-store
client. The scenario step is `store-throttle`; see
[`scheduler-chaos.md`](scheduler-chaos.md) and [`s3-faults.md`](s3-faults.md).

### 12. A throttle shorter than the download budget does not fail an action

- **Statement.** While the object store answers reads with its throttle error
  (which carries `Retry-After`), an action whose inputs are all present must
  not fail on the input fetch, as long as the throttle is shorter than the
  worker's download budget (`max_download_timeout_s`). The store said "retry
  later"; giving up inside that budget is the client's choice, not the store's.
- **Derives from.** The object store's documented throttling contract: a 503
  with `Retry-After` is a transient condition the client is expected to back
  off from and retry, not a failure of the object. REAPI execution semantics
  make the CAS the source of truth for inputs that are present.
- **How checked.** `evaluate` flags an action that completed with a non-`OK`,
  non-client status, whose inputs `FindMissingBlobs` reports present, whose
  message names the store fetch (`download`, `fetch`, `ServerBusy`,
  `SlowDown`, `rateLimit`, `throttl`, `On attempt`, ...), and whose failure
  time falls inside a `store-throttle` window (plus five seconds) shorter than
  the download budget. A throttle longer than the budget makes giving up
  legitimate and produces no finding.
- **Signature.** `store-throttle-giveup`.
- **Violation looks like.** `INTERNAL: ... Failed to start download from
  Azure ... On attempt 7` about 36 s into a 60 s throttle, exactly a
  6-retry/0.3 s/0.5-jitter client budget. Reproduced on upstream v1.7.6 with
  the Azure dialect; quiet on post-fix `main`, where every action completed
  two seconds after the throttle lifted after 480 throttled reads that honored
  `Retry-After` (NativeLink #2931, #2932).

### 13. A throttle does not re-dispatch an action to another worker

- **Statement.** An action must not fall from `EXECUTING` back to `QUEUED`
  because of an object-store throttle shorter than the download budget: the
  worker that holds it retries in place. Re-dispatch makes another worker
  download the same inputs from the same throttled account, which is how one
  account's egress limit turns into a fleet-wide storm.
- **Derives from.** The same throttling contract as invariant 12, applied to
  the scheduler's response to a worker's fetch failure, and the arithmetic
  of a throttled account: every re-dispatch is another full download of the
  input tree.
- **How checked.** The engine records every `EXECUTING` to `QUEUED`
  transition on an action's `Execute` stream. `evaluate` flags an action with
  at least one such requeue inside a `store-throttle` window (plus five
  seconds) shorter than the download budget. A scenario whose scheduler
  `max_action_executing_timeout_s` is shorter than the throttle is refused as
  inconclusive, because that timeout requeues fetching actions on its own
  clock.
- **Signature.** `store-throttle-redispatch`.
- **Violation looks like.** Requeues at 20 s and 40 s into the throttle and a
  final `FAILED_PRECONDITION: Job cancelled because it attempted to execute
  too many times 4 > 3`. Reproduced on upstream v1.7.6 with both the Azure
  and S3 dialects; quiet on post-fix `main`. On the S3 path the client sees
  the action end with `INTERNAL: channel closed : Failed to wait for awaited
  action to change` rather than the fetch error, so invariant 12 cannot
  attribute the give-up there; the re-dispatch and the stream failure
  (`action-failed-inputs-present:INTERNAL`) still surface it.

## Meta: iteration integrity

The harness also treats an iteration that crashes before completing its checks as
a signal in its own right (`iteration-exception:<mode>:<ExceptionType>`), on the
principle that an invariant check that cannot run is not a passing check. Findings
are deduplicated by signature; the first occurrence of each signature freezes a
reproducer (for proxy findings: the `policy.json` plus the recorded
`timeline.jsonl` and its outcomes sidecar; for direct findings: the seed and
scenario), which replays through `rechaos serve --replay` and shrinks through
`rechaos minimize`.
