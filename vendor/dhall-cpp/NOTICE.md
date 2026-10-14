# vendor/dhall-cpp

A C++23 Dhall evaluator (lexer, parser, import resolver, normalizer),
vendored for measurement against the reference implementation on rechaos's
inputs. See `docs/dhall-cost.md` for the method and the numbers.

| | |
|---|---|
| Source | https://github.com/straylight-software/libevring, branch `b7r6/cpp-dhall-sensenet-prototype-0x01`, directory `cpp/dhall` |
| Commit | `8fc7c6cbde0e2b75d5e1b65d6ffd3eab5c4dff20` (2026-03-06) |
| Files taken | `dhall.hpp`, `lexer.hpp`, `lexer.cpp`, `parser.hpp`, `parser.cpp`, `import.hpp` |
| Patches here | `lexer.cpp`: double literals re-read with `std::from_chars` (correct rounding); unsigned literals past 2^64-1 become BigInt tokens instead of a truncated Natural; absolute local imports (`/path`) lexed as paths. `parser.cpp`: `Type`, `Kind`, `Sort` accepted as field labels after `.`. Each patch is marked `rechaos:` in the source. `dhall.hpp`, `lexer.hpp`, `parser.hpp`, `import.hpp` are unmodified. |
| Files left behind | `cbor.hpp`, `async_import.hpp`, `http_fetch.hpp`, `http2_fetcher.hpp`, the tests and benchmarks: HTTP imports, CBOR, and the io_uring fetcher are not needed to evaluate local files |
| Added here | `tools/dhall-cpp.cpp`, a command-line driver with a JSON emitter that follows `dhall-to-json`'s conventions |
| License | MIT, as its upstream (`LICENSE` in this directory). |

What the evaluator is and is not: it parses, resolves local imports, and
normalizes. It has **no type checker**; an ill-typed program is evaluated as
far as it goes. The reference implementation's `dhall type` has no
counterpart here, and `dhall-cpp check` means "parses, resolves, and
evaluates", nothing stronger. Its normal form also differs from the standard
in one way that matters for JSON: an applied union constructor
`< A : T >.A x` becomes the record `{ A = x }` (and a nullary `< B >.B`
becomes `{ B = {} }`), so a union value left in a rendered result is
indistinguishable from a one-field record. Scenarios whose `render` merges
the union away are unaffected.
