#!/usr/bin/env python3
"""Protocol-only NativeLink fault campaigns with byte and recovery oracles.

No server source imports, fleet configuration edits, or service restarts.
Each run gets fresh deterministic blobs and saves its seed, identities, calls,
fault policies, gateway timelines, metrics, and findings.
"""
import argparse
import collections
import concurrent.futures as cf
import contextlib
import datetime
import hashlib
import json
import pathlib
import statistics
import sys
import threading
import time
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test"))
from integration import bs, re, grpc, proxy, rule, READ, WRITE, MISSING

CHUNK = 65536


def measured(fn):
    started = time.monotonic()
    try:
        value = fn()
        result = {"status": "OK", **value}
    except grpc.FutureCancelledError:
        result = {"status": "CLIENT_CANCELLED"}
    except grpc.RpcError as error:
        result = {"status": error.code().name, "details": error.details()[:1200]}
    result["seconds"] = time.monotonic() - started
    return result


class Blob:
    def __init__(self, label, size, seed, run_id, instance):
        self.label = label
        self.data = hashlib.shake_256(f"{seed}/{run_id}/{label}".encode()).digest(size)
        self.hash = hashlib.sha256(self.data).hexdigest()
        self.size = size
        self.instance = instance
        self.read_name = f"{instance}/blobs/{self.hash}/{self.size}"

    def upload_name(self, writer):
        raw = hashlib.sha256(f"{self.hash}/{writer}".encode()).digest()[:16]
        identifier = uuid.UUID(bytes=raw, version=4)
        return f"{self.instance}/uploads/{identifier}/blobs/{self.hash}/{self.size}"

    def descriptor(self):
        return {"label": self.label, "size": self.size, "sha256": self.hash, "resource": self.read_name}


class Endpoint:
    def __init__(self, address, channel=None):
        self.address = address
        self.channel = channel or grpc.insecure_channel(address)
        self.read_rpc = self.channel.unary_stream("/" + READ,
            request_serializer=bs.ReadRequest.SerializeToString, response_deserializer=bs.ReadResponse.FromString)
        self.write_rpc = self.channel.stream_unary("/" + WRITE,
            request_serializer=bs.WriteRequest.SerializeToString, response_deserializer=bs.WriteResponse.FromString)
        self.query_rpc = self.channel.unary_unary("/google.bytestream.ByteStream/QueryWriteStatus",
            request_serializer=bs.QueryWriteStatusRequest.SerializeToString, response_deserializer=bs.QueryWriteStatusResponse.FromString)
        self.missing_rpc = self.channel.unary_unary("/" + MISSING,
            request_serializer=re.FindMissingBlobsRequest.SerializeToString, response_deserializer=re.FindMissingBlobsResponse.FromString)

    def read(self, blob, offset=0, limit=0, cancel_after=None, delay=0, timeout=8):
        def perform():
            total = 0
            chunks = 0
            digest = hashlib.sha256()
            call = self.read_rpc(bs.ReadRequest(resource_name=blob.read_name, read_offset=offset, read_limit=limit), timeout=timeout)
            try:
                for message in call:
                    total += len(message.data)
                    chunks += 1
                    digest.update(message.data)
                    if cancel_after is not None and chunks >= cancel_after:
                        cancelled = call.cancel()
                        return {"status": "CLIENT_CANCELLED" if cancelled else call.code().name,
                            "bytes": total, "chunks": chunks, "sha256": digest.hexdigest()}
                    if delay:
                        time.sleep(delay)
            finally:
                call.cancel()
            expected = blob.data[offset:] if limit == 0 else blob.data[offset:offset+limit]
            return {"bytes": total, "chunks": chunks, "sha256": digest.hexdigest(),
                "matches": total == len(expected) and digest.hexdigest() == hashlib.sha256(expected).hexdigest()}
        return measured(perform)

    def write(self, blob, writer="default", offset=0, stop_at=None, finish=True,
              pause=0, cancel_after=None, timeout=8):
        stop = threading.Event()
        prefix_queued = threading.Event()
        name = blob.upload_name(writer)
        end = blob.size if stop_at is None else stop_at
        def requests():
            if offset == end:
                yield bs.WriteRequest(resource_name=name, write_offset=offset, finish_write=finish)
                return
            for position in range(offset, end, CHUNK):
                if stop.is_set():
                    return
                data = blob.data[position:min(position+CHUNK,end)]
                yield bs.WriteRequest(resource_name=name if position == offset else "",
                    write_offset=position, data=data, finish_write=finish and position+len(data) == end)
                prefix_queued.set()
                if pause and stop.wait(pause):
                    return
            if cancel_after is not None:
                stop.wait(timeout)
        def perform():
            call = self.write_rpc.future(requests(), timeout=timeout)
            try:
                if cancel_after is not None:
                    prefix_queued.wait(timeout=2)
                    time.sleep(cancel_after)
                    call.cancel()
                result = call.result()
                return {"committedBytes": result.committed_size}
            finally:
                stop.set()
        result = measured(perform)
        result["upload"] = name
        return result

    def query(self, blob, writer="default", timeout=4):
        def perform():
            reply = self.query_rpc(bs.QueryWriteStatusRequest(resource_name=blob.upload_name(writer)),timeout=timeout)
            return {"committedBytes": reply.committed_size, "complete": reply.complete}
        return measured(perform)

    def missing(self, blobs, instance="main", timeout=8):
        def perform():
            reply = self.missing_rpc(re.FindMissingBlobsRequest(instance_name=instance,
                digest_function=re.DigestFunction.SHA256,
                blob_digests=[re.Digest(hash=b.hash,size_bytes=b.size) for b in blobs]), timeout=timeout)
            return {"missing": [{"hash": d.hash, "size": d.size_bytes} for d in reply.missing_blob_digests]}
        return measured(perform)


