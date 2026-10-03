# Fault policy reference

A fault policy is a single JSON document that tells the rechaos gateway which
wire messages to perturb and how. This page is the authoritative reference for
the policy grammar, every field, every constraint, and the exact error message
the decoder emits when a constraint is violated. It is derived directly from the
strict, versioned decoder in `src/Rechaos/Shell/Json.hs`; nothing here is
aspirational.

The companion [timeline format reference](timeline-format.md) documents the
on-disk record of what the gateway actually did with a policy.

## Design rules

Two rules govern the whole decoder and are worth stating up front:

- **Unknown fields are errors.** Every object (`policy`, `rule`, `target`,
  `fault`) is decoded against a fixed allow-list of keys. Any key outside that
  list fails the parse. This is deliberate: a misspelled `occurence` or a
  field from a newer schema must not be silently ignored.
- **The schema is versioned.** The top-level `version` must equal `1`. There is
  no implicit default; a missing or mismatched version is an error.

## Grammar

```json5
{
  "version": 1,            // required, must equal 1
  "seed":    20261002,     // required, unsigned 64-bit integer
  "rules": [               // required, ordered; may be empty
    {
      "target":    { /* target object, see below */ },
      "chancePpm": 1000000, // optional, default 1000000
      "fault":     { /* fault object, see below */ }
    }
    // ...more rules
  ]
}
```

The `rules` array is **ordered and first-match wins**: for each observed
message the gateway walks the rules in order and the first rule whose `target`
matches owns the event. No later rule is consulted for that event. A policy with
an empty `rules` array injects no faults.

The `seed` is a `Word64`; it seeds the SplitMix64 generator that drives
probabilistic selection. Exactly one SplitMix64 step is consumed per observed
message, whether or not any rule matched, so the decision stream is a pure
function of `seed` plus the event trace.

## Envelope fields

| Field | Type | Unit | Range | Default | Required |
|---|---|---|---|---|---|
| `version` | integer | — | exactly `1` | — | yes |
| `seed` | integer | — | unsigned 64-bit | — | yes |
| `rules` | array of rule | — | may be empty | — | yes |

## Rule fields

| Field | Type | Unit | Range | Default | Required |
|---|---|---|---|---|---|
| `target` | object | — | see Target | — | yes |
| `chancePpm` | integer | parts-per-million | `0`..`1000000` | `1000000` | no |
| `fault` | object | — | see Fault | — | yes |

`chancePpm` is the probability that a matching event is actually faulted,
expressed in parts per million. `1000000` (the default) means "always inject on
match"; `0` means "never inject" (the rule still consumes its SplitMix64 step
and still owns the event, blocking later rules). Selection fires when
`draw mod 1000000 < chancePpm`, where `draw` is this event's SplitMix64 output.

## Target fields

A target narrows which events a rule applies to. `method` and `direction` are
required; every other field is an optional additional constraint, and an absent
constraint matches anything.

| Field | Type | Unit | Range | Default | Required |
|---|---|---|---|---|---|
| `method` | string | — | a supported `service/Method` (see matrix) | — | yes |
| `direction` | string | — | `"request"` or `"response"` | — | yes |
| `occurrence` | integer | 1-based call index per method | `>= 1` | match any | no |
| `messageIndex` | integer | 1-based message index per direction | `>= 1` | match any | no |
| `minBlobBytes` | integer | bytes, inclusive lower bound | `<= maxBlobBytes` | match any | no |
| `maxBlobBytes` | integer | bytes, inclusive upper bound | `>= minBlobBytes` | match any | no |
| `afterMicros` | integer | microseconds, inclusive lower bound on elapsed | `<= beforeMicros` | match any | no |
| `beforeMicros` | integer | microseconds, inclusive upper bound on elapsed | `>= afterMicros` | match any | no |

Notes:

- `method` uses the full `service/Method` name **without** a leading slash, e.g.
  `google.bytestream.ByteStream/Read`.
- `direction` selects whether the rule sees the client-to-server (`request`) or
  server-to-client (`response`) side of the stream.
- `occurrence` and `messageIndex` are **1-based**. Occurrence counts calls to a
  given method; message index counts messages within a given direction of a
  single call. A value of `0` is rejected.
- `minBlobBytes`/`maxBlobBytes` match against the event's observed blob size and
  are an **inclusive** range. An event with no known blob size does not match a
  policy that constrains blob bytes.
- `afterMicros`/`beforeMicros` match against the elapsed microseconds since the
  call began and are an **inclusive** range.
- A range whose lower bound exceeds its upper bound (either blob-bytes or
  micros) is rejected at decode time, before the policy is ever run.

## Faults

Each rule carries exactly one `fault` object, discriminated by its `kind`. Each
fault kind has its own fixed allow-list of keys.

### delay

```json
{"kind": "delay", "micros": 100000}
```

| Field | Type | Unit | Range | Required |
|---|---|---|---|---|
| `kind` | string | — | `"delay"` | yes |
| `micros` | integer | microseconds | `>= 0` | yes |

Holds the selected message for `micros` microseconds, then forwards it
unchanged.

### abort

```json
{"kind": "abort", "status": "Unavailable"}
```

| Field | Type | Unit | Range | Required |
|---|---|---|---|---|
| `kind` | string | — | `"abort"` | yes |
| `status` | string | — | a gRPC status name (below) | yes |

Ends the selected RPC with the given gRPC error status. The `status` string is
one of the following constructors, each mapped to its canonical gRPC status:

