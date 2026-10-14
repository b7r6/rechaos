# What Dhall costs rechaos, and when a faster implementation pays

rechaos renders its typed configuration and witnesses (`dhall/`) with the
reference Haskell implementation (`dhall` 1.42.3, `dhall-json` 1.7.12 from
nixpkgs). This page records what that costs, where the cost sits in each loop
that uses it, at what input size it stops being negligible, and the protocol
for measuring a replacement implementation against the same inputs. The
numbers come from [`scripts/dhall_bench.py`](../scripts/dhall_bench.py) on one
workstation (24 cores, 30 GB), medians over five fresh processes per input,
wall time and peak resident set from the child's rusage.

## Method

The harness separates four things a slow number can mean, because they call
for different remedies:

| Measurement | What it isolates | Command |
|---|---|---|
| startup | binary and runtime cost, paid once per invocation | `dhall-to-json` on `{=}` |
| type | parse, import resolution, type-check | `dhall type --quiet --file F` |
| json | parse, type-check, normalize, emit | `dhall-to-json --file F` |
| flake gate | everything CI pays: every module type-checked, every example rendered and validated, fleet configs diffed against the Python emitter | `nix build --rebuild .#checks.<system>.dhall` |

Inputs are the repository's own modules and examples plus generated inputs
along the two axes that grow in practice: **steps per scenario**, in the two
forms a scenario takes (a *literal* list, which is what a frozen witness or a
minimized output is, and a *generated* list built with `Natural/fold` and
`List/fold`, which is how a human authors one), and **workers per fleet**, since
every worker configuration is rendered on each rig start.

## Reference numbers

| input | type | json | peak RSS |
|---|---|---|---|
| startup (`{=}`) | - | 4 ms | 13 MB |
| modules (`Step`, `Rig`, `NativeLink`, `Scenario`, `Limits`, `Weaker`) | 4 to 26 ms each | - | - |
| the six examples | 17 to 29 ms | 17 to 28 ms | 19 to 20 MB |
| literal scenario, 10 steps | 22 ms | 24 ms | 20 MB |
| literal scenario, 100 steps | 46 ms | 68 ms | 23 MB |
| literal scenario, 1000 steps | 495 ms | 521 ms | 63 MB |
| literal scenario, 2000 steps | 991 ms | 731 ms | 116 MB |
| literal scenario, 5000 steps | 1.6 s | 1.9 s | 288 MB |
| literal scenario, 7000 steps | 2.2 s | 3.6 s | 356 MB |
| literal scenario, 10000 steps | 4.7 s | 9.6 s | 548 MB |
| generated scenario, 1000 steps | 20 ms | 53 ms | 26 MB |
| generated scenario, 5000 steps | 16 ms | 183 ms | 60 MB |
| generated scenario, 10000 steps | 32 ms | 1.0 s | 115 MB |
| fleet config, 4 workers | 38 ms | 36 ms | 20 MB |
| fleet config, 64 workers | 47 ms | 96 ms | 21 MB |
| fleet config, 256 workers | 44 ms | 90 ms | 27 MB |
| `dhall` flake gate, full rebuild | | 2.9 s | |

The 2000, 3000, 5000, 7000-step and 128, 256-worker rows come from a second run with
`--step-sizes 2000,3000,5000,7000 --worker-sizes 128,256`; the others are the
script's defaults.

Three readings:

- **Startup is not the cost.** Four milliseconds. An implementation that wins
  on startup alone wins nothing here.
- **Fleet configs are linear and small.** 256 workers render in 90 ms. Even a
  fleet an order of magnitude larger than anything the rig will run stays
  well under a second.
- **Literal step lists are the cliff.** Near-linear to about 5000 steps (about
  0.4 ms and 55 KB of heap per step), then the time exponent between
  successive sizes climbs to 1.9 and 2.7 and the 10k-step file takes 9.6 s
  and 548 MB. Memory grows in step with time, which points at heap and
  garbage-collection pressure in the reference runtime rather than at the
  normalization algorithm; the generated form of the same scenario, which
  carries far less syntax into the type-checker, renders the 10k case in 1 s.

## Where Dhall sits in each loop today

| Loop | Dhall work per iteration | Iteration cost | Share |
|---|---|---|---|
| `nix flake check` | the whole gate | 2.9 s of a multi-minute check | negligible |
| fleet rig start or restart | one scheduler config plus N worker configs | about 3 s per restart | about 1% at 4 workers, 3% at 256 |
| chaos-monkey iteration (if it emitted Dhall) | one scenario of 15 to 110 literal steps | 20 to 100 s | under 0.5% |
| shrink trial (if candidates were Dhall) | one candidate of at most the witness's size | 30 to 60 s, including a rig restart | under 0.2% |

Nothing rechaos does today is bounded by Dhall. The current wire format for
witnesses is JSONL, read directly by `rechaos`; Dhall is the authoring and
configuration layer and the flake gate.

## When it starts to matter

Two things change the picture, and both are foreseeable:

1. **Witness size.** The literal form is what a frozen witness is. A scenario
   long enough to describe a soak (a stream of a few actions per second for an
   hour is 10^4 steps; a day is 10^5) crosses the cliff: 10 s and half a
   gigabyte at 10^4, and the exponent past 7000 steps says 10^5 is minutes and
   many gigabytes, if it completes. At that size the reference implementation
   cannot be the thing that renders a witness per shrink trial, and cannot
   be in a flake gate.
2. **Rendering per event rather than per scenario.** If Dhall moves onto a
   path that evaluates once per action, per trial, or per telemetry record
   (a typed evidence manifest per witness is the obvious candidate), the
   20 to 30 ms floor per evaluation becomes the cost, not the size: 10^4
   evaluations an hour is 5 minutes of Dhall an hour.

