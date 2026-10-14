-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                  // rechaos // shell // steps
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   opaque JSON scenario steps: on-disk JSONL, validation, declared intensity
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE OverloadedStrings #-}

{- | A scenario step list is the witness for failures the gateway cannot
express: a scheduler that starves a large action, a worker whose cache evicts an
input mid-stage, a scheduler store that refuses a result write. The stimulus is
a sequence of opaque JSON objects (action submissions, control-plane faults)
that an external driver replays; rechaos never interprets a step beyond what
this module validates. Shrinking treats the list exactly like a fault timeline
through "Rechaos.Core.Shrink": chunk deletions, and intensity reductions on the
numeric fields each step declares under @weaker@.

The on-disk form is JSON Lines, one object per step; a JSON array of objects
(what @dhall-to-json@ renders) is accepted on read and written back as JSONL. A step may carry
@\"weaker\": {\"field\": floor, ...}@, naming non-negative integer fields of the
same object and the floor each may shrink toward. Each intensity candidate
halves one such field's distance to its floor, so the chain is finite and
strictly decreasing, and the floor itself is reachable.

n.b. Validation is fail-closed on read: a step that is not an object, a
@weaker@ that is not an object of non-negative integers, or a declared field
that is absent, non-integral, or already below its floor rejects the whole file
with the line number. A hand-edited witness cannot smuggle in a step whose
shrink order is undefined.
-}
module Rechaos.Shell.Steps (
  Step,
  readSteps,
  writeSteps,
  decodeSteps,
  weakerStep,
) where

import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseMaybe)
import Data.ByteString.Lazy qualified as L
import Data.ByteString.Lazy.Char8 qualified as LC
import Data.Foldable (toList)
import Data.List (sortOn)
import Numeric.Natural (Natural)

-- | One scenario step: a JSON object the external driver interprets.
type Step = Object

-- | Read and validate a JSONL step file, failing with the offending line number.
readSteps :: FilePath -> IO [Step]
readSteps path = L.readFile path >>= either fail pure . decodeSteps

-- | Write steps as JSON Lines, one object per line.
writeSteps :: FilePath -> [Step] -> IO ()
writeSteps path = L.writeFile path . LC.unlines . map encode

{- | Decode and validate steps from either on-disk form. A JSON array is read
  whole and each element reported by its index; otherwise every non-blank line
  must be one object. In both forms a @weaker@ field, if present, must declare
  only existing non-negative integer fields with floors no greater than their
  current values.
-}
decodeSteps :: L.ByteString -> Either String [Step]
decodeSteps bytes
  | Right (Array elements) <- eitherDecode bytes =
      traverse arrayElement (zip [(0 :: Int) ..] (toList elements))
  | otherwise = traverse parseLine (zip [(1 :: Int) ..] (filter (not . blank) (LC.lines bytes)))
 where
  arrayElement (n, Object step) = maybe (Right step) (Left . located ("step " ++ show n ++ " (array element)")) (invalid step)
  arrayElement (n, _) = Left (located ("step " ++ show n ++ " (array element)") "must be a JSON object")
  parseLine (n, line) = either (Left . located ("steps line " ++ show n)) (validated n) (eitherDecode line)
  validated n step = maybe (Right step) (Left . located ("steps line " ++ show n)) (invalid step)
  located place message = place ++ ": " ++ message
  blank = L.null . LC.dropWhile (`elem` (" \t\r" :: String))

-- | Why a step's declared intensity is unusable, if it is.
invalid :: Step -> Maybe String
invalid step = KeyMap.lookup "weaker" step >>= badDeclaration
 where
  badDeclaration (Object floors) = firstBad (KeyMap.toList floors)
  badDeclaration _ = Just "weaker must be an object of field -> floor"
  firstBad [] = Nothing
  firstBad ((field, floorValue) : rest)
    | Nothing <- natural floorValue = Just (name ++ ": floor must be a non-negative integer")
    | Nothing <- current = Just (name ++ ": declared field is absent")
    | Just value <- current
    , Nothing <- natural value =
        Just (name ++ ": declared field must be a non-negative integer")
    | Just floorNatural <- natural floorValue
    , Just valueNatural <- current >>= natural
    , valueNatural < floorNatural =
        Just (name ++ ": value is below its floor")
    | otherwise = firstBad rest
   where
    name = "weaker." ++ Key.toString field
    current = KeyMap.lookup field step

{- | The strictly weaker forms of a step: for each declared field, in key order,
  the same step with that field moved halfway toward its floor. A step with no
  declaration, or with every field already at its floor, has none.
-}
weakerStep :: Step -> [Step]
weakerStep step = maybe [] shrinkEach (KeyMap.lookup "weaker" step >>= floors)
 where
  floors (Object declared) = Just (sortOn fst (KeyMap.toList declared))
  floors _ = Nothing
  shrinkEach declared =
    [ KeyMap.insert field (toJSON (f + (v - f) `div` 2)) step
    | (field, floorValue) <- declared
    , Just f <- [natural floorValue]
    , Just v <- [KeyMap.lookup field step >>= natural]
    , v > f
    ]

-- | A JSON value as a non-negative integer, if it is one.
natural :: Value -> Maybe Natural
natural = parseMaybe parseJSON
