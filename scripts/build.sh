#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Single source of truth is rechaos.cabal; build the library, executable, and
# test-suite through cabal. Run inside `nix develop` (ghc + cabal-install).
#
# The core test-suite reads its golden fixtures (test/golden/*) CWD-relative,
# and those fixtures are now listed in rechaos.cabal's extra-source-files, so an
# sdist is self-contained: `cabal sdist` then unpacking the tarball and running
# `cabal test` from inside it passes. This remains a thin cabal wrapper.
cabal build all
