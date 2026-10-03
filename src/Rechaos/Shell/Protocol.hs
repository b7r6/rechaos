-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // shell // protocol
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   proto-lens message inspection and stream edits
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

module Rechaos.Shell.Protocol (
  blobSize,
  messageSize,
  sha256,
  payloadChunks,
  truncatePayload,
  readMethod,
  writeMethod,
  missingMethod,
) where

import Control.Lens ((&), (.~), (^.))
import Crypto.Hash (Digest, SHA256, hashlazy)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as L
import Data.Int (Int64)
import Data.ProtoLens (Message, decodeMessage, encodeMessage)
import Data.Text (Text)
import qualified Data.Text as T
import Numeric.Natural (Natural)
import qualified Proto.Build.Bazel.Remote.Execution.V2.RemoteExecution as RE
import qualified Proto.Build.Bazel.Remote.Execution.V2.RemoteExecution_Fields as R
import qualified Proto.Google.Bytestream.Bytestream as BS
import qualified Proto.Google.Bytestream.Bytestream_Fields as F
import Rechaos.Core.Types
import Text.Read (readMaybe)

readMethod, writeMethod, missingMethod :: Text
readMethod = "google.bytestream.ByteStream/Read"
writeMethod = "google.bytestream.ByteStream/Write"
missingMethod = "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"

decode :: (Message a) => L.ByteString -> Either String a
decode = decodeMessage . L.toStrict
encode :: (Message a) => a -> L.ByteString
encode = L.fromStrict . encodeMessage

sha256 :: L.ByteString -> Text
sha256 = T.pack . show . (hashlazy :: L.ByteString -> Digest SHA256)

resourceSize :: Text -> Maybe Natural
resourceSize resource = case reverse (T.splitOn "/" resource) of
  size : _hash : rest | "blobs" `elem` rest || "compressed-blobs" `elem` rest -> readMaybe (T.unpack size)
  _ -> Nothing

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
  | otherwise = Nothing
 where
  sizes req =
    let ns = map (^. R.sizeBytes) (req ^. R.blobDigests)
     in if all (>= 0) ns then Just (sum (map fromIntegral ns)) else Nothing

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

-- Split at protobuf message boundaries, never split a serialized protobuf into
-- invalid messages. Non-ByteStream RPCs are paced whole messages.
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
