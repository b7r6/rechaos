-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                   // rechaos // shell // json
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   versioned policy and timeline decoding and validation
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Rechaos.Shell.Json (
  readPolicy,
  readTimeline,
  writeTimeline,
  decodeLines,
  validatePolicy,
  payloadRewriting,
) where

import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KM
import Data.Aeson.Types (Parser)
import Data.ByteString.Lazy qualified as L
import Data.ByteString.Lazy.Char8 qualified as LC
import Data.Text (Text)
import Data.Text qualified as T
import Rechaos.Core.Scheduler (validateTimeline)
import Rechaos.Core.Types

onlyKeys :: [Key] -> Object -> Parser ()
onlyKeys allowed o =
  unless (all (`elem` allowed) (KM.keys o)) $
    fail "unknown JSON field (check policy/timeline spelling)"

instance ToJSON Direction where
  toJSON Request = String "request"
  toJSON Response = String "response"
instance FromJSON Direction where
  parseJSON = withText "direction" parse
   where
    parse "request" = pure Request
    parse "response" = pure Response
    parse _ = fail "direction must be request or response"
instance ToJSON Status where toJSON = String . T.pack . show
instance FromJSON Status where
  parseJSON = withText "status" $ \x ->
    case filter ((== x) . T.pack . show) [minBound .. maxBound] of -- CASE-OK: unique-match on a mid-expression filtered list
      [s] -> pure s
      _ -> fail "unsupported gRPC error status"
instance ToJSON Fault where
  toJSON (Delay n) = object ["kind" .= String "delay", "micros" .= n]
  toJSON (Abort s) = object ["kind" .= String "abort", "status" .= s]
  toJSON (Dribble r c) = object ["kind" .= String "dribble", "bytesPerSecond" .= r, "chunkBytes" .= c]
  toJSON (Truncate n) = object ["kind" .= String "truncate", "keepBytes" .= n]
  toJSON (Corrupt n) = object ["kind" .= String "corrupt", "bytes" .= n]
instance FromJSON Fault where
  parseJSON = withObject "fault" $ \o -> do
    kind <- o .: "kind" :: Parser Text
    let byKind "delay" = onlyKeys ["kind", "micros"] o >> Delay <$> o .: "micros"
        byKind "abort" = onlyKeys ["kind", "status"] o >> Abort <$> o .: "status"
        byKind "dribble" = do
          onlyKeys ["kind", "bytesPerSecond", "chunkBytes"] o
          r <- o .: "bytesPerSecond"
          c <- o .: "chunkBytes"
          -- n.b. bounds checked here, not in 'mkRule': a Dribble can also land
          -- on a decision/timeline value that never passes through a rule.
          unless (validFaultBounds (Dribble r c)) $
            fail "dribble requires positive rate and chunkBytes in 1..4194304"
          pure (Dribble r c)
        byKind "truncate" = onlyKeys ["kind", "keepBytes"] o >> Truncate <$> o .: "keepBytes"
        byKind "corrupt" = onlyKeys ["kind", "bytes"] o >> Corrupt <$> o .: "bytes"
        byKind _ = fail "unknown fault kind"
    byKind kind
instance ToJSON Target where
  toJSON t =
    object
      [ "method" .= tMethod t
      , "direction" .= tDirection t
      , "occurrence" .= tOccurrence t
      , "messageIndex" .= tMessageIndex t
      , "minBlobBytes" .= tMinBlobBytes t
      , "maxBlobBytes" .= tMaxBlobBytes t
      , "afterMicros" .= tAfterMicros t
      , "beforeMicros" .= tBeforeMicros t
      ]
instance FromJSON Target where
  parseJSON = withObject "target" $ \o -> do
    onlyKeys
      [ "method"
      , "direction"
      , "occurrence"
      , "messageIndex"
      , "minBlobBytes"
      , "maxBlobBytes"
      , "afterMicros"
      , "beforeMicros"
      ]
      o
    t <-
      Target
        <$> o .: "method"
        <*> o .: "direction"
        <*> o .:? "occurrence"
        <*> o .:? "messageIndex"
        <*> o .:? "minBlobBytes"
        <*> o .:? "maxBlobBytes"
        <*> o .:? "afterMicros"
        <*> o .:? "beforeMicros"
    when (tOccurrence t == Just 0 || tMessageIndex t == Just 0) $ fail "indices are 1-based"
    when (inverted (tMinBlobBytes t) (tMaxBlobBytes t) || inverted (tAfterMicros t) (tBeforeMicros t)) $
      fail "inverted target range"
    pure t
   where
    inverted (Just lo) (Just hi) = lo > hi
    inverted _ _ = False
