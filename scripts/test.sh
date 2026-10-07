#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Build against the pinned dev-shell package set, then check core and wire paths.
bash scripts/build.sh
rechaos_build_dir="${RECHAOS_BUILD_DIR:-.build/cabal}"
runghc Setup.hs test --builddir="$rechaos_build_dir" --show-details=direct
export RECHAOS_BIN
RECHAOS_BIN="$(realpath "$rechaos_build_dir/build/rechaos/rechaos")"
bash scripts/test-python.sh
