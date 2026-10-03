#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Single source of truth is rechaos.cabal; build the library, executable, and
# test-suite through cabal. Run inside `nix develop` (ghc + cabal-install).
cabal build all
