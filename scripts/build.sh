#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Use Cabal's build driver with the package set already supplied by nix develop.
# cabal-install's solver cannot select the intentional random 1.2/1.3 split in
# that set. Setup uses rechaos.cabal directly, as the Nix package builder does.
rechaos_build_dir="${RECHAOS_BUILD_DIR:-.build/cabal}"
runghc Setup.hs configure --builddir="$rechaos_build_dir" --enable-tests
runghc Setup.hs build --builddir="$rechaos_build_dir" --jobs=2
