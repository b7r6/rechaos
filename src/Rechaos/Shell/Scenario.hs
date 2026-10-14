-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                               // rechaos // shell // scenario
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   observations.json on disk: decoding, limit overrides, findings as JSON
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

{- | The on-disk side of "Rechaos.Core.Scenario": the @observations.json@ a step
engine writes (actions, control windows, and the limits it ran with), decoded
fail-closed, and the findings rendered back as JSON in the same shape the
Python engine emits, so the two evaluators can be compared field for field.
-}
module Rechaos.Shell.Scenario (
  readObservations,
  observationsFromJSON,
  findingJSON,
  evaluateFile,
) where

import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as L
import Rechaos.Core.Scenario

-- | Decode an observations file: the observations and the limits it recorded.
readObservations :: FilePath -> IO (Observations, Limits)
readObservations path = L.readFile path >>= either fail pure . observationsFromJSON

-- | Decode observations JSON, or explain what is wrong with it.
observationsFromJSON :: L.ByteString -> Either String (Observations, Limits)
observationsFromJSON bytes = eitherDecode bytes >>= parseEither parseObservations

parseObservations :: Value -> Parser (Observations, Limits)
parseObservations = withObject "observations" $ \o -> do
  actions <- o .: "actions" >>= traverse parseAction
  controls <- o .:? "controls" .!= [] >>= traverse parseControl
  limits <- o .: "limits" >>= parseLimits
  pure (Observations actions controls, limits)

{- | One action, fail-closed: every field the evaluator reads must be present
(a @null@ is a value, an absent key is a malformed file), matching the Python
engine, which indexes them. Only @inputs_present@ and @requeues@ may be
absent, as the engine reads them with a default.
-}
parseAction :: Value -> Parser Action
parseAction = withObject "action" $ \o ->
  Action
    <$> o .: "id"
    <*> o .: "submit_ms"
    <*> o .: "executing_ms"
    <*> o .: "done_ms"
    <*> o .: "last_ms"
    <*> o .: "last_stage"
    <*> o .: "status"
    <*> o .: "message"
    <*> o .: "exit_code"
    <*> o .: "operation"
    <*> o .: "detached"
    <*> (probeCount <$> o .: "probes")
    <*> o .:? "inputs_present"
    <*> o .:? "requeues" .!= []
    <*> o .: "cpu"
    <*> o .: "memory_kb"
 where
  probeCount :: [Value] -> Integer
  probeCount = fromIntegral . length

parseControl :: Value -> Parser Control
parseControl = withObject "control" $ \o ->
  Control <$> o .: "step" <*> o .: "start_ms" <*> o .: "end_ms"

parseLimits :: Value -> Parser Limits
parseLimits = withObject "limits" $ \o ->
  Limits
    <$> o .: "queue_age_ms"
    <*> o .: "executing_ms"
    <*> o .: "workers"
    <*> o .: "slots"
    <*> o .: "memory_kb"
    <*> o .:? "download_budget_ms" .!= 600000

-- | A finding in the engine's JSON shape.
findingJSON :: Finding -> Value
findingJSON (Finding signature action kind evidence) =
  object
    [ "signature" .= signature
    , "action" .= action
    , "kind" .= kind
    , "evidence" .= evidenceJSON (EObject evidence)
    ]

evidenceJSON :: Evidence -> Value
evidenceJSON (EInt n) = toJSON n
evidenceJSON (EText t) = toJSON t
evidenceJSON (EBool b) = toJSON b
evidenceJSON ENull = Null
evidenceJSON (EList xs) = toJSON (map evidenceJSON xs)
evidenceJSON (EObject entries) = object [(Key.fromText key, evidenceJSON value) | (key, value) <- entries]

{- | Evaluate an observations file with the limits it recorded, each overridden
by the supplied value when present, and return the report object:
@{"findings": [...], "signatures": [...], "actions": n}@.
-}
evaluateFile :: FilePath -> (Limits -> Limits) -> IO Value
evaluateFile path override = do
  (observations, recorded) <- readObservations path
  let findings = evaluate (override recorded) observations
  pure
    ( object
        [ "findings" .= map findingJSON findings
        , "signatures" .= signatures findings
        , "actions" .= length (oActions observations)
        ]
    )
