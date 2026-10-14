#!/usr/bin/env python3
"""Launch an isolated local NativeLink fleet: one scheduler process, N worker
processes, and optionally a Redis the scheduler stores its state in.

This is the rig the scheduler scenarios in scripts/scheduler_steps.py and the
chaos monkey's scheduler mode run against. Everything is a loopback process
you own; nothing here reaches a cluster. The rig writes one manifest
(rig.json) that the step engine, the monkey, and the minimize checker read, so
a frozen finding names exactly the fleet shape it was found on.

stdlib only (subprocess, socket, json, signal). It does not speak REAPI.

    NATIVELINK_BIN=/path/to/nativelink python3 scripts/fleet_rig.py up \\
        --backend redis --workers 3 --slots 4 --memory-kb 20480 \\
        --worker-cache-bytes 8000000 --out runs/rig
    python3 scripts/fleet_rig.py down runs/rig/rig.json
    python3 scripts/fleet_rig.py restart runs/rig/rig.json   # same shape, fresh state

Library use: ``rig = Rig.launch(Params(...), out_dir)``; ``rig.manifest`` is
the dict written to rig.json; ``rig.redis()`` is a tiny RESP client;
``rig.stop()`` tears everything down; ``Rig.restart(manifest_path)`` rebuilds a
fleet with the manifest's parameters from scratch.
"""
import argparse
import dataclasses
import hashlib
import json
import os
import pathlib
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_VERSION = 1


def log(message):
    print(f"[fleet-rig] {message}", file=sys.stderr, flush=True)


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def port_open(port, timeout=0.5):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=timeout):
            return True
    except OSError:
        return False


def wait_for(predicate, seconds, what):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.1)
    raise RuntimeError(f"timed out after {seconds}s waiting for {what}")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# A minimal RESP client: enough for CONFIG GET/SET, INFO, DBSIZE, FLUSHALL.
# No third-party redis client is needed and nothing else in the tree has one.
# ---------------------------------------------------------------------------
class Redis:
    def __init__(self, port, host="127.0.0.1", timeout=3.0):
        self.host, self.port, self.timeout = host, port, timeout

    def command(self, *parts):
        payload = f"*{len(parts)}\r\n".encode()
        for part in parts:
            raw = str(part).encode()
            payload += f"${len(raw)}\r\n".encode() + raw + b"\r\n"
        with socket.create_connection((self.host, self.port), timeout=self.timeout) as s:
            s.sendall(payload)
            reader = s.makefile("rb")
            return self._read(reader)

    def _read(self, reader):
        line = reader.readline()
        if not line:
            raise ConnectionError("redis closed the connection")
        kind, body = line[:1], line[1:-2]
        if kind == b"+":
            return body.decode()
        if kind == b"-":
            raise RuntimeError(body.decode())
        if kind == b":":
            return int(body)
        if kind == b"$":
            n = int(body)
            if n < 0:
                return None
            data = reader.read(n + 2)[:-2]
            return data.decode(errors="replace")
        if kind == b"*":
            n = int(body)
            return None if n < 0 else [self._read(reader) for _ in range(n)]
        raise ValueError(f"unexpected RESP prefix {kind!r}")

    def info(self, section="memory"):
        reply = self.command("INFO", section)
        text = reply if isinstance(reply, str) else ""
        out = {}
        for line in text.splitlines():
            if ":" in line and not line.startswith("#"):
                k, v = line.split(":", 1)
                out[k] = v
        return out

    def used_memory(self):
        return int(self.info("memory").get("used_memory", "0"))

    def set_maxmemory(self, value):
        return self.command("CONFIG", "SET", "maxmemory", str(value))

    def get_maxmemory(self):
        reply = self.command("CONFIG", "GET", "maxmemory")
        return int(str(reply[1])) if isinstance(reply, list) and len(reply) > 1 else 0

    def dbsize(self):
        reply = self.command("DBSIZE")
        return int(reply) if isinstance(reply, int) else 0

    def ping(self):
        return self.command("PING") == "PONG"


# ---------------------------------------------------------------------------
# Fleet parameters and the generated NativeLink configs.
# ---------------------------------------------------------------------------
@dataclasses.dataclass
class Params:
    backend: str = "memory"            # memory | redis
    workers: int = 3
    slots: int = 4                     # cpu_count advertised per worker
    memory_kb: int = 20480             # memory_kb advertised per worker
    worker_cache_bytes: int = 200_000_000
    cas_bytes: int = 2_000_000_000
    worker_timeout_s: int = 10
    max_action_executing_timeout_s: int = 20
    client_action_timeout_s: int = 30
    retain_completed_for_s: int = 10
    max_job_retries: int = 3           # n.b. NativeLink treats 0 as its default (3), so say 3
    max_inflight_tasks: int = 0        # 0 = let platform properties bound concurrency
    reservation_hold_after_s: int = 0  # >0 emits reservation_hold (NativeLink >= v1.7.7); 0 = off
    max_download_timeout_s: int = 600  # worker input-fetch budget (NativeLink default 10 min)
    cas_backend: str = "filesystem"    # filesystem | azure | s3 (the CAS slow tier behind the fault proxy)
    cas_fast_bytes: int = 1_000_000    # CAS fast tier when an object store is the slow tier: tiny, so reads go cold
    store_retries: int = 6             # the rig's default retrier: about 38 s of backoff before the client gives up
    store_retry_delay: float = 0.3
    store_retry_jitter: float = 0.5
    s3_endpoint: str = ""              # "" = start MinIO; otherwise an S3 endpoint you control
    s3_bucket: str = "cas"
    proxy_seed: int = 1
    proxy_port: int = 0
    control_port: int = 0
    emulator_port: int = 0
    instance: str = "main"
    port: int = 0
    worker_api_port: int = 0
    redis_port: int = 0
    nativelink_bin: str = ""
    redis_bin: str = ""
    redis_module: str = ""             # RediSearch module path, "auto", or "" for none
    redis_ld_path: str = ""            # extra LD_LIBRARY_PATH entries the module needs

    @classmethod
    def from_manifest(cls, manifest):
        fields = {f.name for f in dataclasses.fields(cls)}
        values = {k: v for k, v in manifest["params"].items() if k in fields}
        return cls(**values)


