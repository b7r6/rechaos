{- This file was auto-generated from google/api/launch_stage.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Google.Api.LaunchStage (
        LaunchStage(..), LaunchStage(), LaunchStage'UnrecognizedValue
    ) where
import qualified Data.ProtoLens.Runtime.Control.DeepSeq as Control.DeepSeq
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Prism as Data.ProtoLens.Prism
import qualified Data.ProtoLens.Runtime.Prelude as Prelude
import qualified Data.ProtoLens.Runtime.Data.Int as Data.Int
import qualified Data.ProtoLens.Runtime.Data.Monoid as Data.Monoid
import qualified Data.ProtoLens.Runtime.Data.Word as Data.Word
import qualified Data.ProtoLens.Runtime.Data.ProtoLens as Data.ProtoLens
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Encoding.Bytes as Data.ProtoLens.Encoding.Bytes
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Encoding.Growing as Data.ProtoLens.Encoding.Growing
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Encoding.Parser.Unsafe as Data.ProtoLens.Encoding.Parser.Unsafe
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Encoding.Wire as Data.ProtoLens.Encoding.Wire
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Field as Data.ProtoLens.Field
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Message.Enum as Data.ProtoLens.Message.Enum
import qualified Data.ProtoLens.Runtime.Data.ProtoLens.Service.Types as Data.ProtoLens.Service.Types
import qualified Data.ProtoLens.Runtime.Lens.Family2 as Lens.Family2
import qualified Data.ProtoLens.Runtime.Lens.Family2.Unchecked as Lens.Family2.Unchecked
import qualified Data.ProtoLens.Runtime.Data.Text as Data.Text
import qualified Data.ProtoLens.Runtime.Data.Map as Data.Map
import qualified Data.ProtoLens.Runtime.Data.ByteString as Data.ByteString
import qualified Data.ProtoLens.Runtime.Data.ByteString.Char8 as Data.ByteString.Char8
import qualified Data.ProtoLens.Runtime.Data.Text.Encoding as Data.Text.Encoding
import qualified Data.ProtoLens.Runtime.Data.Vector as Data.Vector
import qualified Data.ProtoLens.Runtime.Data.Vector.Generic as Data.Vector.Generic
import qualified Data.ProtoLens.Runtime.Data.Vector.Unboxed as Data.Vector.Unboxed
import qualified Data.ProtoLens.Runtime.Text.Read as Text.Read
newtype LaunchStage'UnrecognizedValue
  = LaunchStage'UnrecognizedValue Data.Int.Int32
  deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show)
data LaunchStage
  = LAUNCH_STAGE_UNSPECIFIED |
    EARLY_ACCESS |
    ALPHA |
    BETA |
    GA |
    DEPRECATED |
    UNIMPLEMENTED |
    PRELAUNCH |
    LaunchStage'Unrecognized !LaunchStage'UnrecognizedValue
  deriving stock (Prelude.Show, Prelude.Eq, Prelude.Ord)
