# Dependency fetches under a dropped stream (`rechaos modproxy`)

A build has a second remote besides its execution service: the proxies it
fetches dependencies from. When one of them drops a transfer, the build fails
in analysis, before any action is dispatched, and the message looks like this:

```
fetch_repo: github.com/casbin/casbin/v2@v2.105.0: read
"https://proxy.golang.org/github.com/casbin/casbin/v2/@v/v2.105.0.zip":
stream error: stream ID 5; INTERNAL_ERROR; received from peer
```

That is an HTTP/2 `RST_STREAM` with `INTERNAL_ERROR` arriving part-way through a
response body. Nothing in the remote execution path is involved: the fetch runs
on the machine driving the build, inside a Bazel repository rule, and the
client is the Go toolchain's module downloader. This page is about triggering
exactly that fault on demand and measuring which client configurations cope.

## The fault

`rechaos modproxy` is a Go module proxy (the `GOPROXY` protocol, which is a
directory layout over HTTPS) that serves a module cache's `cache/download`
tree over HTTP/2 and TLS and, under a rule, cuts chosen responses after a given
number of body bytes:

```sh
rechaos modproxy --root "$GOMODCACHE/cache/download" --port 3443 \
  --certificate cert.pem --key key.pem \
  --reset-path .zip --reset-after-bytes 65536 --reset-count 1
```

The reset is the HTTP/2 library's own cancel path: the response headers and the
bytes pushed so far are on the wire with the promised `content-length`, then
the stream is reset with `INTERNAL_ERROR`. A client cannot distinguish this from
an upstream that failed for real; `curl --http2` reports exit 92 with
"HTTP/2 stream was not closed cleanly: INTERNAL_ERROR", and Go reports the
message above, stream ID included. HTTP/2 and TLS are what the fault needs
rather than decoration: a plain-text proxy would get HTTP/1.1 from a Go client,
where the nearest fault is a truncated body and the client's behaviour differs.

The rule is pure (`Rechaos.Core.ModuleProxy`): the first `--reset-count`
responses whose path contains `--reset-path` are cut at `--reset-after-bytes`,
every later one is served whole. That models a transient fault and measures a
retry budget: a fetcher that retries once copes with a count of 1 and fails at
2. Every request is logged as one JSON line to stderr (and to `--log`):

```json
{"request":3,"path":"/github.com/casbin/casbin/v2/@v/v2.105.0.zip","bytes":65536,"outcome":"reset"}
```

`outcome` is `complete`, `reset`, `missing` (served 404, which the `GOPROXY`
protocol treats as "not here"), or `rejected` (a path that would leave the
root). The client trusts the proxy's certificate through `SSL_CERT_FILE`, which
Go honours and gazelle's `go_repository` forwards.

## The matrix

`scripts/fetch_matrix.py` puts Bazel in the loop. The victim workspace in
`examples/dependency-fetch/victim` has one dependency, fetched through
gazelle's bzlmod `go_deps` extension, which is the path in the message above.
The runner generates a certificate, fills a module cache from the proxy's own
miss log until a warm build is served entirely from disk (gazelle resolves a
module graph of its own, so the workspace's `go.sum` alone does not predict the
set), and then, per case, starts a fault proxy and a clean proxy and forces a
refetch of the one external repository with `bazel fetch --force --repo=...`,
which is the step that fails in the wild.

```sh
nix shell nixpkgs#go --command python3 scripts/fetch_matrix.py \
  --rechaos .build/cabal/build/rechaos/rechaos --out runs/fetch-matrix \
  --output runs/fetch-matrix/results.json
```

Measured with Bazel 8.7.0, rules_go 0.64.2, gazelle 0.54.0, the host Go
toolchain from nixpkgs, one reset after 64 KiB of a 213 KiB module zip:

| case | `GOPROXY` | Bazel options | copes | fault proxy saw | clean proxy saw |
|---|---|---|---|---|---|
| baseline | clean | | yes | | zip complete |
| reset-once | fault | | **no** | zip reset at 65536 | |
| comma-fallback | `fault,clean` | | **no** | zip reset at 65536 | |
| pipe-fallback | `fault\|clean` | | yes | zip reset at 65536 | zip complete |
| downloader-retries | fault | `--experimental_repository_downloader_retries=3` | **no** | zip reset at 65536 | |

The three failures carry the message above verbatim, stream ID 5 included.
A bare `go mod download` against the same proxies gives the same three
outcomes without Bazel, so the behaviour is the Go module downloader's, not
Bazel's or gazelle's.

Three readings:

- **There is no retry.** One dropped stream on one module zip is a red build.
  The fault proxy's log shows exactly one zip request in every failing case.
- **The comma in `GOPROXY` is not a fallback for this.** `proxy,next` falls
  through only on 404 and 410, by the protocol's definition; a mid-body error
  stops the search. The pipe separator, `proxy|next`, falls through on any
  error, and it is the one configuration here that copes.
- **Bazel's own retries do not reach this fetch.** The downloader retry flag
  governs `repository_ctx.download`; `go_repository` shells out to gazelle's
  `fetch_repo`, which runs the Go downloader, so the flag changes nothing. The
  same holds for a remote downloader: NativeLink's fetch service answers from
  assets already pushed into its store and never downloads from a URI, so it
  cannot absorb the fault either.

What follows: for a module proxy that is a single point of failure, the cheap
mitigation is `GOPROXY=https://proxy.golang.org|direct` (or a second proxy
after the pipe), which turns one dropped stream into a slower fetch rather
than a failed build. A mirror the build owns is the fuller fix, and the
matrix above is the check that a candidate configuration actually survives
the fault rather than only being expected to.

## Scope

This is a property of the build's fetch configuration, not of the remote
execution service, so it is not numbered among the service invariants in
[`invariants.md`](invariants.md). It belongs here because the fault is the
same shape as the object-store egress faults in
[`s3-faults.md`](s3-faults.md) (a transfer that ends early with a retryable
error) and because a build that fails in analysis never reaches the service
that the rest of rechaos exercises. For HTTP/2 faults below the message layer
on the gRPC path (cleartext, frame-level, against a live upstream), see
[`h2-faults.md`](h2-faults.md); `modproxy` is the TLS-terminating server a Go
client will actually speak HTTP/2 to.
