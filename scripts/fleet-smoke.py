#!/usr/bin/env python3
"""Small bounded, protocol-only test against an unmodified REAPI endpoint."""
import argparse
import json
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT / "test"))
from integration import grpc, re, DATA, READ, MISSING, digest, write, read, contents, proxy, rule

parser = argparse.ArgumentParser()
parser.add_argument("--host", required=True)
parser.add_argument("--port", type=int, default=50051)
parser.add_argument("--output", default="runs/fleet")
opts = parser.parse_args()
out = ROOT / opts.output
out.mkdir(parents=True,exist_ok=True)
results = {"endpoint":f"{opts.host}:{opts.port}","blobBytes":len(DATA),"sha256":digest(DATA)}

with grpc.insecure_channel(results["endpoint"]) as direct:
    assert write(direct).committed_size == len(DATA)
    clean = contents(read(direct))
    assert clean == DATA
    results["directWriteRead"] = "verified"

with proxy(opts.port,out/"clean",upstream_host=opts.host) as (channel,_,_):
    assert contents(read(channel)) == clean
    results["cleanProxyRead"] = "verified"

with proxy(opts.port,out/"truncate",[rule(READ,"response",{"kind":"truncate","keepBytes":7},messageIndex=1)],upstream_host=opts.host) as (channel,timeline,_):
    call=read(channel)
    torn=contents(call)
    assert torn==clean[:7] and call.code()==grpc.StatusCode.OK
    results["truncatedRead"]={"status":"OK","receivedBytes":len(torn)}
    for name,data in [("clean-output",clean),("chaos-output",torn)]:
        (out/name).mkdir(exist_ok=True)
        (out/name/"artifact").write_bytes(data)
    result=subprocess.run([str(ROOT/"bin/rechaos"),"oracle",str(out/"clean-output"),str(out/"chaos-output")],capture_output=True,text=True)
    assert result.returncode==1, result.stderr
    results["oracle"]=json.loads(result.stdout)
with proxy(opts.port,out/"replay",replay=timeline,upstream_host=opts.host) as (channel,_,_):
    assert contents(read(channel))==torn
    results["replay"]="same 7-byte output"

# Fixed unknown digest, bounded workload, and no fleet configuration changes.
# Unary dribble is message pacing; this does not throttle server -> S3 traffic.
faults=[rule(MISSING,"request",{"kind":"dribble","bytesPerSecond":1024,"chunkBytes":64}),
        {**rule(MISSING,"response",{"kind":"abort","status":"Unavailable"}),"chancePpm":500000}]
with proxy(opts.port,out/"missing-pressure",faults,upstream_host=opts.host) as (channel,_,_):
    rpc=channel.unary_unary('/'+MISSING,request_serializer=re.FindMissingBlobsRequest.SerializeToString,response_deserializer=re.FindMissingBlobsResponse.FromString)
    request=re.FindMissingBlobsRequest(instance_name="main",digest_function=re.DigestFunction.SHA256,
        blob_digests=[re.Digest(hash=digest(b"rechaos intentionally absent probe v1"),size_bytes=43)])
    counts={"OK":0,"UNAVAILABLE":0,"other":0}
    start=time.monotonic()
    for _ in range(24):
        try:
            rpc(request,timeout=3)
            counts["OK"]+=1
        except grpc.RpcError as e:
            if e.code()==grpc.StatusCode.UNAVAILABLE:counts["UNAVAILABLE"]+=1
            else:counts["other"]+=1
        time.sleep(.1)
    results["boundedFindMissingBlobs"]={"calls":24,"counts":counts,"seconds":time.monotonic()-start,
        "s3DeathSpiral":"not established: injection is on client-facing REAPI, not S3 egress"}
with grpc.insecure_channel(results["endpoint"]) as direct:
    assert contents(read(direct))==DATA
    results["postFaultDirectRead"]="verified"
(out/"summary.json").write_text(json.dumps(results,indent=2)+"\n")
print(json.dumps(results,indent=2))
