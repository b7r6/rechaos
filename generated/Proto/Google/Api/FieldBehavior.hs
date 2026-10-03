{- This file was auto-generated from google/api/field_behavior.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Google.Api.FieldBehavior (
        FieldBehavior(..), FieldBehavior(), FieldBehavior'UnrecognizedValue
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
import qualified Proto.Google.Protobuf.Descriptor
newtype FieldBehavior'UnrecognizedValue
  = FieldBehavior'UnrecognizedValue Data.Int.Int32
  deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show)
data FieldBehavior
  = FIELD_BEHAVIOR_UNSPECIFIED |
    OPTIONAL |
    REQUIRED |
    OUTPUT_ONLY |
    INPUT_ONLY |
    IMMUTABLE |
    UNORDERED_LIST |
    NON_EMPTY_DEFAULT |
    IDENTIFIER |
    FieldBehavior'Unrecognized !FieldBehavior'UnrecognizedValue
  deriving stock (Prelude.Show, Prelude.Eq, Prelude.Ord)
instance Data.ProtoLens.MessageEnum FieldBehavior where
  maybeToEnum 0 = Prelude.Just FIELD_BEHAVIOR_UNSPECIFIED
  maybeToEnum 1 = Prelude.Just OPTIONAL
  maybeToEnum 2 = Prelude.Just REQUIRED
  maybeToEnum 3 = Prelude.Just OUTPUT_ONLY
  maybeToEnum 4 = Prelude.Just INPUT_ONLY
  maybeToEnum 5 = Prelude.Just IMMUTABLE
  maybeToEnum 6 = Prelude.Just UNORDERED_LIST
  maybeToEnum 7 = Prelude.Just NON_EMPTY_DEFAULT
  maybeToEnum 8 = Prelude.Just IDENTIFIER
  maybeToEnum k
    = Prelude.Just
        (FieldBehavior'Unrecognized
           (FieldBehavior'UnrecognizedValue (Prelude.fromIntegral k)))
  showEnum FIELD_BEHAVIOR_UNSPECIFIED = "FIELD_BEHAVIOR_UNSPECIFIED"
  showEnum OPTIONAL = "OPTIONAL"
  showEnum REQUIRED = "REQUIRED"
  showEnum OUTPUT_ONLY = "OUTPUT_ONLY"
  showEnum INPUT_ONLY = "INPUT_ONLY"
  showEnum IMMUTABLE = "IMMUTABLE"
  showEnum UNORDERED_LIST = "UNORDERED_LIST"
  showEnum NON_EMPTY_DEFAULT = "NON_EMPTY_DEFAULT"
  showEnum IDENTIFIER = "IDENTIFIER"
  showEnum
    (FieldBehavior'Unrecognized (FieldBehavior'UnrecognizedValue k))
    = Prelude.show k
  readEnum k
    | (Prelude.==) k "FIELD_BEHAVIOR_UNSPECIFIED"
    = Prelude.Just FIELD_BEHAVIOR_UNSPECIFIED
    | (Prelude.==) k "OPTIONAL" = Prelude.Just OPTIONAL
    | (Prelude.==) k "REQUIRED" = Prelude.Just REQUIRED
    | (Prelude.==) k "OUTPUT_ONLY" = Prelude.Just OUTPUT_ONLY
    | (Prelude.==) k "INPUT_ONLY" = Prelude.Just INPUT_ONLY
    | (Prelude.==) k "IMMUTABLE" = Prelude.Just IMMUTABLE
    | (Prelude.==) k "UNORDERED_LIST" = Prelude.Just UNORDERED_LIST
    | (Prelude.==) k "NON_EMPTY_DEFAULT"
    = Prelude.Just NON_EMPTY_DEFAULT
    | (Prelude.==) k "IDENTIFIER" = Prelude.Just IDENTIFIER
    | Prelude.otherwise
    = (Prelude.>>=) (Text.Read.readMaybe k) Data.ProtoLens.maybeToEnum
instance Prelude.Bounded FieldBehavior where
  minBound = FIELD_BEHAVIOR_UNSPECIFIED
  maxBound = IDENTIFIER
instance Prelude.Enum FieldBehavior where
  toEnum k__
    = Prelude.maybe
        (Prelude.error
           ((Prelude.++)
              "toEnum: unknown value for enum FieldBehavior: "
              (Prelude.show k__)))
        Prelude.id (Data.ProtoLens.maybeToEnum k__)
  fromEnum FIELD_BEHAVIOR_UNSPECIFIED = 0
  fromEnum OPTIONAL = 1
  fromEnum REQUIRED = 2
  fromEnum OUTPUT_ONLY = 3
  fromEnum INPUT_ONLY = 4
  fromEnum IMMUTABLE = 5
  fromEnum UNORDERED_LIST = 6
  fromEnum NON_EMPTY_DEFAULT = 7
  fromEnum IDENTIFIER = 8
  fromEnum
    (FieldBehavior'Unrecognized (FieldBehavior'UnrecognizedValue k))
    = Prelude.fromIntegral k
  succ IDENTIFIER
    = Prelude.error
        "FieldBehavior.succ: bad argument IDENTIFIER. This value would be out of bounds."
  succ FIELD_BEHAVIOR_UNSPECIFIED = OPTIONAL
  succ OPTIONAL = REQUIRED
  succ REQUIRED = OUTPUT_ONLY
  succ OUTPUT_ONLY = INPUT_ONLY
  succ INPUT_ONLY = IMMUTABLE
  succ IMMUTABLE = UNORDERED_LIST
  succ UNORDERED_LIST = NON_EMPTY_DEFAULT
  succ NON_EMPTY_DEFAULT = IDENTIFIER
  succ (FieldBehavior'Unrecognized _)
    = Prelude.error
        "FieldBehavior.succ: bad argument: unrecognized value"
  pred FIELD_BEHAVIOR_UNSPECIFIED
    = Prelude.error
        "FieldBehavior.pred: bad argument FIELD_BEHAVIOR_UNSPECIFIED. This value would be out of bounds."
  pred OPTIONAL = FIELD_BEHAVIOR_UNSPECIFIED
  pred REQUIRED = OPTIONAL
  pred OUTPUT_ONLY = REQUIRED
  pred INPUT_ONLY = OUTPUT_ONLY
  pred IMMUTABLE = INPUT_ONLY
  pred UNORDERED_LIST = IMMUTABLE
  pred NON_EMPTY_DEFAULT = UNORDERED_LIST
  pred IDENTIFIER = NON_EMPTY_DEFAULT
  pred (FieldBehavior'Unrecognized _)
    = Prelude.error
        "FieldBehavior.pred: bad argument: unrecognized value"
  enumFrom = Data.ProtoLens.Message.Enum.messageEnumFrom
  enumFromTo = Data.ProtoLens.Message.Enum.messageEnumFromTo
  enumFromThen = Data.ProtoLens.Message.Enum.messageEnumFromThen
  enumFromThenTo = Data.ProtoLens.Message.Enum.messageEnumFromThenTo
instance Data.ProtoLens.FieldDefault FieldBehavior where
  fieldDefault = FIELD_BEHAVIOR_UNSPECIFIED
instance Control.DeepSeq.NFData FieldBehavior where
  rnf x__ = Prelude.seq x__ ()