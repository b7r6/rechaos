#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Pure-core QuickCheck/HUnit suite via cabal, then the independent Python
# gRPC wire-level peer. Run inside `nix develop` (ghc + cabal-install + python).
cabal test core
mkdir -p .build/python
mapfile -t protos < <(rg --files proto -g '*.proto')
python3 -m grpc_tools.protoc -Iproto --python_out=.build/python --grpc_python_out=.build/python "${protos[@]}"
python3 test/integration.py
