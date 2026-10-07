#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Shared by the Nix wire gate and the development test wrapper.
mkdir -p .build/python
mapfile -t protos < <(rg --files proto -g '*.proto')
python3 -m grpc_tools.protoc -Iproto --python_out=.build/python --grpc_python_out=.build/python "${protos[@]}"
python3 -m unittest discover -s test -p '*_contracts.py' -v
python3 scripts/consistency_oracle.py self-test
python3 scripts/process_chaos.py demo
python3 test/integration.py --output "${RECHAOS_TEST_OUTPUT:-runs/integration}"
