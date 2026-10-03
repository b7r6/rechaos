-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                   // rechaos // core // types
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   fault algebra, policy, events, and timeline values; explicit units
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

module Rechaos.Core.Types where

import Data.Text (Text)
import Data.Word (Word64)
import Numeric.Natural (Natural)

-- Units are explicit and nonnegative. Validation at the shell boundary rejects
-- zero rates/chunks and unsupported method/direction/fault combinations.
data Direction = Request | Response deriving (Eq, Ord, Show)
data Status
  = Cancelled
  | InvalidArgument
  | DeadlineExceeded
  | NotFound
  | ResourceExhausted
  | FailedPrecondition
  | Internal
  | Unavailable
  | DataLoss
  deriving (Eq, Ord, Show, Enum, Bounded)
data Fault
  = Delay Natural
  | Abort Status
  | Dribble Natural Natural
  | Truncate Natural
  deriving (Eq, Show)

data Target = Target
  { tMethod :: Text
  , tDirection :: Direction
  , tOccurrence :: Maybe Natural
  , tMessageIndex :: Maybe Natural
  , tMinBlobBytes :: Maybe Natural
  , tMaxBlobBytes :: Maybe Natural
  , tAfterMicros :: Maybe Natural
  , tBeforeMicros :: Maybe Natural
  }
  deriving (Eq, Show)
data Rule = Rule {target :: Target, chancePpm :: Natural, fault :: Fault}
  deriving (Eq, Show)
data Policy = Policy {seed :: Word64, rules :: [Rule]} deriving (Eq, Show)

-- An event is an observation supplied by the shell, never a clock read.
-- Occurrences are 1-based per method; message indices are 1-based per direction.
data Event = Event
  { eMethod :: Text
  , eOccurrence :: Natural
  , eDirection :: Direction
  , eMessageIndex :: Natural
  , eBlobBytes :: Maybe Natural
  , eElapsedMicros :: Natural
  , eMessageBytes :: Natural
  , ePayloadHash :: Text
  }
  deriving (Eq, Show)
data Decision = Decision {event :: Event, injection :: Maybe Fault}
  deriving (Eq, Show)
type Timeline = [Decision]
type EventKey = (Text, Natural, Direction, Natural)

eventKey :: Event -> EventKey
eventKey e = (eMethod e, eOccurrence e, eDirection e, eMessageIndex e)

-- Arrival time may vary during live replay. All other observations must agree.
sameEvent :: Event -> Event -> Bool
sameEvent a b = a{eElapsedMicros = 0} == b{eElapsedMicros = 0}