def object_store_spec(p: Params, sas_url=""):
    """The CAS slow-tier store for an object-store backend, pointed at the fault
    proxy. The retry triple (6 retries, 0.3 s, 0.5 jitter) is the rig's default:
    about 38 s of backoff before the client gives up."""
    # n.b. NativeLink >= 1.7 keys every cloud store under experimental_cloud_object_store
    # with a `provider` tag; the retry/prefix/http fields are flattened into it.
    common = {"retry": {"max_retries": p.store_retries, "delay": p.store_retry_delay,
                        "jitter": p.store_retry_jitter},
              "insecure_allow_http": True}
    if p.cas_backend == "azure":
        return {"experimental_cloud_object_store": {"provider": "azure", "account_name": AZURITE_ACCOUNT,
                                                    "container": AZURITE_CONTAINER, "sas_url": sas_url, **common}}
    if p.cas_backend == "s3":
        return {"experimental_cloud_object_store": {"provider": "aws", "region": "us-east-1", "bucket": p.s3_bucket,
                                                    "endpoint": f"http://127.0.0.1:{p.proxy_port}",
                                                    "force_path_style": True, **common}}
    raise ValueError(f"no object store spec for cas_backend={p.cas_backend!r}")


def server_config(p: Params, state: pathlib.Path, redis_port, sas_url=""):
    if p.cas_backend == "filesystem":
        cas_store = {"name": "CAS_MAIN_STORE", "filesystem": {
            "content_path": str(state / "server/content-cas"),
            "temp_path": str(state / "server/tmp-cas"),
            "eviction_policy": {"max_bytes": p.cas_bytes}}}
    else:
        # n.b. A tiny fast tier: every input larger than the scenario's working
        # set is served from the object store, through the proxy, on each cold
        # read, which is the path a throttle must be able to reach.
        cas_store = {"name": "CAS_MAIN_STORE", "fast_slow": {
            "fast": {"filesystem": {
                "content_path": str(state / "server/content-cas"),
                "temp_path": str(state / "server/tmp-cas"),
                "eviction_policy": {"max_bytes": p.cas_fast_bytes}}},
            "slow": object_store_spec(p, sas_url)}}
    stores = [
        cas_store,
        {"name": "AC_MAIN_STORE", "filesystem": {
            "content_path": str(state / "server/content-ac"),
            "temp_path": str(state / "server/tmp-ac"),
            "eviction_policy": {"max_bytes": 200_000_000}}},
    ]
    simple = {
        "supported_platform_properties": {
            "cpu_count": "minimum", "memory_kb": "minimum",
            "OSFamily": "priority", "container-image": "priority", "cpu_arch": "priority",
        },
        "worker_timeout_s": p.worker_timeout_s,
        "max_action_executing_timeout_s": p.max_action_executing_timeout_s,
        "client_action_timeout_s": p.client_action_timeout_s,
        "retain_completed_for_s": p.retain_completed_for_s,
        "max_job_retries": p.max_job_retries,
    }
    if p.reservation_hold_after_s:
        simple["reservation_hold"] = {"hold_after_s": p.reservation_hold_after_s}
    if p.backend == "redis":
        stores.append({"name": "SCHEDULER_REDIS_STORE", "redis_store": {
            "addresses": [f"redis://127.0.0.1:{redis_port}/"],
            "mode": "standard",
            "experimental_pub_sub_channel": "rechaos_scheduler_key_change"}})
        simple["experimental_backend"] = {"redis": {"redis_store": "SCHEDULER_REDIS_STORE"}}
    else:
        simple["experimental_backend"] = "memory"
    inst = p.instance
    return {
        "stores": stores,
        "schedulers": [{"name": "MAIN_SCHEDULER", "simple": simple}],
        "servers": [
            {"name": "public", "listener": {"http": {"socket_address": f"127.0.0.1:{p.port}"}},
             "services": {
                 "cas": [{"instance_name": inst, "cas_store": "CAS_MAIN_STORE"}],
                 "ac": [{"instance_name": inst, "ac_store": "AC_MAIN_STORE"}],
                 "bytestream": [{"instance_name": inst, "cas_store": "CAS_MAIN_STORE"}],
                 "execution": [{"instance_name": inst, "cas_store": "CAS_MAIN_STORE",
                                "scheduler": "MAIN_SCHEDULER"}],
                 "capabilities": [{"instance_name": inst,
                                   "remote_execution": {"scheduler": "MAIN_SCHEDULER"}}],
                 # n.b. No Prometheus service: NativeLink >= 1.7 emits OTLP only, so the
                 # rig's readiness and health checks use the HTTP health route.
                 "health": {"path": "/status"},
             }},
            {"name": "worker_api", "listener": {"http": {"socket_address": f"127.0.0.1:{p.worker_api_port}"}},
             "services": {"worker_api": {"scheduler": "MAIN_SCHEDULER"}, "health": {}}},
        ],
        "global": {"max_open_files": 4096},
    }


