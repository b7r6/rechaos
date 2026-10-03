#!/usr/bin/env python3
"""Warm a small cache target, then compare clean and faulted cache downloads."""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"test"))
from integration import proxy, rule, READ

parser=argparse.ArgumentParser()
parser.add_argument("--host",required=True)
parser.add_argument("--port",type=int,default=50051)
parser.add_argument("--bazel",default="bazel")
parser.add_argument("--javabase")
parser.add_argument("--output",default="runs/bazel")
opts=parser.parse_args()
out=(ROOT/opts.output).resolve()
work=out/"workspace"
work.mkdir(parents=True,exist_ok=True)
(work/"WORKSPACE").write_text('workspace(name="rechaos_smoke")\n')
(work/"MODULE.bazel").write_text('module(name="rechaos_smoke")\n')
(work/"BUILD.bazel").write_text('''genrule(
    name = "artifact",
    outs = ["artifact.txt"],
    cmd = "for i in $$(seq 1 8192); do echo 'rechaos deterministic build artifact v1'; done > $@",
)
''')

def build(name,endpoint,upload):
    root=out/(name+"-root")
    # Unique roots ensure no previous local action-cache hit can mask a download.
    if root.exists():
        raise RuntimeError(f"{root} already exists: choose a new --output directory")
    cmd=[opts.bazel,"--batch",f"--output_user_root={root}","--ignore_all_rc_files"]
    if opts.javabase:cmd.append(f"--server_javabase={opts.javabase}")
    cmd += ["build","--enable_bzlmod=false","--enable_workspace=true","--spawn_strategy=local",
        f"--remote_cache=grpc://{endpoint}","--remote_instance_name=main","--remote_timeout=10","--remote_retries=0",
        "--remote_download_outputs=all",f"--remote_upload_local_results={'true' if upload else 'false'}","//:artifact"]
    run=subprocess.run(cmd,cwd=work,capture_output=True,text=True,timeout=120)
    (out/(name+".log")).write_text(run.stdout+run.stderr)
    result={"exitCode":run.returncode,"remoteCacheHit":"remote cache hit" in run.stderr.lower()}
    if run.returncode==0:
        artifact=work/"bazel-bin/artifact.txt"
        data=artifact.read_bytes()
        tree=out/(name+"-output")
        tree.mkdir()
        (tree/"artifact.txt").write_bytes(data)
        result.update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
    return result

summary={"endpoint":f"{opts.host}:{opts.port}"}
summary["warm"]=build("warm",summary["endpoint"],True)
assert summary["warm"]["exitCode"]==0, summary
with proxy(opts.port,out/"clean-proxy",upstream_host=opts.host) as (_,_,port):
    summary["clean"]=build("clean",f"127.0.0.1:{port}",False)
assert summary["clean"]["exitCode"]==0 and summary["clean"]["remoteCacheHit"], summary
with proxy(opts.port,out/"chaos-proxy",[rule(READ,"response",{"kind":"truncate","keepBytes":7},messageIndex=1)],upstream_host=opts.host) as (_,timeline,port):
    summary["chaos"]=build("chaos",f"127.0.0.1:{port}",False)
assert any(json.loads(line)["injection"] for line in timeline.read_text().splitlines()), "Bazel did not exercise the targeted Read"
if summary["chaos"]["exitCode"]==0:
    result=subprocess.run([str(ROOT/"bin/rechaos"),"oracle",str(out/"clean-output"),str(out/"chaos-output")],capture_output=True,text=True)
    summary["oracle"]=json.loads(result.stdout)
else:
    summary["oracle"]={"verdict":"inconclusive","reason":"Bazel rejected the faulted download; no successful chaos build output"}
(out/"summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print(json.dumps(summary,indent=2))
