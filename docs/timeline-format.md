# Timeline and outcomes on-disk format

The gateway writes two JSON Lines (JSONL) files per run: the **decision
timeline** (`--record PATH`) and the **outcomes sidecar**
(`PATH.outcomes.jsonl`). This page documents both as a stable on-disk schema so
third-party tools can read recordings without linking against rechaos. It is
derived directly from the `Decision`/`Event` `ToJSON`/`FromJSON` instances in
`src/Rechaos/Shell/Json.hs` and the outcomes writer in
`src/Rechaos/Shell/Runtime.hs`.

For the policy that produces these recordings, see the companion
[fault policy reference](fault-dsl.md).

## File conventions

- Both files are **JSON Lines**: one self-contained JSON object per line, UTF-8,
  newline-terminated.
- The decision timeline is written in observation order, one line per observed
  message. It is self-contained for replay: each line stores the observed event
  and the fault that was (or was not) selected for it.
- The outcomes sidecar is written to `<record-path>.outcomes.jsonl`, one line
  per completed RPC.
- The two files share a run but have **distinct schemas**; do not parse one with
  the reader for the other.

## Decision timeline schema

Each line is a `decision` object:

```json
{"version":1,"event":{ /* event */ },"injection":{ /* fault */ } | null}
```

| Field | Type | Range | Required |
|---|---|---|---|
| `version` | integer | exactly `1` | yes |
| `event` | object | see Event | yes |
| `injection` | fault object or `null` | — | yes |

- `version` must equal `1`; any other value is rejected on read with
  `unsupported timeline version`.
