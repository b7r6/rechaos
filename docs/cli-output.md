# CLI output reference

This page documents the machine-readable verdict objects that rechaos subcommands
emit, read directly from the emitters in source. It describes **current
behavior**; it is a reference, not a proposal. If you want to change a schema,
change the emitter and then this page — nothing here is aspirational.

## The stdout / stderr contract

Every terminal subcommand (`validate`, `verify-replay`, `oracle`, `minimize`)
follows one rule:

- **stdout is machine-readable.** It carries exactly the verdict object(s)
  described below, one JSON value per line, and nothing else.
- **stderr is human chatter.** Progress banners, the "policy valid" /
  "trees diverged" one-liners, and error diagnostics all go to stderr.

This split is what makes the tool composable in CI: redirect stdout to a file,
parse it, and ignore stderr (or tee it to a log). The convention is stated in
the emitter modules themselves (see `putVerdict` in
[`src/Rechaos/Shell/Oracle.hs`](../src/Rechaos/Shell/Oracle.hs)).

Exit codes carry the pass/fail bit so a script can branch without parsing JSON;
the JSON carries the detail. The two never disagree.

## `validate` and `verify-replay` — the shared label verdict

Both commands emit the single-label object produced by `verdictJSON` /
`putVerdict` in [`src/Rechaos/Shell/Oracle.hs`](../src/Rechaos/Shell/Oracle.hs).
The object has exactly one key:

```json
{"verdict": "valid"}
```

```json
{"verdict": "covered"}
```

| Field | Type | Meaning |
|---|---|---|
| `verdict` | string | The outcome label. `validate` emits `"valid"` on success; `verify-replay` emits `"covered"` on success. |

Failure is not reported as a different label here: an invalid policy or an
uncovered replay is raised as an error, printed to stderr, and surfaced as a
non-zero exit code with no stdout verdict object.

| Command | On success (stdout) | Exit codes |
|---|---|---|
| `validate` | `{"verdict":"valid"}` | `0` valid; `2` invalid or IO error |
| `verify-replay` | `{"verdict":"covered"}` | `0` covered; `2` uncovered or IO error |

## `oracle` — the differential build verdict

The `oracle` command emits the richer object produced by `oracleJSON` in
[`src/Rechaos/Shell/Oracle.hs`](../src/Rechaos/Shell/Oracle.hs). The `verdict`
key takes one of three values, and only the diverged case carries a `changes`
array.

### `equivalent`

```json
{"verdict": "equivalent"}
```

The clean and chaos output trees are byte-for-byte equal over their relative
paths. Exit code `0`.

### `diverged`

```json
{
  "verdict": "diverged",
  "changes": [
    {"path": "artifact", "clean": "File \"<sha256>\" 40 False", "chaos": null}
  ]
}
```

The trees differ. Exit code `1`.

| Field | Type | Meaning |
|---|---|---|
| `verdict` | string | `"diverged"`. |
| `changes` | array | One entry per differing relative path. |
| `changes[].path` | string | The path, relative to the compared tree root. |
| `changes[].clean` | string or null | The clean-side entry rendered via `show`, or `null` if the path is absent on the clean side. |
| `changes[].chaos` | string or null | The chaos-side entry rendered via `show`, or `null` if the path is absent on the chaos side. |

The `clean` / `chaos` strings are the `Show` rendering of the pure `Entry` type
(a `File` with its SHA256, size, and executable bit; a `Directory`; or a
`Symlink`). They are diagnostic, not a stable parse target.

### `inconclusive`

```json
{"verdict": "inconclusive"}
```

The CLI could not snapshot at least one directory (missing, unreadable, changed
during traversal, or unsupported node); the reason goes to stderr. Exit code
`2`. The CLI assumes the caller supplies outputs from successful completed
builds. The library additionally produces this verdict for failed/timed-out
`BuildResult` values.

| Verdict | Exit code |
|---|---|
| `equivalent` | `0` |
| `diverged` | `1` |
| `inconclusive` | `2` |

These codes match the dispatch in [`app/Main.hs`](../app/Main.hs): `Equivalent`
returns normally (`0`), `Diverged` raises `ExitFailure 1`, and `Inconclusive`
raises `ExitFailure 2`.

## `minimize` — the delta-debugging summary

The `minimize` command emits a separate summary object from
[`src/Rechaos/Shell/Minimize.hs`](../src/Rechaos/Shell/Minimize.hs) on stdout
when the search finishes and the final witness is confirmed:

```json
{
  "status": "complete",
  "faults": 3,
  "checkerRuns": 42,
  "signature": "scheduler-queue-leak"
}
```

| Field | Type | Meaning |
|---|---|---|
| `status` | string | `"complete"` after exhausting candidates conclusively; `"inconclusive"` if an unresolved checker outcome remains for the final witness; `"trial-limit"` when it hit `--max-trials` before exhausting candidates. |
| `faults` | number | Count of firing faults in the minimized witness written to `--output`. |
| `checkerRuns` | number | Total number of checker subprocess invocations across all trials. |
| `signature` | string | The exact failure signature that every retained trial preserved (the `--signature` argument). |

The minimized timeline itself is written to the `--output` path; a per-trial
evidence log is written to `<output>.trials.jsonl`. If the baseline or the final
witness fails to reproduce the signature, `minimize` fails on stderr with a
non-zero exit and writes no summary object. `inconclusive` and `trial-limit`
still write a repeatedly confirmed witness and exit 0; callers requiring
minimality must require `status == "complete"`. The limit counts candidate
trials; baseline and final confirmation runs are additional.

| Command | Exit codes |
|---|---|
| `minimize` | `0` ok; `2` usage or IO error |