instance ToJSON Rule where
  toJSON r = object ["target" .= target r, "chancePpm" .= chancePpm r, "fault" .= fault r]
instance FromJSON Rule where
  parseJSON = withObject "rule" $ \o -> do
    onlyKeys ["target", "chancePpm", "fault"] o
    t <- o .: "target"
    c <- o .:? "chancePpm" .!= maxPpm
    f <- o .: "fault"
    maybe (fail "chancePpm must be in 0..1000000") pure (mkRule t c f)
instance ToJSON Policy where
  toJSON p = object ["version" .= (1 :: Int), "seed" .= seed p, "rules" .= rules p]
instance FromJSON Policy where
  parseJSON = withObject "policy" $ \o -> do
    onlyKeys ["version", "seed", "rules"] o
    v <- o .: "version" :: Parser Int
    unless (v == 1) $ fail "unsupported policy version"
    p <- Policy <$> o .: "seed" <*> o .: "rules"
    either (fail . T.unpack) (const (pure p)) (validatePolicy p)
instance ToJSON Event where
  toJSON e =
    object
      [ "method" .= eMethod e
      , "occurrence" .= eOccurrence e
      , "direction" .= eDirection e
      , "messageIndex" .= eMessageIndex e
      , "blobBytes" .= eBlobBytes e
      , "elapsedMicros" .= eElapsedMicros e
      , "messageBytes" .= eMessageBytes e
      , "payloadHash" .= ePayloadHash e
      ]
instance FromJSON Event where
  parseJSON = withObject "event" $ \o -> do
    onlyKeys
      [ "method"
      , "occurrence"
      , "direction"
      , "messageIndex"
      , "blobBytes"
      , "elapsedMicros"
      , "messageBytes"
      , "payloadHash"
      ]
      o
    Event
      <$> o .: "method"
      <*> o .: "occurrence"
      <*> o .: "direction"
      <*> o .: "messageIndex"
      <*> o .: "blobBytes"
      <*> o .: "elapsedMicros"
      <*> o .: "messageBytes"
      <*> o .: "payloadHash"
instance ToJSON Decision where
  toJSON d = object ["version" .= (1 :: Int), "event" .= event d, "injection" .= injection d]
instance FromJSON Decision where
  parseJSON = withObject "decision" $ \o -> do
    onlyKeys ["version", "event", "injection"] o
    v <- o .: "version" :: Parser Int
    unless (v == 1) $ fail "unsupported timeline version"
    d <- Decision <$> o .: "event" <*> o .: "injection"
    when (eOccurrence (event d) == 0 || eMessageIndex (event d) == 0) $ fail "indices are 1-based"
    maybe
      (pure d)
      ( \f ->
          either (fail . T.unpack) (const (pure d)) (validFault (eMethod (event d)) (eDirection (event d)) f)
      )
      (injection d)

{- | Check every rule's fault against its targeted method and direction, failing
on the first offending rule (see 'validFault'). 'Left' carries the reason.
-}
validatePolicy :: Policy -> Either Text ()
validatePolicy = mapM_ (\r -> validFault (tMethod (target r)) (tDirection (target r)) (fault r)) . rules