class Campaign:
    def __init__(self, args):
        self.args = args
        self.out = (ROOT / args.output).resolve()
        self.out.mkdir(parents=True,exist_ok=False)
        self.log = (self.out / "calls.jsonl").open("w",buffering=1)
        self.lock = threading.RLock()
        self.direct = Endpoint(f"{args.host}:{args.port}")
        self.blobs = {}
        self.findings = []
        self.phases = {}
        self.start = time.monotonic()
        self.manifest = vars(args).copy()
        self.save()

    def save(self):
        with self.lock:
            manifest = {**self.manifest, "blobs": [b.descriptor() for b in self.blobs.values()]}
            (self.out / "manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
            (self.out / "summary.json").write_text(json.dumps({"phases":self.phases,"findings":self.findings},indent=2)+"\n")

    def blob(self,label,size):
        blob = Blob(label,size,self.args.seed,self.args.run_id,self.args.instance)
        self.blobs[label] = blob
        self.save()
        return blob

    def record(self,phase,operation,blob,result):
        row = {"phase":phase,"operation":operation,"blob":blob.label if blob else None,
            "atSeconds":time.monotonic()-self.start, **result}
        with self.lock:
            self.log.write(json.dumps(row,separators=(",",":"))+"\n")
        return result

    def finding(self,phase,kind,evidence):
        item={"phase":phase,"kind":kind,"evidence":evidence}
        with self.lock:
            self.findings.append(item)
            print("FINDING",json.dumps(item),flush=True)
            self.save()

    def verify_read(self,phase,endpoint,blob,**kwargs):
        result = self.record(phase,"Read",blob,endpoint.read(blob,**kwargs))
        if result["status"]=="OK" and result.get("matches") is False:
            self.finding(phase,"successful read returned wrong bytes",result)
        return result

    def require_blob(self,phase,blob):
        result=self.record(phase,"Write",blob,self.direct.write(blob))
        if result["status"]!="OK" or result.get("committedBytes")!=blob.size:
            raise RuntimeError(f"setup upload failed: {result}")
        check=self.verify_read(phase,self.direct,blob)
        if check["status"]!="OK" or not check.get("matches"):
            raise RuntimeError(f"setup read failed: {check}")

    def metrics(self,name):
        for host,port,label in [(self.args.host,self.args.port,"public"),("127.0.0.1",50052,"local-cas")]:
            try:
                data=urllib.request.urlopen(f"http://{host}:{port}/metrics",timeout=3).read()
                (self.out/f"metrics-{name}-{label}.prom").write_bytes(data)
            except Exception as error:
                self.record(name,"metrics",None,{"status":"unavailable","details":str(error)})

    @contextlib.contextmanager
    def gateway(self,phase,rules=None,max_seconds=12):
        with proxy(self.args.port,self.out/phase,rules,upstream_host=self.args.host,max_seconds=max_seconds) as (channel,timeline,port):
            yield Endpoint(f"127.0.0.1:{port}",channel),timeline

    def summarize(self,phase,rows):
        times=sorted(r["seconds"] for r in rows if "seconds" in r)
        value={"calls":len(rows),"statuses":dict(collections.Counter(r["status"] for r in rows))}
        if times:
            value.update(p50=statistics.median(times),p95=times[min(len(times)-1,int(len(times)*.95))],maximum=times[-1])
        self.phases[phase]=value
        self.save()
        print(phase,json.dumps(value),flush=True)

    def recovery(self,phase,blob):
        with cf.ThreadPoolExecutor(max_workers=8) as pool:
            rows=list(pool.map(lambda _:self.verify_read(phase,self.direct,blob,timeout=4),range(24)))
        self.summarize(phase,rows)
        bad=[r for r in rows if r["status"]!="OK" or not r.get("matches")]
        if bad:
            self.finding(phase,"clean recovery failed",bad)
        return not bad

    def ranges(self,blob):
        phase="ranges"
        ranges=[(0,0),(0,1),(1,1),(32767,3),(65535,3),(blob.size-1,0),
            (blob.size,0),(blob.size,1),(blob.size-17,1000),(1,65536)]
        rows=[]
        with self.gateway(phase) as (gateway,_):
            for label,endpoint in [("direct",self.direct),("gateway",gateway)]:
                for offset,limit in ranges:
                    result=self.verify_read(phase,endpoint,blob,offset=offset,limit=limit)
                    rows.append(result)
                    if result["status"]!="OK":
                        self.finding(phase,"valid range read failed",{"endpoint":label,"offset":offset,"limit":limit,**result})
        self.summarize(phase,rows)

    def interrupted(self):
        phase="interrupted-writes"
        rows=[]
        modes=["half-close-prefix","cancel-prefix","half-close-full","truncate"]
        for mode in modes:
            blob=self.blob(mode,1024*1024)
            if mode=="truncate":
                faults=[rule(WRITE,"request",{"kind":"truncate","keepBytes":17},messageIndex=2)]
                with self.gateway(phase+"-truncate",faults) as (gateway,_):
                    result=gateway.write(blob,mode,timeout=4)
            elif mode=="cancel-prefix":
                result=self.direct.write(blob,mode,stop_at=CHUNK,finish=False,cancel_after=.1,timeout=4)
            else:
                result=self.direct.write(blob,mode,stop_at=blob.size if mode=="half-close-full" else CHUNK,finish=False,timeout=4)
            rows.append(self.record(phase,mode,blob,result))
            query=self.record(phase,"QueryWriteStatus",blob,self.direct.query(blob,mode))
            missing=self.record(phase,"FindMissingBlobs",blob,self.direct.missing([blob]))
            before=self.verify_read(phase,self.direct,blob,timeout=3)
            if mode!="half-close-full" and before["status"]=="OK":
                self.finding(phase,"incomplete upload exposed as readable",{"mode":mode,"read":before,"query":query,"write":result})
            if mode=="half-close-full" and query.get("complete"):
                self.finding(phase,"upload reported complete without finish_write",{"query":query,"write":result,"read":before})
            if query["status"]=="OK" and not query["complete"]:
                offset=query["committedBytes"]
                if not 0 <= offset <= blob.size:
                    self.finding(phase,"invalid resumable offset",query)
                    continue
                resumed=self.direct.write(blob,mode,offset=offset,timeout=8)
                rows.append(self.record(phase,"resume",blob,resumed))
                if resumed["status"]!="OK":
                    self.finding(phase,"resume from server-reported offset failed",{"query":query,"resume":resumed})
            else:
                retried=self.direct.write(blob,mode+"-retry",timeout=8)
                rows.append(self.record(phase,"fresh-retry",blob,retried))
            after=self.verify_read(phase,self.direct,blob)
            if after["status"]!="OK":
                self.finding(phase,"upload did not recover",after)
        self.summarize(phase,rows)

    def duplicate_writers(self):
        phase="duplicate-writers"
        all_rows=[]
        for round_id in range(self.args.rounds):
            blob=self.blob(f"duplicate-{round_id}",8*1024*1024)
            barrier=threading.Barrier(self.args.concurrency)
            connection = (contextlib.nullcontext((self.direct,None)) if self.args.direct_concurrency
                          else self.gateway(f"{phase}-{round_id}"))
            with connection as (gateway,_):
                def writer(index):
                    barrier.wait(timeout=10)
                    cancelled=index%3==0
                    result=gateway.write(blob,f"writer-{index}",pause=.002 if cancelled else 0,
                        cancel_after=.02 if cancelled else None,timeout=12)
                    self.record(phase,"cancel-write" if cancelled else "Write",blob,result)
                    if result["status"]=="OK":
                        if result["committedBytes"]!=blob.size:
                            self.finding(phase,"incorrect successful committed size",result)
                        read=self.verify_read(phase,self.direct,blob)
                        if read["status"]!="OK":
                            self.finding(phase,"acknowledged upload not readable",read)
                    return result
                with cf.ThreadPoolExecutor(max_workers=self.args.concurrency) as pool:
                    rows=list(pool.map(writer,range(self.args.concurrency)))
            all_rows+=rows
            if not any(r["status"]=="OK" for r in rows):
                self.finding(phase,"all competing writers failed",rows)
            self.verify_read(phase,self.direct,blob)
        self.summarize(phase,all_rows)

    def read_pressure(self,large,health):
        phase="read-pressure"
        rules=[rule(READ,"response",{"kind":"dribble","bytesPerSecond":262144,"chunkBytes":4096},minBlobBytes=large.size)]
        rows=[]
        connection = (contextlib.nullcontext((self.direct,None)) if self.args.direct_concurrency
                      else self.gateway(phase,rules,max_seconds=5))
        with connection as (gateway,_):
            barrier=threading.Barrier(self.args.concurrency)
            def reader(index):
                barrier.wait(timeout=10)
                # Cancel some streams explicitly; others hit their own deadline.
                return self.record(phase,"cancel-read" if index%2 else "deadline-read",large,
                    gateway.read(large,cancel_after=1 if index%2 else None,
                        delay=.02 if self.args.direct_concurrency else 0,timeout=.4+index*.005))
            with cf.ThreadPoolExecutor(max_workers=self.args.concurrency+1) as pool:
                futures=[pool.submit(reader,i) for i in range(self.args.concurrency)]
                for _ in range(12):
                    probe=self.verify_read(phase+"-healthy",gateway,health,timeout=3)
                    rows.append(probe)
                    time.sleep(.04)
                rows.extend(f.result(timeout=8) for f in futures)
            # Same gateway/connection must still carry unrelated healthy traffic.
            for _ in range(12):
                rows.append(self.verify_read(phase+"-healthy-after",gateway,health,timeout=3))
        self.summarize(phase,rows)
        failed_probes=[r for r in rows[:12]+rows[-12:] if r["status"]!="OK" or not r.get("matches")]
        if failed_probes:
            self.finding(phase,"healthy traffic failed during or after read pressure",failed_probes)

    def missing_pressure(self,health):
        phase="missing-retries"
        absent=[self.blob(f"absent-{i}",31+i) for i in range(128)]
        faults=[{**rule(MISSING,"response",{"kind":"abort","status":"Unavailable"}),"chancePpm":600000}]
        all_rows=[]
        with self.gateway(phase,faults,max_seconds=8) as (gateway,_):
            def request(index):
                batch=[absent[(index*8+j)%len(absent)] for j in range(8)]
                rows=[]
                for attempt in range(3):
                    result=gateway.missing(batch,self.args.instance,timeout=4)
                    rows.append(self.record(phase,f"FindMissingBlobs-attempt-{attempt+1}",None,result))
                    if result["status"]=="OK":
                        expected={(b.hash,b.size) for b in batch}
                        returned={(d["hash"],d["size"]) for d in result["missing"]}
                        if returned!=expected:
                            self.finding(phase,"incorrect missing-set response",result)
                        break
                    if result["status"]!="UNAVAILABLE":
                        self.finding(phase,"unexpected FindMissingBlobs failure",result)
                    time.sleep(.01*(2**attempt))
                return rows
            with cf.ThreadPoolExecutor(max_workers=self.args.concurrency+1) as pool:
                futures=[pool.submit(request,i) for i in range(self.args.requests)]
                probes=[]
                while any(not f.done() for f in futures):
                    probes.append(self.verify_read(phase+"-healthy",self.direct,health,timeout=3))
                    time.sleep(.1)
                for f in futures:all_rows.extend(f.result())
            self.summarize(phase+"-healthy",probes)
        self.summarize(phase,all_rows)

    def run(self):
        self.metrics("before")
        health=self.blob("health",65537)
        self.require_blob("setup",health)
        large=self.blob("large",16*1024*1024)
        self.require_blob("setup",large)
        self.recovery("baseline",health)
        selected=self.args.phases.split(",")
        try:
            for name,action in [("ranges",lambda:self.ranges(health)),
                ("interrupted",self.interrupted),("duplicates",self.duplicate_writers),
                ("reads",lambda:self.read_pressure(large,health)),
                ("missing",lambda:self.missing_pressure(health))]:
                if name not in selected and "all" not in selected:continue
                print("START",name,flush=True)
                action()
                self.metrics(name)
                if not self.recovery(name+"-recovery",health):
                    print("Stopping new pressure after failed clean recovery",flush=True)
                    break
        finally:
            self.metrics("after")
            self.save()
            self.log.close()
            self.direct.channel.close()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--host",required=True)
    parser.add_argument("--port",type=int,default=50051)
    parser.add_argument("--instance",default="main")
    parser.add_argument("--seed",type=int,default=20261002)
    parser.add_argument("--run-id",default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    parser.add_argument("--output",required=True)
    parser.add_argument("--concurrency",type=int,default=16)
    parser.add_argument("--rounds",type=int,default=3)
    parser.add_argument("--requests",type=int,default=128)
    parser.add_argument("--phases",default="all")
    parser.add_argument("--direct-concurrency",action="store_true",
        help="Run competing writes and slow/cancelled reads directly against NativeLink")
    args=parser.parse_args()
    if not 2<=args.concurrency<=128:parser.error("concurrency must be 2..128")
    Campaign(args).run()


if __name__=="__main__":
    main()
