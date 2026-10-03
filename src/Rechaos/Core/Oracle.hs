-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                  // rechaos // core // oracle
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   output-tree maps, difference, and build-equivalence verdicts
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{- | The equivalence oracle: model a build's outputs as an ordered 'Tree', take a
deterministic 'diff' between two such trees, and render a 'Verdict' on whether two
builds agreed.

Equivalence is defined as a null diff: two trees are 'equivalent' exactly when
'diff' between them is empty. The diff iterates the union of both trees' paths in
ascending key order, so its output is a stable, canonical list of 'Change's.
Build outcomes other than success are 'Inconclusive' rather than divergent. This
module is pure: no IO, no filesystem access, and no partial functions.
-}
module Rechaos.Core.Oracle (
  -- * Output trees
  Entry (..),
  Tree,

  -- * Differences
  Change (..),
  diff,
  equivalent,

  -- * Verdicts
  BuildResult (..),
  Verdict (..),
  compareBuilds,
) where

import Data.Map.Strict qualified as M
import Data.Set qualified as S
import Data.Text (Text)
import Numeric.Natural (Natural)

-- | A single node in a build-output tree.
data Entry
  = {- | A regular file: @File contentHash sizeBytes executable@, where the size is
    in bytes and the flag is the executable bit.
    -}
    File Text Natural Bool
  | -- | A symlink carrying its target path.
    Symlink Text
  | -- | A directory node.
    Directory
  deriving (Eq, Show)

-- | A build's outputs keyed by path, in ascending path order.
type Tree = M.Map Text Entry

{- | A per-path difference: @Change path before after@, where 'Nothing' marks
  absence on that side (an addition or deletion).
-}
data Change = Change Text (Maybe Entry) (Maybe Entry) deriving (Eq, Show)

-- | The result of attempting a build.
data BuildResult
  = -- | The build succeeded, producing this output 'Tree'.
    Built Tree
  | -- | The build failed with the given message.
    BuildFailed Text
  | -- | The build did not finish within its deadline.
    BuildTimedOut
  deriving (Eq, Show)

-- | The oracle's judgement on a pair of builds.
data Verdict
  = -- | The builds produced identical outputs.
    Equivalent
  | -- | The builds diverged; carries the canonical list of 'Change's.
    Diverged [Change]
  | -- | At least one build did not succeed, so no judgement is possible.
    Inconclusive
  deriving (Eq, Show)

{- | The canonical difference between two trees: one 'Change' per path (in
  ascending key order) whose entries differ. An empty result means the trees
  are identical.
-}
diff :: Tree -> Tree -> [Change]
diff a b =
  [ Change path x y
  | path <- S.toAscList (M.keysSet a `S.union` M.keysSet b)
  , let x = M.lookup path a
  , let y = M.lookup path b
  , x /= y
  ]

-- | Whether two trees are equivalent, i.e. their 'diff' is empty.
equivalent :: Tree -> Tree -> Bool
equivalent a b = null (diff a b)

{- | Compare two build outcomes. Both must have 'Built' successfully to be judged;
  equal outputs yield 'Equivalent', differing outputs 'Diverged', and any
  non-success on either side 'Inconclusive'.
-}
compareBuilds :: BuildResult -> BuildResult -> Verdict
compareBuilds (Built a) (Built b) = case diff a b of
  [] -> Equivalent
  changes -> Diverged changes
compareBuilds _ _ = Inconclusive