def worker_config(p: Params, state: pathlib.Path, index):
    wdir = state / f"worker-{index}"
    grpc_store = lambda kind: {"grpc": {  # noqa: E731
        "instance_name": p.instance,
        "endpoints": [{"address": f"grpc://127.0.0.1:{p.port}"}],
        "store_type": kind}}
    local = {
        "name": f"w{index}",
        "worker_api_endpoint": {"uri": f"grpc://127.0.0.1:{p.worker_api_port}"},
        "cas_fast_slow_store": "WORKER_FAST_SLOW_STORE",
        "upload_action_result": {"ac_store": "GRPC_AC"},
        "work_directory": str(wdir / "work"),
        "platform_properties": {
            "cpu_count": {"values": [str(p.slots)]},
            "memory_kb": {"values": [str(p.memory_kb)]},
            "OSFamily": {"values": ["linux", ""]},
            "container-image": {"values": [""]},
            "cpu_arch": {"values": ["x86_64", ""]},
        },
    }
    if p.max_inflight_tasks:
        local["max_inflight_tasks"] = p.max_inflight_tasks
    local["max_download_timeout_s"] = p.max_download_timeout_s
    return {
        "stores": [
            {"name": "GRPC_CAS", **grpc_store("cas")},
            {"name": "GRPC_AC", **grpc_store("ac")},
            {"name": "WORKER_FAST_SLOW_STORE", "fast_slow": {
                "fast": {"filesystem": {
                    "content_path": str(wdir / "content-cas"),
                    "temp_path": str(wdir / "tmp-cas"),
                    "eviction_policy": {"max_bytes": p.worker_cache_bytes}}},
                "slow": {"ref_store": {"name": "GRPC_CAS"}}}},
        ],
        "workers": [{"local": local}],
        "servers": [],
        "global": {"max_open_files": 4096},
    }


# ---------------------------------------------------------------------------
# Process lifecycle.
# ---------------------------------------------------------------------------
def resolve_nativelink(explicit):
    candidate = explicit or os.environ.get("NATIVELINK_BIN") or shutil.which("nativelink")
    if not candidate or not os.access(candidate, os.X_OK):
        raise SystemExit("no nativelink binary: pass --nativelink or set NATIVELINK_BIN")
    return str(pathlib.Path(candidate).resolve())


def resolve_redis(explicit):
    """A redis-server command line. Prefers an explicit path, then PATH, then
    the nixpkgs package through `nix shell` (slow the first time, cached after)."""
    candidate = explicit or os.environ.get("REDIS_SERVER_BIN") or shutil.which("redis-server")
    if candidate:
        return [candidate]
    if shutil.which("nix"):
        return ["nix", "shell", "nixpkgs#redis", "-c", "redis-server"]
    raise SystemExit("no redis-server: pass --redis-bin, set REDIS_SERVER_BIN, or install nix")


MODULE_CACHE = ROOT / ".build" / "redis-modules"


def resolve_redis_module(explicit):
    """The RediSearch module NativeLink's Redis scheduler backend needs
    (`FT.CREATE`). An explicit path wins; "auto" tries $REDIS_SEARCH_MODULE, a
    cached copy under .build/redis-modules, and finally extracts the module from
    the official redis:8 image with docker. Returns "" when no module is wanted."""
    if not explicit:
        return ""
    if explicit != "auto":
        if not os.path.isfile(explicit):
            raise SystemExit(f"redis module not found: {explicit}")
        return str(pathlib.Path(explicit).resolve())
    env = os.environ.get("REDIS_SEARCH_MODULE")
    if env and os.path.isfile(env):
        return env
    cached = MODULE_CACHE / "redisearch.so"
    if cached.is_file():
        return str(cached)
    if not shutil.which("docker"):
        raise SystemExit("no RediSearch module: set REDIS_SEARCH_MODULE or install docker to extract one from redis:8")
    MODULE_CACHE.mkdir(parents=True, exist_ok=True)
    log("extracting redisearch.so from the redis:8 image (one-time)")
    container = subprocess.run(["docker", "create", "redis:8"], capture_output=True, text=True, check=True).stdout.strip()
    try:
        subprocess.run(["docker", "cp", f"{container}:/usr/local/lib/redis/modules/redisearch.so", str(cached)], check=True)
    finally:
        subprocess.run(["docker", "rm", container], capture_output=True)
    return str(cached)


def resolve_redis_ld_path(explicit, module):
    """Library directories the module needs that a nixpkgs redis-server does not
    see: the legacy libcrypt ABI and libstdc++. Explicit wins; otherwise, with a
    module in play and nix available, both are resolved from nixpkgs."""
    if explicit or not module:
        return explicit
    env = os.environ.get("REDIS_MODULE_LD_PATH")
    if env:
        return env
    if not shutil.which("nix"):
        return ""
    paths = []
    for attr in ("nixpkgs#libxcrypt-legacy", "nixpkgs#stdenv.cc.cc.lib"):
        out = subprocess.run(["nix", "build", "--no-link", "--print-out-paths", attr],
                             capture_output=True, text=True)
        if out.returncode == 0 and out.stdout.strip():
            paths.append(out.stdout.strip().splitlines()[-1] + "/lib")
    return ":".join(paths)


# ---------------------------------------------------------------------------
# Object-store emulators and the dialect fault proxy. Azurite's well-known
# development account is public knowledge (it is in every Azurite README); MinIO
# gets throwaway root credentials the rig generates.
# ---------------------------------------------------------------------------
AZURITE_ACCOUNT = "devstoreaccount1"
AZURITE_KEY = ("Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==")
AZURITE_CONTAINER = "cas"


