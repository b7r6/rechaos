#!/usr/bin/env python3
"""Minimal stdlib SigV4 S3 client for MinIO: create-bucket, list, get, head."""
import sys, os, hashlib, hmac, datetime, urllib.request, urllib.error

ENDPOINT = os.environ.get("S3_ENDPOINT", "http://127.0.0.1:51090")
AK = os.environ.get("AWS_ACCESS_KEY_ID", "deathspiral")
SK = os.environ.get("AWS_SECRET_ACCESS_KEY", "deathspiral123")
REGION = os.environ.get("AWS_REGION", "us-east-1")
SERVICE = "s3"

def _sign(key, msg): return hmac.new(key, msg.encode(), hashlib.sha256).digest()

def sigkey(dstamp):
    k = _sign(("AWS4"+SK).encode(), dstamp)
    k = _sign(k, REGION); k = _sign(k, SERVICE); return _sign(k, "aws4_request")

def _canon_query(query):
    if not query: return ""
    import urllib.parse as up
    parts=[]
    for kv in query.split("&"):
        if "=" in kv: k,v=kv.split("=",1)
        else: k,v=kv,""
        parts.append((up.quote(k,safe="-_.~"), up.quote(v,safe="-_.~")))
    parts.sort()
    return "&".join(f"{k}={v}" for k,v in parts)

def request(method, path, body=b"", query=""):
    # path-style: /bucket or /bucket/key
    query = _canon_query(query)
    host = ENDPOINT.split("://",1)[1]
    now = datetime.datetime.utcnow()
    amzdate = now.strftime("%Y%m%dT%H%M%SZ"); dstamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(body).hexdigest()
    canonical_uri = path
    canonical_querystring = query
    canonical_headers = f"host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amzdate}\n"
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = f"{method}\n{canonical_uri}\n{canonical_querystring}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    scope = f"{dstamp}/{REGION}/{SERVICE}/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amzdate}\n{scope}\n{hashlib.sha256(canonical_request.encode()).hexdigest()}"
    sig = hmac.new(sigkey(dstamp), string_to_sign.encode(), hashlib.sha256).hexdigest()
    auth = f"AWS4-HMAC-SHA256 Credential={AK}/{scope}, SignedHeaders={signed_headers}, Signature={sig}"
    url = ENDPOINT + path + (("?"+query) if query else "")
    req = urllib.request.Request(url, data=body if method in ("PUT","POST") else None, method=method)
    req.add_header("Host", host); req.add_header("x-amz-date", amzdate)
    req.add_header("x-amz-content-sha256", payload_hash); req.add_header("Authorization", auth)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "mb":
        code, body = request("PUT", f"/{sys.argv[2]}")
        print("mb", code, body[:300].decode(errors="replace"))
    elif cmd == "ls":
        bucket = sys.argv[2]; prefix = sys.argv[3] if len(sys.argv)>3 else ""
        code, body = request("GET", f"/{bucket}", query=f"list-type=2&prefix={prefix}")
        print("ls", code)
        import re
        for m in re.findall(r"<Key>(.*?)</Key>", body.decode(errors="replace")): print("  ", m)
        for m in re.findall(r"<Size>(.*?)</Size>", body.decode(errors="replace")): print("   size", m)
    elif cmd == "get":
        bucket, key = sys.argv[2], sys.argv[3]
        code, body = request("GET", f"/{bucket}/{key}")
        sha = hashlib.sha256(body).hexdigest()
        print("get", code, "len", len(body), "sha256", sha)
    elif cmd == "head":
        bucket, key = sys.argv[2], sys.argv[3]
        code, body = request("HEAD", f"/{bucket}/{key}")
        print("head", code)
