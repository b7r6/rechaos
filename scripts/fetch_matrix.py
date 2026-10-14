#!/usr/bin/env python3
"""Does a Bazel dependency fetch survive one dropped stream from its module proxy?

Runs `rechaos modproxy` as the GOPROXY for a small Bazel workspace whose only
dependency is fetched through gazelle's `go_repository`, resets the first zip
download mid-body with RST_STREAM(INTERNAL_ERROR), and reports which client
configurations cope. Each case is a forced refetch of the one external
repository, which is exactly the step that fails in the wild. stdout is a
markdown table; `--output` writes the same as JSON; the per-request proxy logs
sit next to it.

Needs on PATH: bazel, openssl, and go (to fill the module cache once).
"""

import argparse
import json
import os
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
VICTIM = HERE.parent / "examples" / "dependency-fetch" / "victim"
REPO = "@@gazelle++go_deps+com_github_casbin_casbin_v2"
MODULE = "github.com/casbin/casbin/v2@v2.105.0"

# name -> (GOPROXY template, extra bazel options, what coping looks like)
CASES = {
    "baseline": ("{clean}", [], "fetch succeeds with no fault"),
    "reset-once": ("{fault}", [], "the CI failure: one dropped stream, no retry"),
    "comma-fallback": ("{fault},{clean}", [], "GOPROXY with ',' falls through only on 404/410"),
    "pipe-fallback": ("{fault}|{clean}", [], "GOPROXY with '|' falls through on any error"),
    "downloader-retries": (
        "{fault}",
        ["--experimental_repository_downloader_retries=3"],
        "Bazel's downloader retries do not reach go_repository's fetcher",
    ),
}


def sh(cmd, **kw):
    return subprocess.run(cmd, text=True, capture_output=True, **kw)


def make_pki(out):
    pki = out / "pki"
    pki.mkdir(parents=True, exist_ok=True)
    if not (pki / "cert.pem").exists():
        sh(
            [
                "openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1",
                "-nodes", "-keyout", str(pki / "key.pem"), "-out", str(pki / "cert.pem"), "-days", "30",
                "-subj", "/CN=rechaos-modproxy", "-addext", "subjectAltName=IP:127.0.0.1,DNS:localhost",
            ],
            check=True,
        )
    return pki


def modcache_dirs(download):
    """GOPROXY-layout directory -> the GOMODCACHE it lives in."""
    return download, download.parent.parent


def download_modules(download, workspace, modules):
    """Fill the cache with module@version pairs, through whatever GOPROXY the environment has."""
    _, cache = modcache_dirs(download)
    env = dict(os.environ, GOMODCACHE=str(cache), GOFLAGS="-mod=mod", GOPATH=str(cache.parent / "gopath"))
    sh(["go", "mod", "download"] + sorted(modules), cwd=workspace, env=env, check=True)


def missing_modules(requests):
    """module@version for every GOPROXY path the proxy answered 404 to."""
    found = set()
    for request in requests:
        if request["outcome"] != "missing":
            continue
        match = re.match(r"^/(.+)/@v/(v[^/]+)\.(info|mod|zip)$", request["path"])
        if match:
            unescape = lambda text: re.sub(r"!([a-z])", lambda m: m.group(1).upper(), text)
            found.add(f"{unescape(match.group(1))}@{unescape(match.group(2))}")
    return found


class Proxy:
    def __init__(self, rechaos, root, pki, port, log, rule=None):
        cmd = [
            rechaos, "modproxy", "--root", str(root), "--port", str(port),
            "--certificate", str(pki / "cert.pem"), "--key", str(pki / "key.pem"), "--log", str(log),
        ]
        if rule:
            needle, after, count = rule
            cmd += ["--reset-path", needle, "--reset-after-bytes", str(after), "--reset-count", str(count)]
        self.log = log
        self.proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.url = f"https://127.0.0.1:{port}"

    def stop(self):
        self.proc.send_signal(signal.SIGINT)
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()

    def requests(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines() if line.strip()]


