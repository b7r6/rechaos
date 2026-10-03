# Protocol source pins

These are public protocol definitions, independent of any REAPI server source.

| Source | Commit |
|---|---|
| [bazelbuild/remote-apis](https://github.com/bazelbuild/remote-apis/tree/adbf4a27c86fbea4a37637a6cbcacef372406fe7) | `adbf4a27c86fbea4a37637a6cbcacef372406fe7` |
| [googleapis/googleapis](https://github.com/googleapis/googleapis/tree/0394833bee92e202125b97078d76b1950883f354) | `0394833bee92e202125b97078d76b1950883f354` |

Their licenses are included in this directory. Standard `google/protobuf` types
come from `protoc` and `proto-lens-protobuf-types` in the pinned toolchain.

From `nix develop`, `python3 scripts/fetch-protos.py` refreshes these exact pins
and `bash scripts/generate-protos.sh` regenerates Haskell. No regeneration or
network access is needed for the protocol bindings during an ordinary build.