instance Data.ProtoLens.MessageEnum LaunchStage where
  maybeToEnum 0 = Prelude.Just LAUNCH_STAGE_UNSPECIFIED
  maybeToEnum 1 = Prelude.Just EARLY_ACCESS
  maybeToEnum 2 = Prelude.Just ALPHA
  maybeToEnum 3 = Prelude.Just BETA
  maybeToEnum 4 = Prelude.Just GA
  maybeToEnum 5 = Prelude.Just DEPRECATED
  maybeToEnum 6 = Prelude.Just UNIMPLEMENTED
  maybeToEnum 7 = Prelude.Just PRELAUNCH
  maybeToEnum k
    = Prelude.Just
        (LaunchStage'Unrecognized
           (LaunchStage'UnrecognizedValue (Prelude.fromIntegral k)))
  showEnum LAUNCH_STAGE_UNSPECIFIED = "LAUNCH_STAGE_UNSPECIFIED"
  showEnum UNIMPLEMENTED = "UNIMPLEMENTED"
  showEnum PRELAUNCH = "PRELAUNCH"
  showEnum EARLY_ACCESS = "EARLY_ACCESS"
  showEnum ALPHA = "ALPHA"
  showEnum BETA = "BETA"
  showEnum GA = "GA"
  showEnum DEPRECATED = "DEPRECATED"
  showEnum
    (LaunchStage'Unrecognized (LaunchStage'UnrecognizedValue k))
    = Prelude.show k
  readEnum k
    | (Prelude.==) k "LAUNCH_STAGE_UNSPECIFIED"
    = Prelude.Just LAUNCH_STAGE_UNSPECIFIED
    | (Prelude.==) k "UNIMPLEMENTED" = Prelude.Just UNIMPLEMENTED
    | (Prelude.==) k "PRELAUNCH" = Prelude.Just PRELAUNCH
    | (Prelude.==) k "EARLY_ACCESS" = Prelude.Just EARLY_ACCESS
    | (Prelude.==) k "ALPHA" = Prelude.Just ALPHA
    | (Prelude.==) k "BETA" = Prelude.Just BETA
    | (Prelude.==) k "GA" = Prelude.Just GA
    | (Prelude.==) k "DEPRECATED" = Prelude.Just DEPRECATED
    | Prelude.otherwise
    = (Prelude.>>=) (Text.Read.readMaybe k) Data.ProtoLens.maybeToEnum
instance Prelude.Bounded LaunchStage where
  minBound = LAUNCH_STAGE_UNSPECIFIED
  maxBound = PRELAUNCH
instance Prelude.Enum LaunchStage where
  toEnum k__
    = Prelude.maybe
        (Prelude.error
           ((Prelude.++)
              "toEnum: unknown value for enum LaunchStage: " (Prelude.show k__)))
        Prelude.id (Data.ProtoLens.maybeToEnum k__)
  fromEnum LAUNCH_STAGE_UNSPECIFIED = 0
  fromEnum EARLY_ACCESS = 1
  fromEnum ALPHA = 2
  fromEnum BETA = 3
  fromEnum GA = 4
  fromEnum DEPRECATED = 5
  fromEnum UNIMPLEMENTED = 6
  fromEnum PRELAUNCH = 7
  fromEnum
    (LaunchStage'Unrecognized (LaunchStage'UnrecognizedValue k))
    = Prelude.fromIntegral k
  succ PRELAUNCH
    = Prelude.error
        "LaunchStage.succ: bad argument PRELAUNCH. This value would be out of bounds."
  succ LAUNCH_STAGE_UNSPECIFIED = EARLY_ACCESS
  succ EARLY_ACCESS = ALPHA
  succ ALPHA = BETA
  succ BETA = GA
  succ GA = DEPRECATED
  succ DEPRECATED = UNIMPLEMENTED
  succ UNIMPLEMENTED = PRELAUNCH
  succ (LaunchStage'Unrecognized _)
    = Prelude.error
        "LaunchStage.succ: bad argument: unrecognized value"
  pred LAUNCH_STAGE_UNSPECIFIED
    = Prelude.error
        "LaunchStage.pred: bad argument LAUNCH_STAGE_UNSPECIFIED. This value would be out of bounds."
  pred EARLY_ACCESS = LAUNCH_STAGE_UNSPECIFIED
  pred ALPHA = EARLY_ACCESS
  pred BETA = ALPHA
  pred GA = BETA
  pred DEPRECATED = GA
  pred UNIMPLEMENTED = DEPRECATED
  pred PRELAUNCH = UNIMPLEMENTED
  pred (LaunchStage'Unrecognized _)
    = Prelude.error
        "LaunchStage.pred: bad argument: unrecognized value"
  enumFrom = Data.ProtoLens.Message.Enum.messageEnumFrom
  enumFromTo = Data.ProtoLens.Message.Enum.messageEnumFromTo
  enumFromThen = Data.ProtoLens.Message.Enum.messageEnumFromThen
  enumFromThenTo = Data.ProtoLens.Message.Enum.messageEnumFromThenTo
instance Data.ProtoLens.FieldDefault LaunchStage where
  fieldDefault = LAUNCH_STAGE_UNSPECIFIED
instance Control.DeepSeq.NFData LaunchStage where
  rnf x__ = Prelude.seq x__ ()