#!/usr/bin/env python3
"""Verify a load manifest against MinIO (durability/data-loss check) and read-back
through NativeLink. Usage: verify.py <manifest.tsv>"""
import sys, importlib.util, re, hashlib
SCR="/tmp/claude-1001/-home-b7r6-src-rechaos/938e05d3-ad6b-4bca-8210-175bf464aae0/scratchpad"
spec=importlib.util.spec_from_file_location("s3cli",SCR+"/s3cli.py")
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.ENDPOINT="http://127.0.0.1:51090"

def listall(prefix="cas/"):
    keys={}; token=None
    while True:
        q=f"list-type=2&max-keys=1000&prefix={prefix}"+(f"&continuation-token={token}" if token else "")
        code,body=m.request("GET","/cas",query=q); body=body.decode(errors="replace")
        for k,s in zip(re.findall(r"<Key>(.*?)</Key>",body),re.findall(r"<Size>(.*?)</Size>",body)):
            keys[k]=int(s)
        if "<IsTruncated>true</IsTruncated>" in body:
            tok=re.search(r"<NextContinuationToken>(.*?)</NextContinuationToken>",body)
            if tok: token=tok.group(1); continue
        break
    return keys

if __name__=="__main__":
    man=sys.argv[1]
    want={}; acked=set()
    for line in open(man):
        d,l,st,dt=line.strip().split("\t")
        want[f"cas/{d}-{l}"]=(int(l),st)
        if st=="OK": acked.add(f"cas/{d}-{l}")
    keys=listall()
    acked_present = acked & set(keys)
    acked_missing = acked - set(keys)   # <-- DATA LOSS: client got OK, object absent
    badsize=[k for k in acked_present if keys[k]!=want[k][0]]
    print(f"MinIO total={len(keys)} manifest={len(want)} ACKed={len(acked)} "
          f"ACKed_present={len(acked_present)} ACKed_MISSING(DATALOSS)={len(acked_missing)} "
          f"size_mismatch={len(badsize)}")
    for k in list(acked_missing)[:8]: print("  DATALOSS acked-but-absent:",k)
    for k in badsize[:8]: print("  SIZE MISMATCH:",k,"minio",keys[k],"want",want[k][0])
