# HTTP/2 frame-level fault proxy (`scripts/h2_fault_proxy.py`)

gRPC rides on HTTP/2. A high-level gRPC stack (grapesy, grpcio) only ever sees
*decoded messages* -- it hands you `FindMissingBlobsResponse`, not the DATA
frames, WINDOW_UPDATEs, RST_STREAMs and GOAWAYs that carried it. A whole class
of real bugs lives strictly *below* that line: flow-control starvation, stream
lifecycle races, and connection-liveness failures. We have already observed some
of these against the live server -- "GOAWAY: too many rst_stream" and healthy
calls stalling behind resets -- and they cannot be reproduced from the message
layer. `h2_fault_proxy.py` is a transparent TCP proxy that speaks raw HTTP/2
(h2c / cleartext gRPC), parses the wire frame-by-frame, and injects faults at the
frame level.

## How it works (and why raw sockets)

The proxy uses a stdlib-only HTTP/2 framing layer (`socket`, `struct`,
`threading`, `random`). It does not use `h2`, `hyperframe`, or an HPACK codec.

Key design choice: we splice the connection at the **frame boundary** and
forward each frame's bytes *verbatim* unless a rule mutates it. We deliberately
do **not** maintain an HPACK dynamic table or re-encode HEADERS blocks. That
keeps both peers' HPACK decoders consistent (dropping or reordering a
HEADERS/CONTINUATION frame would desync them), while still letting us:

* fabricate brand-new frames: RST_STREAM, GOAWAY, PING, WINDOW_UPDATE, SETTINGS;
* drop / delay whole frames: SETTINGS, WINDOW_UPDATE, PING;
* fragment and reorder DATA frames without changing HPACK state;
* rewrite SETTINGS values and GOAWAY last-stream-id / error code;
* inject a *synthetic* trailers HEADERS frame using an HPACK literal field that
  needs zero dynamic-table state.

The proxy also transparently handles the client connection preface
(`PRI * HTTP/2.0...`) -- it is consumed on the client->upstream side and replayed
to the upstream before any frame.

## Fault menu

Selectable by `--direction {c2s,s2c,both}`, `--stream <id>`, `--probability
<0..1>`, and a deterministic `--seed`. `c2s` = client->upstream,
`s2c` = upstream->client.

| `--fault`                 | Bug class          | What it does |
|---------------------------|--------------------|--------------|
| `withhold-window-update`  | flow-control       | Drops WINDOW_UPDATE frames so the peer's send window is never replenished -> sender stalls after the initial 64 KiB window. Targets flow-control starvation / deadlock. |
| `zero-window-settings`    | flow-control       | Rewrites/append `SETTINGS_INITIAL_WINDOW_SIZE=0` in a SETTINGS frame, so new streams open with a zero send window. Targets startup flow-control starvation. |
| `rst-stream-flood`        | stream lifecycle   | Forwards the triggering HEADERS/DATA, then emits a burst (`--count`) of RST_STREAM(CANCEL) on that stream. Reproduces the "too many rst_stream" GOAWAY class and reset storms. |
| `goaway-midstream`        | connection liveness| Sends a GOAWAY (last-stream-id below the open stream) while a stream is in flight, after forwarding the original frame. Tests client reconnect / in-flight-call handling. |
| `drop-settings`           | connection liveness| Swallows the peer's initial SETTINGS. The handshake never completes -> connection stall / timeout. |
| `delay-settings`          | connection liveness| Holds the peer's initial SETTINGS for `--delay-ms` before forwarding. Tests handshake-timeout handling. |
| `ping-flood`              | connection liveness| Emits a burst (`--count`) of unsolicited PING frames. Trips server anti-abuse ("too many pings") / keepalive-enforcement logic. |
| `ping-drop`               | connection liveness| Swallows PING frames so the peer's keepalive is never ACKed -> peer declares the connection dead. |
| `data-fragment`           | flow-control / reassembly | Removes optional padding and splits DATA into fragments of at most `--fragment` payload bytes, preserving application bytes and placing END_STREAM only on the last fragment. |
| `data-reorder`            | stream lifecycle   | Buffers DATA separately for each stream and direction and reverses buffered frames before the stream's final DATA or trailers. This deliberately changes application bytes; the expected response is integrity rejection or an RPC error. Zero probability passes through unchanged. |
| `trailer-inject`          | stream lifecycle   | Strips END_STREAM from the final DATA frame and appends a synthetic trailers HEADERS frame (`grpc-status: 2`). Tests trailer handling / status-from-trailers. |
| `header-truncate`         | stream lifecycle   | Drops a HEADERS frame outright. **Note:** this desyncs HPACK on purpose -- use only to exercise hard failure handling, not for a recoverable run. |
| `none`                    | --                 | Transparent pass-through (default). Use to confirm the proxy is correct. |