{- | The full fault-eligible REAPI surface and the canonical source of truth for
policy targeting. 'Delay' and 'Abort' operate on raw bytes and are legal on
every method here; the payload-rewriting faults ('Truncate', 'Corrupt' and
'Dribble', see 'payloadRewriting') stay restricted to the ByteStream streaming
payloads (see 'validFault').

Keep these strings in lockstep with the proxy handlers in "Rechaos.Shell.Proxy".
The proxy forwards additional long-running methods (notably the
@google.longrunning.Operations@ surface and @Execution/Execute@) that are
deliberately /excluded/ from this list: their messages are neither CAS blobs nor
ByteStream payloads, so neither size targeting ('blobSize' returns 'Nothing' for
them) nor payload rewriting is meaningful, and admitting them would let a policy
silently match nothing. They are therefore excluded from policy targeting rather
than silently accepted. If a future task widens this list to those methods, keep
'validFault' correct: message-agnostic faults ('Delay'/'Abort') are allowed while
payload-rewriting faults must stay rejected for the non-streaming methods.
-}
supportedMethods :: [Text]
supportedMethods =
  [ "google.bytestream.ByteStream/Read"
  , "google.bytestream.ByteStream/Write"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchUpdateBlobs"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/BatchReadBlobs"
  , "build.bazel.remote.execution.v2.ContentAddressableStorage/GetTree"
  , "build.bazel.remote.execution.v2.ActionCache/GetActionResult"
  , "build.bazel.remote.execution.v2.ActionCache/UpdateActionResult"
  , "build.bazel.remote.execution.v2.Capabilities/GetCapabilities"
  ]

{- | Payload-rewriting faults mutate the bytes of a message in flight and so can
only be applied where rechaos knows how to decode, edit, and re-encode the
streaming payload (ByteStream 'Read' responses and 'Write' requests). 'Delay'
and 'Abort' are message-agnostic and are /not/ payload-rewriting.
-}
payloadRewriting :: Fault -> Bool
payloadRewriting Truncate{} = True
payloadRewriting Corrupt{} = True
payloadRewriting Dribble{} = True
payloadRewriting Delay{} = False
payloadRewriting Abort{} = False

{- | Payload-rewriting faults that require a decodable streaming payload to edit:
'Truncate' and 'Corrupt' rewrite the ByteStream 'Read' response / 'Write'
request @data@ field, so they are rejected anywhere else. 'Dribble' re-chunks
and so remains legal on every supported method (it paces a unary message as a
single chunk), and 'Delay'/'Abort' are message-agnostic.
-}
streamPayloadOnly :: Fault -> Bool
streamPayloadOnly Truncate{} = True
streamPayloadOnly Corrupt{} = True
streamPayloadOnly Dribble{} = False
streamPayloadOnly Delay{} = False
streamPayloadOnly Abort{} = False

validFault :: Text -> Direction -> Fault -> Either Text ()
validFault method direction f
  | method `notElem` supportedMethods =
      Left ("policy targets an unsupported method: " <> method)
  | streamPayloadOnly f
  , not streamPayload =
      Left (faultName f <> " requires a ByteStream Read response or Write request")
  | otherwise = Right ()
 where
  streamPayload =
    (method == "google.bytestream.ByteStream/Read" && direction == Response)
      || (method == "google.bytestream.ByteStream/Write" && direction == Request)
  faultName Truncate{} = "truncate"
  faultName Corrupt{} = "corrupt"
  faultName Dribble{} = "dribble"
  faultName Delay{} = "delay"
  faultName Abort{} = "abort"

{- | Read and decode a single-document JSON policy file, validating it via the
'FromJSON' 'Policy' instance ('validatePolicy' runs there). Fails in 'IO' on
a decode or validation error.
-}
readPolicy :: FilePath -> IO Policy
readPolicy path = L.readFile path >>= either fail pure . eitherDecode

{- | Decode a JSONL timeline: one 'Decision' per line, with the offending
1-based line number prefixed to any decode error.
-}
decodeLines :: L.ByteString -> Either String Timeline
decodeLines bs = traverse parseLine (zip [(1 :: Int) ..] (LC.lines bs))
 where
  parseLine (n, line) =
    either (\e -> Left ("timeline line " ++ show n ++ ": " ++ e)) Right (eitherDecode line)

{- | Read a JSONL timeline file ('decodeLines') and assert its structural
invariants with 'validateTimeline'. Fails in 'IO' on a decode or validation
error.
-}
readTimeline :: FilePath -> IO Timeline
readTimeline path = do
  ds <- L.readFile path >>= either fail pure . decodeLines
  _ <- either (fail . T.unpack) pure (validateTimeline ds)
  pure ds

-- | Serialize a timeline to JSONL: one encoded 'Decision' per line.
writeTimeline :: FilePath -> Timeline -> IO ()
writeTimeline path = L.writeFile path . LC.unlines . map encode