def nix_bin(attr, binary, env_name):
    """A binary from $ENV_NAME, PATH, or nixpkgs (built on first use)."""
    candidate = os.environ.get(env_name) or shutil.which(binary)
    if candidate:
        return candidate
    if not shutil.which("nix"):
        raise SystemExit(f"no {binary}: set {env_name} or install nix")
    env = {**os.environ, "NIXPKGS_ALLOW_INSECURE": "1"}
    out = subprocess.run(["nix", "build", "--impure", "--no-link", "--print-out-paths", f"nixpkgs#{attr}"],
                         capture_output=True, text=True, env=env)
    if out.returncode != 0 or not out.stdout.strip():
        raise SystemExit(f"nix build nixpkgs#{attr} failed: {out.stderr[-500:]}")
    return out.stdout.strip().splitlines()[-1] + "/bin/" + binary


def azure_sign(key_b64, string_to_sign):
    import base64
    import hmac
    import hashlib
    digest = hmac.new(base64.b64decode(key_b64), string_to_sign.encode("utf-8"), hashlib.sha256).digest()
    return base64.b64encode(digest).decode()


def azure_account_sas(account, key_b64, hours=24):
    """An account SAS (version 2020-12-06) over the blob service with read,
    write, delete, list, add, create permissions, signed with the account key."""
    import urllib.parse
    expiry = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + hours * 3600))
    fields = {"sv": "2020-12-06", "ss": "b", "srt": "sco", "sp": "rwdlac", "se": expiry, "spr": "http,https"}
    string_to_sign = "\n".join([account, fields["sp"], fields["ss"], fields["srt"], "", fields["se"], "",
                                 fields["spr"], fields["sv"], "", ""])
    fields["sig"] = azure_sign(key_b64, string_to_sign)
    return urllib.parse.urlencode(fields)


