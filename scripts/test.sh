#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -x .ghc/bin/ghc ]]; then export PATH="$PWD/.ghc/bin:$PATH"; fi
if [[ -x .python/bin/python3 ]]; then export PATH="$PWD/.python/bin:$PATH"; fi
bash scripts/build.sh
ghc --make -O0 -Wall -isrc -itest -outputdir .build/core test/CoreSpec.hs -o .build/core-tests
.build/core-tests
mkdir -p .build/python
mapfile -t protos < <(rg --files proto -g '*.proto')
python3 -m grpc_tools.protoc -Iproto --python_out=.build/python "${protos[@]}"
python3 test/integration.py
