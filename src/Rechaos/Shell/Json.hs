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
) where

import Control.Monad (unless, when)
import Data.Aeson
import qualified Data.Aeson.KeyMap as KM
import Data.Aeson.Types (Parser)
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Lazy.Char8 as LC
import Data.Text (Text)
import qualified Data.Text as T
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
  parseJSON = withText "direction" $ \x -> case x of
    "request" -> pure Request
    "response" -> pure Response
    _ -> fail "direction must be request or response"
instance ToJSON Status where toJSON = String . T.pack . show
instance FromJSON Status where
  parseJSON = withText "status" $ \x ->
    case filter ((== x) . T.pack . show) [minBound .. maxBound] of
      [s] -> pure s
      _ -> fail "unsupported gRPC error status"
instance ToJSON Fault where
  toJSON (Delay n) = object ["kind" .= String "delay", "micros" .= n]
  toJSON (Abort s) = object ["kind" .= String "abort", "status" .= s]
  toJSON (Dribble r c) = object ["kind" .= String "dribble", "bytesPerSecond" .= r, "chunkBytes" .= c]
  toJSON (Truncate n) = object ["kind" .= String "truncate", "keepBytes" .= n]
instance FromJSON Fault where
  parseJSON = withObject "fault" $ \o -> do
    kind <- o .: "kind" :: Parser Text
    case kind of
      "delay" -> onlyKeys ["kind", "micros"] o >> Delay <$> o .: "micros"
      "abort" -> onlyKeys ["kind", "status"] o >> Abort <$> o .: "status"
      "dribble" -> do
        onlyKeys ["kind", "bytesPerSecond", "chunkBytes"] o
        r <- o .: "bytesPerSecond"
        c <- o .: "chunkBytes"
        when (r == 0 || c == 0 || c > 4194304) $
          fail "dribble requires positive rate and chunkBytes in 1..4194304"
        pure (Dribble r c)
      "truncate" -> onlyKeys ["kind", "keepBytes"] o >> Truncate <$> o .: "keepBytes"
      _ -> fail "unknown fault kind"
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
    r <- Rule <$> o .: "target" <*> o .:? "chancePpm" .!= 1000000 <*> o .: "fault"
    when (chancePpm r > 1000000) $ fail "chancePpm must be in 0..1000000"
    pure r
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
    case injection d of
      Nothing -> pure d
      Just f ->
        either (fail . T.unpack) (const (pure d)) (validFault (eMethod (event d)) (eDirection (event d)) f)

validatePolicy :: Policy -> Either Text ()
validatePolicy = mapM_ (\r -> validFault (tMethod (target r)) (tDirection (target r)) (fault r)) . rules

validFault :: Text -> Direction -> Fault -> Either Text ()
validFault method direction f
  | method `notElem` supported = Left "policy targets an unsupported method"
  | Truncate _ <- f, not streamPayload = Left "truncate requires Read response or Write request"
  | otherwise = Right ()
 where
  streamPayload =
    (method == "google.bytestream.ByteStream/Read" && direction == Response)
      || (method == "google.bytestream.ByteStream/Write" && direction == Request)
  supported =
    [ "build.bazel.remote.execution.v2.ContentAddressableStorage/FindMissingBlobs"
    , "google.bytestream.ByteStream/Read"
    , "google.bytestream.ByteStream/Write"
    ]

readPolicy :: FilePath -> IO Policy
readPolicy path = L.readFile path >>= either fail pure . eitherDecode

decodeLines :: L.ByteString -> Either String Timeline
decodeLines bs = traverse parseLine (zip [(1 :: Int) ..] (LC.lines bs))
 where
  parseLine (n, line) = case eitherDecode line of
    Left e -> Left ("timeline line " ++ show n ++ ": " ++ e)
    Right d -> Right d

readTimeline :: FilePath -> IO Timeline
readTimeline path = do
  ds <- L.readFile path >>= either fail pure . decodeLines
  _ <- either (fail . T.unpack) pure (validateTimeline ds)
  pure ds

writeTimeline :: FilePath -> Timeline -> IO ()
writeTimeline path = L.writeFile path . LC.unlines . map encode