def run_case(name, args, out, pki, modcache, bazel_common, repository_cache):
    template, extra, meaning = CASES[name]
    case_dir = out / name
    case_dir.mkdir(parents=True, exist_ok=True)
    fault = Proxy(args.rechaos, modcache, pki, args.port, case_dir / "fault.jsonl",
                  rule=(".zip", args.reset_after_bytes, args.reset_count))
    clean = Proxy(args.rechaos, modcache, pki, args.port + 1, case_dir / "clean.jsonl")
    time.sleep(1.0)
    env = dict(os.environ, GOPROXY=template.format(fault=fault.url, clean=clean.url), SSL_CERT_FILE=str(pki / "cert.pem"))
    started = time.monotonic()
    result = sh(bazel_common + ["fetch", "--force", f"--repo={REPO}"] + repository_cache + extra, cwd=args.workspace, env=env)
    elapsed = round(time.monotonic() - started, 1)
    fault.stop()
    clean.stop()
    error = next((line.strip() for line in result.stderr.splitlines() if "stream error" in line or "fetch_repo" in line), "")
    zips = lambda proxy: [r for r in proxy.requests() if r["path"].endswith(".zip")]
    record = {
        "case": name,
        "goproxy": template,
        "bazel_options": extra,
        "meaning": meaning,
        "exit": result.returncode,
        "copes": result.returncode == 0,
        "seconds": elapsed,
        "fault_zip_requests": [(r["outcome"], r["bytes"]) for r in zips(fault)],
        "clean_zip_requests": [(r["outcome"], r["bytes"]) for r in zips(clean)],
        "error": error[:300],
    }
    (case_dir / "bazel.stderr").write_text(result.stderr)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rechaos", default="rechaos", help="rechaos binary with the modproxy subcommand")
    parser.add_argument("--workspace", type=pathlib.Path, default=VICTIM, help="Bazel workspace to fetch in")
    parser.add_argument("--out", type=pathlib.Path, required=True, help="Output directory (bazel output base, proxy logs, results)")
    parser.add_argument("--modcache", type=pathlib.Path, help="GOPROXY-layout directory (a GOMODCACHE's cache/download) to serve and fill; default under --out")
    parser.add_argument("--port", type=int, default=3443, help="Fault proxy port; the clean proxy takes the next one")
    parser.add_argument("--reset-after-bytes", type=int, default=65536)
    parser.add_argument("--reset-count", type=int, default=1, help="Dropped streams before the fault proxy serves whole")
    parser.add_argument("--cases", default=",".join(CASES), help="Comma-separated subset of: " + ", ".join(CASES))
    parser.add_argument("--output", type=pathlib.Path, help="Write the results JSON here")
    parser.add_argument("--keep-server", action="store_true", help="Leave the bazel server running afterwards")
    args = parser.parse_args()

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    pki = make_pki(out)
    download = args.modcache.resolve() if args.modcache else out / "modcache" / "cache" / "download"
    download.mkdir(parents=True, exist_ok=True)
    bazel_common = ["bazel", f"--output_base={out / 'output_base'}"]
    repository_cache = [f"--repository_cache={out / 'repository_cache'}"]
    cases = [c.strip() for c in args.cases.split(",") if c.strip()]
    unknown = [c for c in cases if c not in CASES]
    if unknown:
        sys.exit(f"unknown cases: {unknown}")

    # Warm builds against the clean proxy until it serves everything from disk:
    # each miss names a module@version to add to the cache (gazelle resolves a
    # module graph of its own, so go.sum alone does not predict the set).
    for attempt in range(8):
        log = out / f"warm-{attempt}.jsonl"
        clean = Proxy(args.rechaos, download, pki, args.port + 1, log)
        time.sleep(1.0)
        env = dict(os.environ, GOPROXY=clean.url, SSL_CERT_FILE=str(pki / "cert.pem"))
        warm = sh(bazel_common + ["build", "//:victim"] + repository_cache, cwd=args.workspace, env=env)
        clean.stop()
        if warm.returncode == 0:
            break
        (out / "warm.stderr").write_text(warm.stderr)
        missing = missing_modules(clean.requests())
        if not missing:
            sys.exit(f"warm build failed with nothing missing from the cache (see {out / 'warm.stderr'})")
        print(f"filling module cache: {' '.join(sorted(missing))}", file=sys.stderr)
        download_modules(download, args.workspace, missing)
    else:
        sys.exit(f"warm build still failing after filling the cache (see {out / 'warm.stderr'})")

    records = [run_case(name, args, out, pki, download, bazel_common, repository_cache) for name in cases]
    if not args.keep_server:
        sh(bazel_common + ["shutdown"], cwd=args.workspace)
    if args.output:
        args.output.write_text(json.dumps({"module": MODULE, "reset_after_bytes": args.reset_after_bytes,
                                           "reset_count": args.reset_count, "cases": records}, indent=2) + "\n")
    print("| case | GOPROXY | bazel options | copes | fault proxy zip requests | clean proxy zip requests | seconds |")
    print("|---|---|---|---|---|---|---|")
    for r in records:
        print(f"| {r['case']} | `{r['goproxy']}` | {' '.join(r['bazel_options']) or '-'} | {'yes' if r['copes'] else 'no'} | "
              f"{r['fault_zip_requests'] or '-'} | {r['clean_zip_requests'] or '-'} | {r['seconds']} |")
    for r in records:
        if r["error"]:
            print(f"\n{r['case']}: {r['error']}", file=sys.stderr)


if __name__ == "__main__":
    main()
