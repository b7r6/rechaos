# rechaos reference docs

This directory holds the reference-grade documentation for rechaos. These pages describe the implemented interfaces, selected models, checks,
and their limits. A documented model assumption is not a proof about a live
server. For the project
overview, install, and command reference, start at the top-level
[README](../README.md).

| Doc | What it covers |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Design rationale: the pure-core / IO-shell split, the SplitMix64 one-step-per-event determinism model, first-match targeting, the incomplete-vs-changed replay distinction, how the shell maps wire traffic onto the core algebra, the oracle's build-equivalence definition, and a module-by-module map. |
| [`invariants.md`](invariants.md) | The citable catalog of correctness and liveness invariants the chaos monkey asserts, each with its exact statement, REAPI/ByteStream basis, how it is checked, and what a violation looks like. |
| [`core-contracts.md`](core-contracts.md) | The catalog of pure-core invariants (SplitMix64 determinism, the status-code bijection, dribble ceiling-minimality and the chunk-pacing schedule, shrinker deletion-1-minimality, oracle-equivalence congruence, and the forward vs bijective replay semantics), each naming its exact Core function, its `CoreSpec` check-site, and whether it is proved as property or not yet a theorem. |
| [`formal.md`](formal.md) | The Lean 4 verified core: how each Haskell Core definition (`nextSeed`, the SplitMix64 step, the scheduler keystream) maps to `lean/Rechaos/Core.lean`, the proved theorems (`iter_zero`, `iter_succ`, `iter_add`, `advance_add`) and their operational meaning, what is machine-checked in Lean vs. only a QuickCheck property in `CoreSpec.hs`, the no-sorry policy, and how to build (`cd lean && lake build`, gated by `nix flake check`). |
| [`fault-dsl.md`](fault-dsl.md) | The fault-policy DSL: grammar, every field and constraint, the method x direction x fault eligibility matrix, and the exact decoder error strings. |
| [`timeline-format.md`](timeline-format.md) | The on-disk decision-timeline and outcomes-sidecar JSONL schema, plus replay and verification semantics. |
| [`cli-output.md`](cli-output.md) | The stdout verdict-JSON vocabulary emitted by each terminal subcommand (`validate`, `verify-replay`, `oracle`, `minimize`), their exit codes, and the stdout-JSON / stderr-chatter contract. |
| [`../scripts/README.md`](../scripts/README.md) | Index of the operational scripts: build/test wrappers, protobuf tooling, the chaos monkey, the smoke/stress harnesses, and the standalone `repro-*.py` reproducers mapped to their invariants. |
| [`HOUSE_STYLE.md`](HOUSE_STYLE.md) | The Straylight house style for rechaos (adapted from narsil): the pure-core/IO-shell law, guards-and-equations over `case`, invalid-states-unrepresentable, naming, comments and banners, the extension hierarchy, the stdout-data/stderr-humans split, the real `nix flake check` gates, and the reference-leads Lean discipline. Marks what is enforced vs. aspirational. |

The executable guarantees are also exercised by `test/python_contracts.py` and
`test/integration.py`, both run by the Nix `wire` check. They cover independent
endpoint observations, incomplete verdicts, recorded graph reconstruction,
consistency histories, CLI verdicts, and message faults. The reference pages for
these surfaces are [differential testing](differential.md),
[build traces](build-trace.md), [consistency](consistency-oracle.md), and the
[selected Lean store model](reapi-spec.md).