### Fault class summary

* **Flow-control** (`withhold-window-update`, `zero-window-settings`,
  `data-fragment`): the peer runs out of send window or mis-accounts per-frame
  windows. Symptom: a healthy call hangs with no error.
* **Connection liveness** (`goaway-midstream`, `drop-settings`,
  `delay-settings`, `ping-flood`, `ping-drop`): the whole connection -- not one
  stream -- is torn down, stalled at handshake, or killed by keepalive.
* **Stream lifecycle** (`rst-stream-flood`, `data-reorder`, `trailer-inject`,
  `header-truncate`): a single stream is reset, reordered, or malformed; tests
  how one bad stream affects its neighbors on the same connection.

## Usage

Transparent (correctness check), in front of the live NativeLink:

```
nix develop --command python3 scripts/h2_fault_proxy.py \
    --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052 --fault none
```

Point any gRPC client at `127.0.0.1:50061`. A normal `FindMissingBlobs`
round-trips unchanged.

Inject a GOAWAY mid-stream toward the client:

```
nix develop --command python3 scripts/h2_fault_proxy.py \
    --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052 \
    --fault goaway-midstream --direction s2c --probability 1.0 --seed 7
```

Flood RST_STREAM (reproduce "too many rst_stream"):

```
nix develop --command python3 scripts/h2_fault_proxy.py \
    --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052 \
    --fault rst-stream-flood --direction s2c --count 50 --probability 1.0
```

Starve flow control (drop client->upstream WINDOW_UPDATE):

```
nix develop --command python3 scripts/h2_fault_proxy.py \
    --listen 127.0.0.1:50061 --upstream 127.0.0.1:50052 \
    --fault withhold-window-update --direction c2s --probability 1.0
```

All options:

```
--listen HOST:PORT        listen address (default 127.0.0.1:50061)
--upstream HOST:PORT       upstream gRPC/h2c target (required; NEVER hardcoded)
--fault NAME               one of the faults above (default none)
--direction c2s|s2c|both   direction the fault applies to
--stream ID                restrict fault to one HTTP/2 stream id
--probability 0..1         per-eligible-frame injection probability
--seed INT                 deterministic RNG seed (default 1337)
--count INT                burst size (flood faults) / buffer depth (reorder)
--fragment INT             fragment size in bytes (data-fragment)
--delay-ms INT             delay (delay-settings)
--max-seconds N            auto-shutdown after N seconds (0 = until Ctrl-C)
--quiet                    suppress per-frame logging
```

On shutdown the proxy prints a JSON line with per-direction frame counts and
injected/dropped tallies.

## Validation (performed against live NativeLink 127.0.0.1:50052)

Run via `nix develop` with the Python gRPC runtime, a channel pointed at the
proxy port:

* **Transparent:** `FindMissingBlobs` round-trips -> `missing=1` (the probe blob
  is absent, as expected). Proxy stats show SETTINGS/WINDOW_UPDATE/PING/HEADERS/
  DATA frames forwarded, zero injected, zero dropped.
* **`goaway-midstream` (s2c):** client's gRPC stack reports
  `StatusCode.UNAVAILABLE / "GOAWAY received; Error code: 0; Debug Text:
  rechaos"` -- our fabricated GOAWAY is observable to the client.
* **`rst-stream-flood` (s2c):** client reports
  `StatusCode.CANCELLED / "Received RST_STREAM with error code 8"` -- directly
  reproducing the stream-reset class.

## Limitations / what needs a library

The proxy does **not** re-encode HPACK header blocks. Faults that mutate header
field *values* (arbitrary rename/retype of `:status`, `content-type`,
`grpc-status`, `grpc-message`, or editing an existing trailers block in place)
require an HPACK codec and are **not** implemented on the raw path. They would be
straightforward with the `hpack` library (or the full `h2` state machine), which
is currently absent under `nix develop`. The implemented subset -- injecting a
*synthetic* trailers frame (`trailer-inject`) and dropping a header frame
(`header-truncate`) -- covers the structural cases without touching HPACK state.
`priority`/stream-dependency manipulation and PUSH_PROMISE abuse (gRPC does not
use server push) are also out of scope. If `h2`/`hyperframe`/`hpack` are added to
the dev shell, these value-level header faults are the natural next increment.
