-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                  // rechaos // core // oracle
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   output-tree maps, difference, and build-equivalence verdicts
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

module Rechaos.Core.Oracle where

import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Data.Text (Text)
import Numeric.Natural (Natural)

data Entry = File Text Natural Bool | Symlink Text | Directory
  deriving (Eq, Show)
type Tree = M.Map Text Entry
data Change = Change Text (Maybe Entry) (Maybe Entry) deriving (Eq, Show)
data BuildResult = Built Tree | BuildFailed Text | BuildTimedOut deriving (Eq, Show)
data Verdict = Equivalent | Diverged [Change] | Inconclusive deriving (Eq, Show)

diff :: Tree -> Tree -> [Change]
diff a b =
  [ Change path x y
  | path <- S.toAscList (M.keysSet a `S.union` M.keysSet b)
  , let x = M.lookup path a
  , let y = M.lookup path b
  , x /= y
  ]

equivalent :: Tree -> Tree -> Bool
equivalent a b = null (diff a b)

compareBuilds :: BuildResult -> BuildResult -> Verdict
compareBuilds (Built a) (Built b) = case diff a b of
  [] -> Equivalent
  changes -> Diverged changes
compareBuilds _ _ = Inconclusive
