#!/usr/bin/env python3
"""Minimizer witness for the bounded fleet-smoke artifact (read-only)."""
import argparse
import json
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"test"))
from integration import DATA, grpc, proxy, read, contents

parser=argparse.ArgumentParser()
parser.add_argument("--host",required=True)
parser.add_argument("--port",type=int,default=50051)
opts=parser.parse_args()
verdict={"verdict":"unknown"}
try:
    with tempfile.TemporaryDirectory() as temp:
        with proxy(opts.port,temp,replay=os.environ["RECHAOS_TIMELINE"],sparse=True,upstream_host=opts.host) as (channel,observed,_):
            call=read(channel)
            data=contents(call)
            coverage=subprocess.run([str(ROOT/"bin/rechaos"),"verify-replay",os.environ["RECHAOS_TIMELINE"],str(observed)],capture_output=True)
            if coverage.returncode==0 and call.code()==grpc.StatusCode.OK:
                verdict={"verdict":"triggers","signature":"fleet-torn-read"} if data!=DATA else {"verdict":"does-not-trigger"}
except grpc.RpcError:
    pass  # availability errors cannot stand in for a silent content divergence
pathlib.Path(os.environ["RECHAOS_VERDICT"]).write_text(json.dumps(verdict))