- `injection` is the fault that was selected for this event, encoded exactly as
  in the [fault reference](fault-dsl.md#faults). **`injection: null` means no
  fault was applied** to this event — this is the explicit no-fault convention,
  not an omitted field. The field is always present.
- When `injection` is non-null, it is re-validated on read against the event's
  method and direction (the same `validFault` check the policy uses), so a
  hand-edited timeline cannot smuggle in an illegal fault.
- Reading rejects any line whose event has a `0` `occurrence` or `messageIndex`
  with `indices are 1-based`, and rejects unknown fields with
  `unknown JSON field (check policy/timeline spelling)`.
- Across a whole timeline, the event identity
  `(method, occurrence, direction, messageIndex)` must be unique; a duplicate is
  rejected with `duplicate event identity in timeline`.

### Event fields

```json
{
  "method":        "google.bytestream.ByteStream/Read",
  "occurrence":    1,
  "direction":     "response",
  "messageIndex":  1,
  "blobBytes":     1024,
  "elapsedMicros": 523,
  "messageBytes":  1031,
  "payloadHash":   "..."
}
```

| Field | Type | Unit | Range | Required |
|---|---|---|---|---|
| `method` | string | — | full `service/Method` | yes |
| `occurrence` | integer | 1-based call index per method | `>= 1` | yes |
| `direction` | string | — | `"request"` or `"response"` | yes |
| `messageIndex` | integer | 1-based message index per direction | `>= 1` | yes |
| `blobBytes` | integer or `null` | bytes | `>= 0` or `null` | yes |
| `elapsedMicros` | integer | microseconds since call start | `>= 0` | yes |
| `messageBytes` | integer | bytes on the wire for this message | `>= 0` | yes |
| `payloadHash` | string | — | SHA-256 hex of the message bytes | yes |

Notes:

- `blobBytes` is the logical blob size associated with the event when known
  (e.g. a ByteStream resource size), and `null` when the message carries no
  blob-size information. Policy `minBlobBytes`/`maxBlobBytes` constraints never
  match an event whose `blobBytes` is `null`.
- `elapsedMicros` is the arrival time relative to the start of the call. It is
  the **only** field allowed to differ between a recorded event and the same
  event observed during replay; all other fields form the replay fingerprint.
- `messageBytes` is the serialized size of this specific message.
- `payloadHash` is the SHA-256 of the message bytes and is part of the replay
  fingerprint.

The identity tuple used for lookup and replay is
`(method, occurrence, direction, messageIndex)`.

## Outcomes sidecar schema

The outcomes file (`PATH.outcomes.jsonl`) records one line per completed RPC. It
has a **different, flatter schema** from the decision timeline and carries no
`version` envelope:

```json
{"method":"google.bytestream.ByteStream/Read","occurrence":1,"result":"OK","elapsedMicros":1840}
```

| Field | Type | Unit | Range |
|---|---|---|---|
| `method` | string | — | full `service/Method` |
| `occurrence` | integer | 1-based call index per method | `>= 1` |
| `result` | string | — | RPC result (e.g. `OK` or a gRPC status) |
| `elapsedMicros` | integer | microseconds for the whole call | `>= 0` |

Unlike the decision timeline, the outcomes file is write-only output: rechaos
produces it for post-run analysis and does not read it back for replay.

## Replay and verification

For the design rationale behind these semantics — why replay distinguishes an
incomplete recording from a changed one, and how the fingerprint is defined — see
the [replay section of ARCHITECTURE.md](ARCHITECTURE.md#replay-incomplete-vs-changed).

- `rechaos serve --replay TIMELINE` replays the decisions from a recorded
  timeline. A full replay fails closed on any event missing from the timeline
  (`event missing from replay timeline`) or whose fingerprint changed
  (`replay fingerprint mismatch`). With `--sparse`, unlisted traffic is allowed
  through unfaulted, but every listed event's fingerprint is still checked.
- `rechaos verify-replay EXPECTED OBSERVED` confirms that every expected event
  was observed with a matching fingerprint and the same injection; a missing or
  changed event fails with `replay incomplete or changed: <identity>`.
- `rechaos schedule --policy P --trace T --output O` recomputes the timeline
  deterministically from a recorded event trace, reading the `event` field of
  each line and writing a fresh decision timeline.

### Incomplete vs. changed

Replay separates two distinct failure modes, and the distinction is deliberate:

- **Incomplete** — a required event never occurred. A full replay fails with
  `event missing from replay timeline`; `verifyReplay` folds this into `replay
  incomplete or changed: <identity>`. A replay is **not** complete merely because
  nothing it observed mismatched: every expected event must also have happened.
- **Changed** — an event occurred, but its fingerprint differs from the
  recording. A full replay fails with `replay fingerprint mismatch`;
  `verify-replay` reports `replay incomplete or changed: <identity>`.

### The `sameEvent` fingerprint

Two events are "the same event" when they agree on every field **except**
`elapsedMicros`. `elapsedMicros` is the arrival time relative to the start of the
call and may legitimately differ between a recording and a live replay, so it is
excluded from the fingerprint. Every other field — the identity tuple
`(method, occurrence, direction, messageIndex)`, `blobBytes`, `messageBytes`, and
`payloadHash` — must match exactly, or the event counts as *changed*. The
identity tuple alone is used to *locate* the recorded event; the remaining
non-timing fields are what the fingerprint compares once located. A fingerprint
with a differing `payloadHash` or `messageBytes` means the traffic itself changed,
which is reported rather than silently replayed.

## Stability and versioning policy

The decision timeline carries an explicit `version` envelope that is currently
`1`. The contract for readers:

- Every decision line has `version: 1` for this schema generation. A tool that
  does not recognize the version must refuse the file rather than guess.
- Within version `1`, the event field set and the `injection: null` no-fault
  convention are stable; new information will be added as a new `version`, not by
  silently adding fields (the decoder rejects unknown fields).
- The determinism contract is **same policy + seed + event trace produces the
  same decisions**. A recorded timeline is therefore a faithful, replayable
  record of a run.
- The outcomes sidecar has no version envelope and is intended for analysis
  only; treat its field set as additive within a schema generation and do not
  rely on it for replay.
