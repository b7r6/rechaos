import sys
import os as _os; sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "..", "..", ".build", "python"))
import grpc
from build.bazel.remote.execution.v2 import remote_execution_pb2 as re
from build.bazel.remote.execution.v2 import remote_execution_pb2_grpc as re_grpc
ch=grpc.insecure_channel("127.0.0.1:51055")
stub=re_grpc.ContentAddressableStorageStub(ch)
digs=[]
for line in open(sys.argv[1]):
    d,l,st,dt=line.strip().split("\t")
    if st=="OK": digs.append((d,int(l)))
digs=digs[:10]
req=re.FindMissingBlobsRequest(instance_name="main",
    blob_digests=[re.Digest(hash=d,size_bytes=l) for d,l in digs])
resp=stub.FindMissingBlobs(req,timeout=10)
missing={(x.hash,x.size_bytes) for x in resp.missing_blob_digests}
print("probed",len(digs),"ACKed-but-lost(FM-1) blobs; NL FindMissingBlobs says MISSING:",len(missing))
print("  -> NL reports PRESENT (but NOT in object store):",len(digs)-len(missing))
