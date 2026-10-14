-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                            // rechaos // core // module-proxy
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   which dependency-proxy responses get their stream reset, and where
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | The fault rule behind "Rechaos.Shell.ModuleProxy": a dependency proxy that
answers a build's module fetches from a directory and resets some response
streams part-way through the body.

The decision is a function of the rule and of how many matching requests the
proxy has already seen, so a run is reproducible from its rule alone: the
first 'ruleCount' responses whose path contains 'ruleNeedle' are cut after
'ruleAfterBytes' bytes, every later one is served whole. That models a
transient upstream fault (a proxy or edge dropping a stream) and lets a run
measure a client's retry budget: a fetcher that retries once copes with
@ruleCount = 1@ and fails at @ruleCount = 2@.

This module is pure: no IO and no partial functions.
-}
module Rechaos.Core.ModuleProxy (
  Rule (..),
  matches,
  decide,
) where

import Data.Text (Text)
import Data.Text qualified as T
import Numeric.Natural (Natural)

-- | Which responses to reset and where in the body.
data Rule = Rule
  { ruleNeedle :: Text
  -- ^ A request matches when its path contains this.
  , ruleAfterBytes :: Natural
  -- ^ Body bytes delivered before the reset.
  , ruleCount :: Natural
  -- ^ How many matching requests are reset, in arrival order; later ones are served whole.
  }
  deriving (Eq, Show)

-- | Whether a request path is subject to the rule.
matches :: Rule -> Text -> Bool
matches rule path = ruleNeedle rule `T.isInfixOf` path

{- | For the zero-based ordinal of a matching request, the number of body bytes
  to deliver before resetting its stream, or 'Nothing' to serve it whole.
-}
decide :: Rule -> Natural -> Maybe Natural
decide rule ordinal
  | ordinal < ruleCount rule = Just (ruleAfterBytes rule)
  | otherwise = Nothing
