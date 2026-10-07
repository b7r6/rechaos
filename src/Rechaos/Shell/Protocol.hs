-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // shell // protocol
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   proto-lens message inspection and stream edits
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

{- | proto-lens message inspection and stream edits for the REAPI/ByteStream
traffic the proxy relays.

This module reads just enough of each RPC's protobuf payload to drive fault
injection without owning a full schema. It recovers blob and message sizes in
bytes ('blobSize', 'messageSize'), computes the SHA-256 payload fingerprint the
timeline records ('sha256'), and rewrites targeted messages when a fault fires:
'payloadChunks' performs dribble re-chunking at protobuf message boundaries,
'truncatePayload' clips a payload to its first @keepBytes@, and 'corruptPayload'
flips the low bit of the leading bytes in place (length-preserving). The exported method
constant strings ('readMethod', 'writeMethod', 'missingMethod') name the
ByteStream and CAS methods the proxy special-cases. It is cited by
@docs/ARCHITECTURE.md@.
-}
module Rechaos.Shell.Protocol (
  -- * Sizing
  blobSize,
  messageSize,

  -- * Fingerprint
  sha256,

  -- * Stream edits
  payloadChunks,
  truncatePayload,
  corruptPayload,

  -- * Method names
  readMethod,
  writeMethod,
  missingMethod,
) where

import Control.Lens ((&), (.~), (^.))
import Crypto.Hash (Digest, SHA256, hashlazy)
import Data.Bits (xor)
import Data.ByteString qualified as B
import Data.ByteString.Lazy qualified as L
import Data.Int (Int64)
import Data.ProtoLens (Message, decodeMessage, encodeMessage)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Word (Word8)
import Numeric.Natural (Natural)
import Proto.Build.Bazel.Remote.Execution.V2.RemoteExecution qualified as RE
import Proto.Build.Bazel.Remote.Execution.V2.RemoteExecution_Fields qualified as R
import Proto.Google.Bytestream.Bytestream qualified as BS
import Proto.Google.Bytestream.Bytestream_Fields qualified as F
import Rechaos.Core.Types
import Text.Read (readMaybe)

batchReadMethod, batchUpdateMethod :: Text
batchReadMethod = "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchReadBlobs"
batchUpdateMethod = "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchUpdateBlobs"

{- | Fully-qualified @service/method@ name of the ByteStream @Read@ RPC, the
streamed-download method the proxy special-cases for response sizing and edits.
-}
readMethod :: Text
readMethod = "google.bytestream.ByteStream/Read"

{- | Fully-qualified @service/method@ name of the ByteStream @Write@ RPC, the
streamed-upload method the proxy special-cases for request sizing and edits.
-}
writeMethod :: Text
writeMethod = "google.bytestream.ByteStream/Write"

-- | Fully-qualified @service/method@ name of the CAS @FindMissingBlobs@ RPC.
missingMethod :: Text
missingMethod = "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"

getTreeMethod, getActionResultMethod, updateActionResultMethod :: Text
getTreeMethod = "build.bazel.remote.execution.v2.ContentAddressableStorage/GetTree"
getActionResultMethod = "build.bazel.remote.execution.v2.ActionCache/GetActionResult"
updateActionResultMethod = "build.bazel.remote.execution.v2.ActionCache/UpdateActionResult"

decode :: (Message a) => L.ByteString -> Either String a
decode = decodeMessage . L.toStrict
encode :: (Message a) => a -> L.ByteString
encode = L.fromStrict . encodeMessage

{- | Hash the lazy bytes with SHA-256 and return the lowercase hex rendering of
the resulting @'Digest' 'SHA256'@. This is the payload fingerprint the
timeline records and that replay checking compares.
-}
sha256 :: L.ByteString -> Text
sha256 = T.pack . show . (hashlazy :: L.ByteString -> Digest SHA256)

resourceSize :: Text -> Maybe Natural
resourceSize resource = case reverse (T.splitOn "/" resource) of
  size : _hash : rest | "blobs" `elem` rest || "compressed-blobs" `elem` rest -> readMaybe (T.unpack size)
  _ -> Nothing

