#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p generated
protoc_binary=$(readlink -f "$(command -v protoc)")
protoc_include="$(dirname "$(dirname "$protoc_binary")")/include"
mapfile -t protos < <(rg --files proto -g '*.proto')
protoc -Iproto -I"$protoc_include" \
  --plugin="protoc-gen-haskell=$(command -v proto-lens-protoc)" \
  --haskell_out=generated "${protos[@]}"