The first is a hard wall; the second is a tax. A faster implementation is
justified the moment either is on the roadmap, and the measurement above is
what "faster" has to beat: per-step cost on literal lists, peak memory on
large inputs, and the per-evaluation floor.

## The candidate: a C++ evaluator, measured

`vendor/dhall-cpp/` holds a C++23 Dhall evaluator (lexer, parser, local import
resolver, normalizer) from the `b7r6/cpp-dhall-sensenet-prototype-0x01` branch of
`straylight-software/libevring`, with a small command-line driver and JSON
emitter added here, built with `nix build .#dhall-cpp`. Same harness, same
inputs, `--compare` on:

| input | reference json | dhall-cpp json | speedup | reference RSS | dhall-cpp RSS | equal |
|---|---|---|---|---|---|---|
| startup (`{=}`) | 4 ms | 3 ms | | 13 MB | 13 MB | |
| the four example scenarios | 17 to 28 ms | 3 ms | 6 to 9x | 19 MB | 13 MB | yes |
| literal scenario, 100 steps | 68 ms | 4 ms | 17x | 23 MB | 13 MB | yes |
| literal scenario, 1000 steps | 521 ms | 16 ms | 33x | 63 MB | 20 MB | yes |
| literal scenario, 10000 steps | 9.6 s | 276 ms | 35x | 548 MB | 494 MB | yes |
| generated scenario, 1000 steps | 53 ms | 20 ms | 2.7x | 26 MB | 26 MB | yes |
| generated scenario, 10000 steps | 1.0 s | 561 ms | 1.8x | 115 MB | 1244 MB | yes |
| fleet config, 64 workers | 96 ms | 4 ms | 24x | 21 MB | 13 MB | **no** |

Three readings, and they are the vendor decision:

- **On the cliff it is a different machine.** Literal witnesses, the form a
  frozen or minimized scenario takes, render 33 to 35 times faster and the
  output is equal as parsed JSON on every scenario input up to 10k steps. The
  10k witness goes from 9.6 s to 276 ms. That is the number that matters for
  rendering a witness per shrink trial at soak scale.
- **Memory is not a win.** The evaluator allocates into an arena it never
  frees, so peak RSS tracks total allocation, not live data: 494 MB on the 10k
  literal (about the same as the reference) and 1.2 GB on the 10k generated
  scenario, ten times the reference. Time at that size is still better, but a
  10^5-step witness would be a multi-gigabyte process. Arena reset at import
  and fold boundaries is the fix, and it is the evaluator's, not the harness's.
- **It is not yet the same language.** Four gaps, three patched here, one not:
  1. the lexer accumulated double literals digit by digit and was not
     correctly rounded (`0.3` read back as `0.30000000000000004`, which would
     have failed the retry-delay comparison); patched to re-read the literal
     with `strtod`;
  2. the parser rejected the keyword constants `Type`, `Kind`, `Sort` as
     field labels, which rules out the standard `Package.Type` idiom every
     module here uses; patched;
  3. the lexer had no absolute local imports (`/path/file`), which the standard
     grammar allows; patched;
  4. **not patched:** the normal form of an applied union constructor is the
     one-field record `{ A = x }` (and `{ B = {} }` for a nullary one), where
     the standard keeps `< A : T >.A x`. Any union value left in a rendered
     result therefore cannot be told from a record, and `dhall-to-json`'s
     convention (payload for a constructor with one, name for one without)
     cannot be applied. That is why both fleet configs compare **no**: their
     scheduler backend is a union value by design. Every scenario compares
     yes because `Scenario.render` merges the step union away before output.

The driver written here follows `dhall-to-json`'s conventions and was checked
against it on every scenario input and a set of edge cases (control
characters and non-ASCII text, nested `Some`, `Some (None T)` in a field,
empty annotated maps, duplicate map keys, large integers). It refuses, with
exit 1, what it cannot render exactly: an integer literal past 64 bits, which
the evaluator holds as a double. Doubles print in C++'s shortest round-trip
form, which can spell a number differently from the reference (`1e+21`
against `1000000000000000000000`) while parsing equal; the comparison is on
parsed JSON for that reason.

And one absence that is not a gap but a category: **there is no type
checker.** `dhall-cpp check` means parsed, resolved, and evaluated. The
guarantees `dhall/` exists to provide (a step kind the engine does not know
is a type error; a rig knob that does not exist is a type error) are the
reference's `dhall type`, which has no counterpart here. Until the evaluator
gains type checking, it can be the renderer behind a type-checked input, never
the gate.

What follows from that for rechaos: the `dhall` flake gate keeps the reference
for type-checking and for the fleet-config comparison, and may switch its
scenario rendering to `dhall-cpp` whenever witness size makes the reference's
cost visible, with `checks.dhall-cpp` holding the two renderers equal as parsed JSON on
every scenario input. Nothing switches today because nothing today is bounded
by Dhall.

## Measuring a replacement

The harness takes the implementation as command templates and checks its
output against the reference on every input before it reports a number:

```sh
nix develop --command python3 scripts/dhall_bench.py \
  --label candidate \
  --type-cmd 'candidate type {file}' \
  --json-cmd 'candidate to-json {file}' \
  --compare --flake-gate
```

`--compare` renders each input with both implementations and fails the run if
any JSON differs after parsing. A result without `--compare` is a speed
number, not an equivalence claim. Both reports are written as JSON
(`--output`) so two runs can be diffed; the table on stdout is the summary.

Promoting a replacement to the gate means: it passes `--compare` on every
input here including the fleet configs, it type-checks, and the gate's two
commands switch to it. The candidate above passes the scenario half of that
bar and neither of the other two; the reference implementation stays in the
gate, because the cost it imposes today rounds to zero.
