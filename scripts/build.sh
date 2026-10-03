#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -x .ghc/bin/ghc ]]; then export PATH="$PWD/.ghc/bin:$PATH"; fi
mkdir -p bin .build
ghc --make -O0 -threaded -rtsopts -Wall -Wcompat -isrc -igenerated -iapp \
  -outputdir .build app/Main.hs -o bin/rechaos