def azure_create_container(port, account, sas, container):
    """PUT the container, authorized by the same account SAS the store will use
    (its permissions include create on the container resource type)."""
    import urllib.request
    request = urllib.request.Request(f"http://127.0.0.1:{port}/{account}/{container}?restype=container&{sas}",
                                     method="PUT", headers={"x-ms-version": "2020-12-06", "Content-Length": "0"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status
    except urllib.error.HTTPError as e:
        if e.code == 409:   # already exists
            return 409
        raise RuntimeError(f"creating Azurite container failed: {e.code} {e.read()[:300]!r}")


def s3_sigv4_put_bucket(port, bucket, access_key, secret_key, region="us-east-1"):
    """Create a bucket on a loopback S3 (MinIO) with a SigV4-signed PUT."""
    import hashlib
    import hmac
    import urllib.request
    now = time.gmtime()
    amz_date = time.strftime("%Y%m%dT%H%M%SZ", now)
    date = time.strftime("%Y%m%d", now)
    host = f"127.0.0.1:{port}"
    payload_hash = hashlib.sha256(b"").hexdigest()
    canonical = "\n".join(["PUT", f"/{bucket}", "", f"host:{host}", f"x-amz-content-sha256:{payload_hash}",
                            f"x-amz-date:{amz_date}", "", "host;x-amz-content-sha256;x-amz-date", payload_hash])
    scope = f"{date}/{region}/s3/aws4_request"
    string_to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical.encode()).hexdigest()])

    def sign(key, msg):
        return hmac.new(key, msg.encode(), hashlib.sha256).digest()
    signing_key = sign(sign(sign(sign(("AWS4" + secret_key).encode(), date), region), "s3"), "aws4_request")
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    auth = (f"AWS4-HMAC-SHA256 Credential={access_key}/{scope}, SignedHeaders=host;x-amz-content-sha256;x-amz-date, "
            f"Signature={signature}")
    request = urllib.request.Request(f"http://{host}/{bucket}", method="PUT",
                                     headers={"x-amz-date": amz_date, "x-amz-content-sha256": payload_hash,
                                              "Authorization": auth, "Content-Length": "0"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status
    except urllib.error.HTTPError as e:
        if e.code == 409:
            return 409
        raise RuntimeError(f"creating MinIO bucket failed: {e.code} {e.read()[:300]!r}")


class Rig:
    def __init__(self, params: Params, out_dir: pathlib.Path):
        self.params = params
        self.out = pathlib.Path(out_dir).resolve()
        self.state = self.out / "state"
        self.logs = self.out / "logs"
        self.processes = {}
        self.identities = {}     # name -> process_identity at spawn, so a stale pid is never signaled
        self.manifest = None
        self.redis_pid = None
        self.store = None       # object-store manifest fragment, when cas_backend is not filesystem
        self.server_env = {}

    @classmethod
    def launch(cls, params: Params, out_dir, fresh_state=True):
        rig = cls(params, out_dir)
        try:
            rig._start(fresh_state)
        except BaseException:
            rig.stop()
            raise
        return rig

    @classmethod
    def restart(cls, manifest_path):
        """Tear down the fleet a manifest describes and start an identical one
        (same ports, same parameters, empty state)."""
        manifest_path = pathlib.Path(manifest_path)
        manifest = json.loads(manifest_path.read_text())
        stop_manifest(manifest)
        params = Params.from_manifest(manifest)
        # The fleet lives where it was first started; a frozen copy of rig.json
        # (a finding's corpus entry) is refreshed with the new pids so a later
        # restart from that copy still finds the right processes.
        rig = cls(params, manifest.get("out_dir", str(manifest_path.parent)))
        try:
            rig._start(fresh_state=True)
        except BaseException:
            rig.stop()
            raise
        if manifest_path.resolve() != rig.manifest_path.resolve():
            manifest_path.write_text(json.dumps(rig.manifest, indent=2) + "\n")
        return rig

    def _start(self, fresh_state):
        p = self.params
        p.nativelink_bin = resolve_nativelink(p.nativelink_bin)
        p.port = p.port or free_port()
        p.worker_api_port = p.worker_api_port or free_port()
        if fresh_state and self.state.exists():
            shutil.rmtree(self.state)
        self.state.mkdir(parents=True, exist_ok=True)
        self.logs.mkdir(parents=True, exist_ok=True)
        redis = None
        if p.backend == "redis":
            p.redis_port = p.redis_port or free_port()
            redis_cmd = resolve_redis(p.redis_bin)
            p.redis_module = resolve_redis_module(p.redis_module)
            p.redis_ld_path = resolve_redis_ld_path(p.redis_ld_path, p.redis_module)
            redis_dir = self.state / "redis"
            redis_dir.mkdir(parents=True, exist_ok=True)
            # noeviction: a full store refuses writes (OOM) rather than silently
            # dropping scheduler state; that is the configuration under which a full
            # store refuses writes, which the store-full step relies on.
            argv = redis_cmd + [
                "--port", str(p.redis_port), "--bind", "127.0.0.1", "--save", "",
                "--appendonly", "no", "--maxmemory-policy", "noeviction",
                "--dir", str(redis_dir), "--loglevel", "warning"]
            if p.redis_module:
                argv += ["--loadmodule", p.redis_module]
            env = {}
            if p.redis_ld_path:
                env["LD_LIBRARY_PATH"] = p.redis_ld_path + (":" + os.environ["LD_LIBRARY_PATH"] if os.environ.get("LD_LIBRARY_PATH") else "")
            self._spawn("redis", argv, env)
            wait_for(lambda: self._alive("redis") and port_open(p.redis_port), 120, "redis to listen")
            redis = Redis(p.redis_port)
            wait_for(lambda: self._try(redis.ping), 20, "redis PING")
            redis.command("FLUSHALL")
            redis.set_maxmemory(0)
            if p.redis_module:
                try:
                    redis.command("FT._LIST")
                except Exception as e:
                    self.stop()
                    raise RuntimeError(f"redis-server has no FT.* commands after loading {p.redis_module}: {e}")
            # n.b. `nix shell ... -c redis-server` execs the server in place, so the
            # spawned pid is the server; but record the pid that owns the port to be
            # sure a store-pause SIGSTOP freezes the server, not a wrapper.
            self.redis_pid = int(redis.info("server").get("process_id", self.processes["redis"].pid))
            self.identities["redis-server"] = process_identity(self.redis_pid)
        sas_url = self._start_object_store() if p.cas_backend != "filesystem" else ""
        server_cfg = self.out / "server.json"
        server_cfg.write_text(json.dumps(server_config(p, self.state, p.redis_port, sas_url), indent=2))
        self._spawn("server", [p.nativelink_bin, str(server_cfg)], self.server_env)
        wait_for(lambda: self._alive("server") and port_open(p.port) and port_open(p.worker_api_port), 30, "scheduler ports")
        wait_for(lambda: self._alive("server") and self._health_ok(), 30, "scheduler /status")
        for index in range(p.workers):
            cfg = self.out / f"worker-{index}.json"
            cfg.write_text(json.dumps(worker_config(p, self.state, index), indent=2))
            self._spawn(f"worker-{index}", [p.nativelink_bin, str(cfg)])
        # Workers register over worker_api; give them a moment and then confirm
        # every process is still alive (a bad config dies within a second).
        time.sleep(1.0)
        dead = [name for name, proc in self.processes.items() if proc.poll() is not None]
        if dead:
            self.stop()
            raise RuntimeError(f"rig processes exited at startup: {dead} (see {self.logs})")
        self.manifest = {
            "version": MANIFEST_VERSION,
            "backend": p.backend,
            "host": "127.0.0.1",
            "port": p.port,
            "health_url": f"http://127.0.0.1:{p.port}/status",
            "worker_api_port": p.worker_api_port,
            "instance": p.instance,
            "workers": p.workers,
            "slots": p.slots,
            "memory_kb": p.memory_kb,
            "worker_cache_bytes": p.worker_cache_bytes,
            "scheduler": {
                "worker_timeout_s": p.worker_timeout_s,
                "max_action_executing_timeout_s": p.max_action_executing_timeout_s,
                "client_action_timeout_s": p.client_action_timeout_s,
                "retain_completed_for_s": p.retain_completed_for_s,
                "max_job_retries": p.max_job_retries,
                "reservation_hold_after_s": p.reservation_hold_after_s,
            },
            "object_store": self.store,
            "worker": {"max_download_timeout_s": p.max_download_timeout_s,
                       "max_inflight_tasks": p.max_inflight_tasks},
            "redis": ({"port": p.redis_port, "pid": self.redis_pid,
                       "module": p.redis_module or None}
                      if p.backend == "redis" else None),
            "pids": {name: proc.pid for name, proc in self.processes.items()},
            "identities": dict(self.identities),
            "nativelink_bin": p.nativelink_bin,
            "nativelink_sha256": sha256_file(p.nativelink_bin),
            "out_dir": str(self.out),
            "state_dir": str(self.state),
            "logs_dir": str(self.logs),
            "params": dataclasses.asdict(p),
            "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        (self.out / "rig.json").write_text(json.dumps(self.manifest, indent=2) + "\n")
        log(f"up: backend={p.backend} cas={p.cas_backend} workers={p.workers} slots={p.slots} memory_kb={p.memory_kb} "
            f"port={p.port} worker_api={p.worker_api_port}"
            + (f" redis={p.redis_port}" if p.backend == "redis" else "")
            + (f" store-proxy={p.proxy_port} control={p.control_port}" if self.store else "")
            + f" -> {self.out / 'rig.json'}")

    def _start_object_store(self):
        """Start the emulator for the CAS backend and the dialect fault proxy in
        front of it; return the Azure sas_url (empty for S3). Fills self.store."""
        p = self.params
        p.proxy_port = p.proxy_port or free_port()
        p.control_port = p.control_port or free_port()
        store_dir = self.state / "object-store"
        store_dir.mkdir(parents=True, exist_ok=True)
        sas_url = ""
        if p.cas_backend == "azure":
            p.emulator_port = p.emulator_port or free_port()
            azurite = nix_bin("azurite", "azurite-blob", "AZURITE_BLOB_BIN")
            self._spawn("azurite", [azurite, "--blobHost", "127.0.0.1", "--blobPort", str(p.emulator_port),
                                    "--location", str(store_dir), "--silent", "--skipApiVersionCheck",
                                    "--debug", str(self.logs / "azurite-debug.log")])
            wait_for(lambda: self._alive("azurite") and port_open(p.emulator_port), 60, "azurite to listen")
            time.sleep(0.5)
            sas = azure_account_sas(AZURITE_ACCOUNT, AZURITE_KEY)
            azure_create_container(p.emulator_port, AZURITE_ACCOUNT, sas, AZURITE_CONTAINER)
            # The SAS signs the path, not the host, so it stays valid through the proxy.
            sas_url = f"http://127.0.0.1:{p.proxy_port}/{AZURITE_ACCOUNT}/{AZURITE_CONTAINER}?{sas}"
            upstream, strip = f"http://127.0.0.1:{p.emulator_port}", 2
        elif p.cas_backend == "s3":
            if p.s3_endpoint:
                upstream = p.s3_endpoint
                access, secret = os.environ.get("AWS_ACCESS_KEY_ID", ""), os.environ.get("AWS_SECRET_ACCESS_KEY", "")
            else:
                p.emulator_port = p.emulator_port or free_port()
                minio = nix_bin("minio", "minio", "MINIO_BIN")
                access, secret = "rechaos", hashlib.sha256(f"{time.time()}{p.proxy_seed}".encode()).hexdigest()[:24]
                self._spawn("minio", [minio, "server", str(store_dir), "--address", f"127.0.0.1:{p.emulator_port}",
                                      "--console-address", "127.0.0.1:0", "--quiet"],
                            {"MINIO_ROOT_USER": access, "MINIO_ROOT_PASSWORD": secret})
                wait_for(lambda: self._alive("minio") and port_open(p.emulator_port), 60, "minio to listen")
                time.sleep(1.0)
                s3_sigv4_put_bucket(p.emulator_port, p.s3_bucket, access, secret)
                upstream = f"http://127.0.0.1:{p.emulator_port}"
            self.server_env.update({"AWS_ACCESS_KEY_ID": access, "AWS_SECRET_ACCESS_KEY": secret,
                                    "AWS_REGION": "us-east-1", "AWS_EC2_METADATA_DISABLED": "true"})
            strip = 1
        else:
            raise ValueError(f"unknown cas_backend {p.cas_backend!r}")
        proxy = ROOT / "scripts" / "s3_fault_proxy.py"
        self._spawn("store-proxy", [sys.executable, "-I", str(proxy), "--dialect", p.cas_backend,
                                    "--upstream", upstream, "--listen", f"127.0.0.1:{p.proxy_port}",
                                    "--control", f"127.0.0.1:{p.control_port}", "--seed", str(p.proxy_seed),
                                    "--strip", str(strip)])
        wait_for(lambda: self._alive("store-proxy") and port_open(p.proxy_port) and port_open(p.control_port), 30, "the store fault proxy")
        self.store = {"dialect": p.cas_backend, "proxy_port": p.proxy_port,
                      "control_url": f"http://127.0.0.1:{p.control_port}",
                      "emulator_port": p.emulator_port or None, "upstream": upstream,
                      "retry": {"max_retries": p.store_retries, "delay": p.store_retry_delay,
                                "jitter": p.store_retry_jitter}}
        return sas_url

    @staticmethod
    def _try(fn):
        try:
            return bool(fn())
        except Exception:
            return False

    def _health_ok(self):
        return health_ok(self.params.port)

    def _spawn(self, name, argv, env=None):
        logfile = (self.logs / f"{name}.log").open("ab")
        proc = subprocess.Popen(argv, stdout=logfile, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=True,
                                env={**os.environ, "RUST_LOG": os.environ.get("RUST_LOG", "warn"), **(env or {})})
        self.processes[name] = proc
        self.identities[name] = process_identity(proc.pid)
        return proc

    def _alive(self, name):
        """The named child is still running (reaped if it has exited)."""
        proc = self.processes[name]
        if proc.poll() is not None:
            raise RuntimeError(f"{name} exited with status {proc.returncode} at startup (see {self.logs / (name + '.log')})")
        return True

    @property
    def manifest_path(self):
        return self.out / "rig.json"

    def redis(self):
        if self.params.backend != "redis":
            raise RuntimeError("this rig has no redis backend")
        return Redis(self.params.redis_port)

    def pid(self, name):
        return self.processes[name].pid

    def stop(self):
        for name, proc in reversed(list(self.processes.items())):
            stop_child(proc, name)
        self.processes.clear()


def process_identity(pid):
    """A pid plus its kernel start time (field 22 of /proc/<pid>/stat), which a
    reused pid cannot reproduce. Empty when /proc is unavailable."""
    try:
        stat = pathlib.Path(f"/proc/{pid}/stat").read_text()
        fields = stat[stat.rindex(")") + 2:].split()
        return {"pid": pid, "starttime": int(fields[19])}
    except (OSError, ValueError, IndexError):
        return {"pid": pid, "starttime": None}


def process_state(pid):
    """The one-letter state of a pid from /proc, or None when it does not exist."""
    try:
        stat = pathlib.Path(f"/proc/{pid}/stat").read_text()
        return stat[stat.rindex(")") + 2:].split()[0]
    except (OSError, ValueError, IndexError):
        return None


def same_process(identity):
    """The pid in `identity` still names the process recorded at spawn."""
    if not identity or identity.get("starttime") is None:
        return process_state(identity.get("pid", -1)) is not None
    return process_identity(identity["pid"]).get("starttime") == identity["starttime"]


def verified_pid(manifest, name):
    """The pid of a rig process named in a manifest, after checking that the
    pid still belongs to the process the rig started. Raises when it does not:
    signaling a reused pid is never acceptable."""
    identities = manifest.get("identities", {})
    pids = manifest.get("pids", {})
    if name == "redis":
        pid = (manifest.get("redis") or {}).get("pid")
        identity = identities.get("redis-server") or ({"pid": pid} if pid else None)
    else:
        pid = pids.get(name)
        identity = identities.get(name) or ({"pid": pid} if pid else None)
    if pid is None or not same_process(identity):
        raise RuntimeError(f"rig process {name!r} (pid {pid}) is not the process the rig started; refusing to signal it")
    return pid


def stop_child(proc, name="process"):
    """Terminate one of this process's own children and reap it."""
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        return
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait(timeout=5)


def kill_process(identity, name="process"):
    """Terminate a rig process named by a manifest identity (not our child), only
    when the pid still belongs to that process."""
    if not same_process(identity):
        log(f"not stopping {name}: pid {identity.get('pid')} is no longer the rig's process")
        return
    pid = identity["pid"]
    try:
        os.killpg(pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        return
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        state = process_state(pid)
        if state is None or state == "Z" or not same_process(identity):
            return
        time.sleep(0.05)
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def stop_manifest(manifest):
    identities = manifest.get("identities", {})
    for name, pid in reversed(list(manifest.get("pids", {}).items())):
        kill_process(identities.get(name) or {"pid": pid}, name)
    time.sleep(0.3)


def healthy(manifest):
    """Every rig process is the one the rig started and is running (not
    stopped or a zombie), and the scheduler answers its health route."""
    identities = manifest.get("identities", {})
    for name, pid in manifest.get("pids", {}).items():
        if not same_process(identities.get(name) or {"pid": pid}):
            return False
        if process_state(pid) in (None, "T", "t", "Z", "X"):
            return False
    redis = manifest.get("redis") or {}
    if redis.get("pid") and process_state(redis["pid"]) in (None, "T", "t", "Z", "X"):
        return False
    return health_ok(manifest["port"], manifest.get("host", "127.0.0.1"), manifest.get("health_url"))


def health_ok(port, host="127.0.0.1", url=None):
    """The scheduler's HTTP health route answers (any 2xx). A manifest for a
    REMOTE fleet (no pids: the rig did not start it) names the route itself
    (`health_url`), since the health service may sit on another listener than
    the REAPI port."""
    try:
        urllib.request.urlopen(url or f"http://{host}:{port}/status", timeout=2).read()
        return True
    except Exception:
        return False


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------
def add_param_args(parser):
    d = Params()
    parser.add_argument("--backend", choices=["memory", "redis"], default=d.backend)
    parser.add_argument("--workers", type=int, default=d.workers)
    parser.add_argument("--slots", type=int, default=d.slots, help="cpu_count per worker")
    parser.add_argument("--memory-kb", type=int, default=d.memory_kb, help="memory_kb per worker")
    parser.add_argument("--worker-cache-bytes", type=int, default=d.worker_cache_bytes,
                        help="fast-tier filesystem store max_bytes per worker")
    parser.add_argument("--cas-bytes", type=int, default=d.cas_bytes)
    parser.add_argument("--worker-timeout-s", type=int, default=d.worker_timeout_s)
    parser.add_argument("--max-action-executing-timeout-s", type=int, default=d.max_action_executing_timeout_s)
    parser.add_argument("--client-action-timeout-s", type=int, default=d.client_action_timeout_s)
    parser.add_argument("--retain-completed-for-s", type=int, default=d.retain_completed_for_s)
    parser.add_argument("--max-job-retries", type=int, default=d.max_job_retries,
                        help="scheduler max_job_retries (NativeLink treats 0 as its default of 3)")
    parser.add_argument("--max-inflight-tasks", type=int, default=d.max_inflight_tasks)
    parser.add_argument("--reservation-hold-after-s", type=int, default=d.reservation_hold_after_s,
                        help="emit scheduler reservation_hold.hold_after_s (NativeLink v1.7.7 and later; 0 = off)")
    parser.add_argument("--max-download-timeout-s", type=int, default=d.max_download_timeout_s,
                        help="worker input-fetch budget; invariant 12's bound")
    parser.add_argument("--cas-backend", choices=["filesystem", "azure", "s3"], default=d.cas_backend,
                        help="CAS slow tier: a local filesystem, or Azurite / MinIO behind the dialect fault proxy")
    parser.add_argument("--cas-fast-bytes", type=int, default=d.cas_fast_bytes,
                        help="CAS fast-tier bytes in front of an object store (tiny, so reads go to the store)")
    parser.add_argument("--store-retries", type=int, default=d.store_retries, help="object-store client max_retries")
    parser.add_argument("--store-retry-delay", type=float, default=d.store_retry_delay)
    parser.add_argument("--store-retry-jitter", type=float, default=d.store_retry_jitter)
    parser.add_argument("--s3-endpoint", default="", help="an S3 endpoint you control instead of a local MinIO "
                                                          "(credentials from AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY)")
    parser.add_argument("--s3-bucket", default=d.s3_bucket)
    parser.add_argument("--proxy-seed", type=int, default=d.proxy_seed, help="fault proxy RNG seed")
    parser.add_argument("--instance", default=d.instance)
    parser.add_argument("--port", type=int, default=0, help="client gRPC port (0 = free)")
    parser.add_argument("--worker-api-port", type=int, default=0)
    parser.add_argument("--redis-port", type=int, default=0)
    parser.add_argument("--nativelink", default="", help="nativelink binary (default $NATIVELINK_BIN or PATH)")
    parser.add_argument("--redis-bin", default="", help="redis-server binary (default PATH, then nix shell)")
    parser.add_argument("--redis-module", default="auto",
                        help="RediSearch module for the redis backend: a path, 'auto' (default: "
                             "$REDIS_SEARCH_MODULE, .build/redis-modules, or extracted from the redis:8 image), "
                             "or '' when the redis-server already has FT.* built in")
    parser.add_argument("--redis-ld-path", default="",
                        help="LD_LIBRARY_PATH entries the module needs (default: libxcrypt-legacy + libstdc++ "
                             "from nixpkgs when a module is loaded; or $REDIS_MODULE_LD_PATH)")


def params_from_args(args):
    return Params(backend=args.backend, workers=args.workers, slots=args.slots, memory_kb=args.memory_kb,
                  worker_cache_bytes=args.worker_cache_bytes, cas_bytes=args.cas_bytes,
                  worker_timeout_s=args.worker_timeout_s,
                  max_action_executing_timeout_s=args.max_action_executing_timeout_s,
                  client_action_timeout_s=args.client_action_timeout_s,
                  retain_completed_for_s=args.retain_completed_for_s, max_job_retries=args.max_job_retries,
                  max_inflight_tasks=args.max_inflight_tasks, reservation_hold_after_s=args.reservation_hold_after_s,
                  max_download_timeout_s=args.max_download_timeout_s, cas_backend=args.cas_backend,
                  cas_fast_bytes=args.cas_fast_bytes, store_retries=args.store_retries,
                  store_retry_delay=args.store_retry_delay, store_retry_jitter=args.store_retry_jitter,
                  s3_endpoint=args.s3_endpoint, s3_bucket=args.s3_bucket, proxy_seed=args.proxy_seed,
                  instance=args.instance, port=args.port,
                  worker_api_port=args.worker_api_port, redis_port=args.redis_port,
                  nativelink_bin=args.nativelink, redis_bin=args.redis_bin,
                  redis_module=args.redis_module, redis_ld_path=args.redis_ld_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    up = sub.add_parser("up", help="start a fleet and write rig.json")
    add_param_args(up)
    up.add_argument("--out", default="runs/rig", help="directory for rig.json, configs, logs, state")
    up.add_argument("--detach", action="store_true", help="return after writing rig.json (processes stay up)")
    down = sub.add_parser("down", help="stop every process a rig.json names")
    down.add_argument("manifest")
    restart = sub.add_parser("restart", help="stop and start an identical fleet with fresh state")
    restart.add_argument("manifest")
    show = sub.add_parser("config", help="print the generated server and worker configs without starting")
    add_param_args(show)
    status = sub.add_parser("status", help="exit 0 if every process in rig.json is alive and the health route answers")
    status.add_argument("manifest")
    args = parser.parse_args()

    if args.command == "config":
        p = params_from_args(args)
        p.port, p.worker_api_port, p.redis_port = p.port or 50090, p.worker_api_port or 50062, p.redis_port or 6379
        state = pathlib.Path("/tmp/rechaos/fleet")
        print(json.dumps({"server": server_config(p, state, p.redis_port),
                          "workers": [worker_config(p, state, i) for i in range(p.workers)]}, indent=2))
        return 0
    if args.command == "down":
        stop_manifest(json.loads(pathlib.Path(args.manifest).read_text()))
        log("down")
        return 0
    if args.command == "status":
        ok = healthy(json.loads(pathlib.Path(args.manifest).read_text()))
        print(json.dumps({"healthy": ok}))
        return 0 if ok else 1
    if args.command == "restart":
        rig = Rig.restart(args.manifest)
        print(str(rig.manifest_path))
        return 0
    out = pathlib.Path(args.out)
    if not out.is_absolute():
        out = ROOT / out
    rig = Rig.launch(params_from_args(args), out)
    print(str(rig.manifest_path), flush=True)
    if args.detach:
        return 0
    stop = []
    signal.signal(signal.SIGINT, lambda *_: stop.append(True))
    signal.signal(signal.SIGTERM, lambda *_: stop.append(True))
    try:
        while not stop:
            time.sleep(0.5)
            dead = [n for n, p in rig.processes.items() if p.poll() is not None]
            if dead:
                log(f"process exited: {dead}; stopping fleet")
                break
    finally:
        rig.stop()
        log("down")
    return 0


if __name__ == "__main__":
    sys.exit(main())