{- | The total content size in bytes that a message refers to, decoded from the
payload for the given method, or 'Nothing' when the method is not understood
or the bytes fail to decode. ByteStream @Read@/@Write@ requests report the
size from their resource name (see 'readMethod', 'writeMethod'); CAS methods
read digest @size_bytes@ fields, and the batch methods sum the sizes of all
their sub-digests. This is the referenced blob size, not the wire size of the
message itself (for that, use 'messageSize').
-}
blobSize :: Text -> L.ByteString -> Maybe Natural
blobSize method bytes
  | method == readMethod =
      either
        (const Nothing)
        (resourceSize . (^. F.resourceName))
        (decode bytes :: Either String BS.ReadRequest)
  | method == writeMethod =
      either
        (const Nothing)
        (resourceSize . (^. F.resourceName))
        (decode bytes :: Either String BS.WriteRequest)
  | method == missingMethod =
      either (const Nothing) sizes (decode bytes :: Either String RE.FindMissingBlobsRequest)
  | method == batchReadMethod =
      either
        (const Nothing)
        (sumSizes . map (^. R.sizeBytes) . (^. R.digests))
        (decode bytes :: Either String RE.BatchReadBlobsRequest)
  | method == batchUpdateMethod =
      either
        (const Nothing)
        (sumSizes . map (^. R.digest . R.sizeBytes) . (^. R.requests))
        (decode bytes :: Either String RE.BatchUpdateBlobsRequest)
  | method == getActionResultMethod =
      getActionResultRequestSize bytes
  | method == updateActionResultMethod =
      either
        (const Nothing)
        (sumSizes . actionResultDigestSizes . (^. R.actionResult))
        (decode bytes :: Either String RE.UpdateActionResultRequest)
  | method == getTreeMethod =
      either
        (const Nothing)
        (sumSizes . pure . (^. R.rootDigest . R.sizeBytes))
        (decode bytes :: Either String RE.GetTreeRequest)
  | otherwise = Nothing
 where
  sizes req = sumSizes (map (^. R.sizeBytes) (req ^. R.blobDigests))
  sumSizes ns = if all (>= 0) ns then Just (sum (map fromIntegral ns)) else Nothing
  getActionResultRequestSize bs =
    either
      (const Nothing)
      (\req -> sumSizes [req ^. R.actionDigest . R.sizeBytes])
      (decode bs :: Either String RE.GetActionResultRequest)
  actionResultDigestSizes r =
    map (^. R.digest . R.sizeBytes) (r ^. R.outputFiles)
      ++ map (^. R.treeDigest . R.sizeBytes) (r ^. R.outputDirectories)
      ++ maybe [] (\d -> [d ^. R.sizeBytes]) (r ^. R.maybe'stdoutDigest)
      ++ maybe [] (\d -> [d ^. R.sizeBytes]) (r ^. R.maybe'stderrDigest)

{- | The size in bytes of the bulk payload carried by a single message. For a
ByteStream @Read@ response or @Write@ request it is the length of the decoded
@data@ chunk; for every other method, and whenever decoding fails, it falls
back to the length of the raw wire bytes. Unlike 'blobSize' this measures the
one message in hand, not the whole blob it belongs to.
-}
messageSize :: Text -> Direction -> L.ByteString -> Natural
messageSize method direction bytes
  | method == readMethod && direction == Response =
      either
        (const wireSize)
        (fromIntegral . B.length . (^. F.data'))
        (decode bytes :: Either String BS.ReadResponse)
  | method == writeMethod && direction == Request =
      either
        (const wireSize)
        (fromIntegral . B.length . (^. F.data'))
        (decode bytes :: Either String BS.WriteRequest)
  | otherwise = wireSize
 where
  wireSize = fromIntegral (L.length bytes)

{- | Re-chunk a message into dribble-sized pieces for a slow-trickle fault,
returning each piece paired with its payload byte count. ByteStream @Read@
responses and @Write@ requests are split along their @data@ field (capped at
4 MiB per piece, with @Write@ pieces re-offset and the final-write flag moved
to the last piece); every other RPC is paced as one whole message. Splitting
always respects protobuf message boundaries, so no piece is an invalid
message. Fails on a zero @chunk@ size or an out-of-range @Write@ offset.
-}
payloadChunks ::
  Text -> Direction -> Natural -> L.ByteString -> Either String [(Natural, L.ByteString)]
payloadChunks method direction chunk bytes
  | chunk == 0 = Left "zero chunk size"
  | method == readMethod && direction == Response = do
      msg <- decode bytes :: Either String BS.ReadResponse
      pure
        [(fromIntegral (B.length part), encode (msg & F.data' .~ part)) | part <- chunks (msg ^. F.data')]
  | method == writeMethod && direction == Request = do
      msg <- decode bytes :: Either String BS.WriteRequest
      let parts = chunks (msg ^. F.data')
          total = toInteger (B.length (msg ^. F.data'))
          offset = toInteger (msg ^. F.writeOffset)
      if offset < 0 || offset + total > toInteger (maxBound :: Int64)
        then Left "invalid write offset"
        else pure (writeParts msg offset parts)
  | otherwise = Right [(fromIntegral (L.length bytes), bytes)]
 where
  bound = fromIntegral (min chunk 4194304)
  chunks input
    | B.null input = [B.empty]
    | otherwise = go input
  go input
    | B.null input = []
    | otherwise = let (a, b) = B.splitAt bound input in a : go b
  writeParts _ _ [] = []
  writeParts msg offset (p : ps) =
    ( fromIntegral (B.length p)
    , encode
        ( msg
            & F.data' .~ p
            & F.writeOffset .~ fromInteger offset
            & F.finishWrite .~ (null ps && msg ^. F.finishWrite)
        )
    )
      : writeParts msg (offset + toInteger (B.length p)) ps

{- | Clip a rewritable payload to its first @keep@ bytes, re-encoding the
message. For a ByteStream @Read@ response or @Write@ request this keeps only
the leading @keep@ bytes of the @data@ field (marking a truncated @Write@ as
finished); messages of any other shape are not rewritable here and yield a
'Left' rather than being altered.
-}
truncatePayload :: Text -> Direction -> Natural -> L.ByteString -> Either String L.ByteString
truncatePayload method direction keep bytes
  | method == readMethod && direction == Response = do
      msg <- decode bytes :: Either String BS.ReadResponse
      pure (encode (msg & F.data' .~ takeBytes (msg ^. F.data')))
  | method == writeMethod && direction == Request = do
      msg <- decode bytes :: Either String BS.WriteRequest
      pure (encode (msg & F.data' .~ takeBytes (msg ^. F.data') & F.finishWrite .~ True))
  | otherwise = Left "truncate unsupported at this event"
 where
  takeBytes b = B.take (fromIntegral (min keep (fromIntegral (B.length b)))) b

{- | Corrupt a rewritable payload in place, flipping the low bit of each of the
leading @bytes@ bytes of the @data@ field and re-encoding the message. Unlike
'truncatePayload' this is length-preserving: the @data@ field keeps its exact
size (and a @Write@ keeps its @finish_write@ flag), so a server that trusts the
declared length sees no shortfall and must re-hash the content to detect the
tampering. Messages of any other shape are not rewritable here and yield a
'Left' rather than being altered.
-}
corruptPayload :: Text -> Direction -> Natural -> L.ByteString -> Either String L.ByteString
corruptPayload method direction count bytes
  | method == readMethod && direction == Response = do
      msg <- decode bytes :: Either String BS.ReadResponse
      pure (encode (msg & F.data' .~ flipBytes (msg ^. F.data')))
  | method == writeMethod && direction == Request = do
      msg <- decode bytes :: Either String BS.WriteRequest
      pure (encode (msg & F.data' .~ flipBytes (msg ^. F.data')))
  | otherwise = Left "corrupt unsupported at this event"
 where
  n = fromIntegral (min count (fromIntegral (maxBound :: Int))) :: Int
  flipBytes b =
    let (prefix, suffix) = B.splitAt n b
     in B.map (`xor` (1 :: Word8)) prefix `B.append` suffix
