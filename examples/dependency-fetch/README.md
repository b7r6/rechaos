# Dependency-fetch victim workspace

A minimal Bazel workspace with one Go dependency fetched through gazelle's
bzlmod `go_deps` extension. `scripts/fetch_matrix.py` points its `GOPROXY` at
`rechaos modproxy` and forces a refetch of the external repository under a
dropped stream. See [`docs/dependency-fetch.md`](../../docs/dependency-fetch.md).

`MODULE.bazel` uses the host Go toolchain (`go_sdk.host()`), so nothing in the
experiment downloads from outside except the module under test:
`nix shell nixpkgs#go --command python3 scripts/fetch_matrix.py ...`.
