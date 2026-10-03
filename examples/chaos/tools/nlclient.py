#!/usr/bin/env python3
"""ByteStream load/verify client for the s3-deathspiral rig.

Usage:
  nlclient.py roundtrip                 # single clean write+read, verify digest
  nlclient.py load N SIZE CONC [TAGSEED]# N blobs of SIZE bytes, CONC workers
Writes to CAS on 127.0.0.1:51055 (instance 'main').
"""
import sys, os, hashlib, time, threading, concurrent.futures
sys.path.insert(0, "/home/b7r6/src/rechaos/.build/python")
import grpc
from google.bytestream import bytestream_pb2 as bs

CAS = "127.0.0.1:51055"
WRITE = "/google.bytestream.ByteStream/Write"
READ = "/google.bytestream.ByteStream/Read"
CHUNK = 64 * 1024

def chan():
    return grpc.insecure_channel(CAS, options=[
        ("grpc.max_send_message_length", 64*1024*1024),
        ("grpc.max_receive_message_length", 64*1024*1024)])

def digest(b): return hashlib.sha256(b).hexdigest()

def write_resource(data, uid):
    return f"main/uploads/{uid}/blobs/sha256/{digest(data)}/{len(data)}"
def read_resource(data):
    return f"main/blobs/sha256/{digest(data)}/{len(data)}"

def do_write(ch, data, uid, timeout=30):
    stub = ch.stream_unary(WRITE, request_serializer=bs.WriteRequest.SerializeToString,
                           response_deserializer=bs.WriteResponse.FromString)
    def gen():
        for off in range(0, len(data), CHUNK):
            part = data[off:off+CHUNK]
            yield bs.WriteRequest(resource_name=write_resource(data, uid) if off == 0 else "",
                                  write_offset=off, data=part,
                                  finish_write=(off+len(part) == len(data)))
    resp = stub(gen(), timeout=timeout)
    return resp.committed_size

def do_read(ch, data, timeout=30):
    stub = ch.unary_stream(READ, request_serializer=bs.ReadRequest.SerializeToString,
                           response_deserializer=bs.ReadResponse.FromString)
    buf = b"".join(m.data for m in stub(bs.ReadRequest(resource_name=read_resource(data)), timeout=timeout))
    return buf

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "roundtrip":
        ch = chan()
        data = ("ROUNDTRIP-"+str(time.time())).encode() + b"\x00"*1024
        cs = do_write(ch, data, "rt-"+str(int(time.time()*1000)))
        got = do_read(ch, data)
        print("committed_size", cs, "read_len", len(got), "digest_match", digest(got)==digest(data))
        print("DIGEST", digest(data), "LEN", len(data))
    elif cmd == "load":
        N = int(sys.argv[2]); SIZE = int(sys.argv[3]); CONC = int(sys.argv[4])
        tagseed = sys.argv[5] if len(sys.argv) > 5 else str(int(time.time()))
        results = {"ok":0, "write_err":0, "errors":{}}
        lock = threading.Lock()
        manifest = []
        def one(i):
            ch = chan()
            # unique content per blob so each is a distinct digest/key
            data = (f"BLOB-{tagseed}-{i}-").encode()
            data = data + hashlib.sha256(data).digest() * (max(1,(SIZE-len(data))//32))
            data = (data + b"\x00"*SIZE)[:SIZE]
            d = digest(data)
            t0 = time.time()
            try:
                cs = do_write(ch, data, f"{tagseed}-{i}")
                dt = time.time()-t0
                with lock:
                    results["ok"] += 1
                    manifest.append((d, len(data), "OK", round(dt,3)))
            except grpc.RpcError as e:
                dt = time.time()-t0
                code = e.code().name
                with lock:
                    results["write_err"] += 1
                    results["errors"][code] = results["errors"].get(code,0)+1
                    manifest.append((d, len(data), "ERR:"+code, round(dt,3)))
            finally:
                ch.close()
        t0 = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=CONC) as ex:
            list(ex.map(one, range(N)))
        wall = time.time()-t0
        print("LOAD", "N",N,"SIZE",SIZE,"CONC",CONC,"tagseed",tagseed,"wall",round(wall,2))
        print("RESULT", results)
        # dump manifest for data-loss verification
        mpath = os.environ.get("MANIFEST","/tmp/claude-1001/-home-b7r6-src-rechaos/938e05d3-ad6b-4bca-8210-175bf464aae0/scratchpad/manifest.tsv")
        with open(mpath,"w") as f:
            for d,l,st,dt in manifest: f.write(f"{d}\t{l}\t{st}\t{dt}\n")
        print("MANIFEST", mpath)