| `status` value | gRPC status |
|---|---|
| `Cancelled` | CANCELLED |
| `InvalidArgument` | INVALID_ARGUMENT |
| `DeadlineExceeded` | DEADLINE_EXCEEDED |
| `NotFound` | NOT_FOUND |
| `ResourceExhausted` | RESOURCE_EXHAUSTED |
| `FailedPrecondition` | FAILED_PRECONDITION |
| `Internal` | INTERNAL |
| `Unavailable` | UNAVAILABLE |
| `DataLoss` | DATA_LOSS |

Any other string is rejected.

### dribble

```json
{"kind": "dribble", "bytesPerSecond": 65536, "chunkBytes": 4096}
```

| Field | Type | Unit | Range | Required |
|---|---|---|---|---|
| `kind` | string | — | `"dribble"` | yes |
| `bytesPerSecond` | integer | bytes per second | `> 0` | yes |
| `chunkBytes` | integer | bytes | `1`..`4194304` (4 MiB) | yes |

Paces ByteStream payload chunks: the payload is re-chunked into `chunkBytes`
pieces and emitted at `bytesPerSecond`, while preserving valid protobuf messages
and Write offsets. Both `bytesPerSecond` and `chunkBytes` must be positive, and
`chunkBytes` must not exceed `4194304` (4 MiB).

### truncate

```json
{"kind": "truncate", "keepBytes": 7}
```

| Field | Type | Unit | Range | Required |
|---|---|---|---|---|
| `kind` | string | — | `"truncate"` | yes |
| `keepBytes` | integer | bytes | `>= 0` | yes |

Keeps the first `keepBytes` bytes of a ByteStream Read response and ends the
stream with `OK`, or shortens a ByteStream Write message and sets
`finish_write`. Truncate is only valid on the ByteStream payload directions (see
matrix).

## Method x direction x fault compatibility

Validity is enforced twice from the same rule: once on the whole policy at
decode time, and again per decision when a recorded timeline is replayed.

The authoritative set of **supported methods** in the current decoder is:

- `build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs`
- `google.bytestream.ByteStream/Read`
- `google.bytestream.ByteStream/Write`

A target naming any other method is rejected. All other REAPI methods pass
through untouched.

**Delay and Abort** are the message-agnostic faults: they apply to any supported
method and either direction, because they do not inspect or rewrite payload
bytes. This is the dimension the fault-coverage work widens — the intent is to
enlarge the supported-method allow-list so Delay/Abort cover the broader REAPI
surface (Execution, ActionCache, Capabilities, and the remaining CAS methods),
with the list in `validFault` as the single source of truth. Consult that list
for the exact set your build of rechaos accepts.

**Truncate and Dribble** rewrite payload bytes and are therefore restricted to
the two ByteStream payload directions:

- ByteStream `Read` with `direction: "response"`
- ByteStream `Write` with `direction: "request"`

| Fault | FindMissingBlobs | ByteStream Read (response) | ByteStream Read (request) | ByteStream Write (request) | ByteStream Write (response) |
|---|---|---|---|---|---|
| `delay` | yes | yes | yes | yes | yes |
| `abort` | yes | yes | yes | yes | yes |
| `dribble` | no | yes | no | yes | no |
| `truncate` | no | yes | no | yes | no |

(Delay/Abort columns are `yes` for every supported method and direction; the
table shows the ByteStream directions explicitly to contrast with the
payload-rewriting faults.)

## Selection scope

- **Per message.** A rule is evaluated against each observed message
  independently. `direction` and `messageIndex` scope a rule to one side and one
  position within a call.
- **Per call.** `occurrence` scopes a rule to a specific 1-based call to a
  method.
- **First match owns the event.** Ordering in `rules` is significant; put more
  specific rules first.
- **One random step per event.** Each observed message advances the SplitMix64
  state exactly once regardless of whether a rule matched, so decisions are a
  deterministic function of `seed` plus the event trace.

## Decoder error messages

The decoder fails closed with these exact strings:

| Condition | Exact message |
|---|---|
| Unknown field in any object | `unknown JSON field (check policy/timeline spelling)` |
| `version` not equal to `1` | `unsupported policy version` |
| `direction` not `request`/`response` | `direction must be request or response` |
| `status` not a known gRPC status | `unsupported gRPC error status` |
| Unknown `fault.kind` | `unknown fault kind` |
| `chancePpm` above `1000000` | `chancePpm must be in 0..1000000` |
| `occurrence` or `messageIndex` is `0` | `indices are 1-based` |
| Inverted blob-bytes or micros range | `inverted target range` |
| `dribble` with zero rate, zero chunk, or chunk > 4 MiB | `dribble requires positive rate and chunkBytes in 1..4194304` |
| Target names an unsupported method | `policy targets an unsupported method` |
| `truncate` on a non-ByteStream-payload target | `truncate requires Read response or Write request` |

The policy-level checks (`unsupported method`, `truncate` target) run through
`validatePolicy`, which validates every rule's method/direction/fault
combination before the gateway starts. The same `validFault` check runs again
per decision during replay, so a hand-edited timeline that injects an illegal
fault is also rejected (see the [timeline format reference](timeline-format.md)).

## Complete example

See [`examples/fault-policy.json`](../examples/fault-policy.json) for a complete,
runnable policy that exercises truncate, abort, and dribble across all three
supported methods.
