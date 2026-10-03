{- This file was auto-generated from google/api/client.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Google.Api.Client (
        BatchingConfigProto(), BatchingDescriptorProto(),
        BatchingSettingsProto(), ClientLibraryDestination(..),
        ClientLibraryDestination(),
        ClientLibraryDestination'UnrecognizedValue,
        ClientLibraryOrganization(..), ClientLibraryOrganization(),
        ClientLibraryOrganization'UnrecognizedValue,
        ClientLibrarySettings(), CommonLanguageSettings(), CppSettings(),
        DotnetSettings(), DotnetSettings'RenamedResourcesEntry(),
        DotnetSettings'RenamedServicesEntry(),
        FlowControlLimitExceededBehaviorProto(..),
        FlowControlLimitExceededBehaviorProto(),
        FlowControlLimitExceededBehaviorProto'UnrecognizedValue,
        GoSettings(), GoSettings'RenamedServicesEntry(), JavaSettings(),
        JavaSettings'ServiceClassNamesEntry(), MethodSettings(),
        MethodSettings'LongRunning(), NodeSettings(), PhpSettings(),
        Publishing(), PythonSettings(),
        PythonSettings'ExperimentalFeatures(), RubySettings(),
        SelectiveGapicGeneration()
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
import qualified Proto.Google.Api.LaunchStage
import qualified Proto.Google.Protobuf.Descriptor
import qualified Proto.Google.Protobuf.Duration
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.thresholds' @:: Lens' BatchingConfigProto BatchingSettingsProto@
         * 'Proto.Google.Api.Client_Fields.maybe'thresholds' @:: Lens' BatchingConfigProto (Prelude.Maybe BatchingSettingsProto)@
         * 'Proto.Google.Api.Client_Fields.batchDescriptor' @:: Lens' BatchingConfigProto BatchingDescriptorProto@
         * 'Proto.Google.Api.Client_Fields.maybe'batchDescriptor' @:: Lens' BatchingConfigProto (Prelude.Maybe BatchingDescriptorProto)@ -}
data BatchingConfigProto
  = BatchingConfigProto'_constructor {_BatchingConfigProto'thresholds :: !(Prelude.Maybe BatchingSettingsProto),
                                      _BatchingConfigProto'batchDescriptor :: !(Prelude.Maybe BatchingDescriptorProto),
                                      _BatchingConfigProto'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show BatchingConfigProto where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField BatchingConfigProto "thresholds" BatchingSettingsProto where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingConfigProto'thresholds
           (\ x__ y__ -> x__ {_BatchingConfigProto'thresholds = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField BatchingConfigProto "maybe'thresholds" (Prelude.Maybe BatchingSettingsProto) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingConfigProto'thresholds
           (\ x__ y__ -> x__ {_BatchingConfigProto'thresholds = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingConfigProto "batchDescriptor" BatchingDescriptorProto where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingConfigProto'batchDescriptor
           (\ x__ y__ -> x__ {_BatchingConfigProto'batchDescriptor = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField BatchingConfigProto "maybe'batchDescriptor" (Prelude.Maybe BatchingDescriptorProto) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingConfigProto'batchDescriptor
           (\ x__ y__ -> x__ {_BatchingConfigProto'batchDescriptor = y__}))
        Prelude.id
instance Data.ProtoLens.Message BatchingConfigProto where
  messageName _ = Data.Text.pack "google.api.BatchingConfigProto"
  packedMessageDescriptor _
    = "\n\
      \\DC3BatchingConfigProto\DC2A\n\
      \\n\
      \thresholds\CAN\SOH \SOH(\v2!.google.api.BatchingSettingsProtoR\n\
      \thresholds\DC2N\n\
      \\DLEbatch_descriptor\CAN\STX \SOH(\v2#.google.api.BatchingDescriptorProtoR\SIbatchDescriptor"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        thresholds__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "thresholds"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor BatchingSettingsProto)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'thresholds")) ::
              Data.ProtoLens.FieldDescriptor BatchingConfigProto
        batchDescriptor__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "batch_descriptor"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor BatchingDescriptorProto)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'batchDescriptor")) ::
              Data.ProtoLens.FieldDescriptor BatchingConfigProto
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, thresholds__field_descriptor),
           (Data.ProtoLens.Tag 2, batchDescriptor__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _BatchingConfigProto'_unknownFields
        (\ x__ y__ -> x__ {_BatchingConfigProto'_unknownFields = y__})
  defMessage
    = BatchingConfigProto'_constructor
        {_BatchingConfigProto'thresholds = Prelude.Nothing,
         _BatchingConfigProto'batchDescriptor = Prelude.Nothing,
         _BatchingConfigProto'_unknownFields = []}
  parseMessage
    = let
        loop ::
          BatchingConfigProto
          -> Data.ProtoLens.Encoding.Bytes.Parser BatchingConfigProto
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "thresholds"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"thresholds") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "batch_descriptor"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"batchDescriptor") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "BatchingConfigProto"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view
                    (Data.ProtoLens.Field.field @"maybe'thresholds") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             ((Data.Monoid.<>)
                (case
                     Lens.Family2.view
                       (Data.ProtoLens.Field.field @"maybe'batchDescriptor") _x
                 of
                   Prelude.Nothing -> Data.Monoid.mempty
                   (Prelude.Just _v)
                     -> (Data.Monoid.<>)
                          (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                          ((Prelude..)
                             (\ bs
                                -> (Data.Monoid.<>)
                                     (Data.ProtoLens.Encoding.Bytes.putVarInt
                                        (Prelude.fromIntegral (Data.ByteString.length bs)))
                                     (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                             Data.ProtoLens.encodeMessage _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData BatchingConfigProto where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_BatchingConfigProto'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_BatchingConfigProto'thresholds x__)
                (Control.DeepSeq.deepseq
                   (_BatchingConfigProto'batchDescriptor x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.batchedField' @:: Lens' BatchingDescriptorProto Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.discriminatorFields' @:: Lens' BatchingDescriptorProto [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'discriminatorFields' @:: Lens' BatchingDescriptorProto (Data.Vector.Vector Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.subresponseField' @:: Lens' BatchingDescriptorProto Data.Text.Text@ -}
data BatchingDescriptorProto
  = BatchingDescriptorProto'_constructor {_BatchingDescriptorProto'batchedField :: !Data.Text.Text,
                                          _BatchingDescriptorProto'discriminatorFields :: !(Data.Vector.Vector Data.Text.Text),
                                          _BatchingDescriptorProto'subresponseField :: !Data.Text.Text,
                                          _BatchingDescriptorProto'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show BatchingDescriptorProto where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField BatchingDescriptorProto "batchedField" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingDescriptorProto'batchedField
           (\ x__ y__ -> x__ {_BatchingDescriptorProto'batchedField = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingDescriptorProto "discriminatorFields" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingDescriptorProto'discriminatorFields
           (\ x__ y__
              -> x__ {_BatchingDescriptorProto'discriminatorFields = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField BatchingDescriptorProto "vec'discriminatorFields" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingDescriptorProto'discriminatorFields
           (\ x__ y__
              -> x__ {_BatchingDescriptorProto'discriminatorFields = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingDescriptorProto "subresponseField" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingDescriptorProto'subresponseField
           (\ x__ y__
              -> x__ {_BatchingDescriptorProto'subresponseField = y__}))
        Prelude.id
instance Data.ProtoLens.Message BatchingDescriptorProto where
  messageName _ = Data.Text.pack "google.api.BatchingDescriptorProto"
  packedMessageDescriptor _
    = "\n\
      \\ETBBatchingDescriptorProto\DC2#\n\
      \\rbatched_field\CAN\SOH \SOH(\tR\fbatchedField\DC21\n\
      \\DC4discriminator_fields\CAN\STX \ETX(\tR\DC3discriminatorFields\DC2+\n\
      \\DC1subresponse_field\CAN\ETX \SOH(\tR\DLEsubresponseField"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        batchedField__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "batched_field"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"batchedField")) ::
              Data.ProtoLens.FieldDescriptor BatchingDescriptorProto
        discriminatorFields__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "discriminator_fields"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"discriminatorFields")) ::
              Data.ProtoLens.FieldDescriptor BatchingDescriptorProto
        subresponseField__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "subresponse_field"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"subresponseField")) ::
              Data.ProtoLens.FieldDescriptor BatchingDescriptorProto
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, batchedField__field_descriptor),
           (Data.ProtoLens.Tag 2, discriminatorFields__field_descriptor),
           (Data.ProtoLens.Tag 3, subresponseField__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _BatchingDescriptorProto'_unknownFields
        (\ x__ y__ -> x__ {_BatchingDescriptorProto'_unknownFields = y__})
  defMessage
    = BatchingDescriptorProto'_constructor
        {_BatchingDescriptorProto'batchedField = Data.ProtoLens.fieldDefault,
         _BatchingDescriptorProto'discriminatorFields = Data.Vector.Generic.empty,
         _BatchingDescriptorProto'subresponseField = Data.ProtoLens.fieldDefault,
         _BatchingDescriptorProto'_unknownFields = []}
  parseMessage
    = let
        loop ::
          BatchingDescriptorProto
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
             -> Data.ProtoLens.Encoding.Bytes.Parser BatchingDescriptorProto
        loop x mutable'discriminatorFields
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'discriminatorFields <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                      (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                         mutable'discriminatorFields)
                      (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t)
                           (Lens.Family2.set
                              (Data.ProtoLens.Field.field @"vec'discriminatorFields")
                              frozen'discriminatorFields x))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "batched_field"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"batchedField") y x)
                                  mutable'discriminatorFields
                        18
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "discriminator_fields"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'discriminatorFields y)
                                loop x v
                        26
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "subresponse_field"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"subresponseField") y x)
                                  mutable'discriminatorFields
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'discriminatorFields
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'discriminatorFields <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                               Data.ProtoLens.Encoding.Growing.new
              loop Data.ProtoLens.defMessage mutable'discriminatorFields)
          "BatchingDescriptorProto"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view (Data.ProtoLens.Field.field @"batchedField") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                   (\ _v
                      -> (Data.Monoid.<>)
                           (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                           ((Prelude..)
                              (\ bs
                                 -> (Data.Monoid.<>)
                                      (Data.ProtoLens.Encoding.Bytes.putVarInt
                                         (Prelude.fromIntegral (Data.ByteString.length bs)))
                                      (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                              Data.Text.Encoding.encodeUtf8 _v))
                   (Lens.Family2.view
                      (Data.ProtoLens.Field.field @"vec'discriminatorFields") _x))
                ((Data.Monoid.<>)
                   (let
                      _v
                        = Lens.Family2.view
                            (Data.ProtoLens.Field.field @"subresponseField") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                            ((Prelude..)
                               (\ bs
                                  -> (Data.Monoid.<>)
                                       (Data.ProtoLens.Encoding.Bytes.putVarInt
                                          (Prelude.fromIntegral (Data.ByteString.length bs)))
                                       (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                               Data.Text.Encoding.encodeUtf8 _v))
                   (Data.ProtoLens.Encoding.Wire.buildFieldSet
                      (Lens.Family2.view Data.ProtoLens.unknownFields _x))))
instance Control.DeepSeq.NFData BatchingDescriptorProto where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_BatchingDescriptorProto'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_BatchingDescriptorProto'batchedField x__)
                (Control.DeepSeq.deepseq
                   (_BatchingDescriptorProto'discriminatorFields x__)
                   (Control.DeepSeq.deepseq
                      (_BatchingDescriptorProto'subresponseField x__) ())))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.elementCountThreshold' @:: Lens' BatchingSettingsProto Data.Int.Int32@
         * 'Proto.Google.Api.Client_Fields.requestByteThreshold' @:: Lens' BatchingSettingsProto Data.Int.Int64@
         * 'Proto.Google.Api.Client_Fields.delayThreshold' @:: Lens' BatchingSettingsProto Proto.Google.Protobuf.Duration.Duration@
         * 'Proto.Google.Api.Client_Fields.maybe'delayThreshold' @:: Lens' BatchingSettingsProto (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration)@
         * 'Proto.Google.Api.Client_Fields.elementCountLimit' @:: Lens' BatchingSettingsProto Data.Int.Int32@
         * 'Proto.Google.Api.Client_Fields.requestByteLimit' @:: Lens' BatchingSettingsProto Data.Int.Int32@
         * 'Proto.Google.Api.Client_Fields.flowControlElementLimit' @:: Lens' BatchingSettingsProto Data.Int.Int32@
         * 'Proto.Google.Api.Client_Fields.flowControlByteLimit' @:: Lens' BatchingSettingsProto Data.Int.Int32@
         * 'Proto.Google.Api.Client_Fields.flowControlLimitExceededBehavior' @:: Lens' BatchingSettingsProto FlowControlLimitExceededBehaviorProto@ -}
data BatchingSettingsProto
  = BatchingSettingsProto'_constructor {_BatchingSettingsProto'elementCountThreshold :: !Data.Int.Int32,
                                        _BatchingSettingsProto'requestByteThreshold :: !Data.Int.Int64,
                                        _BatchingSettingsProto'delayThreshold :: !(Prelude.Maybe Proto.Google.Protobuf.Duration.Duration),
                                        _BatchingSettingsProto'elementCountLimit :: !Data.Int.Int32,
                                        _BatchingSettingsProto'requestByteLimit :: !Data.Int.Int32,
                                        _BatchingSettingsProto'flowControlElementLimit :: !Data.Int.Int32,
                                        _BatchingSettingsProto'flowControlByteLimit :: !Data.Int.Int32,
                                        _BatchingSettingsProto'flowControlLimitExceededBehavior :: !FlowControlLimitExceededBehaviorProto,
                                        _BatchingSettingsProto'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show BatchingSettingsProto where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "elementCountThreshold" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'elementCountThreshold
           (\ x__ y__
              -> x__ {_BatchingSettingsProto'elementCountThreshold = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "requestByteThreshold" Data.Int.Int64 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'requestByteThreshold
           (\ x__ y__
              -> x__ {_BatchingSettingsProto'requestByteThreshold = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "delayThreshold" Proto.Google.Protobuf.Duration.Duration where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'delayThreshold
           (\ x__ y__ -> x__ {_BatchingSettingsProto'delayThreshold = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "maybe'delayThreshold" (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'delayThreshold
           (\ x__ y__ -> x__ {_BatchingSettingsProto'delayThreshold = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "elementCountLimit" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'elementCountLimit
           (\ x__ y__
              -> x__ {_BatchingSettingsProto'elementCountLimit = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "requestByteLimit" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'requestByteLimit
           (\ x__ y__ -> x__ {_BatchingSettingsProto'requestByteLimit = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "flowControlElementLimit" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'flowControlElementLimit
           (\ x__ y__
              -> x__ {_BatchingSettingsProto'flowControlElementLimit = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "flowControlByteLimit" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'flowControlByteLimit
           (\ x__ y__
              -> x__ {_BatchingSettingsProto'flowControlByteLimit = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField BatchingSettingsProto "flowControlLimitExceededBehavior" FlowControlLimitExceededBehaviorProto where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _BatchingSettingsProto'flowControlLimitExceededBehavior
           (\ x__ y__
              -> x__
                   {_BatchingSettingsProto'flowControlLimitExceededBehavior = y__}))
        Prelude.id
instance Data.ProtoLens.Message BatchingSettingsProto where
  messageName _ = Data.Text.pack "google.api.BatchingSettingsProto"
  packedMessageDescriptor _
    = "\n\
      \\NAKBatchingSettingsProto\DC26\n\
      \\ETBelement_count_threshold\CAN\SOH \SOH(\ENQR\NAKelementCountThreshold\DC24\n\
      \\SYNrequest_byte_threshold\CAN\STX \SOH(\ETXR\DC4requestByteThreshold\DC2B\n\
      \\SIdelay_threshold\CAN\ETX \SOH(\v2\EM.google.protobuf.DurationR\SOdelayThreshold\DC2.\n\
      \\DC3element_count_limit\CAN\EOT \SOH(\ENQR\DC1elementCountLimit\DC2,\n\
      \\DC2request_byte_limit\CAN\ENQ \SOH(\ENQR\DLErequestByteLimit\DC2;\n\
      \\SUBflow_control_element_limit\CAN\ACK \SOH(\ENQR\ETBflowControlElementLimit\DC25\n\
      \\ETBflow_control_byte_limit\CAN\a \SOH(\ENQR\DC4flowControlByteLimit\DC2\129\SOH\n\
      \$flow_control_limit_exceeded_behavior\CAN\b \SOH(\SO21.google.api.FlowControlLimitExceededBehaviorProtoR flowControlLimitExceededBehavior"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        elementCountThreshold__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "element_count_threshold"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"elementCountThreshold")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        requestByteThreshold__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "request_byte_threshold"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int64Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int64)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"requestByteThreshold")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        delayThreshold__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "delay_threshold"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Duration.Duration)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'delayThreshold")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        elementCountLimit__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "element_count_limit"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"elementCountLimit")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        requestByteLimit__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "request_byte_limit"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"requestByteLimit")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        flowControlElementLimit__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "flow_control_element_limit"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"flowControlElementLimit")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        flowControlByteLimit__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "flow_control_byte_limit"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"flowControlByteLimit")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
        flowControlLimitExceededBehavior__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "flow_control_limit_exceeded_behavior"
              (Data.ProtoLens.ScalarField Data.ProtoLens.EnumField ::
                 Data.ProtoLens.FieldTypeDescriptor FlowControlLimitExceededBehaviorProto)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field
                    @"flowControlLimitExceededBehavior")) ::
              Data.ProtoLens.FieldDescriptor BatchingSettingsProto
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, elementCountThreshold__field_descriptor),
           (Data.ProtoLens.Tag 2, requestByteThreshold__field_descriptor),
           (Data.ProtoLens.Tag 3, delayThreshold__field_descriptor),
           (Data.ProtoLens.Tag 4, elementCountLimit__field_descriptor),
           (Data.ProtoLens.Tag 5, requestByteLimit__field_descriptor),
           (Data.ProtoLens.Tag 6, flowControlElementLimit__field_descriptor),
           (Data.ProtoLens.Tag 7, flowControlByteLimit__field_descriptor),
           (Data.ProtoLens.Tag 8, 
            flowControlLimitExceededBehavior__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _BatchingSettingsProto'_unknownFields
        (\ x__ y__ -> x__ {_BatchingSettingsProto'_unknownFields = y__})
  defMessage
    = BatchingSettingsProto'_constructor
        {_BatchingSettingsProto'elementCountThreshold = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'requestByteThreshold = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'delayThreshold = Prelude.Nothing,
         _BatchingSettingsProto'elementCountLimit = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'requestByteLimit = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'flowControlElementLimit = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'flowControlByteLimit = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'flowControlLimitExceededBehavior = Data.ProtoLens.fieldDefault,
         _BatchingSettingsProto'_unknownFields = []}
  parseMessage
    = let
        loop ::
          BatchingSettingsProto
          -> Data.ProtoLens.Encoding.Bytes.Parser BatchingSettingsProto
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        8 -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "element_count_threshold"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"elementCountThreshold") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "request_byte_threshold"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"requestByteThreshold") y x)
                        26
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "delay_threshold"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"delayThreshold") y x)
                        32
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "element_count_limit"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"elementCountLimit") y x)
                        40
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "request_byte_limit"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"requestByteLimit") y x)
                        48
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "flow_control_element_limit"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"flowControlElementLimit") y x)
                        56
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "flow_control_byte_limit"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"flowControlByteLimit") y x)
                        64
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.toEnum
                                          (Prelude.fmap
                                             Prelude.fromIntegral
                                             Data.ProtoLens.Encoding.Bytes.getVarInt))
                                       "flow_control_limit_exceeded_behavior"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field
                                        @"flowControlLimitExceededBehavior")
                                     y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "BatchingSettingsProto"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view
                      (Data.ProtoLens.Field.field @"elementCountThreshold") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 8)
                      ((Prelude..)
                         Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"requestByteThreshold") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 16)
                         ((Prelude..)
                            Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
                ((Data.Monoid.<>)
                   (case
                        Lens.Family2.view
                          (Data.ProtoLens.Field.field @"maybe'delayThreshold") _x
                    of
                      Prelude.Nothing -> Data.Monoid.mempty
                      (Prelude.Just _v)
                        -> (Data.Monoid.<>)
                             (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                             ((Prelude..)
                                (\ bs
                                   -> (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt
                                           (Prelude.fromIntegral (Data.ByteString.length bs)))
                                        (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                Data.ProtoLens.encodeMessage _v))
                   ((Data.Monoid.<>)
                      (let
                         _v
                           = Lens.Family2.view
                               (Data.ProtoLens.Field.field @"elementCountLimit") _x
                       in
                         if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                             Data.Monoid.mempty
                         else
                             (Data.Monoid.<>)
                               (Data.ProtoLens.Encoding.Bytes.putVarInt 32)
                               ((Prelude..)
                                  Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
                      ((Data.Monoid.<>)
                         (let
                            _v
                              = Lens.Family2.view
                                  (Data.ProtoLens.Field.field @"requestByteLimit") _x
                          in
                            if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                Data.Monoid.mempty
                            else
                                (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt 40)
                                  ((Prelude..)
                                     Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral
                                     _v))
                         ((Data.Monoid.<>)
                            (let
                               _v
                                 = Lens.Family2.view
                                     (Data.ProtoLens.Field.field @"flowControlElementLimit") _x
                             in
                               if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                   Data.Monoid.mempty
                               else
                                   (Data.Monoid.<>)
                                     (Data.ProtoLens.Encoding.Bytes.putVarInt 48)
                                     ((Prelude..)
                                        Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral
                                        _v))
                            ((Data.Monoid.<>)
                               (let
                                  _v
                                    = Lens.Family2.view
                                        (Data.ProtoLens.Field.field @"flowControlByteLimit") _x
                                in
                                  if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                      Data.Monoid.mempty
                                  else
                                      (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt 56)
                                        ((Prelude..)
                                           Data.ProtoLens.Encoding.Bytes.putVarInt
                                           Prelude.fromIntegral _v))
                               ((Data.Monoid.<>)
                                  (let
                                     _v
                                       = Lens.Family2.view
                                           (Data.ProtoLens.Field.field
                                              @"flowControlLimitExceededBehavior")
                                           _x
                                   in
                                     if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                         Data.Monoid.mempty
                                     else
                                         (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt 64)
                                           ((Prelude..)
                                              ((Prelude..)
                                                 Data.ProtoLens.Encoding.Bytes.putVarInt
                                                 Prelude.fromIntegral)
                                              Prelude.fromEnum _v))
                                  (Data.ProtoLens.Encoding.Wire.buildFieldSet
                                     (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))))))
instance Control.DeepSeq.NFData BatchingSettingsProto where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_BatchingSettingsProto'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_BatchingSettingsProto'elementCountThreshold x__)
                (Control.DeepSeq.deepseq
                   (_BatchingSettingsProto'requestByteThreshold x__)
                   (Control.DeepSeq.deepseq
                      (_BatchingSettingsProto'delayThreshold x__)
                      (Control.DeepSeq.deepseq
                         (_BatchingSettingsProto'elementCountLimit x__)
                         (Control.DeepSeq.deepseq
                            (_BatchingSettingsProto'requestByteLimit x__)
                            (Control.DeepSeq.deepseq
                               (_BatchingSettingsProto'flowControlElementLimit x__)
                               (Control.DeepSeq.deepseq
                                  (_BatchingSettingsProto'flowControlByteLimit x__)
                                  (Control.DeepSeq.deepseq
                                     (_BatchingSettingsProto'flowControlLimitExceededBehavior x__)
                                     ()))))))))
newtype ClientLibraryDestination'UnrecognizedValue
  = ClientLibraryDestination'UnrecognizedValue Data.Int.Int32
  deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show)
data ClientLibraryDestination
  = CLIENT_LIBRARY_DESTINATION_UNSPECIFIED |
    GITHUB |
    PACKAGE_MANAGER |
    ClientLibraryDestination'Unrecognized !ClientLibraryDestination'UnrecognizedValue
  deriving stock (Prelude.Show, Prelude.Eq, Prelude.Ord)
instance Data.ProtoLens.MessageEnum ClientLibraryDestination where
  maybeToEnum 0 = Prelude.Just CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
  maybeToEnum 10 = Prelude.Just GITHUB
  maybeToEnum 20 = Prelude.Just PACKAGE_MANAGER
  maybeToEnum k
    = Prelude.Just
        (ClientLibraryDestination'Unrecognized
           (ClientLibraryDestination'UnrecognizedValue
              (Prelude.fromIntegral k)))
  showEnum CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
    = "CLIENT_LIBRARY_DESTINATION_UNSPECIFIED"
  showEnum GITHUB = "GITHUB"
  showEnum PACKAGE_MANAGER = "PACKAGE_MANAGER"
  showEnum
    (ClientLibraryDestination'Unrecognized (ClientLibraryDestination'UnrecognizedValue k))
    = Prelude.show k
  readEnum k
    | (Prelude.==) k "CLIENT_LIBRARY_DESTINATION_UNSPECIFIED"
    = Prelude.Just CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
    | (Prelude.==) k "GITHUB" = Prelude.Just GITHUB
    | (Prelude.==) k "PACKAGE_MANAGER" = Prelude.Just PACKAGE_MANAGER
    | Prelude.otherwise
    = (Prelude.>>=) (Text.Read.readMaybe k) Data.ProtoLens.maybeToEnum
instance Prelude.Bounded ClientLibraryDestination where
  minBound = CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
  maxBound = PACKAGE_MANAGER
instance Prelude.Enum ClientLibraryDestination where
  toEnum k__
    = Prelude.maybe
        (Prelude.error
           ((Prelude.++)
              "toEnum: unknown value for enum ClientLibraryDestination: "
              (Prelude.show k__)))
        Prelude.id (Data.ProtoLens.maybeToEnum k__)
  fromEnum CLIENT_LIBRARY_DESTINATION_UNSPECIFIED = 0
  fromEnum GITHUB = 10
  fromEnum PACKAGE_MANAGER = 20
  fromEnum
    (ClientLibraryDestination'Unrecognized (ClientLibraryDestination'UnrecognizedValue k))
    = Prelude.fromIntegral k
  succ PACKAGE_MANAGER
    = Prelude.error
        "ClientLibraryDestination.succ: bad argument PACKAGE_MANAGER. This value would be out of bounds."
  succ CLIENT_LIBRARY_DESTINATION_UNSPECIFIED = GITHUB
  succ GITHUB = PACKAGE_MANAGER
  succ (ClientLibraryDestination'Unrecognized _)
    = Prelude.error
        "ClientLibraryDestination.succ: bad argument: unrecognized value"
  pred CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
    = Prelude.error
        "ClientLibraryDestination.pred: bad argument CLIENT_LIBRARY_DESTINATION_UNSPECIFIED. This value would be out of bounds."
  pred GITHUB = CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
  pred PACKAGE_MANAGER = GITHUB
  pred (ClientLibraryDestination'Unrecognized _)
    = Prelude.error
        "ClientLibraryDestination.pred: bad argument: unrecognized value"
  enumFrom = Data.ProtoLens.Message.Enum.messageEnumFrom
  enumFromTo = Data.ProtoLens.Message.Enum.messageEnumFromTo
  enumFromThen = Data.ProtoLens.Message.Enum.messageEnumFromThen
  enumFromThenTo = Data.ProtoLens.Message.Enum.messageEnumFromThenTo
instance Data.ProtoLens.FieldDefault ClientLibraryDestination where
  fieldDefault = CLIENT_LIBRARY_DESTINATION_UNSPECIFIED
instance Control.DeepSeq.NFData ClientLibraryDestination where
  rnf x__ = Prelude.seq x__ ()
newtype ClientLibraryOrganization'UnrecognizedValue
  = ClientLibraryOrganization'UnrecognizedValue Data.Int.Int32
  deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show)
data ClientLibraryOrganization
  = CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED |
    CLOUD |
    ADS |
    PHOTOS |
    STREET_VIEW |
    SHOPPING |
    GEO |
    GENERATIVE_AI |
    ClientLibraryOrganization'Unrecognized !ClientLibraryOrganization'UnrecognizedValue
  deriving stock (Prelude.Show, Prelude.Eq, Prelude.Ord)
instance Data.ProtoLens.MessageEnum ClientLibraryOrganization where
  maybeToEnum 0
    = Prelude.Just CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
  maybeToEnum 1 = Prelude.Just CLOUD
  maybeToEnum 2 = Prelude.Just ADS
  maybeToEnum 3 = Prelude.Just PHOTOS
  maybeToEnum 4 = Prelude.Just STREET_VIEW
  maybeToEnum 5 = Prelude.Just SHOPPING
  maybeToEnum 6 = Prelude.Just GEO
  maybeToEnum 7 = Prelude.Just GENERATIVE_AI
  maybeToEnum k
    = Prelude.Just
        (ClientLibraryOrganization'Unrecognized
           (ClientLibraryOrganization'UnrecognizedValue
              (Prelude.fromIntegral k)))
  showEnum CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
    = "CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED"
  showEnum CLOUD = "CLOUD"
  showEnum ADS = "ADS"
  showEnum PHOTOS = "PHOTOS"
  showEnum STREET_VIEW = "STREET_VIEW"
  showEnum SHOPPING = "SHOPPING"
  showEnum GEO = "GEO"
  showEnum GENERATIVE_AI = "GENERATIVE_AI"
  showEnum
    (ClientLibraryOrganization'Unrecognized (ClientLibraryOrganization'UnrecognizedValue k))
    = Prelude.show k
  readEnum k
    | (Prelude.==) k "CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED"
    = Prelude.Just CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
    | (Prelude.==) k "CLOUD" = Prelude.Just CLOUD
    | (Prelude.==) k "ADS" = Prelude.Just ADS
    | (Prelude.==) k "PHOTOS" = Prelude.Just PHOTOS
    | (Prelude.==) k "STREET_VIEW" = Prelude.Just STREET_VIEW
    | (Prelude.==) k "SHOPPING" = Prelude.Just SHOPPING
    | (Prelude.==) k "GEO" = Prelude.Just GEO
    | (Prelude.==) k "GENERATIVE_AI" = Prelude.Just GENERATIVE_AI
    | Prelude.otherwise
    = (Prelude.>>=) (Text.Read.readMaybe k) Data.ProtoLens.maybeToEnum
instance Prelude.Bounded ClientLibraryOrganization where
  minBound = CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
  maxBound = GENERATIVE_AI
instance Prelude.Enum ClientLibraryOrganization where
  toEnum k__
    = Prelude.maybe
        (Prelude.error
           ((Prelude.++)
              "toEnum: unknown value for enum ClientLibraryOrganization: "
              (Prelude.show k__)))
        Prelude.id (Data.ProtoLens.maybeToEnum k__)
  fromEnum CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED = 0
  fromEnum CLOUD = 1
  fromEnum ADS = 2
  fromEnum PHOTOS = 3
  fromEnum STREET_VIEW = 4
  fromEnum SHOPPING = 5
  fromEnum GEO = 6
  fromEnum GENERATIVE_AI = 7
  fromEnum
    (ClientLibraryOrganization'Unrecognized (ClientLibraryOrganization'UnrecognizedValue k))
    = Prelude.fromIntegral k
  succ GENERATIVE_AI
    = Prelude.error
        "ClientLibraryOrganization.succ: bad argument GENERATIVE_AI. This value would be out of bounds."
  succ CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED = CLOUD
  succ CLOUD = ADS
  succ ADS = PHOTOS
  succ PHOTOS = STREET_VIEW
  succ STREET_VIEW = SHOPPING
  succ SHOPPING = GEO
  succ GEO = GENERATIVE_AI
  succ (ClientLibraryOrganization'Unrecognized _)
    = Prelude.error
        "ClientLibraryOrganization.succ: bad argument: unrecognized value"
  pred CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
    = Prelude.error
        "ClientLibraryOrganization.pred: bad argument CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED. This value would be out of bounds."
  pred CLOUD = CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
  pred ADS = CLOUD
  pred PHOTOS = ADS
  pred STREET_VIEW = PHOTOS
  pred SHOPPING = STREET_VIEW
  pred GEO = SHOPPING
  pred GENERATIVE_AI = GEO
  pred (ClientLibraryOrganization'Unrecognized _)
    = Prelude.error
        "ClientLibraryOrganization.pred: bad argument: unrecognized value"
  enumFrom = Data.ProtoLens.Message.Enum.messageEnumFrom
  enumFromTo = Data.ProtoLens.Message.Enum.messageEnumFromTo
  enumFromThen = Data.ProtoLens.Message.Enum.messageEnumFromThen
  enumFromThenTo = Data.ProtoLens.Message.Enum.messageEnumFromThenTo
instance Data.ProtoLens.FieldDefault ClientLibraryOrganization where
  fieldDefault = CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED
instance Control.DeepSeq.NFData ClientLibraryOrganization where
  rnf x__ = Prelude.seq x__ ()
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.version' @:: Lens' ClientLibrarySettings Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.launchStage' @:: Lens' ClientLibrarySettings Proto.Google.Api.LaunchStage.LaunchStage@
         * 'Proto.Google.Api.Client_Fields.restNumericEnums' @:: Lens' ClientLibrarySettings Prelude.Bool@
         * 'Proto.Google.Api.Client_Fields.javaSettings' @:: Lens' ClientLibrarySettings JavaSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'javaSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe JavaSettings)@
         * 'Proto.Google.Api.Client_Fields.cppSettings' @:: Lens' ClientLibrarySettings CppSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'cppSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe CppSettings)@
         * 'Proto.Google.Api.Client_Fields.phpSettings' @:: Lens' ClientLibrarySettings PhpSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'phpSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe PhpSettings)@
         * 'Proto.Google.Api.Client_Fields.pythonSettings' @:: Lens' ClientLibrarySettings PythonSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'pythonSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe PythonSettings)@
         * 'Proto.Google.Api.Client_Fields.nodeSettings' @:: Lens' ClientLibrarySettings NodeSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'nodeSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe NodeSettings)@
         * 'Proto.Google.Api.Client_Fields.dotnetSettings' @:: Lens' ClientLibrarySettings DotnetSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'dotnetSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe DotnetSettings)@
         * 'Proto.Google.Api.Client_Fields.rubySettings' @:: Lens' ClientLibrarySettings RubySettings@
         * 'Proto.Google.Api.Client_Fields.maybe'rubySettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe RubySettings)@
         * 'Proto.Google.Api.Client_Fields.goSettings' @:: Lens' ClientLibrarySettings GoSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'goSettings' @:: Lens' ClientLibrarySettings (Prelude.Maybe GoSettings)@ -}
data ClientLibrarySettings
  = ClientLibrarySettings'_constructor {_ClientLibrarySettings'version :: !Data.Text.Text,
                                        _ClientLibrarySettings'launchStage :: !Proto.Google.Api.LaunchStage.LaunchStage,
                                        _ClientLibrarySettings'restNumericEnums :: !Prelude.Bool,
                                        _ClientLibrarySettings'javaSettings :: !(Prelude.Maybe JavaSettings),
                                        _ClientLibrarySettings'cppSettings :: !(Prelude.Maybe CppSettings),
                                        _ClientLibrarySettings'phpSettings :: !(Prelude.Maybe PhpSettings),
                                        _ClientLibrarySettings'pythonSettings :: !(Prelude.Maybe PythonSettings),
                                        _ClientLibrarySettings'nodeSettings :: !(Prelude.Maybe NodeSettings),
                                        _ClientLibrarySettings'dotnetSettings :: !(Prelude.Maybe DotnetSettings),
                                        _ClientLibrarySettings'rubySettings :: !(Prelude.Maybe RubySettings),
                                        _ClientLibrarySettings'goSettings :: !(Prelude.Maybe GoSettings),
                                        _ClientLibrarySettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show ClientLibrarySettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "version" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'version
           (\ x__ y__ -> x__ {_ClientLibrarySettings'version = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "launchStage" Proto.Google.Api.LaunchStage.LaunchStage where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'launchStage
           (\ x__ y__ -> x__ {_ClientLibrarySettings'launchStage = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "restNumericEnums" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'restNumericEnums
           (\ x__ y__ -> x__ {_ClientLibrarySettings'restNumericEnums = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "javaSettings" JavaSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'javaSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'javaSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'javaSettings" (Prelude.Maybe JavaSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'javaSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'javaSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "cppSettings" CppSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'cppSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'cppSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'cppSettings" (Prelude.Maybe CppSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'cppSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'cppSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "phpSettings" PhpSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'phpSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'phpSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'phpSettings" (Prelude.Maybe PhpSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'phpSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'phpSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "pythonSettings" PythonSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'pythonSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'pythonSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'pythonSettings" (Prelude.Maybe PythonSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'pythonSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'pythonSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "nodeSettings" NodeSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'nodeSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'nodeSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'nodeSettings" (Prelude.Maybe NodeSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'nodeSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'nodeSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "dotnetSettings" DotnetSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'dotnetSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'dotnetSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'dotnetSettings" (Prelude.Maybe DotnetSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'dotnetSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'dotnetSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "rubySettings" RubySettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'rubySettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'rubySettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'rubySettings" (Prelude.Maybe RubySettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'rubySettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'rubySettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "goSettings" GoSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'goSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'goSettings = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField ClientLibrarySettings "maybe'goSettings" (Prelude.Maybe GoSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ClientLibrarySettings'goSettings
           (\ x__ y__ -> x__ {_ClientLibrarySettings'goSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Message ClientLibrarySettings where
  messageName _ = Data.Text.pack "google.api.ClientLibrarySettings"
  packedMessageDescriptor _
    = "\n\
      \\NAKClientLibrarySettings\DC2\CAN\n\
      \\aversion\CAN\SOH \SOH(\tR\aversion\DC2:\n\
      \\flaunch_stage\CAN\STX \SOH(\SO2\ETB.google.api.LaunchStageR\vlaunchStage\DC2,\n\
      \\DC2rest_numeric_enums\CAN\ETX \SOH(\bR\DLErestNumericEnums\DC2=\n\
      \\rjava_settings\CAN\NAK \SOH(\v2\CAN.google.api.JavaSettingsR\fjavaSettings\DC2:\n\
      \\fcpp_settings\CAN\SYN \SOH(\v2\ETB.google.api.CppSettingsR\vcppSettings\DC2:\n\
      \\fphp_settings\CAN\ETB \SOH(\v2\ETB.google.api.PhpSettingsR\vphpSettings\DC2C\n\
      \\SIpython_settings\CAN\CAN \SOH(\v2\SUB.google.api.PythonSettingsR\SOpythonSettings\DC2=\n\
      \\rnode_settings\CAN\EM \SOH(\v2\CAN.google.api.NodeSettingsR\fnodeSettings\DC2C\n\
      \\SIdotnet_settings\CAN\SUB \SOH(\v2\SUB.google.api.DotnetSettingsR\SOdotnetSettings\DC2=\n\
      \\rruby_settings\CAN\ESC \SOH(\v2\CAN.google.api.RubySettingsR\frubySettings\DC27\n\
      \\vgo_settings\CAN\FS \SOH(\v2\SYN.google.api.GoSettingsR\n\
      \goSettings"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        version__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "version"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"version")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        launchStage__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "launch_stage"
              (Data.ProtoLens.ScalarField Data.ProtoLens.EnumField ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Api.LaunchStage.LaunchStage)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"launchStage")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        restNumericEnums__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "rest_numeric_enums"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"restNumericEnums")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        javaSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "java_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor JavaSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'javaSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        cppSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "cpp_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CppSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'cppSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        phpSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "php_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor PhpSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'phpSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        pythonSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "python_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor PythonSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'pythonSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        nodeSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "node_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor NodeSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'nodeSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        dotnetSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "dotnet_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor DotnetSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'dotnetSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        rubySettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "ruby_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor RubySettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'rubySettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
        goSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "go_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor GoSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'goSettings")) ::
              Data.ProtoLens.FieldDescriptor ClientLibrarySettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, version__field_descriptor),
           (Data.ProtoLens.Tag 2, launchStage__field_descriptor),
           (Data.ProtoLens.Tag 3, restNumericEnums__field_descriptor),
           (Data.ProtoLens.Tag 21, javaSettings__field_descriptor),
           (Data.ProtoLens.Tag 22, cppSettings__field_descriptor),
           (Data.ProtoLens.Tag 23, phpSettings__field_descriptor),
           (Data.ProtoLens.Tag 24, pythonSettings__field_descriptor),
           (Data.ProtoLens.Tag 25, nodeSettings__field_descriptor),
           (Data.ProtoLens.Tag 26, dotnetSettings__field_descriptor),
           (Data.ProtoLens.Tag 27, rubySettings__field_descriptor),
           (Data.ProtoLens.Tag 28, goSettings__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _ClientLibrarySettings'_unknownFields
        (\ x__ y__ -> x__ {_ClientLibrarySettings'_unknownFields = y__})
  defMessage
    = ClientLibrarySettings'_constructor
        {_ClientLibrarySettings'version = Data.ProtoLens.fieldDefault,
         _ClientLibrarySettings'launchStage = Data.ProtoLens.fieldDefault,
         _ClientLibrarySettings'restNumericEnums = Data.ProtoLens.fieldDefault,
         _ClientLibrarySettings'javaSettings = Prelude.Nothing,
         _ClientLibrarySettings'cppSettings = Prelude.Nothing,
         _ClientLibrarySettings'phpSettings = Prelude.Nothing,
         _ClientLibrarySettings'pythonSettings = Prelude.Nothing,
         _ClientLibrarySettings'nodeSettings = Prelude.Nothing,
         _ClientLibrarySettings'dotnetSettings = Prelude.Nothing,
         _ClientLibrarySettings'rubySettings = Prelude.Nothing,
         _ClientLibrarySettings'goSettings = Prelude.Nothing,
         _ClientLibrarySettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          ClientLibrarySettings
          -> Data.ProtoLens.Encoding.Bytes.Parser ClientLibrarySettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "version"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"version") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.toEnum
                                          (Prelude.fmap
                                             Prelude.fromIntegral
                                             Data.ProtoLens.Encoding.Bytes.getVarInt))
                                       "launch_stage"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"launchStage") y x)
                        24
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "rest_numeric_enums"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"restNumericEnums") y x)
                        170
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "java_settings"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"javaSettings") y x)
                        178
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "cpp_settings"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"cppSettings") y x)
                        186
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "php_settings"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"phpSettings") y x)
                        194
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "python_settings"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"pythonSettings") y x)
                        202
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "node_settings"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"nodeSettings") y x)
                        210
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "dotnet_settings"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"dotnetSettings") y x)
                        218
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "ruby_settings"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"rubySettings") y x)
                        226
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "go_settings"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"goSettings") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "ClientLibrarySettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v = Lens.Family2.view (Data.ProtoLens.Field.field @"version") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view (Data.ProtoLens.Field.field @"launchStage") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 16)
                         ((Prelude..)
                            ((Prelude..)
                               Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral)
                            Prelude.fromEnum _v))
                ((Data.Monoid.<>)
                   (let
                      _v
                        = Lens.Family2.view
                            (Data.ProtoLens.Field.field @"restNumericEnums") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 24)
                            ((Prelude..)
                               Data.ProtoLens.Encoding.Bytes.putVarInt (\ b -> if b then 1 else 0)
                               _v))
                   ((Data.Monoid.<>)
                      (case
                           Lens.Family2.view
                             (Data.ProtoLens.Field.field @"maybe'javaSettings") _x
                       of
                         Prelude.Nothing -> Data.Monoid.mempty
                         (Prelude.Just _v)
                           -> (Data.Monoid.<>)
                                (Data.ProtoLens.Encoding.Bytes.putVarInt 170)
                                ((Prelude..)
                                   (\ bs
                                      -> (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt
                                              (Prelude.fromIntegral (Data.ByteString.length bs)))
                                           (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                   Data.ProtoLens.encodeMessage _v))
                      ((Data.Monoid.<>)
                         (case
                              Lens.Family2.view
                                (Data.ProtoLens.Field.field @"maybe'cppSettings") _x
                          of
                            Prelude.Nothing -> Data.Monoid.mempty
                            (Prelude.Just _v)
                              -> (Data.Monoid.<>)
                                   (Data.ProtoLens.Encoding.Bytes.putVarInt 178)
                                   ((Prelude..)
                                      (\ bs
                                         -> (Data.Monoid.<>)
                                              (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                 (Prelude.fromIntegral (Data.ByteString.length bs)))
                                              (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                      Data.ProtoLens.encodeMessage _v))
                         ((Data.Monoid.<>)
                            (case
                                 Lens.Family2.view
                                   (Data.ProtoLens.Field.field @"maybe'phpSettings") _x
                             of
                               Prelude.Nothing -> Data.Monoid.mempty
                               (Prelude.Just _v)
                                 -> (Data.Monoid.<>)
                                      (Data.ProtoLens.Encoding.Bytes.putVarInt 186)
                                      ((Prelude..)
                                         (\ bs
                                            -> (Data.Monoid.<>)
                                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                    (Prelude.fromIntegral
                                                       (Data.ByteString.length bs)))
                                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                         Data.ProtoLens.encodeMessage _v))
                            ((Data.Monoid.<>)
                               (case
                                    Lens.Family2.view
                                      (Data.ProtoLens.Field.field @"maybe'pythonSettings") _x
                                of
                                  Prelude.Nothing -> Data.Monoid.mempty
                                  (Prelude.Just _v)
                                    -> (Data.Monoid.<>)
                                         (Data.ProtoLens.Encoding.Bytes.putVarInt 194)
                                         ((Prelude..)
                                            (\ bs
                                               -> (Data.Monoid.<>)
                                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                       (Prelude.fromIntegral
                                                          (Data.ByteString.length bs)))
                                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                            Data.ProtoLens.encodeMessage _v))
                               ((Data.Monoid.<>)
                                  (case
                                       Lens.Family2.view
                                         (Data.ProtoLens.Field.field @"maybe'nodeSettings") _x
                                   of
                                     Prelude.Nothing -> Data.Monoid.mempty
                                     (Prelude.Just _v)
                                       -> (Data.Monoid.<>)
                                            (Data.ProtoLens.Encoding.Bytes.putVarInt 202)
                                            ((Prelude..)
                                               (\ bs
                                                  -> (Data.Monoid.<>)
                                                       (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                          (Prelude.fromIntegral
                                                             (Data.ByteString.length bs)))
                                                       (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                               Data.ProtoLens.encodeMessage _v))
                                  ((Data.Monoid.<>)
                                     (case
                                          Lens.Family2.view
                                            (Data.ProtoLens.Field.field @"maybe'dotnetSettings") _x
                                      of
                                        Prelude.Nothing -> Data.Monoid.mempty
                                        (Prelude.Just _v)
                                          -> (Data.Monoid.<>)
                                               (Data.ProtoLens.Encoding.Bytes.putVarInt 210)
                                               ((Prelude..)
                                                  (\ bs
                                                     -> (Data.Monoid.<>)
                                                          (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                             (Prelude.fromIntegral
                                                                (Data.ByteString.length bs)))
                                                          (Data.ProtoLens.Encoding.Bytes.putBytes
                                                             bs))
                                                  Data.ProtoLens.encodeMessage _v))
                                     ((Data.Monoid.<>)
                                        (case
                                             Lens.Family2.view
                                               (Data.ProtoLens.Field.field @"maybe'rubySettings") _x
                                         of
                                           Prelude.Nothing -> Data.Monoid.mempty
                                           (Prelude.Just _v)
                                             -> (Data.Monoid.<>)
                                                  (Data.ProtoLens.Encoding.Bytes.putVarInt 218)
                                                  ((Prelude..)
                                                     (\ bs
                                                        -> (Data.Monoid.<>)
                                                             (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                                (Prelude.fromIntegral
                                                                   (Data.ByteString.length bs)))
                                                             (Data.ProtoLens.Encoding.Bytes.putBytes
                                                                bs))
                                                     Data.ProtoLens.encodeMessage _v))
                                        ((Data.Monoid.<>)
                                           (case
                                                Lens.Family2.view
                                                  (Data.ProtoLens.Field.field @"maybe'goSettings")
                                                  _x
                                            of
                                              Prelude.Nothing -> Data.Monoid.mempty
                                              (Prelude.Just _v)
                                                -> (Data.Monoid.<>)
                                                     (Data.ProtoLens.Encoding.Bytes.putVarInt 226)
                                                     ((Prelude..)
                                                        (\ bs
                                                           -> (Data.Monoid.<>)
                                                                (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                                   (Prelude.fromIntegral
                                                                      (Data.ByteString.length bs)))
                                                                (Data.ProtoLens.Encoding.Bytes.putBytes
                                                                   bs))
                                                        Data.ProtoLens.encodeMessage _v))
                                           (Data.ProtoLens.Encoding.Wire.buildFieldSet
                                              (Lens.Family2.view
                                                 Data.ProtoLens.unknownFields _x))))))))))))
instance Control.DeepSeq.NFData ClientLibrarySettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_ClientLibrarySettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_ClientLibrarySettings'version x__)
                (Control.DeepSeq.deepseq
                   (_ClientLibrarySettings'launchStage x__)
                   (Control.DeepSeq.deepseq
                      (_ClientLibrarySettings'restNumericEnums x__)
                      (Control.DeepSeq.deepseq
                         (_ClientLibrarySettings'javaSettings x__)
                         (Control.DeepSeq.deepseq
                            (_ClientLibrarySettings'cppSettings x__)
                            (Control.DeepSeq.deepseq
                               (_ClientLibrarySettings'phpSettings x__)
                               (Control.DeepSeq.deepseq
                                  (_ClientLibrarySettings'pythonSettings x__)
                                  (Control.DeepSeq.deepseq
                                     (_ClientLibrarySettings'nodeSettings x__)
                                     (Control.DeepSeq.deepseq
                                        (_ClientLibrarySettings'dotnetSettings x__)
                                        (Control.DeepSeq.deepseq
                                           (_ClientLibrarySettings'rubySettings x__)
                                           (Control.DeepSeq.deepseq
                                              (_ClientLibrarySettings'goSettings x__) ())))))))))))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.referenceDocsUri' @:: Lens' CommonLanguageSettings Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.destinations' @:: Lens' CommonLanguageSettings [ClientLibraryDestination]@
         * 'Proto.Google.Api.Client_Fields.vec'destinations' @:: Lens' CommonLanguageSettings (Data.Vector.Vector ClientLibraryDestination)@
         * 'Proto.Google.Api.Client_Fields.selectiveGapicGeneration' @:: Lens' CommonLanguageSettings SelectiveGapicGeneration@
         * 'Proto.Google.Api.Client_Fields.maybe'selectiveGapicGeneration' @:: Lens' CommonLanguageSettings (Prelude.Maybe SelectiveGapicGeneration)@ -}
data CommonLanguageSettings
  = CommonLanguageSettings'_constructor {_CommonLanguageSettings'referenceDocsUri :: !Data.Text.Text,
                                         _CommonLanguageSettings'destinations :: !(Data.Vector.Vector ClientLibraryDestination),
                                         _CommonLanguageSettings'selectiveGapicGeneration :: !(Prelude.Maybe SelectiveGapicGeneration),
                                         _CommonLanguageSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show CommonLanguageSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField CommonLanguageSettings "referenceDocsUri" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CommonLanguageSettings'referenceDocsUri
           (\ x__ y__
              -> x__ {_CommonLanguageSettings'referenceDocsUri = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField CommonLanguageSettings "destinations" [ClientLibraryDestination] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CommonLanguageSettings'destinations
           (\ x__ y__ -> x__ {_CommonLanguageSettings'destinations = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField CommonLanguageSettings "vec'destinations" (Data.Vector.Vector ClientLibraryDestination) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CommonLanguageSettings'destinations
           (\ x__ y__ -> x__ {_CommonLanguageSettings'destinations = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField CommonLanguageSettings "selectiveGapicGeneration" SelectiveGapicGeneration where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CommonLanguageSettings'selectiveGapicGeneration
           (\ x__ y__
              -> x__ {_CommonLanguageSettings'selectiveGapicGeneration = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField CommonLanguageSettings "maybe'selectiveGapicGeneration" (Prelude.Maybe SelectiveGapicGeneration) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CommonLanguageSettings'selectiveGapicGeneration
           (\ x__ y__
              -> x__ {_CommonLanguageSettings'selectiveGapicGeneration = y__}))
        Prelude.id
instance Data.ProtoLens.Message CommonLanguageSettings where
  messageName _ = Data.Text.pack "google.api.CommonLanguageSettings"
  packedMessageDescriptor _
    = "\n\
      \\SYNCommonLanguageSettings\DC20\n\
      \\DC2reference_docs_uri\CAN\SOH \SOH(\tR\DLEreferenceDocsUriB\STX\CAN\SOH\DC2H\n\
      \\fdestinations\CAN\STX \ETX(\SO2$.google.api.ClientLibraryDestinationR\fdestinations\DC2b\n\
      \\SUBselective_gapic_generation\CAN\ETX \SOH(\v2$.google.api.SelectiveGapicGenerationR\CANselectiveGapicGeneration"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        referenceDocsUri__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "reference_docs_uri"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"referenceDocsUri")) ::
              Data.ProtoLens.FieldDescriptor CommonLanguageSettings
        destinations__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "destinations"
              (Data.ProtoLens.ScalarField Data.ProtoLens.EnumField ::
                 Data.ProtoLens.FieldTypeDescriptor ClientLibraryDestination)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Packed
                 (Data.ProtoLens.Field.field @"destinations")) ::
              Data.ProtoLens.FieldDescriptor CommonLanguageSettings
        selectiveGapicGeneration__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "selective_gapic_generation"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor SelectiveGapicGeneration)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'selectiveGapicGeneration")) ::
              Data.ProtoLens.FieldDescriptor CommonLanguageSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, referenceDocsUri__field_descriptor),
           (Data.ProtoLens.Tag 2, destinations__field_descriptor),
           (Data.ProtoLens.Tag 3, selectiveGapicGeneration__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _CommonLanguageSettings'_unknownFields
        (\ x__ y__ -> x__ {_CommonLanguageSettings'_unknownFields = y__})
  defMessage
    = CommonLanguageSettings'_constructor
        {_CommonLanguageSettings'referenceDocsUri = Data.ProtoLens.fieldDefault,
         _CommonLanguageSettings'destinations = Data.Vector.Generic.empty,
         _CommonLanguageSettings'selectiveGapicGeneration = Prelude.Nothing,
         _CommonLanguageSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          CommonLanguageSettings
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld ClientLibraryDestination
             -> Data.ProtoLens.Encoding.Bytes.Parser CommonLanguageSettings
        loop x mutable'destinations
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'destinations <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                               (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                  mutable'destinations)
                      (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t)
                           (Lens.Family2.set
                              (Data.ProtoLens.Field.field @"vec'destinations")
                              frozen'destinations x))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "reference_docs_uri"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"referenceDocsUri") y x)
                                  mutable'destinations
                        16
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (Prelude.fmap
                                           Prelude.toEnum
                                           (Prelude.fmap
                                              Prelude.fromIntegral
                                              Data.ProtoLens.Encoding.Bytes.getVarInt))
                                        "destinations"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'destinations y)
                                loop x v
                        18
                          -> do y <- do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                        Data.ProtoLens.Encoding.Bytes.isolate
                                          (Prelude.fromIntegral len)
                                          ((let
                                              ploop qs
                                                = do packedEnd <- Data.ProtoLens.Encoding.Bytes.atEnd
                                                     if packedEnd then
                                                         Prelude.return qs
                                                     else
                                                         do !q <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                                                    (Prelude.fmap
                                                                       Prelude.toEnum
                                                                       (Prelude.fmap
                                                                          Prelude.fromIntegral
                                                                          Data.ProtoLens.Encoding.Bytes.getVarInt))
                                                                    "destinations"
                                                            qs' <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                                     (Data.ProtoLens.Encoding.Growing.append
                                                                        qs q)
                                                            ploop qs'
                                            in ploop)
                                             mutable'destinations)
                                loop x y
                        26
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "selective_gapic_generation"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"selectiveGapicGeneration") y x)
                                  mutable'destinations
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'destinations
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'destinations <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                        Data.ProtoLens.Encoding.Growing.new
              loop Data.ProtoLens.defMessage mutable'destinations)
          "CommonLanguageSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view
                      (Data.ProtoLens.Field.field @"referenceDocsUri") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   p = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"vec'destinations") _x
                 in
                   if Data.Vector.Generic.null p then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                         ((\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            (Data.ProtoLens.Encoding.Bytes.runBuilder
                               (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                                  ((Prelude..)
                                     ((Prelude..)
                                        Data.ProtoLens.Encoding.Bytes.putVarInt
                                        Prelude.fromIntegral)
                                     Prelude.fromEnum)
                                  p))))
                ((Data.Monoid.<>)
                   (case
                        Lens.Family2.view
                          (Data.ProtoLens.Field.field @"maybe'selectiveGapicGeneration") _x
                    of
                      Prelude.Nothing -> Data.Monoid.mempty
                      (Prelude.Just _v)
                        -> (Data.Monoid.<>)
                             (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                             ((Prelude..)
                                (\ bs
                                   -> (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt
                                           (Prelude.fromIntegral (Data.ByteString.length bs)))
                                        (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                Data.ProtoLens.encodeMessage _v))
                   (Data.ProtoLens.Encoding.Wire.buildFieldSet
                      (Lens.Family2.view Data.ProtoLens.unknownFields _x))))
instance Control.DeepSeq.NFData CommonLanguageSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_CommonLanguageSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_CommonLanguageSettings'referenceDocsUri x__)
                (Control.DeepSeq.deepseq
                   (_CommonLanguageSettings'destinations x__)
                   (Control.DeepSeq.deepseq
                      (_CommonLanguageSettings'selectiveGapicGeneration x__) ())))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' CppSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' CppSettings (Prelude.Maybe CommonLanguageSettings)@ -}
data CppSettings
  = CppSettings'_constructor {_CppSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                              _CppSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show CppSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField CppSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CppSettings'common (\ x__ y__ -> x__ {_CppSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField CppSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CppSettings'common (\ x__ y__ -> x__ {_CppSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Message CppSettings where
  messageName _ = Data.Text.pack "google.api.CppSettings"
  packedMessageDescriptor _
    = "\n\
      \\vCppSettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor CppSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _CppSettings'_unknownFields
        (\ x__ y__ -> x__ {_CppSettings'_unknownFields = y__})
  defMessage
    = CppSettings'_constructor
        {_CppSettings'common = Prelude.Nothing,
         _CppSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          CppSettings -> Data.ProtoLens.Encoding.Bytes.Parser CppSettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "CppSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData CppSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_CppSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq (_CppSettings'common x__) ())
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' DotnetSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' DotnetSettings (Prelude.Maybe CommonLanguageSettings)@
         * 'Proto.Google.Api.Client_Fields.renamedServices' @:: Lens' DotnetSettings (Data.Map.Map Data.Text.Text Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.renamedResources' @:: Lens' DotnetSettings (Data.Map.Map Data.Text.Text Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.ignoredResources' @:: Lens' DotnetSettings [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'ignoredResources' @:: Lens' DotnetSettings (Data.Vector.Vector Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.forcedNamespaceAliases' @:: Lens' DotnetSettings [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'forcedNamespaceAliases' @:: Lens' DotnetSettings (Data.Vector.Vector Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.handwrittenSignatures' @:: Lens' DotnetSettings [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'handwrittenSignatures' @:: Lens' DotnetSettings (Data.Vector.Vector Data.Text.Text)@ -}
data DotnetSettings
  = DotnetSettings'_constructor {_DotnetSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                                 _DotnetSettings'renamedServices :: !(Data.Map.Map Data.Text.Text Data.Text.Text),
                                 _DotnetSettings'renamedResources :: !(Data.Map.Map Data.Text.Text Data.Text.Text),
                                 _DotnetSettings'ignoredResources :: !(Data.Vector.Vector Data.Text.Text),
                                 _DotnetSettings'forcedNamespaceAliases :: !(Data.Vector.Vector Data.Text.Text),
                                 _DotnetSettings'handwrittenSignatures :: !(Data.Vector.Vector Data.Text.Text),
                                 _DotnetSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show DotnetSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField DotnetSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'common
           (\ x__ y__ -> x__ {_DotnetSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField DotnetSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'common
           (\ x__ y__ -> x__ {_DotnetSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings "renamedServices" (Data.Map.Map Data.Text.Text Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'renamedServices
           (\ x__ y__ -> x__ {_DotnetSettings'renamedServices = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings "renamedResources" (Data.Map.Map Data.Text.Text Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'renamedResources
           (\ x__ y__ -> x__ {_DotnetSettings'renamedResources = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings "ignoredResources" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'ignoredResources
           (\ x__ y__ -> x__ {_DotnetSettings'ignoredResources = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField DotnetSettings "vec'ignoredResources" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'ignoredResources
           (\ x__ y__ -> x__ {_DotnetSettings'ignoredResources = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings "forcedNamespaceAliases" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'forcedNamespaceAliases
           (\ x__ y__ -> x__ {_DotnetSettings'forcedNamespaceAliases = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField DotnetSettings "vec'forcedNamespaceAliases" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'forcedNamespaceAliases
           (\ x__ y__ -> x__ {_DotnetSettings'forcedNamespaceAliases = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings "handwrittenSignatures" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'handwrittenSignatures
           (\ x__ y__ -> x__ {_DotnetSettings'handwrittenSignatures = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField DotnetSettings "vec'handwrittenSignatures" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'handwrittenSignatures
           (\ x__ y__ -> x__ {_DotnetSettings'handwrittenSignatures = y__}))
        Prelude.id
instance Data.ProtoLens.Message DotnetSettings where
  messageName _ = Data.Text.pack "google.api.DotnetSettings"
  packedMessageDescriptor _
    = "\n\
      \\SODotnetSettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2Z\n\
      \\DLErenamed_services\CAN\STX \ETX(\v2/.google.api.DotnetSettings.RenamedServicesEntryR\SIrenamedServices\DC2]\n\
      \\DC1renamed_resources\CAN\ETX \ETX(\v20.google.api.DotnetSettings.RenamedResourcesEntryR\DLErenamedResources\DC2+\n\
      \\DC1ignored_resources\CAN\EOT \ETX(\tR\DLEignoredResources\DC28\n\
      \\CANforced_namespace_aliases\CAN\ENQ \ETX(\tR\SYNforcedNamespaceAliases\DC25\n\
      \\SYNhandwritten_signatures\CAN\ACK \ETX(\tR\NAKhandwrittenSignatures\SUBB\n\
      \\DC4RenamedServicesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH\SUBC\n\
      \\NAKRenamedResourcesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings
        renamedServices__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "renamed_services"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor DotnetSettings'RenamedServicesEntry)
              (Data.ProtoLens.MapField
                 (Data.ProtoLens.Field.field @"key")
                 (Data.ProtoLens.Field.field @"value")
                 (Data.ProtoLens.Field.field @"renamedServices")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings
        renamedResources__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "renamed_resources"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor DotnetSettings'RenamedResourcesEntry)
              (Data.ProtoLens.MapField
                 (Data.ProtoLens.Field.field @"key")
                 (Data.ProtoLens.Field.field @"value")
                 (Data.ProtoLens.Field.field @"renamedResources")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings
        ignoredResources__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "ignored_resources"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"ignoredResources")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings
        forcedNamespaceAliases__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "forced_namespace_aliases"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"forcedNamespaceAliases")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings
        handwrittenSignatures__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "handwritten_signatures"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"handwrittenSignatures")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor),
           (Data.ProtoLens.Tag 2, renamedServices__field_descriptor),
           (Data.ProtoLens.Tag 3, renamedResources__field_descriptor),
           (Data.ProtoLens.Tag 4, ignoredResources__field_descriptor),
           (Data.ProtoLens.Tag 5, forcedNamespaceAliases__field_descriptor),
           (Data.ProtoLens.Tag 6, handwrittenSignatures__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _DotnetSettings'_unknownFields
        (\ x__ y__ -> x__ {_DotnetSettings'_unknownFields = y__})
  defMessage
    = DotnetSettings'_constructor
        {_DotnetSettings'common = Prelude.Nothing,
         _DotnetSettings'renamedServices = Data.Map.empty,
         _DotnetSettings'renamedResources = Data.Map.empty,
         _DotnetSettings'ignoredResources = Data.Vector.Generic.empty,
         _DotnetSettings'forcedNamespaceAliases = Data.Vector.Generic.empty,
         _DotnetSettings'handwrittenSignatures = Data.Vector.Generic.empty,
         _DotnetSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          DotnetSettings
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
             -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
                -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
                   -> Data.ProtoLens.Encoding.Bytes.Parser DotnetSettings
        loop
          x
          mutable'forcedNamespaceAliases
          mutable'handwrittenSignatures
          mutable'ignoredResources
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'forcedNamespaceAliases <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                         (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                            mutable'forcedNamespaceAliases)
                      frozen'handwrittenSignatures <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                        (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                           mutable'handwrittenSignatures)
                      frozen'ignoredResources <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                   (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                      mutable'ignoredResources)
                      (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t)
                           (Lens.Family2.set
                              (Data.ProtoLens.Field.field @"vec'forcedNamespaceAliases")
                              frozen'forcedNamespaceAliases
                              (Lens.Family2.set
                                 (Data.ProtoLens.Field.field @"vec'handwrittenSignatures")
                                 frozen'handwrittenSignatures
                                 (Lens.Family2.set
                                    (Data.ProtoLens.Field.field @"vec'ignoredResources")
                                    frozen'ignoredResources x))))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                                  mutable'forcedNamespaceAliases mutable'handwrittenSignatures
                                  mutable'ignoredResources
                        18
                          -> do !(entry :: DotnetSettings'RenamedServicesEntry) <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                                                                     (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                                                                         Data.ProtoLens.Encoding.Bytes.isolate
                                                                                           (Prelude.fromIntegral
                                                                                              len)
                                                                                           Data.ProtoLens.parseMessage)
                                                                                     "renamed_services"
                                (let
                                   key = Lens.Family2.view (Data.ProtoLens.Field.field @"key") entry
                                   value
                                     = Lens.Family2.view (Data.ProtoLens.Field.field @"value") entry
                                 in
                                   loop
                                     (Lens.Family2.over
                                        (Data.ProtoLens.Field.field @"renamedServices")
                                        (\ !t -> Data.Map.insert key value t) x)
                                     mutable'forcedNamespaceAliases mutable'handwrittenSignatures
                                     mutable'ignoredResources)
                        26
                          -> do !(entry :: DotnetSettings'RenamedResourcesEntry) <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                                                                      (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                                                                          Data.ProtoLens.Encoding.Bytes.isolate
                                                                                            (Prelude.fromIntegral
                                                                                               len)
                                                                                            Data.ProtoLens.parseMessage)
                                                                                      "renamed_resources"
                                (let
                                   key = Lens.Family2.view (Data.ProtoLens.Field.field @"key") entry
                                   value
                                     = Lens.Family2.view (Data.ProtoLens.Field.field @"value") entry
                                 in
                                   loop
                                     (Lens.Family2.over
                                        (Data.ProtoLens.Field.field @"renamedResources")
                                        (\ !t -> Data.Map.insert key value t) x)
                                     mutable'forcedNamespaceAliases mutable'handwrittenSignatures
                                     mutable'ignoredResources)
                        34
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "ignored_resources"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'ignoredResources y)
                                loop
                                  x mutable'forcedNamespaceAliases mutable'handwrittenSignatures v
                        42
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "forced_namespace_aliases"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'forcedNamespaceAliases y)
                                loop x v mutable'handwrittenSignatures mutable'ignoredResources
                        50
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "handwritten_signatures"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'handwrittenSignatures y)
                                loop x mutable'forcedNamespaceAliases v mutable'ignoredResources
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'forcedNamespaceAliases mutable'handwrittenSignatures
                                  mutable'ignoredResources
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'forcedNamespaceAliases <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                  Data.ProtoLens.Encoding.Growing.new
              mutable'handwrittenSignatures <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                 Data.ProtoLens.Encoding.Growing.new
              mutable'ignoredResources <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                            Data.ProtoLens.Encoding.Growing.new
              loop
                Data.ProtoLens.defMessage mutable'forcedNamespaceAliases
                mutable'handwrittenSignatures mutable'ignoredResources)
          "DotnetSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             ((Data.Monoid.<>)
                (Data.Monoid.mconcat
                   (Prelude.map
                      (\ _v
                         -> (Data.Monoid.<>)
                              (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                              ((Prelude..)
                                 (\ bs
                                    -> (Data.Monoid.<>)
                                         (Data.ProtoLens.Encoding.Bytes.putVarInt
                                            (Prelude.fromIntegral (Data.ByteString.length bs)))
                                         (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                 Data.ProtoLens.encodeMessage
                                 (Lens.Family2.set
                                    (Data.ProtoLens.Field.field @"key") (Prelude.fst _v)
                                    (Lens.Family2.set
                                       (Data.ProtoLens.Field.field @"value") (Prelude.snd _v)
                                       (Data.ProtoLens.defMessage ::
                                          DotnetSettings'RenamedServicesEntry)))))
                      (Data.Map.toList
                         (Lens.Family2.view
                            (Data.ProtoLens.Field.field @"renamedServices") _x))))
                ((Data.Monoid.<>)
                   (Data.Monoid.mconcat
                      (Prelude.map
                         (\ _v
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                                 ((Prelude..)
                                    (\ bs
                                       -> (Data.Monoid.<>)
                                            (Data.ProtoLens.Encoding.Bytes.putVarInt
                                               (Prelude.fromIntegral (Data.ByteString.length bs)))
                                            (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                    Data.ProtoLens.encodeMessage
                                    (Lens.Family2.set
                                       (Data.ProtoLens.Field.field @"key") (Prelude.fst _v)
                                       (Lens.Family2.set
                                          (Data.ProtoLens.Field.field @"value") (Prelude.snd _v)
                                          (Data.ProtoLens.defMessage ::
                                             DotnetSettings'RenamedResourcesEntry)))))
                         (Data.Map.toList
                            (Lens.Family2.view
                               (Data.ProtoLens.Field.field @"renamedResources") _x))))
                   ((Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                         (\ _v
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt 34)
                                 ((Prelude..)
                                    (\ bs
                                       -> (Data.Monoid.<>)
                                            (Data.ProtoLens.Encoding.Bytes.putVarInt
                                               (Prelude.fromIntegral (Data.ByteString.length bs)))
                                            (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                    Data.Text.Encoding.encodeUtf8 _v))
                         (Lens.Family2.view
                            (Data.ProtoLens.Field.field @"vec'ignoredResources") _x))
                      ((Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                            (\ _v
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt 42)
                                    ((Prelude..)
                                       (\ bs
                                          -> (Data.Monoid.<>)
                                               (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                  (Prelude.fromIntegral
                                                     (Data.ByteString.length bs)))
                                               (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                       Data.Text.Encoding.encodeUtf8 _v))
                            (Lens.Family2.view
                               (Data.ProtoLens.Field.field @"vec'forcedNamespaceAliases") _x))
                         ((Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                               (\ _v
                                  -> (Data.Monoid.<>)
                                       (Data.ProtoLens.Encoding.Bytes.putVarInt 50)
                                       ((Prelude..)
                                          (\ bs
                                             -> (Data.Monoid.<>)
                                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                     (Prelude.fromIntegral
                                                        (Data.ByteString.length bs)))
                                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                          Data.Text.Encoding.encodeUtf8 _v))
                               (Lens.Family2.view
                                  (Data.ProtoLens.Field.field @"vec'handwrittenSignatures") _x))
                            (Data.ProtoLens.Encoding.Wire.buildFieldSet
                               (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))))
instance Control.DeepSeq.NFData DotnetSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_DotnetSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_DotnetSettings'common x__)
                (Control.DeepSeq.deepseq
                   (_DotnetSettings'renamedServices x__)
                   (Control.DeepSeq.deepseq
                      (_DotnetSettings'renamedResources x__)
                      (Control.DeepSeq.deepseq
                         (_DotnetSettings'ignoredResources x__)
                         (Control.DeepSeq.deepseq
                            (_DotnetSettings'forcedNamespaceAliases x__)
                            (Control.DeepSeq.deepseq
                               (_DotnetSettings'handwrittenSignatures x__) ()))))))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.key' @:: Lens' DotnetSettings'RenamedResourcesEntry Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.value' @:: Lens' DotnetSettings'RenamedResourcesEntry Data.Text.Text@ -}
data DotnetSettings'RenamedResourcesEntry
  = DotnetSettings'RenamedResourcesEntry'_constructor {_DotnetSettings'RenamedResourcesEntry'key :: !Data.Text.Text,
                                                       _DotnetSettings'RenamedResourcesEntry'value :: !Data.Text.Text,
                                                       _DotnetSettings'RenamedResourcesEntry'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show DotnetSettings'RenamedResourcesEntry where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField DotnetSettings'RenamedResourcesEntry "key" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'RenamedResourcesEntry'key
           (\ x__ y__
              -> x__ {_DotnetSettings'RenamedResourcesEntry'key = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings'RenamedResourcesEntry "value" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'RenamedResourcesEntry'value
           (\ x__ y__
              -> x__ {_DotnetSettings'RenamedResourcesEntry'value = y__}))
        Prelude.id
instance Data.ProtoLens.Message DotnetSettings'RenamedResourcesEntry where
  messageName _
    = Data.Text.pack "google.api.DotnetSettings.RenamedResourcesEntry"
  packedMessageDescriptor _
    = "\n\
      \\NAKRenamedResourcesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        key__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "key"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"key")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings'RenamedResourcesEntry
        value__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "value"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"value")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings'RenamedResourcesEntry
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, key__field_descriptor),
           (Data.ProtoLens.Tag 2, value__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _DotnetSettings'RenamedResourcesEntry'_unknownFields
        (\ x__ y__
           -> x__
                {_DotnetSettings'RenamedResourcesEntry'_unknownFields = y__})
  defMessage
    = DotnetSettings'RenamedResourcesEntry'_constructor
        {_DotnetSettings'RenamedResourcesEntry'key = Data.ProtoLens.fieldDefault,
         _DotnetSettings'RenamedResourcesEntry'value = Data.ProtoLens.fieldDefault,
         _DotnetSettings'RenamedResourcesEntry'_unknownFields = []}
  parseMessage
    = let
        loop ::
          DotnetSettings'RenamedResourcesEntry
          -> Data.ProtoLens.Encoding.Bytes.Parser DotnetSettings'RenamedResourcesEntry
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "key"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"key") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "value"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"value") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "RenamedResourcesEntry"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"key") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"value") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                         ((Prelude..)
                            (\ bs
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                       (Prelude.fromIntegral (Data.ByteString.length bs)))
                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            Data.Text.Encoding.encodeUtf8 _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData DotnetSettings'RenamedResourcesEntry where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_DotnetSettings'RenamedResourcesEntry'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_DotnetSettings'RenamedResourcesEntry'key x__)
                (Control.DeepSeq.deepseq
                   (_DotnetSettings'RenamedResourcesEntry'value x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.key' @:: Lens' DotnetSettings'RenamedServicesEntry Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.value' @:: Lens' DotnetSettings'RenamedServicesEntry Data.Text.Text@ -}
data DotnetSettings'RenamedServicesEntry
  = DotnetSettings'RenamedServicesEntry'_constructor {_DotnetSettings'RenamedServicesEntry'key :: !Data.Text.Text,
                                                      _DotnetSettings'RenamedServicesEntry'value :: !Data.Text.Text,
                                                      _DotnetSettings'RenamedServicesEntry'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show DotnetSettings'RenamedServicesEntry where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField DotnetSettings'RenamedServicesEntry "key" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'RenamedServicesEntry'key
           (\ x__ y__
              -> x__ {_DotnetSettings'RenamedServicesEntry'key = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField DotnetSettings'RenamedServicesEntry "value" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DotnetSettings'RenamedServicesEntry'value
           (\ x__ y__
              -> x__ {_DotnetSettings'RenamedServicesEntry'value = y__}))
        Prelude.id
instance Data.ProtoLens.Message DotnetSettings'RenamedServicesEntry where
  messageName _
    = Data.Text.pack "google.api.DotnetSettings.RenamedServicesEntry"
  packedMessageDescriptor _
    = "\n\
      \\DC4RenamedServicesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        key__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "key"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"key")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings'RenamedServicesEntry
        value__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "value"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"value")) ::
              Data.ProtoLens.FieldDescriptor DotnetSettings'RenamedServicesEntry
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, key__field_descriptor),
           (Data.ProtoLens.Tag 2, value__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _DotnetSettings'RenamedServicesEntry'_unknownFields
        (\ x__ y__
           -> x__ {_DotnetSettings'RenamedServicesEntry'_unknownFields = y__})
  defMessage
    = DotnetSettings'RenamedServicesEntry'_constructor
        {_DotnetSettings'RenamedServicesEntry'key = Data.ProtoLens.fieldDefault,
         _DotnetSettings'RenamedServicesEntry'value = Data.ProtoLens.fieldDefault,
         _DotnetSettings'RenamedServicesEntry'_unknownFields = []}
  parseMessage
    = let
        loop ::
          DotnetSettings'RenamedServicesEntry
          -> Data.ProtoLens.Encoding.Bytes.Parser DotnetSettings'RenamedServicesEntry
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "key"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"key") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "value"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"value") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "RenamedServicesEntry"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"key") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"value") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                         ((Prelude..)
                            (\ bs
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                       (Prelude.fromIntegral (Data.ByteString.length bs)))
                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            Data.Text.Encoding.encodeUtf8 _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData DotnetSettings'RenamedServicesEntry where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_DotnetSettings'RenamedServicesEntry'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_DotnetSettings'RenamedServicesEntry'key x__)
                (Control.DeepSeq.deepseq
                   (_DotnetSettings'RenamedServicesEntry'value x__) ()))
newtype FlowControlLimitExceededBehaviorProto'UnrecognizedValue
  = FlowControlLimitExceededBehaviorProto'UnrecognizedValue Data.Int.Int32
  deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show)
data FlowControlLimitExceededBehaviorProto
  = UNSET_BEHAVIOR |
    THROW_EXCEPTION |
    BLOCK |
    IGNORE |
    FlowControlLimitExceededBehaviorProto'Unrecognized !FlowControlLimitExceededBehaviorProto'UnrecognizedValue
  deriving stock (Prelude.Show, Prelude.Eq, Prelude.Ord)
instance Data.ProtoLens.MessageEnum FlowControlLimitExceededBehaviorProto where
  maybeToEnum 0 = Prelude.Just UNSET_BEHAVIOR
  maybeToEnum 1 = Prelude.Just THROW_EXCEPTION
  maybeToEnum 2 = Prelude.Just BLOCK
  maybeToEnum 3 = Prelude.Just IGNORE
  maybeToEnum k
    = Prelude.Just
        (FlowControlLimitExceededBehaviorProto'Unrecognized
           (FlowControlLimitExceededBehaviorProto'UnrecognizedValue
              (Prelude.fromIntegral k)))
  showEnum UNSET_BEHAVIOR = "UNSET_BEHAVIOR"
  showEnum THROW_EXCEPTION = "THROW_EXCEPTION"
  showEnum BLOCK = "BLOCK"
  showEnum IGNORE = "IGNORE"
  showEnum
    (FlowControlLimitExceededBehaviorProto'Unrecognized (FlowControlLimitExceededBehaviorProto'UnrecognizedValue k))
    = Prelude.show k
  readEnum k
    | (Prelude.==) k "UNSET_BEHAVIOR" = Prelude.Just UNSET_BEHAVIOR
    | (Prelude.==) k "THROW_EXCEPTION" = Prelude.Just THROW_EXCEPTION
    | (Prelude.==) k "BLOCK" = Prelude.Just BLOCK
    | (Prelude.==) k "IGNORE" = Prelude.Just IGNORE
    | Prelude.otherwise
    = (Prelude.>>=) (Text.Read.readMaybe k) Data.ProtoLens.maybeToEnum
instance Prelude.Bounded FlowControlLimitExceededBehaviorProto where
  minBound = UNSET_BEHAVIOR
  maxBound = IGNORE
instance Prelude.Enum FlowControlLimitExceededBehaviorProto where
  toEnum k__
    = Prelude.maybe
        (Prelude.error
           ((Prelude.++)
              "toEnum: unknown value for enum FlowControlLimitExceededBehaviorProto: "
              (Prelude.show k__)))
        Prelude.id (Data.ProtoLens.maybeToEnum k__)
  fromEnum UNSET_BEHAVIOR = 0
  fromEnum THROW_EXCEPTION = 1
  fromEnum BLOCK = 2
  fromEnum IGNORE = 3
  fromEnum
    (FlowControlLimitExceededBehaviorProto'Unrecognized (FlowControlLimitExceededBehaviorProto'UnrecognizedValue k))
    = Prelude.fromIntegral k
  succ IGNORE
    = Prelude.error
        "FlowControlLimitExceededBehaviorProto.succ: bad argument IGNORE. This value would be out of bounds."
  succ UNSET_BEHAVIOR = THROW_EXCEPTION
  succ THROW_EXCEPTION = BLOCK
  succ BLOCK = IGNORE
  succ (FlowControlLimitExceededBehaviorProto'Unrecognized _)
    = Prelude.error
        "FlowControlLimitExceededBehaviorProto.succ: bad argument: unrecognized value"
  pred UNSET_BEHAVIOR
    = Prelude.error
        "FlowControlLimitExceededBehaviorProto.pred: bad argument UNSET_BEHAVIOR. This value would be out of bounds."
  pred THROW_EXCEPTION = UNSET_BEHAVIOR
  pred BLOCK = THROW_EXCEPTION
  pred IGNORE = BLOCK
  pred (FlowControlLimitExceededBehaviorProto'Unrecognized _)
    = Prelude.error
        "FlowControlLimitExceededBehaviorProto.pred: bad argument: unrecognized value"
  enumFrom = Data.ProtoLens.Message.Enum.messageEnumFrom
  enumFromTo = Data.ProtoLens.Message.Enum.messageEnumFromTo
  enumFromThen = Data.ProtoLens.Message.Enum.messageEnumFromThen
  enumFromThenTo = Data.ProtoLens.Message.Enum.messageEnumFromThenTo
instance Data.ProtoLens.FieldDefault FlowControlLimitExceededBehaviorProto where
  fieldDefault = UNSET_BEHAVIOR
instance Control.DeepSeq.NFData FlowControlLimitExceededBehaviorProto where
  rnf x__ = Prelude.seq x__ ()
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' GoSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' GoSettings (Prelude.Maybe CommonLanguageSettings)@
         * 'Proto.Google.Api.Client_Fields.renamedServices' @:: Lens' GoSettings (Data.Map.Map Data.Text.Text Data.Text.Text)@ -}
data GoSettings
  = GoSettings'_constructor {_GoSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                             _GoSettings'renamedServices :: !(Data.Map.Map Data.Text.Text Data.Text.Text),
                             _GoSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show GoSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField GoSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _GoSettings'common (\ x__ y__ -> x__ {_GoSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField GoSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _GoSettings'common (\ x__ y__ -> x__ {_GoSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField GoSettings "renamedServices" (Data.Map.Map Data.Text.Text Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _GoSettings'renamedServices
           (\ x__ y__ -> x__ {_GoSettings'renamedServices = y__}))
        Prelude.id
instance Data.ProtoLens.Message GoSettings where
  messageName _ = Data.Text.pack "google.api.GoSettings"
  packedMessageDescriptor _
    = "\n\
      \\n\
      \GoSettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2V\n\
      \\DLErenamed_services\CAN\STX \ETX(\v2+.google.api.GoSettings.RenamedServicesEntryR\SIrenamedServices\SUBB\n\
      \\DC4RenamedServicesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor GoSettings
        renamedServices__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "renamed_services"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor GoSettings'RenamedServicesEntry)
              (Data.ProtoLens.MapField
                 (Data.ProtoLens.Field.field @"key")
                 (Data.ProtoLens.Field.field @"value")
                 (Data.ProtoLens.Field.field @"renamedServices")) ::
              Data.ProtoLens.FieldDescriptor GoSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor),
           (Data.ProtoLens.Tag 2, renamedServices__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _GoSettings'_unknownFields
        (\ x__ y__ -> x__ {_GoSettings'_unknownFields = y__})
  defMessage
    = GoSettings'_constructor
        {_GoSettings'common = Prelude.Nothing,
         _GoSettings'renamedServices = Data.Map.empty,
         _GoSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          GoSettings -> Data.ProtoLens.Encoding.Bytes.Parser GoSettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        18
                          -> do !(entry :: GoSettings'RenamedServicesEntry) <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                                                                 (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                                                                     Data.ProtoLens.Encoding.Bytes.isolate
                                                                                       (Prelude.fromIntegral
                                                                                          len)
                                                                                       Data.ProtoLens.parseMessage)
                                                                                 "renamed_services"
                                (let
                                   key = Lens.Family2.view (Data.ProtoLens.Field.field @"key") entry
                                   value
                                     = Lens.Family2.view (Data.ProtoLens.Field.field @"value") entry
                                 in
                                   loop
                                     (Lens.Family2.over
                                        (Data.ProtoLens.Field.field @"renamedServices")
                                        (\ !t -> Data.Map.insert key value t) x))
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "GoSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             ((Data.Monoid.<>)
                (Data.Monoid.mconcat
                   (Prelude.map
                      (\ _v
                         -> (Data.Monoid.<>)
                              (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                              ((Prelude..)
                                 (\ bs
                                    -> (Data.Monoid.<>)
                                         (Data.ProtoLens.Encoding.Bytes.putVarInt
                                            (Prelude.fromIntegral (Data.ByteString.length bs)))
                                         (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                 Data.ProtoLens.encodeMessage
                                 (Lens.Family2.set
                                    (Data.ProtoLens.Field.field @"key") (Prelude.fst _v)
                                    (Lens.Family2.set
                                       (Data.ProtoLens.Field.field @"value") (Prelude.snd _v)
                                       (Data.ProtoLens.defMessage ::
                                          GoSettings'RenamedServicesEntry)))))
                      (Data.Map.toList
                         (Lens.Family2.view
                            (Data.ProtoLens.Field.field @"renamedServices") _x))))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData GoSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_GoSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_GoSettings'common x__)
                (Control.DeepSeq.deepseq (_GoSettings'renamedServices x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.key' @:: Lens' GoSettings'RenamedServicesEntry Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.value' @:: Lens' GoSettings'RenamedServicesEntry Data.Text.Text@ -}
data GoSettings'RenamedServicesEntry
  = GoSettings'RenamedServicesEntry'_constructor {_GoSettings'RenamedServicesEntry'key :: !Data.Text.Text,
                                                  _GoSettings'RenamedServicesEntry'value :: !Data.Text.Text,
                                                  _GoSettings'RenamedServicesEntry'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show GoSettings'RenamedServicesEntry where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField GoSettings'RenamedServicesEntry "key" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _GoSettings'RenamedServicesEntry'key
           (\ x__ y__ -> x__ {_GoSettings'RenamedServicesEntry'key = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField GoSettings'RenamedServicesEntry "value" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _GoSettings'RenamedServicesEntry'value
           (\ x__ y__ -> x__ {_GoSettings'RenamedServicesEntry'value = y__}))
        Prelude.id
instance Data.ProtoLens.Message GoSettings'RenamedServicesEntry where
  messageName _
    = Data.Text.pack "google.api.GoSettings.RenamedServicesEntry"
  packedMessageDescriptor _
    = "\n\
      \\DC4RenamedServicesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        key__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "key"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"key")) ::
              Data.ProtoLens.FieldDescriptor GoSettings'RenamedServicesEntry
        value__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "value"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"value")) ::
              Data.ProtoLens.FieldDescriptor GoSettings'RenamedServicesEntry
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, key__field_descriptor),
           (Data.ProtoLens.Tag 2, value__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _GoSettings'RenamedServicesEntry'_unknownFields
        (\ x__ y__
           -> x__ {_GoSettings'RenamedServicesEntry'_unknownFields = y__})
  defMessage
    = GoSettings'RenamedServicesEntry'_constructor
        {_GoSettings'RenamedServicesEntry'key = Data.ProtoLens.fieldDefault,
         _GoSettings'RenamedServicesEntry'value = Data.ProtoLens.fieldDefault,
         _GoSettings'RenamedServicesEntry'_unknownFields = []}
  parseMessage
    = let
        loop ::
          GoSettings'RenamedServicesEntry
          -> Data.ProtoLens.Encoding.Bytes.Parser GoSettings'RenamedServicesEntry
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "key"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"key") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "value"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"value") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "RenamedServicesEntry"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"key") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"value") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                         ((Prelude..)
                            (\ bs
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                       (Prelude.fromIntegral (Data.ByteString.length bs)))
                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            Data.Text.Encoding.encodeUtf8 _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData GoSettings'RenamedServicesEntry where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_GoSettings'RenamedServicesEntry'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_GoSettings'RenamedServicesEntry'key x__)
                (Control.DeepSeq.deepseq
                   (_GoSettings'RenamedServicesEntry'value x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.libraryPackage' @:: Lens' JavaSettings Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.serviceClassNames' @:: Lens' JavaSettings (Data.Map.Map Data.Text.Text Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' JavaSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' JavaSettings (Prelude.Maybe CommonLanguageSettings)@ -}
data JavaSettings
  = JavaSettings'_constructor {_JavaSettings'libraryPackage :: !Data.Text.Text,
                               _JavaSettings'serviceClassNames :: !(Data.Map.Map Data.Text.Text Data.Text.Text),
                               _JavaSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                               _JavaSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show JavaSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField JavaSettings "libraryPackage" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _JavaSettings'libraryPackage
           (\ x__ y__ -> x__ {_JavaSettings'libraryPackage = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField JavaSettings "serviceClassNames" (Data.Map.Map Data.Text.Text Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _JavaSettings'serviceClassNames
           (\ x__ y__ -> x__ {_JavaSettings'serviceClassNames = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField JavaSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _JavaSettings'common
           (\ x__ y__ -> x__ {_JavaSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField JavaSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _JavaSettings'common
           (\ x__ y__ -> x__ {_JavaSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Message JavaSettings where
  messageName _ = Data.Text.pack "google.api.JavaSettings"
  packedMessageDescriptor _
    = "\n\
      \\fJavaSettings\DC2'\n\
      \\SIlibrary_package\CAN\SOH \SOH(\tR\SOlibraryPackage\DC2_\n\
      \\DC3service_class_names\CAN\STX \ETX(\v2/.google.api.JavaSettings.ServiceClassNamesEntryR\DC1serviceClassNames\DC2:\n\
      \\ACKcommon\CAN\ETX \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\SUBD\n\
      \\SYNServiceClassNamesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        libraryPackage__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "library_package"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"libraryPackage")) ::
              Data.ProtoLens.FieldDescriptor JavaSettings
        serviceClassNames__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "service_class_names"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor JavaSettings'ServiceClassNamesEntry)
              (Data.ProtoLens.MapField
                 (Data.ProtoLens.Field.field @"key")
                 (Data.ProtoLens.Field.field @"value")
                 (Data.ProtoLens.Field.field @"serviceClassNames")) ::
              Data.ProtoLens.FieldDescriptor JavaSettings
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor JavaSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, libraryPackage__field_descriptor),
           (Data.ProtoLens.Tag 2, serviceClassNames__field_descriptor),
           (Data.ProtoLens.Tag 3, common__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _JavaSettings'_unknownFields
        (\ x__ y__ -> x__ {_JavaSettings'_unknownFields = y__})
  defMessage
    = JavaSettings'_constructor
        {_JavaSettings'libraryPackage = Data.ProtoLens.fieldDefault,
         _JavaSettings'serviceClassNames = Data.Map.empty,
         _JavaSettings'common = Prelude.Nothing,
         _JavaSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          JavaSettings -> Data.ProtoLens.Encoding.Bytes.Parser JavaSettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "library_package"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"libraryPackage") y x)
                        18
                          -> do !(entry :: JavaSettings'ServiceClassNamesEntry) <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                                                                     (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                                                                         Data.ProtoLens.Encoding.Bytes.isolate
                                                                                           (Prelude.fromIntegral
                                                                                              len)
                                                                                           Data.ProtoLens.parseMessage)
                                                                                     "service_class_names"
                                (let
                                   key = Lens.Family2.view (Data.ProtoLens.Field.field @"key") entry
                                   value
                                     = Lens.Family2.view (Data.ProtoLens.Field.field @"value") entry
                                 in
                                   loop
                                     (Lens.Family2.over
                                        (Data.ProtoLens.Field.field @"serviceClassNames")
                                        (\ !t -> Data.Map.insert key value t) x))
                        26
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "JavaSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view
                      (Data.ProtoLens.Field.field @"libraryPackage") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (Data.Monoid.mconcat
                   (Prelude.map
                      (\ _v
                         -> (Data.Monoid.<>)
                              (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                              ((Prelude..)
                                 (\ bs
                                    -> (Data.Monoid.<>)
                                         (Data.ProtoLens.Encoding.Bytes.putVarInt
                                            (Prelude.fromIntegral (Data.ByteString.length bs)))
                                         (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                 Data.ProtoLens.encodeMessage
                                 (Lens.Family2.set
                                    (Data.ProtoLens.Field.field @"key") (Prelude.fst _v)
                                    (Lens.Family2.set
                                       (Data.ProtoLens.Field.field @"value") (Prelude.snd _v)
                                       (Data.ProtoLens.defMessage ::
                                          JavaSettings'ServiceClassNamesEntry)))))
                      (Data.Map.toList
                         (Lens.Family2.view
                            (Data.ProtoLens.Field.field @"serviceClassNames") _x))))
                ((Data.Monoid.<>)
                   (case
                        Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
                    of
                      Prelude.Nothing -> Data.Monoid.mempty
                      (Prelude.Just _v)
                        -> (Data.Monoid.<>)
                             (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                             ((Prelude..)
                                (\ bs
                                   -> (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt
                                           (Prelude.fromIntegral (Data.ByteString.length bs)))
                                        (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                Data.ProtoLens.encodeMessage _v))
                   (Data.ProtoLens.Encoding.Wire.buildFieldSet
                      (Lens.Family2.view Data.ProtoLens.unknownFields _x))))
instance Control.DeepSeq.NFData JavaSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_JavaSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_JavaSettings'libraryPackage x__)
                (Control.DeepSeq.deepseq
                   (_JavaSettings'serviceClassNames x__)
                   (Control.DeepSeq.deepseq (_JavaSettings'common x__) ())))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.key' @:: Lens' JavaSettings'ServiceClassNamesEntry Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.value' @:: Lens' JavaSettings'ServiceClassNamesEntry Data.Text.Text@ -}
data JavaSettings'ServiceClassNamesEntry
  = JavaSettings'ServiceClassNamesEntry'_constructor {_JavaSettings'ServiceClassNamesEntry'key :: !Data.Text.Text,
                                                      _JavaSettings'ServiceClassNamesEntry'value :: !Data.Text.Text,
                                                      _JavaSettings'ServiceClassNamesEntry'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show JavaSettings'ServiceClassNamesEntry where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField JavaSettings'ServiceClassNamesEntry "key" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _JavaSettings'ServiceClassNamesEntry'key
           (\ x__ y__
              -> x__ {_JavaSettings'ServiceClassNamesEntry'key = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField JavaSettings'ServiceClassNamesEntry "value" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _JavaSettings'ServiceClassNamesEntry'value
           (\ x__ y__
              -> x__ {_JavaSettings'ServiceClassNamesEntry'value = y__}))
        Prelude.id
instance Data.ProtoLens.Message JavaSettings'ServiceClassNamesEntry where
  messageName _
    = Data.Text.pack "google.api.JavaSettings.ServiceClassNamesEntry"
  packedMessageDescriptor _
    = "\n\
      \\SYNServiceClassNamesEntry\DC2\DLE\n\
      \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
      \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        key__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "key"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"key")) ::
              Data.ProtoLens.FieldDescriptor JavaSettings'ServiceClassNamesEntry
        value__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "value"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"value")) ::
              Data.ProtoLens.FieldDescriptor JavaSettings'ServiceClassNamesEntry
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, key__field_descriptor),
           (Data.ProtoLens.Tag 2, value__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _JavaSettings'ServiceClassNamesEntry'_unknownFields
        (\ x__ y__
           -> x__ {_JavaSettings'ServiceClassNamesEntry'_unknownFields = y__})
  defMessage
    = JavaSettings'ServiceClassNamesEntry'_constructor
        {_JavaSettings'ServiceClassNamesEntry'key = Data.ProtoLens.fieldDefault,
         _JavaSettings'ServiceClassNamesEntry'value = Data.ProtoLens.fieldDefault,
         _JavaSettings'ServiceClassNamesEntry'_unknownFields = []}
  parseMessage
    = let
        loop ::
          JavaSettings'ServiceClassNamesEntry
          -> Data.ProtoLens.Encoding.Bytes.Parser JavaSettings'ServiceClassNamesEntry
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "key"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"key") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "value"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"value") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "ServiceClassNamesEntry"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"key") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"value") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                         ((Prelude..)
                            (\ bs
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                       (Prelude.fromIntegral (Data.ByteString.length bs)))
                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            Data.Text.Encoding.encodeUtf8 _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData JavaSettings'ServiceClassNamesEntry where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_JavaSettings'ServiceClassNamesEntry'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_JavaSettings'ServiceClassNamesEntry'key x__)
                (Control.DeepSeq.deepseq
                   (_JavaSettings'ServiceClassNamesEntry'value x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.selector' @:: Lens' MethodSettings Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.longRunning' @:: Lens' MethodSettings MethodSettings'LongRunning@
         * 'Proto.Google.Api.Client_Fields.maybe'longRunning' @:: Lens' MethodSettings (Prelude.Maybe MethodSettings'LongRunning)@
         * 'Proto.Google.Api.Client_Fields.autoPopulatedFields' @:: Lens' MethodSettings [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'autoPopulatedFields' @:: Lens' MethodSettings (Data.Vector.Vector Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.batching' @:: Lens' MethodSettings BatchingConfigProto@
         * 'Proto.Google.Api.Client_Fields.maybe'batching' @:: Lens' MethodSettings (Prelude.Maybe BatchingConfigProto)@ -}
data MethodSettings
  = MethodSettings'_constructor {_MethodSettings'selector :: !Data.Text.Text,
                                 _MethodSettings'longRunning :: !(Prelude.Maybe MethodSettings'LongRunning),
                                 _MethodSettings'autoPopulatedFields :: !(Data.Vector.Vector Data.Text.Text),
                                 _MethodSettings'batching :: !(Prelude.Maybe BatchingConfigProto),
                                 _MethodSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show MethodSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField MethodSettings "selector" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'selector
           (\ x__ y__ -> x__ {_MethodSettings'selector = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField MethodSettings "longRunning" MethodSettings'LongRunning where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'longRunning
           (\ x__ y__ -> x__ {_MethodSettings'longRunning = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField MethodSettings "maybe'longRunning" (Prelude.Maybe MethodSettings'LongRunning) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'longRunning
           (\ x__ y__ -> x__ {_MethodSettings'longRunning = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField MethodSettings "autoPopulatedFields" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'autoPopulatedFields
           (\ x__ y__ -> x__ {_MethodSettings'autoPopulatedFields = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField MethodSettings "vec'autoPopulatedFields" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'autoPopulatedFields
           (\ x__ y__ -> x__ {_MethodSettings'autoPopulatedFields = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField MethodSettings "batching" BatchingConfigProto where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'batching
           (\ x__ y__ -> x__ {_MethodSettings'batching = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField MethodSettings "maybe'batching" (Prelude.Maybe BatchingConfigProto) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'batching
           (\ x__ y__ -> x__ {_MethodSettings'batching = y__}))
        Prelude.id
instance Data.ProtoLens.Message MethodSettings where
  messageName _ = Data.Text.pack "google.api.MethodSettings"
  packedMessageDescriptor _
    = "\n\
      \\SOMethodSettings\DC2\SUB\n\
      \\bselector\CAN\SOH \SOH(\tR\bselector\DC2I\n\
      \\flong_running\CAN\STX \SOH(\v2&.google.api.MethodSettings.LongRunningR\vlongRunning\DC22\n\
      \\NAKauto_populated_fields\CAN\ETX \ETX(\tR\DC3autoPopulatedFields\DC2;\n\
      \\bbatching\CAN\EOT \SOH(\v2\US.google.api.BatchingConfigProtoR\bbatching\SUB\148\STX\n\
      \\vLongRunning\DC2G\n\
      \\DC2initial_poll_delay\CAN\SOH \SOH(\v2\EM.google.protobuf.DurationR\DLEinitialPollDelay\DC22\n\
      \\NAKpoll_delay_multiplier\CAN\STX \SOH(\STXR\DC3pollDelayMultiplier\DC2?\n\
      \\SOmax_poll_delay\CAN\ETX \SOH(\v2\EM.google.protobuf.DurationR\fmaxPollDelay\DC2G\n\
      \\DC2total_poll_timeout\CAN\EOT \SOH(\v2\EM.google.protobuf.DurationR\DLEtotalPollTimeout"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        selector__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "selector"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"selector")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings
        longRunning__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "long_running"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor MethodSettings'LongRunning)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'longRunning")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings
        autoPopulatedFields__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "auto_populated_fields"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"autoPopulatedFields")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings
        batching__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "batching"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor BatchingConfigProto)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'batching")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, selector__field_descriptor),
           (Data.ProtoLens.Tag 2, longRunning__field_descriptor),
           (Data.ProtoLens.Tag 3, autoPopulatedFields__field_descriptor),
           (Data.ProtoLens.Tag 4, batching__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _MethodSettings'_unknownFields
        (\ x__ y__ -> x__ {_MethodSettings'_unknownFields = y__})
  defMessage
    = MethodSettings'_constructor
        {_MethodSettings'selector = Data.ProtoLens.fieldDefault,
         _MethodSettings'longRunning = Prelude.Nothing,
         _MethodSettings'autoPopulatedFields = Data.Vector.Generic.empty,
         _MethodSettings'batching = Prelude.Nothing,
         _MethodSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          MethodSettings
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
             -> Data.ProtoLens.Encoding.Bytes.Parser MethodSettings
        loop x mutable'autoPopulatedFields
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'autoPopulatedFields <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                      (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                         mutable'autoPopulatedFields)
                      (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t)
                           (Lens.Family2.set
                              (Data.ProtoLens.Field.field @"vec'autoPopulatedFields")
                              frozen'autoPopulatedFields x))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "selector"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"selector") y x)
                                  mutable'autoPopulatedFields
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "long_running"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"longRunning") y x)
                                  mutable'autoPopulatedFields
                        26
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "auto_populated_fields"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'autoPopulatedFields y)
                                loop x v
                        34
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "batching"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"batching") y x)
                                  mutable'autoPopulatedFields
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'autoPopulatedFields
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'autoPopulatedFields <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                               Data.ProtoLens.Encoding.Growing.new
              loop Data.ProtoLens.defMessage mutable'autoPopulatedFields)
          "MethodSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v = Lens.Family2.view (Data.ProtoLens.Field.field @"selector") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (case
                     Lens.Family2.view
                       (Data.ProtoLens.Field.field @"maybe'longRunning") _x
                 of
                   Prelude.Nothing -> Data.Monoid.mempty
                   (Prelude.Just _v)
                     -> (Data.Monoid.<>)
                          (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                          ((Prelude..)
                             (\ bs
                                -> (Data.Monoid.<>)
                                     (Data.ProtoLens.Encoding.Bytes.putVarInt
                                        (Prelude.fromIntegral (Data.ByteString.length bs)))
                                     (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                             Data.ProtoLens.encodeMessage _v))
                ((Data.Monoid.<>)
                   (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                      (\ _v
                         -> (Data.Monoid.<>)
                              (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                              ((Prelude..)
                                 (\ bs
                                    -> (Data.Monoid.<>)
                                         (Data.ProtoLens.Encoding.Bytes.putVarInt
                                            (Prelude.fromIntegral (Data.ByteString.length bs)))
                                         (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                 Data.Text.Encoding.encodeUtf8 _v))
                      (Lens.Family2.view
                         (Data.ProtoLens.Field.field @"vec'autoPopulatedFields") _x))
                   ((Data.Monoid.<>)
                      (case
                           Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'batching") _x
                       of
                         Prelude.Nothing -> Data.Monoid.mempty
                         (Prelude.Just _v)
                           -> (Data.Monoid.<>)
                                (Data.ProtoLens.Encoding.Bytes.putVarInt 34)
                                ((Prelude..)
                                   (\ bs
                                      -> (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt
                                              (Prelude.fromIntegral (Data.ByteString.length bs)))
                                           (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                   Data.ProtoLens.encodeMessage _v))
                      (Data.ProtoLens.Encoding.Wire.buildFieldSet
                         (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))
instance Control.DeepSeq.NFData MethodSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_MethodSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_MethodSettings'selector x__)
                (Control.DeepSeq.deepseq
                   (_MethodSettings'longRunning x__)
                   (Control.DeepSeq.deepseq
                      (_MethodSettings'autoPopulatedFields x__)
                      (Control.DeepSeq.deepseq (_MethodSettings'batching x__) ()))))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.initialPollDelay' @:: Lens' MethodSettings'LongRunning Proto.Google.Protobuf.Duration.Duration@
         * 'Proto.Google.Api.Client_Fields.maybe'initialPollDelay' @:: Lens' MethodSettings'LongRunning (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration)@
         * 'Proto.Google.Api.Client_Fields.pollDelayMultiplier' @:: Lens' MethodSettings'LongRunning Prelude.Float@
         * 'Proto.Google.Api.Client_Fields.maxPollDelay' @:: Lens' MethodSettings'LongRunning Proto.Google.Protobuf.Duration.Duration@
         * 'Proto.Google.Api.Client_Fields.maybe'maxPollDelay' @:: Lens' MethodSettings'LongRunning (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration)@
         * 'Proto.Google.Api.Client_Fields.totalPollTimeout' @:: Lens' MethodSettings'LongRunning Proto.Google.Protobuf.Duration.Duration@
         * 'Proto.Google.Api.Client_Fields.maybe'totalPollTimeout' @:: Lens' MethodSettings'LongRunning (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration)@ -}
data MethodSettings'LongRunning
  = MethodSettings'LongRunning'_constructor {_MethodSettings'LongRunning'initialPollDelay :: !(Prelude.Maybe Proto.Google.Protobuf.Duration.Duration),
                                             _MethodSettings'LongRunning'pollDelayMultiplier :: !Prelude.Float,
                                             _MethodSettings'LongRunning'maxPollDelay :: !(Prelude.Maybe Proto.Google.Protobuf.Duration.Duration),
                                             _MethodSettings'LongRunning'totalPollTimeout :: !(Prelude.Maybe Proto.Google.Protobuf.Duration.Duration),
                                             _MethodSettings'LongRunning'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show MethodSettings'LongRunning where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "initialPollDelay" Proto.Google.Protobuf.Duration.Duration where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'initialPollDelay
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'initialPollDelay = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "maybe'initialPollDelay" (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'initialPollDelay
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'initialPollDelay = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "pollDelayMultiplier" Prelude.Float where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'pollDelayMultiplier
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'pollDelayMultiplier = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "maxPollDelay" Proto.Google.Protobuf.Duration.Duration where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'maxPollDelay
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'maxPollDelay = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "maybe'maxPollDelay" (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'maxPollDelay
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'maxPollDelay = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "totalPollTimeout" Proto.Google.Protobuf.Duration.Duration where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'totalPollTimeout
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'totalPollTimeout = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField MethodSettings'LongRunning "maybe'totalPollTimeout" (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _MethodSettings'LongRunning'totalPollTimeout
           (\ x__ y__
              -> x__ {_MethodSettings'LongRunning'totalPollTimeout = y__}))
        Prelude.id
instance Data.ProtoLens.Message MethodSettings'LongRunning where
  messageName _
    = Data.Text.pack "google.api.MethodSettings.LongRunning"
  packedMessageDescriptor _
    = "\n\
      \\vLongRunning\DC2G\n\
      \\DC2initial_poll_delay\CAN\SOH \SOH(\v2\EM.google.protobuf.DurationR\DLEinitialPollDelay\DC22\n\
      \\NAKpoll_delay_multiplier\CAN\STX \SOH(\STXR\DC3pollDelayMultiplier\DC2?\n\
      \\SOmax_poll_delay\CAN\ETX \SOH(\v2\EM.google.protobuf.DurationR\fmaxPollDelay\DC2G\n\
      \\DC2total_poll_timeout\CAN\EOT \SOH(\v2\EM.google.protobuf.DurationR\DLEtotalPollTimeout"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        initialPollDelay__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "initial_poll_delay"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Duration.Duration)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'initialPollDelay")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings'LongRunning
        pollDelayMultiplier__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "poll_delay_multiplier"
              (Data.ProtoLens.ScalarField Data.ProtoLens.FloatField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Float)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"pollDelayMultiplier")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings'LongRunning
        maxPollDelay__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "max_poll_delay"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Duration.Duration)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'maxPollDelay")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings'LongRunning
        totalPollTimeout__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "total_poll_timeout"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Duration.Duration)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'totalPollTimeout")) ::
              Data.ProtoLens.FieldDescriptor MethodSettings'LongRunning
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, initialPollDelay__field_descriptor),
           (Data.ProtoLens.Tag 2, pollDelayMultiplier__field_descriptor),
           (Data.ProtoLens.Tag 3, maxPollDelay__field_descriptor),
           (Data.ProtoLens.Tag 4, totalPollTimeout__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _MethodSettings'LongRunning'_unknownFields
        (\ x__ y__
           -> x__ {_MethodSettings'LongRunning'_unknownFields = y__})
  defMessage
    = MethodSettings'LongRunning'_constructor
        {_MethodSettings'LongRunning'initialPollDelay = Prelude.Nothing,
         _MethodSettings'LongRunning'pollDelayMultiplier = Data.ProtoLens.fieldDefault,
         _MethodSettings'LongRunning'maxPollDelay = Prelude.Nothing,
         _MethodSettings'LongRunning'totalPollTimeout = Prelude.Nothing,
         _MethodSettings'LongRunning'_unknownFields = []}
  parseMessage
    = let
        loop ::
          MethodSettings'LongRunning
          -> Data.ProtoLens.Encoding.Bytes.Parser MethodSettings'LongRunning
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "initial_poll_delay"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"initialPollDelay") y x)
                        21
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Data.ProtoLens.Encoding.Bytes.wordToFloat
                                          Data.ProtoLens.Encoding.Bytes.getFixed32)
                                       "poll_delay_multiplier"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"pollDelayMultiplier") y x)
                        26
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "max_poll_delay"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"maxPollDelay") y x)
                        34
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "total_poll_timeout"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"totalPollTimeout") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "LongRunning"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view
                    (Data.ProtoLens.Field.field @"maybe'initialPollDelay") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"pollDelayMultiplier") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 21)
                         ((Prelude..)
                            Data.ProtoLens.Encoding.Bytes.putFixed32
                            Data.ProtoLens.Encoding.Bytes.floatToWord _v))
                ((Data.Monoid.<>)
                   (case
                        Lens.Family2.view
                          (Data.ProtoLens.Field.field @"maybe'maxPollDelay") _x
                    of
                      Prelude.Nothing -> Data.Monoid.mempty
                      (Prelude.Just _v)
                        -> (Data.Monoid.<>)
                             (Data.ProtoLens.Encoding.Bytes.putVarInt 26)
                             ((Prelude..)
                                (\ bs
                                   -> (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt
                                           (Prelude.fromIntegral (Data.ByteString.length bs)))
                                        (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                Data.ProtoLens.encodeMessage _v))
                   ((Data.Monoid.<>)
                      (case
                           Lens.Family2.view
                             (Data.ProtoLens.Field.field @"maybe'totalPollTimeout") _x
                       of
                         Prelude.Nothing -> Data.Monoid.mempty
                         (Prelude.Just _v)
                           -> (Data.Monoid.<>)
                                (Data.ProtoLens.Encoding.Bytes.putVarInt 34)
                                ((Prelude..)
                                   (\ bs
                                      -> (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt
                                              (Prelude.fromIntegral (Data.ByteString.length bs)))
                                           (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                   Data.ProtoLens.encodeMessage _v))
                      (Data.ProtoLens.Encoding.Wire.buildFieldSet
                         (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))
instance Control.DeepSeq.NFData MethodSettings'LongRunning where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_MethodSettings'LongRunning'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_MethodSettings'LongRunning'initialPollDelay x__)
                (Control.DeepSeq.deepseq
                   (_MethodSettings'LongRunning'pollDelayMultiplier x__)
                   (Control.DeepSeq.deepseq
                      (_MethodSettings'LongRunning'maxPollDelay x__)
                      (Control.DeepSeq.deepseq
                         (_MethodSettings'LongRunning'totalPollTimeout x__) ()))))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' NodeSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' NodeSettings (Prelude.Maybe CommonLanguageSettings)@ -}
data NodeSettings
  = NodeSettings'_constructor {_NodeSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                               _NodeSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show NodeSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField NodeSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _NodeSettings'common
           (\ x__ y__ -> x__ {_NodeSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField NodeSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _NodeSettings'common
           (\ x__ y__ -> x__ {_NodeSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Message NodeSettings where
  messageName _ = Data.Text.pack "google.api.NodeSettings"
  packedMessageDescriptor _
    = "\n\
      \\fNodeSettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor NodeSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _NodeSettings'_unknownFields
        (\ x__ y__ -> x__ {_NodeSettings'_unknownFields = y__})
  defMessage
    = NodeSettings'_constructor
        {_NodeSettings'common = Prelude.Nothing,
         _NodeSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          NodeSettings -> Data.ProtoLens.Encoding.Bytes.Parser NodeSettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "NodeSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData NodeSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_NodeSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq (_NodeSettings'common x__) ())
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' PhpSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' PhpSettings (Prelude.Maybe CommonLanguageSettings)@
         * 'Proto.Google.Api.Client_Fields.libraryPackage' @:: Lens' PhpSettings Data.Text.Text@ -}
data PhpSettings
  = PhpSettings'_constructor {_PhpSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                              _PhpSettings'libraryPackage :: !Data.Text.Text,
                              _PhpSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show PhpSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField PhpSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PhpSettings'common (\ x__ y__ -> x__ {_PhpSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField PhpSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PhpSettings'common (\ x__ y__ -> x__ {_PhpSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField PhpSettings "libraryPackage" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PhpSettings'libraryPackage
           (\ x__ y__ -> x__ {_PhpSettings'libraryPackage = y__}))
        Prelude.id
instance Data.ProtoLens.Message PhpSettings where
  messageName _ = Data.Text.pack "google.api.PhpSettings"
  packedMessageDescriptor _
    = "\n\
      \\vPhpSettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2'\n\
      \\SIlibrary_package\CAN\STX \SOH(\tR\SOlibraryPackage"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor PhpSettings
        libraryPackage__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "library_package"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"libraryPackage")) ::
              Data.ProtoLens.FieldDescriptor PhpSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor),
           (Data.ProtoLens.Tag 2, libraryPackage__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _PhpSettings'_unknownFields
        (\ x__ y__ -> x__ {_PhpSettings'_unknownFields = y__})
  defMessage
    = PhpSettings'_constructor
        {_PhpSettings'common = Prelude.Nothing,
         _PhpSettings'libraryPackage = Data.ProtoLens.fieldDefault,
         _PhpSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          PhpSettings -> Data.ProtoLens.Encoding.Bytes.Parser PhpSettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "library_package"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"libraryPackage") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "PhpSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"libraryPackage") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                         ((Prelude..)
                            (\ bs
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                       (Prelude.fromIntegral (Data.ByteString.length bs)))
                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            Data.Text.Encoding.encodeUtf8 _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData PhpSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_PhpSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_PhpSettings'common x__)
                (Control.DeepSeq.deepseq (_PhpSettings'libraryPackage x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.methodSettings' @:: Lens' Publishing [MethodSettings]@
         * 'Proto.Google.Api.Client_Fields.vec'methodSettings' @:: Lens' Publishing (Data.Vector.Vector MethodSettings)@
         * 'Proto.Google.Api.Client_Fields.newIssueUri' @:: Lens' Publishing Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.documentationUri' @:: Lens' Publishing Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.apiShortName' @:: Lens' Publishing Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.githubLabel' @:: Lens' Publishing Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.codeownerGithubTeams' @:: Lens' Publishing [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'codeownerGithubTeams' @:: Lens' Publishing (Data.Vector.Vector Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.docTagPrefix' @:: Lens' Publishing Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.organization' @:: Lens' Publishing ClientLibraryOrganization@
         * 'Proto.Google.Api.Client_Fields.librarySettings' @:: Lens' Publishing [ClientLibrarySettings]@
         * 'Proto.Google.Api.Client_Fields.vec'librarySettings' @:: Lens' Publishing (Data.Vector.Vector ClientLibrarySettings)@
         * 'Proto.Google.Api.Client_Fields.protoReferenceDocumentationUri' @:: Lens' Publishing Data.Text.Text@
         * 'Proto.Google.Api.Client_Fields.restReferenceDocumentationUri' @:: Lens' Publishing Data.Text.Text@ -}
data Publishing
  = Publishing'_constructor {_Publishing'methodSettings :: !(Data.Vector.Vector MethodSettings),
                             _Publishing'newIssueUri :: !Data.Text.Text,
                             _Publishing'documentationUri :: !Data.Text.Text,
                             _Publishing'apiShortName :: !Data.Text.Text,
                             _Publishing'githubLabel :: !Data.Text.Text,
                             _Publishing'codeownerGithubTeams :: !(Data.Vector.Vector Data.Text.Text),
                             _Publishing'docTagPrefix :: !Data.Text.Text,
                             _Publishing'organization :: !ClientLibraryOrganization,
                             _Publishing'librarySettings :: !(Data.Vector.Vector ClientLibrarySettings),
                             _Publishing'protoReferenceDocumentationUri :: !Data.Text.Text,
                             _Publishing'restReferenceDocumentationUri :: !Data.Text.Text,
                             _Publishing'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show Publishing where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField Publishing "methodSettings" [MethodSettings] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'methodSettings
           (\ x__ y__ -> x__ {_Publishing'methodSettings = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField Publishing "vec'methodSettings" (Data.Vector.Vector MethodSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'methodSettings
           (\ x__ y__ -> x__ {_Publishing'methodSettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "newIssueUri" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'newIssueUri
           (\ x__ y__ -> x__ {_Publishing'newIssueUri = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "documentationUri" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'documentationUri
           (\ x__ y__ -> x__ {_Publishing'documentationUri = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "apiShortName" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'apiShortName
           (\ x__ y__ -> x__ {_Publishing'apiShortName = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "githubLabel" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'githubLabel
           (\ x__ y__ -> x__ {_Publishing'githubLabel = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "codeownerGithubTeams" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'codeownerGithubTeams
           (\ x__ y__ -> x__ {_Publishing'codeownerGithubTeams = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField Publishing "vec'codeownerGithubTeams" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'codeownerGithubTeams
           (\ x__ y__ -> x__ {_Publishing'codeownerGithubTeams = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "docTagPrefix" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'docTagPrefix
           (\ x__ y__ -> x__ {_Publishing'docTagPrefix = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "organization" ClientLibraryOrganization where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'organization
           (\ x__ y__ -> x__ {_Publishing'organization = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "librarySettings" [ClientLibrarySettings] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'librarySettings
           (\ x__ y__ -> x__ {_Publishing'librarySettings = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField Publishing "vec'librarySettings" (Data.Vector.Vector ClientLibrarySettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'librarySettings
           (\ x__ y__ -> x__ {_Publishing'librarySettings = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "protoReferenceDocumentationUri" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'protoReferenceDocumentationUri
           (\ x__ y__
              -> x__ {_Publishing'protoReferenceDocumentationUri = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Publishing "restReferenceDocumentationUri" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Publishing'restReferenceDocumentationUri
           (\ x__ y__
              -> x__ {_Publishing'restReferenceDocumentationUri = y__}))
        Prelude.id
instance Data.ProtoLens.Message Publishing where
  messageName _ = Data.Text.pack "google.api.Publishing"
  packedMessageDescriptor _
    = "\n\
      \\n\
      \Publishing\DC2C\n\
      \\SImethod_settings\CAN\STX \ETX(\v2\SUB.google.api.MethodSettingsR\SOmethodSettings\DC2\"\n\
      \\rnew_issue_uri\CANe \SOH(\tR\vnewIssueUri\DC2+\n\
      \\DC1documentation_uri\CANf \SOH(\tR\DLEdocumentationUri\DC2$\n\
      \\SOapi_short_name\CANg \SOH(\tR\fapiShortName\DC2!\n\
      \\fgithub_label\CANh \SOH(\tR\vgithubLabel\DC24\n\
      \\SYNcodeowner_github_teams\CANi \ETX(\tR\DC4codeownerGithubTeams\DC2$\n\
      \\SOdoc_tag_prefix\CANj \SOH(\tR\fdocTagPrefix\DC2I\n\
      \\forganization\CANk \SOH(\SO2%.google.api.ClientLibraryOrganizationR\forganization\DC2L\n\
      \\DLElibrary_settings\CANm \ETX(\v2!.google.api.ClientLibrarySettingsR\SIlibrarySettings\DC2I\n\
      \!proto_reference_documentation_uri\CANn \SOH(\tR\RSprotoReferenceDocumentationUri\DC2G\n\
      \ rest_reference_documentation_uri\CANo \SOH(\tR\GSrestReferenceDocumentationUri"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        methodSettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "method_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor MethodSettings)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"methodSettings")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        newIssueUri__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "new_issue_uri"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"newIssueUri")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        documentationUri__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "documentation_uri"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"documentationUri")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        apiShortName__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "api_short_name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"apiShortName")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        githubLabel__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "github_label"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"githubLabel")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        codeownerGithubTeams__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "codeowner_github_teams"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"codeownerGithubTeams")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        docTagPrefix__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "doc_tag_prefix"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"docTagPrefix")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        organization__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "organization"
              (Data.ProtoLens.ScalarField Data.ProtoLens.EnumField ::
                 Data.ProtoLens.FieldTypeDescriptor ClientLibraryOrganization)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"organization")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        librarySettings__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "library_settings"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor ClientLibrarySettings)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"librarySettings")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        protoReferenceDocumentationUri__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "proto_reference_documentation_uri"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"protoReferenceDocumentationUri")) ::
              Data.ProtoLens.FieldDescriptor Publishing
        restReferenceDocumentationUri__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "rest_reference_documentation_uri"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"restReferenceDocumentationUri")) ::
              Data.ProtoLens.FieldDescriptor Publishing
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 2, methodSettings__field_descriptor),
           (Data.ProtoLens.Tag 101, newIssueUri__field_descriptor),
           (Data.ProtoLens.Tag 102, documentationUri__field_descriptor),
           (Data.ProtoLens.Tag 103, apiShortName__field_descriptor),
           (Data.ProtoLens.Tag 104, githubLabel__field_descriptor),
           (Data.ProtoLens.Tag 105, codeownerGithubTeams__field_descriptor),
           (Data.ProtoLens.Tag 106, docTagPrefix__field_descriptor),
           (Data.ProtoLens.Tag 107, organization__field_descriptor),
           (Data.ProtoLens.Tag 109, librarySettings__field_descriptor),
           (Data.ProtoLens.Tag 110, 
            protoReferenceDocumentationUri__field_descriptor),
           (Data.ProtoLens.Tag 111, 
            restReferenceDocumentationUri__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _Publishing'_unknownFields
        (\ x__ y__ -> x__ {_Publishing'_unknownFields = y__})
  defMessage
    = Publishing'_constructor
        {_Publishing'methodSettings = Data.Vector.Generic.empty,
         _Publishing'newIssueUri = Data.ProtoLens.fieldDefault,
         _Publishing'documentationUri = Data.ProtoLens.fieldDefault,
         _Publishing'apiShortName = Data.ProtoLens.fieldDefault,
         _Publishing'githubLabel = Data.ProtoLens.fieldDefault,
         _Publishing'codeownerGithubTeams = Data.Vector.Generic.empty,
         _Publishing'docTagPrefix = Data.ProtoLens.fieldDefault,
         _Publishing'organization = Data.ProtoLens.fieldDefault,
         _Publishing'librarySettings = Data.Vector.Generic.empty,
         _Publishing'protoReferenceDocumentationUri = Data.ProtoLens.fieldDefault,
         _Publishing'restReferenceDocumentationUri = Data.ProtoLens.fieldDefault,
         _Publishing'_unknownFields = []}
  parseMessage
    = let
        loop ::
          Publishing
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
             -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld ClientLibrarySettings
                -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld MethodSettings
                   -> Data.ProtoLens.Encoding.Bytes.Parser Publishing
        loop
          x
          mutable'codeownerGithubTeams
          mutable'librarySettings
          mutable'methodSettings
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'codeownerGithubTeams <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                       (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                          mutable'codeownerGithubTeams)
                      frozen'librarySettings <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                  (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                     mutable'librarySettings)
                      frozen'methodSettings <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                 (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                    mutable'methodSettings)
                      (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t)
                           (Lens.Family2.set
                              (Data.ProtoLens.Field.field @"vec'codeownerGithubTeams")
                              frozen'codeownerGithubTeams
                              (Lens.Family2.set
                                 (Data.ProtoLens.Field.field @"vec'librarySettings")
                                 frozen'librarySettings
                                 (Lens.Family2.set
                                    (Data.ProtoLens.Field.field @"vec'methodSettings")
                                    frozen'methodSettings x))))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        18
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.isolate
                                              (Prelude.fromIntegral len)
                                              Data.ProtoLens.parseMessage)
                                        "method_settings"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'methodSettings y)
                                loop x mutable'codeownerGithubTeams mutable'librarySettings v
                        810
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "new_issue_uri"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"newIssueUri") y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        818
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "documentation_uri"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"documentationUri") y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        826
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "api_short_name"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"apiShortName") y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        834
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "github_label"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"githubLabel") y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        842
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "codeowner_github_teams"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'codeownerGithubTeams y)
                                loop x v mutable'librarySettings mutable'methodSettings
                        850
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "doc_tag_prefix"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"docTagPrefix") y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        856
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.toEnum
                                          (Prelude.fmap
                                             Prelude.fromIntegral
                                             Data.ProtoLens.Encoding.Bytes.getVarInt))
                                       "organization"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"organization") y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        874
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.isolate
                                              (Prelude.fromIntegral len)
                                              Data.ProtoLens.parseMessage)
                                        "library_settings"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'librarySettings y)
                                loop x mutable'codeownerGithubTeams v mutable'methodSettings
                        882
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "proto_reference_documentation_uri"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"protoReferenceDocumentationUri")
                                     y x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        890
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "rest_reference_documentation_uri"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"restReferenceDocumentationUri") y
                                     x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'codeownerGithubTeams mutable'librarySettings
                                  mutable'methodSettings
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'codeownerGithubTeams <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                                Data.ProtoLens.Encoding.Growing.new
              mutable'librarySettings <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                           Data.ProtoLens.Encoding.Growing.new
              mutable'methodSettings <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                          Data.ProtoLens.Encoding.Growing.new
              loop
                Data.ProtoLens.defMessage mutable'codeownerGithubTeams
                mutable'librarySettings mutable'methodSettings)
          "Publishing"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                (\ _v
                   -> (Data.Monoid.<>)
                        (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                        ((Prelude..)
                           (\ bs
                              -> (Data.Monoid.<>)
                                   (Data.ProtoLens.Encoding.Bytes.putVarInt
                                      (Prelude.fromIntegral (Data.ByteString.length bs)))
                                   (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                           Data.ProtoLens.encodeMessage _v))
                (Lens.Family2.view
                   (Data.ProtoLens.Field.field @"vec'methodSettings") _x))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view (Data.ProtoLens.Field.field @"newIssueUri") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 810)
                         ((Prelude..)
                            (\ bs
                               -> (Data.Monoid.<>)
                                    (Data.ProtoLens.Encoding.Bytes.putVarInt
                                       (Prelude.fromIntegral (Data.ByteString.length bs)))
                                    (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                            Data.Text.Encoding.encodeUtf8 _v))
                ((Data.Monoid.<>)
                   (let
                      _v
                        = Lens.Family2.view
                            (Data.ProtoLens.Field.field @"documentationUri") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 818)
                            ((Prelude..)
                               (\ bs
                                  -> (Data.Monoid.<>)
                                       (Data.ProtoLens.Encoding.Bytes.putVarInt
                                          (Prelude.fromIntegral (Data.ByteString.length bs)))
                                       (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                               Data.Text.Encoding.encodeUtf8 _v))
                   ((Data.Monoid.<>)
                      (let
                         _v
                           = Lens.Family2.view (Data.ProtoLens.Field.field @"apiShortName") _x
                       in
                         if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                             Data.Monoid.mempty
                         else
                             (Data.Monoid.<>)
                               (Data.ProtoLens.Encoding.Bytes.putVarInt 826)
                               ((Prelude..)
                                  (\ bs
                                     -> (Data.Monoid.<>)
                                          (Data.ProtoLens.Encoding.Bytes.putVarInt
                                             (Prelude.fromIntegral (Data.ByteString.length bs)))
                                          (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                  Data.Text.Encoding.encodeUtf8 _v))
                      ((Data.Monoid.<>)
                         (let
                            _v
                              = Lens.Family2.view (Data.ProtoLens.Field.field @"githubLabel") _x
                          in
                            if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                Data.Monoid.mempty
                            else
                                (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt 834)
                                  ((Prelude..)
                                     (\ bs
                                        -> (Data.Monoid.<>)
                                             (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                (Prelude.fromIntegral (Data.ByteString.length bs)))
                                             (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                     Data.Text.Encoding.encodeUtf8 _v))
                         ((Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                               (\ _v
                                  -> (Data.Monoid.<>)
                                       (Data.ProtoLens.Encoding.Bytes.putVarInt 842)
                                       ((Prelude..)
                                          (\ bs
                                             -> (Data.Monoid.<>)
                                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                     (Prelude.fromIntegral
                                                        (Data.ByteString.length bs)))
                                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                          Data.Text.Encoding.encodeUtf8 _v))
                               (Lens.Family2.view
                                  (Data.ProtoLens.Field.field @"vec'codeownerGithubTeams") _x))
                            ((Data.Monoid.<>)
                               (let
                                  _v
                                    = Lens.Family2.view
                                        (Data.ProtoLens.Field.field @"docTagPrefix") _x
                                in
                                  if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                      Data.Monoid.mempty
                                  else
                                      (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt 850)
                                        ((Prelude..)
                                           (\ bs
                                              -> (Data.Monoid.<>)
                                                   (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                      (Prelude.fromIntegral
                                                         (Data.ByteString.length bs)))
                                                   (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                           Data.Text.Encoding.encodeUtf8 _v))
                               ((Data.Monoid.<>)
                                  (let
                                     _v
                                       = Lens.Family2.view
                                           (Data.ProtoLens.Field.field @"organization") _x
                                   in
                                     if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                         Data.Monoid.mempty
                                     else
                                         (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt 856)
                                           ((Prelude..)
                                              ((Prelude..)
                                                 Data.ProtoLens.Encoding.Bytes.putVarInt
                                                 Prelude.fromIntegral)
                                              Prelude.fromEnum _v))
                                  ((Data.Monoid.<>)
                                     (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                                        (\ _v
                                           -> (Data.Monoid.<>)
                                                (Data.ProtoLens.Encoding.Bytes.putVarInt 874)
                                                ((Prelude..)
                                                   (\ bs
                                                      -> (Data.Monoid.<>)
                                                           (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                              (Prelude.fromIntegral
                                                                 (Data.ByteString.length bs)))
                                                           (Data.ProtoLens.Encoding.Bytes.putBytes
                                                              bs))
                                                   Data.ProtoLens.encodeMessage _v))
                                        (Lens.Family2.view
                                           (Data.ProtoLens.Field.field @"vec'librarySettings") _x))
                                     ((Data.Monoid.<>)
                                        (let
                                           _v
                                             = Lens.Family2.view
                                                 (Data.ProtoLens.Field.field
                                                    @"protoReferenceDocumentationUri")
                                                 _x
                                         in
                                           if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                               Data.Monoid.mempty
                                           else
                                               (Data.Monoid.<>)
                                                 (Data.ProtoLens.Encoding.Bytes.putVarInt 882)
                                                 ((Prelude..)
                                                    (\ bs
                                                       -> (Data.Monoid.<>)
                                                            (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                               (Prelude.fromIntegral
                                                                  (Data.ByteString.length bs)))
                                                            (Data.ProtoLens.Encoding.Bytes.putBytes
                                                               bs))
                                                    Data.Text.Encoding.encodeUtf8 _v))
                                        ((Data.Monoid.<>)
                                           (let
                                              _v
                                                = Lens.Family2.view
                                                    (Data.ProtoLens.Field.field
                                                       @"restReferenceDocumentationUri")
                                                    _x
                                            in
                                              if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                                  Data.Monoid.mempty
                                              else
                                                  (Data.Monoid.<>)
                                                    (Data.ProtoLens.Encoding.Bytes.putVarInt 890)
                                                    ((Prelude..)
                                                       (\ bs
                                                          -> (Data.Monoid.<>)
                                                               (Data.ProtoLens.Encoding.Bytes.putVarInt
                                                                  (Prelude.fromIntegral
                                                                     (Data.ByteString.length bs)))
                                                               (Data.ProtoLens.Encoding.Bytes.putBytes
                                                                  bs))
                                                       Data.Text.Encoding.encodeUtf8 _v))
                                           (Data.ProtoLens.Encoding.Wire.buildFieldSet
                                              (Lens.Family2.view
                                                 Data.ProtoLens.unknownFields _x))))))))))))
instance Control.DeepSeq.NFData Publishing where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_Publishing'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_Publishing'methodSettings x__)
                (Control.DeepSeq.deepseq
                   (_Publishing'newIssueUri x__)
                   (Control.DeepSeq.deepseq
                      (_Publishing'documentationUri x__)
                      (Control.DeepSeq.deepseq
                         (_Publishing'apiShortName x__)
                         (Control.DeepSeq.deepseq
                            (_Publishing'githubLabel x__)
                            (Control.DeepSeq.deepseq
                               (_Publishing'codeownerGithubTeams x__)
                               (Control.DeepSeq.deepseq
                                  (_Publishing'docTagPrefix x__)
                                  (Control.DeepSeq.deepseq
                                     (_Publishing'organization x__)
                                     (Control.DeepSeq.deepseq
                                        (_Publishing'librarySettings x__)
                                        (Control.DeepSeq.deepseq
                                           (_Publishing'protoReferenceDocumentationUri x__)
                                           (Control.DeepSeq.deepseq
                                              (_Publishing'restReferenceDocumentationUri x__)
                                              ())))))))))))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' PythonSettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' PythonSettings (Prelude.Maybe CommonLanguageSettings)@
         * 'Proto.Google.Api.Client_Fields.experimentalFeatures' @:: Lens' PythonSettings PythonSettings'ExperimentalFeatures@
         * 'Proto.Google.Api.Client_Fields.maybe'experimentalFeatures' @:: Lens' PythonSettings (Prelude.Maybe PythonSettings'ExperimentalFeatures)@ -}
data PythonSettings
  = PythonSettings'_constructor {_PythonSettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                                 _PythonSettings'experimentalFeatures :: !(Prelude.Maybe PythonSettings'ExperimentalFeatures),
                                 _PythonSettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show PythonSettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField PythonSettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'common
           (\ x__ y__ -> x__ {_PythonSettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField PythonSettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'common
           (\ x__ y__ -> x__ {_PythonSettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField PythonSettings "experimentalFeatures" PythonSettings'ExperimentalFeatures where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'experimentalFeatures
           (\ x__ y__ -> x__ {_PythonSettings'experimentalFeatures = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField PythonSettings "maybe'experimentalFeatures" (Prelude.Maybe PythonSettings'ExperimentalFeatures) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'experimentalFeatures
           (\ x__ y__ -> x__ {_PythonSettings'experimentalFeatures = y__}))
        Prelude.id
instance Data.ProtoLens.Message PythonSettings where
  messageName _ = Data.Text.pack "google.api.PythonSettings"
  packedMessageDescriptor _
    = "\n\
      \\SOPythonSettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2d\n\
      \\NAKexperimental_features\CAN\STX \SOH(\v2/.google.api.PythonSettings.ExperimentalFeaturesR\DC4experimentalFeatures\SUB\210\SOH\n\
      \\DC4ExperimentalFeatures\DC21\n\
      \\NAKrest_async_io_enabled\CAN\SOH \SOH(\bR\DC2restAsyncIoEnabled\DC2E\n\
      \\USprotobuf_pythonic_types_enabled\CAN\STX \SOH(\bR\FSprotobufPythonicTypesEnabled\DC2@\n\
      \\FSunversioned_package_disabled\CAN\ETX \SOH(\bR\SUBunversionedPackageDisabled"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor PythonSettings
        experimentalFeatures__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "experimental_features"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor PythonSettings'ExperimentalFeatures)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'experimentalFeatures")) ::
              Data.ProtoLens.FieldDescriptor PythonSettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor),
           (Data.ProtoLens.Tag 2, experimentalFeatures__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _PythonSettings'_unknownFields
        (\ x__ y__ -> x__ {_PythonSettings'_unknownFields = y__})
  defMessage
    = PythonSettings'_constructor
        {_PythonSettings'common = Prelude.Nothing,
         _PythonSettings'experimentalFeatures = Prelude.Nothing,
         _PythonSettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          PythonSettings
          -> Data.ProtoLens.Encoding.Bytes.Parser PythonSettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "experimental_features"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"experimentalFeatures") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "PythonSettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             ((Data.Monoid.<>)
                (case
                     Lens.Family2.view
                       (Data.ProtoLens.Field.field @"maybe'experimentalFeatures") _x
                 of
                   Prelude.Nothing -> Data.Monoid.mempty
                   (Prelude.Just _v)
                     -> (Data.Monoid.<>)
                          (Data.ProtoLens.Encoding.Bytes.putVarInt 18)
                          ((Prelude..)
                             (\ bs
                                -> (Data.Monoid.<>)
                                     (Data.ProtoLens.Encoding.Bytes.putVarInt
                                        (Prelude.fromIntegral (Data.ByteString.length bs)))
                                     (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                             Data.ProtoLens.encodeMessage _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData PythonSettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_PythonSettings'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_PythonSettings'common x__)
                (Control.DeepSeq.deepseq
                   (_PythonSettings'experimentalFeatures x__) ()))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.restAsyncIoEnabled' @:: Lens' PythonSettings'ExperimentalFeatures Prelude.Bool@
         * 'Proto.Google.Api.Client_Fields.protobufPythonicTypesEnabled' @:: Lens' PythonSettings'ExperimentalFeatures Prelude.Bool@
         * 'Proto.Google.Api.Client_Fields.unversionedPackageDisabled' @:: Lens' PythonSettings'ExperimentalFeatures Prelude.Bool@ -}
data PythonSettings'ExperimentalFeatures
  = PythonSettings'ExperimentalFeatures'_constructor {_PythonSettings'ExperimentalFeatures'restAsyncIoEnabled :: !Prelude.Bool,
                                                      _PythonSettings'ExperimentalFeatures'protobufPythonicTypesEnabled :: !Prelude.Bool,
                                                      _PythonSettings'ExperimentalFeatures'unversionedPackageDisabled :: !Prelude.Bool,
                                                      _PythonSettings'ExperimentalFeatures'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show PythonSettings'ExperimentalFeatures where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField PythonSettings'ExperimentalFeatures "restAsyncIoEnabled" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'ExperimentalFeatures'restAsyncIoEnabled
           (\ x__ y__
              -> x__
                   {_PythonSettings'ExperimentalFeatures'restAsyncIoEnabled = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField PythonSettings'ExperimentalFeatures "protobufPythonicTypesEnabled" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'ExperimentalFeatures'protobufPythonicTypesEnabled
           (\ x__ y__
              -> x__
                   {_PythonSettings'ExperimentalFeatures'protobufPythonicTypesEnabled = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField PythonSettings'ExperimentalFeatures "unversionedPackageDisabled" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _PythonSettings'ExperimentalFeatures'unversionedPackageDisabled
           (\ x__ y__
              -> x__
                   {_PythonSettings'ExperimentalFeatures'unversionedPackageDisabled = y__}))
        Prelude.id
instance Data.ProtoLens.Message PythonSettings'ExperimentalFeatures where
  messageName _
    = Data.Text.pack "google.api.PythonSettings.ExperimentalFeatures"
  packedMessageDescriptor _
    = "\n\
      \\DC4ExperimentalFeatures\DC21\n\
      \\NAKrest_async_io_enabled\CAN\SOH \SOH(\bR\DC2restAsyncIoEnabled\DC2E\n\
      \\USprotobuf_pythonic_types_enabled\CAN\STX \SOH(\bR\FSprotobufPythonicTypesEnabled\DC2@\n\
      \\FSunversioned_package_disabled\CAN\ETX \SOH(\bR\SUBunversionedPackageDisabled"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        restAsyncIoEnabled__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "rest_async_io_enabled"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"restAsyncIoEnabled")) ::
              Data.ProtoLens.FieldDescriptor PythonSettings'ExperimentalFeatures
        protobufPythonicTypesEnabled__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "protobuf_pythonic_types_enabled"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"protobufPythonicTypesEnabled")) ::
              Data.ProtoLens.FieldDescriptor PythonSettings'ExperimentalFeatures
        unversionedPackageDisabled__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "unversioned_package_disabled"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"unversionedPackageDisabled")) ::
              Data.ProtoLens.FieldDescriptor PythonSettings'ExperimentalFeatures
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, restAsyncIoEnabled__field_descriptor),
           (Data.ProtoLens.Tag 2, 
            protobufPythonicTypesEnabled__field_descriptor),
           (Data.ProtoLens.Tag 3, 
            unversionedPackageDisabled__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _PythonSettings'ExperimentalFeatures'_unknownFields
        (\ x__ y__
           -> x__ {_PythonSettings'ExperimentalFeatures'_unknownFields = y__})
  defMessage
    = PythonSettings'ExperimentalFeatures'_constructor
        {_PythonSettings'ExperimentalFeatures'restAsyncIoEnabled = Data.ProtoLens.fieldDefault,
         _PythonSettings'ExperimentalFeatures'protobufPythonicTypesEnabled = Data.ProtoLens.fieldDefault,
         _PythonSettings'ExperimentalFeatures'unversionedPackageDisabled = Data.ProtoLens.fieldDefault,
         _PythonSettings'ExperimentalFeatures'_unknownFields = []}
  parseMessage
    = let
        loop ::
          PythonSettings'ExperimentalFeatures
          -> Data.ProtoLens.Encoding.Bytes.Parser PythonSettings'ExperimentalFeatures
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        8 -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "rest_async_io_enabled"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"restAsyncIoEnabled") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "protobuf_pythonic_types_enabled"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"protobufPythonicTypesEnabled") y
                                     x)
                        24
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "unversioned_package_disabled"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"unversionedPackageDisabled") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "ExperimentalFeatures"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view
                      (Data.ProtoLens.Field.field @"restAsyncIoEnabled") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 8)
                      ((Prelude..)
                         Data.ProtoLens.Encoding.Bytes.putVarInt (\ b -> if b then 1 else 0)
                         _v))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"protobufPythonicTypesEnabled") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 16)
                         ((Prelude..)
                            Data.ProtoLens.Encoding.Bytes.putVarInt (\ b -> if b then 1 else 0)
                            _v))
                ((Data.Monoid.<>)
                   (let
                      _v
                        = Lens.Family2.view
                            (Data.ProtoLens.Field.field @"unversionedPackageDisabled") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 24)
                            ((Prelude..)
                               Data.ProtoLens.Encoding.Bytes.putVarInt (\ b -> if b then 1 else 0)
                               _v))
                   (Data.ProtoLens.Encoding.Wire.buildFieldSet
                      (Lens.Family2.view Data.ProtoLens.unknownFields _x))))
instance Control.DeepSeq.NFData PythonSettings'ExperimentalFeatures where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_PythonSettings'ExperimentalFeatures'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_PythonSettings'ExperimentalFeatures'restAsyncIoEnabled x__)
                (Control.DeepSeq.deepseq
                   (_PythonSettings'ExperimentalFeatures'protobufPythonicTypesEnabled
                      x__)
                   (Control.DeepSeq.deepseq
                      (_PythonSettings'ExperimentalFeatures'unversionedPackageDisabled
                         x__)
                      ())))
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.common' @:: Lens' RubySettings CommonLanguageSettings@
         * 'Proto.Google.Api.Client_Fields.maybe'common' @:: Lens' RubySettings (Prelude.Maybe CommonLanguageSettings)@ -}
data RubySettings
  = RubySettings'_constructor {_RubySettings'common :: !(Prelude.Maybe CommonLanguageSettings),
                               _RubySettings'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show RubySettings where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField RubySettings "common" CommonLanguageSettings where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _RubySettings'common
           (\ x__ y__ -> x__ {_RubySettings'common = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField RubySettings "maybe'common" (Prelude.Maybe CommonLanguageSettings) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _RubySettings'common
           (\ x__ y__ -> x__ {_RubySettings'common = y__}))
        Prelude.id
instance Data.ProtoLens.Message RubySettings where
  messageName _ = Data.Text.pack "google.api.RubySettings"
  packedMessageDescriptor _
    = "\n\
      \\fRubySettings\DC2:\n\
      \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        common__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "common"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor CommonLanguageSettings)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'common")) ::
              Data.ProtoLens.FieldDescriptor RubySettings
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, common__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _RubySettings'_unknownFields
        (\ x__ y__ -> x__ {_RubySettings'_unknownFields = y__})
  defMessage
    = RubySettings'_constructor
        {_RubySettings'common = Prelude.Nothing,
         _RubySettings'_unknownFields = []}
  parseMessage
    = let
        loop ::
          RubySettings -> Data.ProtoLens.Encoding.Bytes.Parser RubySettings
        loop x
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t) x)
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "common"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"common") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "RubySettings"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (case
                  Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'common") _x
              of
                Prelude.Nothing -> Data.Monoid.mempty
                (Prelude.Just _v)
                  -> (Data.Monoid.<>)
                       (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                       ((Prelude..)
                          (\ bs
                             -> (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (Prelude.fromIntegral (Data.ByteString.length bs)))
                                  (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                          Data.ProtoLens.encodeMessage _v))
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData RubySettings where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_RubySettings'_unknownFields x__)
             (Control.DeepSeq.deepseq (_RubySettings'common x__) ())
{- | Fields :
     
         * 'Proto.Google.Api.Client_Fields.methods' @:: Lens' SelectiveGapicGeneration [Data.Text.Text]@
         * 'Proto.Google.Api.Client_Fields.vec'methods' @:: Lens' SelectiveGapicGeneration (Data.Vector.Vector Data.Text.Text)@
         * 'Proto.Google.Api.Client_Fields.generateOmittedAsInternal' @:: Lens' SelectiveGapicGeneration Prelude.Bool@ -}
data SelectiveGapicGeneration
  = SelectiveGapicGeneration'_constructor {_SelectiveGapicGeneration'methods :: !(Data.Vector.Vector Data.Text.Text),
                                           _SelectiveGapicGeneration'generateOmittedAsInternal :: !Prelude.Bool,
                                           _SelectiveGapicGeneration'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show SelectiveGapicGeneration where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField SelectiveGapicGeneration "methods" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SelectiveGapicGeneration'methods
           (\ x__ y__ -> x__ {_SelectiveGapicGeneration'methods = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField SelectiveGapicGeneration "vec'methods" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SelectiveGapicGeneration'methods
           (\ x__ y__ -> x__ {_SelectiveGapicGeneration'methods = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField SelectiveGapicGeneration "generateOmittedAsInternal" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SelectiveGapicGeneration'generateOmittedAsInternal
           (\ x__ y__
              -> x__
                   {_SelectiveGapicGeneration'generateOmittedAsInternal = y__}))
        Prelude.id
instance Data.ProtoLens.Message SelectiveGapicGeneration where
  messageName _
    = Data.Text.pack "google.api.SelectiveGapicGeneration"
  packedMessageDescriptor _
    = "\n\
      \\CANSelectiveGapicGeneration\DC2\CAN\n\
      \\amethods\CAN\SOH \ETX(\tR\amethods\DC2?\n\
      \\FSgenerate_omitted_as_internal\CAN\STX \SOH(\bR\EMgenerateOmittedAsInternal"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        methods__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "methods"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked (Data.ProtoLens.Field.field @"methods")) ::
              Data.ProtoLens.FieldDescriptor SelectiveGapicGeneration
        generateOmittedAsInternal__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "generate_omitted_as_internal"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"generateOmittedAsInternal")) ::
              Data.ProtoLens.FieldDescriptor SelectiveGapicGeneration
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, methods__field_descriptor),
           (Data.ProtoLens.Tag 2, 
            generateOmittedAsInternal__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _SelectiveGapicGeneration'_unknownFields
        (\ x__ y__ -> x__ {_SelectiveGapicGeneration'_unknownFields = y__})
  defMessage
    = SelectiveGapicGeneration'_constructor
        {_SelectiveGapicGeneration'methods = Data.Vector.Generic.empty,
         _SelectiveGapicGeneration'generateOmittedAsInternal = Data.ProtoLens.fieldDefault,
         _SelectiveGapicGeneration'_unknownFields = []}
  parseMessage
    = let
        loop ::
          SelectiveGapicGeneration
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
             -> Data.ProtoLens.Encoding.Bytes.Parser SelectiveGapicGeneration
        loop x mutable'methods
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'methods <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                          (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                             mutable'methods)
                      (let missing = []
                       in
                         if Prelude.null missing then
                             Prelude.return ()
                         else
                             Prelude.fail
                               ((Prelude.++)
                                  "Missing required fields: "
                                  (Prelude.show (missing :: [Prelude.String]))))
                      Prelude.return
                        (Lens.Family2.over
                           Data.ProtoLens.unknownFields (\ !t -> Prelude.reverse t)
                           (Lens.Family2.set
                              (Data.ProtoLens.Field.field @"vec'methods") frozen'methods x))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "methods"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append mutable'methods y)
                                loop x v
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "generate_omitted_as_internal"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"generateOmittedAsInternal") y x)
                                  mutable'methods
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'methods
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'methods <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                   Data.ProtoLens.Encoding.Growing.new
              loop Data.ProtoLens.defMessage mutable'methods)
          "SelectiveGapicGeneration"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (Data.ProtoLens.Encoding.Bytes.foldMapBuilder
                (\ _v
                   -> (Data.Monoid.<>)
                        (Data.ProtoLens.Encoding.Bytes.putVarInt 10)
                        ((Prelude..)
                           (\ bs
                              -> (Data.Monoid.<>)
                                   (Data.ProtoLens.Encoding.Bytes.putVarInt
                                      (Prelude.fromIntegral (Data.ByteString.length bs)))
                                   (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                           Data.Text.Encoding.encodeUtf8 _v))
                (Lens.Family2.view (Data.ProtoLens.Field.field @"vec'methods") _x))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"generateOmittedAsInternal") _x
                 in
                   if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                       Data.Monoid.mempty
                   else
                       (Data.Monoid.<>)
                         (Data.ProtoLens.Encoding.Bytes.putVarInt 16)
                         ((Prelude..)
                            Data.ProtoLens.Encoding.Bytes.putVarInt (\ b -> if b then 1 else 0)
                            _v))
                (Data.ProtoLens.Encoding.Wire.buildFieldSet
                   (Lens.Family2.view Data.ProtoLens.unknownFields _x)))
instance Control.DeepSeq.NFData SelectiveGapicGeneration where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_SelectiveGapicGeneration'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_SelectiveGapicGeneration'methods x__)
                (Control.DeepSeq.deepseq
                   (_SelectiveGapicGeneration'generateOmittedAsInternal x__) ()))
packedFileDescriptor :: Data.ByteString.ByteString
packedFileDescriptor
  = "\n\
    \\ETBgoogle/api/client.proto\DC2\n\
    \google.api\SUB\GSgoogle/api/launch_stage.proto\SUB google/protobuf/descriptor.proto\SUB\RSgoogle/protobuf/duration.proto\"\248\SOH\n\
    \\SYNCommonLanguageSettings\DC20\n\
    \\DC2reference_docs_uri\CAN\SOH \SOH(\tR\DLEreferenceDocsUriB\STX\CAN\SOH\DC2H\n\
    \\fdestinations\CAN\STX \ETX(\SO2$.google.api.ClientLibraryDestinationR\fdestinations\DC2b\n\
    \\SUBselective_gapic_generation\CAN\ETX \SOH(\v2$.google.api.SelectiveGapicGenerationR\CANselectiveGapicGeneration\"\147\ENQ\n\
    \\NAKClientLibrarySettings\DC2\CAN\n\
    \\aversion\CAN\SOH \SOH(\tR\aversion\DC2:\n\
    \\flaunch_stage\CAN\STX \SOH(\SO2\ETB.google.api.LaunchStageR\vlaunchStage\DC2,\n\
    \\DC2rest_numeric_enums\CAN\ETX \SOH(\bR\DLErestNumericEnums\DC2=\n\
    \\rjava_settings\CAN\NAK \SOH(\v2\CAN.google.api.JavaSettingsR\fjavaSettings\DC2:\n\
    \\fcpp_settings\CAN\SYN \SOH(\v2\ETB.google.api.CppSettingsR\vcppSettings\DC2:\n\
    \\fphp_settings\CAN\ETB \SOH(\v2\ETB.google.api.PhpSettingsR\vphpSettings\DC2C\n\
    \\SIpython_settings\CAN\CAN \SOH(\v2\SUB.google.api.PythonSettingsR\SOpythonSettings\DC2=\n\
    \\rnode_settings\CAN\EM \SOH(\v2\CAN.google.api.NodeSettingsR\fnodeSettings\DC2C\n\
    \\SIdotnet_settings\CAN\SUB \SOH(\v2\SUB.google.api.DotnetSettingsR\SOdotnetSettings\DC2=\n\
    \\rruby_settings\CAN\ESC \SOH(\v2\CAN.google.api.RubySettingsR\frubySettings\DC27\n\
    \\vgo_settings\CAN\FS \SOH(\v2\SYN.google.api.GoSettingsR\n\
    \goSettings\"\244\EOT\n\
    \\n\
    \Publishing\DC2C\n\
    \\SImethod_settings\CAN\STX \ETX(\v2\SUB.google.api.MethodSettingsR\SOmethodSettings\DC2\"\n\
    \\rnew_issue_uri\CANe \SOH(\tR\vnewIssueUri\DC2+\n\
    \\DC1documentation_uri\CANf \SOH(\tR\DLEdocumentationUri\DC2$\n\
    \\SOapi_short_name\CANg \SOH(\tR\fapiShortName\DC2!\n\
    \\fgithub_label\CANh \SOH(\tR\vgithubLabel\DC24\n\
    \\SYNcodeowner_github_teams\CANi \ETX(\tR\DC4codeownerGithubTeams\DC2$\n\
    \\SOdoc_tag_prefix\CANj \SOH(\tR\fdocTagPrefix\DC2I\n\
    \\forganization\CANk \SOH(\SO2%.google.api.ClientLibraryOrganizationR\forganization\DC2L\n\
    \\DLElibrary_settings\CANm \ETX(\v2!.google.api.ClientLibrarySettingsR\SIlibrarySettings\DC2I\n\
    \!proto_reference_documentation_uri\CANn \SOH(\tR\RSprotoReferenceDocumentationUri\DC2G\n\
    \ rest_reference_documentation_uri\CANo \SOH(\tR\GSrestReferenceDocumentationUri\"\154\STX\n\
    \\fJavaSettings\DC2'\n\
    \\SIlibrary_package\CAN\SOH \SOH(\tR\SOlibraryPackage\DC2_\n\
    \\DC3service_class_names\CAN\STX \ETX(\v2/.google.api.JavaSettings.ServiceClassNamesEntryR\DC1serviceClassNames\DC2:\n\
    \\ACKcommon\CAN\ETX \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\SUBD\n\
    \\SYNServiceClassNamesEntry\DC2\DLE\n\
    \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
    \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH\"I\n\
    \\vCppSettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\"r\n\
    \\vPhpSettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2'\n\
    \\SIlibrary_package\CAN\STX \SOH(\tR\SOlibraryPackage\"\135\ETX\n\
    \\SOPythonSettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2d\n\
    \\NAKexperimental_features\CAN\STX \SOH(\v2/.google.api.PythonSettings.ExperimentalFeaturesR\DC4experimentalFeatures\SUB\210\SOH\n\
    \\DC4ExperimentalFeatures\DC21\n\
    \\NAKrest_async_io_enabled\CAN\SOH \SOH(\bR\DC2restAsyncIoEnabled\DC2E\n\
    \\USprotobuf_pythonic_types_enabled\CAN\STX \SOH(\bR\FSprotobufPythonicTypesEnabled\DC2@\n\
    \\FSunversioned_package_disabled\CAN\ETX \SOH(\bR\SUBunversionedPackageDisabled\"J\n\
    \\fNodeSettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\"\174\EOT\n\
    \\SODotnetSettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2Z\n\
    \\DLErenamed_services\CAN\STX \ETX(\v2/.google.api.DotnetSettings.RenamedServicesEntryR\SIrenamedServices\DC2]\n\
    \\DC1renamed_resources\CAN\ETX \ETX(\v20.google.api.DotnetSettings.RenamedResourcesEntryR\DLErenamedResources\DC2+\n\
    \\DC1ignored_resources\CAN\EOT \ETX(\tR\DLEignoredResources\DC28\n\
    \\CANforced_namespace_aliases\CAN\ENQ \ETX(\tR\SYNforcedNamespaceAliases\DC25\n\
    \\SYNhandwritten_signatures\CAN\ACK \ETX(\tR\NAKhandwrittenSignatures\SUBB\n\
    \\DC4RenamedServicesEntry\DC2\DLE\n\
    \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
    \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH\SUBC\n\
    \\NAKRenamedResourcesEntry\DC2\DLE\n\
    \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
    \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH\"J\n\
    \\fRubySettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\"\228\SOH\n\
    \\n\
    \GoSettings\DC2:\n\
    \\ACKcommon\CAN\SOH \SOH(\v2\".google.api.CommonLanguageSettingsR\ACKcommon\DC2V\n\
    \\DLErenamed_services\CAN\STX \ETX(\v2+.google.api.GoSettings.RenamedServicesEntryR\SIrenamedServices\SUBB\n\
    \\DC4RenamedServicesEntry\DC2\DLE\n\
    \\ETXkey\CAN\SOH \SOH(\tR\ETXkey\DC2\DC4\n\
    \\ENQvalue\CAN\STX \SOH(\tR\ENQvalue:\STX8\SOH\"\255\ETX\n\
    \\SOMethodSettings\DC2\SUB\n\
    \\bselector\CAN\SOH \SOH(\tR\bselector\DC2I\n\
    \\flong_running\CAN\STX \SOH(\v2&.google.api.MethodSettings.LongRunningR\vlongRunning\DC22\n\
    \\NAKauto_populated_fields\CAN\ETX \ETX(\tR\DC3autoPopulatedFields\DC2;\n\
    \\bbatching\CAN\EOT \SOH(\v2\US.google.api.BatchingConfigProtoR\bbatching\SUB\148\STX\n\
    \\vLongRunning\DC2G\n\
    \\DC2initial_poll_delay\CAN\SOH \SOH(\v2\EM.google.protobuf.DurationR\DLEinitialPollDelay\DC22\n\
    \\NAKpoll_delay_multiplier\CAN\STX \SOH(\STXR\DC3pollDelayMultiplier\DC2?\n\
    \\SOmax_poll_delay\CAN\ETX \SOH(\v2\EM.google.protobuf.DurationR\fmaxPollDelay\DC2G\n\
    \\DC2total_poll_timeout\CAN\EOT \SOH(\v2\EM.google.protobuf.DurationR\DLEtotalPollTimeout\"u\n\
    \\CANSelectiveGapicGeneration\DC2\CAN\n\
    \\amethods\CAN\SOH \ETX(\tR\amethods\DC2?\n\
    \\FSgenerate_omitted_as_internal\CAN\STX \SOH(\bR\EMgenerateOmittedAsInternal\"\168\SOH\n\
    \\DC3BatchingConfigProto\DC2A\n\
    \\n\
    \thresholds\CAN\SOH \SOH(\v2!.google.api.BatchingSettingsProtoR\n\
    \thresholds\DC2N\n\
    \\DLEbatch_descriptor\CAN\STX \SOH(\v2#.google.api.BatchingDescriptorProtoR\SIbatchDescriptor\"\159\EOT\n\
    \\NAKBatchingSettingsProto\DC26\n\
    \\ETBelement_count_threshold\CAN\SOH \SOH(\ENQR\NAKelementCountThreshold\DC24\n\
    \\SYNrequest_byte_threshold\CAN\STX \SOH(\ETXR\DC4requestByteThreshold\DC2B\n\
    \\SIdelay_threshold\CAN\ETX \SOH(\v2\EM.google.protobuf.DurationR\SOdelayThreshold\DC2.\n\
    \\DC3element_count_limit\CAN\EOT \SOH(\ENQR\DC1elementCountLimit\DC2,\n\
    \\DC2request_byte_limit\CAN\ENQ \SOH(\ENQR\DLErequestByteLimit\DC2;\n\
    \\SUBflow_control_element_limit\CAN\ACK \SOH(\ENQR\ETBflowControlElementLimit\DC25\n\
    \\ETBflow_control_byte_limit\CAN\a \SOH(\ENQR\DC4flowControlByteLimit\DC2\129\SOH\n\
    \$flow_control_limit_exceeded_behavior\CAN\b \SOH(\SO21.google.api.FlowControlLimitExceededBehaviorProtoR flowControlLimitExceededBehavior\"\158\SOH\n\
    \\ETBBatchingDescriptorProto\DC2#\n\
    \\rbatched_field\CAN\SOH \SOH(\tR\fbatchedField\DC21\n\
    \\DC4discriminator_fields\CAN\STX \ETX(\tR\DC3discriminatorFields\DC2+\n\
    \\DC1subresponse_field\CAN\ETX \SOH(\tR\DLEsubresponseField*\163\SOH\n\
    \\EMClientLibraryOrganization\DC2+\n\
    \'CLIENT_LIBRARY_ORGANIZATION_UNSPECIFIED\DLE\NUL\DC2\t\n\
    \\ENQCLOUD\DLE\SOH\DC2\a\n\
    \\ETXADS\DLE\STX\DC2\n\
    \\n\
    \\ACKPHOTOS\DLE\ETX\DC2\SI\n\
    \\vSTREET_VIEW\DLE\EOT\DC2\f\n\
    \\bSHOPPING\DLE\ENQ\DC2\a\n\
    \\ETXGEO\DLE\ACK\DC2\DC1\n\
    \\rGENERATIVE_AI\DLE\a*g\n\
    \\CANClientLibraryDestination\DC2*\n\
    \&CLIENT_LIBRARY_DESTINATION_UNSPECIFIED\DLE\NUL\DC2\n\
    \\n\
    \\ACKGITHUB\DLE\n\
    \\DC2\DC3\n\
    \\SIPACKAGE_MANAGER\DLE\DC4*g\n\
    \%FlowControlLimitExceededBehaviorProto\DC2\DC2\n\
    \\SOUNSET_BEHAVIOR\DLE\NUL\DC2\DC3\n\
    \\SITHROW_EXCEPTION\DLE\SOH\DC2\t\n\
    \\ENQBLOCK\DLE\STX\DC2\n\
    \\n\
    \\ACKIGNORE\DLE\ETX:J\n\
    \\DLEmethod_signature\CAN\155\b \ETX(\t\DC2\RS.google.protobuf.MethodOptionsR\SImethodSignature:C\n\
    \\fdefault_host\CAN\153\b \SOH(\t\DC2\US.google.protobuf.ServiceOptionsR\vdefaultHost:C\n\
    \\foauth_scopes\CAN\154\b \SOH(\t\DC2\US.google.protobuf.ServiceOptionsR\voauthScopes:D\n\
    \\vapi_version\CAN\193\186\171\250\SOH \SOH(\t\DC2\US.google.protobuf.ServiceOptionsR\n\
    \apiVersionBi\n\
    \\SOcom.google.apiB\vClientProtoP\SOHZAgoogle.golang.org/genproto/googleapis/api/annotations;annotations\162\STX\EOTGAPIJ\253\170\SOH\n\
    \\a\DC2\ENQ\SO\NUL\213\EOT\SOH\n\
    \\188\EOT\n\
    \\SOH\f\DC2\ETX\SO\NUL\DC22\177\EOT Copyright 2026 Google LLC\n\
    \\n\
    \ Licensed under the Apache License, Version 2.0 (the \"License\");\n\
    \ you may not use this file except in compliance with the License.\n\
    \ You may obtain a copy of the License at\n\
    \\n\
    \     http://www.apache.org/licenses/LICENSE-2.0\n\
    \\n\
    \ Unless required by applicable law or agreed to in writing, software\n\
    \ distributed under the License is distributed on an \"AS IS\" BASIS,\n\
    \ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n\
    \ See the License for the specific language governing permissions and\n\
    \ limitations under the License.\n\
    \\n\
    \\b\n\
    \\SOH\STX\DC2\ETX\DLE\NUL\DC3\n\
    \\t\n\
    \\STX\ETX\NUL\DC2\ETX\DC2\NUL'\n\
    \\t\n\
    \\STX\ETX\SOH\DC2\ETX\DC3\NUL*\n\
    \\t\n\
    \\STX\ETX\STX\DC2\ETX\DC4\NUL(\n\
    \\b\n\
    \\SOH\b\DC2\ETX\SYN\NULX\n\
    \\t\n\
    \\STX\b\v\DC2\ETX\SYN\NULX\n\
    \\b\n\
    \\SOH\b\DC2\ETX\ETB\NUL\"\n\
    \\t\n\
    \\STX\b\n\
    \\DC2\ETX\ETB\NUL\"\n\
    \\b\n\
    \\SOH\b\DC2\ETX\CAN\NUL,\n\
    \\t\n\
    \\STX\b\b\DC2\ETX\CAN\NUL,\n\
    \\b\n\
    \\SOH\b\DC2\ETX\EM\NUL'\n\
    \\t\n\
    \\STX\b\SOH\DC2\ETX\EM\NUL'\n\
    \\b\n\
    \\SOH\b\DC2\ETX\SUB\NUL\"\n\
    \\t\n\
    \\STX\b$\DC2\ETX\SUB\NUL\"\n\
    \\t\n\
    \\SOH\a\DC2\EOT\FS\NULA\SOH\n\
    \\143\v\n\
    \\STX\a\NUL\DC2\ETX@\STX*\SUB\131\v A definition of a client library method signature.\n\
    \\n\
    \ In client libraries, each proto RPC corresponds to one or more methods\n\
    \ which the end user is able to call, and calls the underlying RPC.\n\
    \ Normally, this method receives a single argument (a struct or instance\n\
    \ corresponding to the RPC request object). Defining this field will\n\
    \ add one or more overloads providing flattened or simpler method signatures\n\
    \ in some languages.\n\
    \\n\
    \ The fields on the method signature are provided as a comma-separated\n\
    \ string.\n\
    \\n\
    \ For example, the proto RPC and annotation:\n\
    \\n\
    \     rpc CreateSubscription(CreateSubscriptionRequest)\n\
    \         returns (Subscription) {\n\
    \       option (google.api.method_signature) = \"name,topic\";\n\
    \     }\n\
    \\n\
    \ Would add the following Java overload (in addition to the method accepting\n\
    \ the request object):\n\
    \\n\
    \     public final Subscription createSubscription(String name, String topic)\n\
    \\n\
    \ The following backwards-compatibility guidelines apply:\n\
    \\n\
    \   * Adding this annotation to an unannotated method is backwards\n\
    \     compatible.\n\
    \   * Adding this annotation to a method which already has existing\n\
    \     method signature annotations is backwards compatible if and only if\n\
    \     the new method signature annotation is last in the sequence.\n\
    \   * Modifying or removing an existing method signature annotation is\n\
    \     a breaking change.\n\
    \   * Re-ordering existing method signature annotations is a breaking\n\
    \     change.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\a\NUL\STX\DC2\ETX\FS\a$\n\
    \\n\
    \\n\
    \\ETX\a\NUL\EOT\DC2\ETX@\STX\n\
    \\n\
    \\n\
    \\n\
    \\ETX\a\NUL\ENQ\DC2\ETX@\v\DC1\n\
    \\n\
    \\n\
    \\ETX\a\NUL\SOH\DC2\ETX@\DC2\"\n\
    \\n\
    \\n\
    \\ETX\a\NUL\ETX\DC2\ETX@%)\n\
    \\t\n\
    \\SOH\a\DC2\EOTC\NULt\SOH\n\
    \\210\SOH\n\
    \\STX\a\SOH\DC2\ETXM\STX\GS\SUB\198\SOH The hostname for this service.\n\
    \ This should be specified with no prefix or protocol.\n\
    \\n\
    \ Example:\n\
    \\n\
    \     service Foo {\n\
    \       option (google.api.default_host) = \"foo.googleapi.com\";\n\
    \       ...\n\
    \     }\n\
    \\n\
    \\n\
    \\n\
    \\ETX\a\SOH\STX\DC2\ETXC\a%\n\
    \\n\
    \\n\
    \\ETX\a\SOH\ENQ\DC2\ETXM\STX\b\n\
    \\n\
    \\n\
    \\ETX\a\SOH\SOH\DC2\ETXM\t\NAK\n\
    \\n\
    \\n\
    \\ETX\a\SOH\ETX\DC2\ETXM\CAN\FS\n\
    \\217\ETX\n\
    \\STX\a\STX\DC2\ETXc\STX\GS\SUB\205\ETX OAuth scopes needed for the client.\n\
    \\n\
    \ Example:\n\
    \\n\
    \     service Foo {\n\
    \       option (google.api.oauth_scopes) = \\\n\
    \         \"https://www.googleapis.com/auth/cloud-platform\";\n\
    \       ...\n\
    \     }\n\
    \\n\
    \ If there is more than one scope, use a comma-separated string:\n\
    \\n\
    \ Example:\n\
    \\n\
    \     service Foo {\n\
    \       option (google.api.oauth_scopes) = \\\n\
    \         \"https://www.googleapis.com/auth/cloud-platform,\"\n\
    \         \"https://www.googleapis.com/auth/monitoring\";\n\
    \       ...\n\
    \     }\n\
    \\n\
    \\n\
    \\n\
    \\ETX\a\STX\STX\DC2\ETXC\a%\n\
    \\n\
    \\n\
    \\ETX\a\STX\ENQ\DC2\ETXc\STX\b\n\
    \\n\
    \\n\
    \\ETX\a\STX\SOH\DC2\ETXc\t\NAK\n\
    \\n\
    \\n\
    \\ETX\a\STX\ETX\DC2\ETXc\CAN\FS\n\
    \\163\ENQ\n\
    \\STX\a\ETX\DC2\ETXs\STX!\SUB\151\ENQ The API version of this service, which should be sent by version-aware\n\
    \ clients to the service. This allows services to abide by the schema and\n\
    \ behavior of the service at the time this API version was deployed.\n\
    \ The format of the API version must be treated as opaque by clients.\n\
    \ Services may use a format with an apparent structure, but clients must\n\
    \ not rely on this to determine components within an API version, or attempt\n\
    \ to construct other valid API versions. Note that this is for upcoming\n\
    \ functionality and may not be implemented for all services.\n\
    \\n\
    \ Example:\n\
    \\n\
    \     service Foo {\n\
    \       option (google.api.api_version) = \"v1_20230821_preview\";\n\
    \     }\n\
    \\n\
    \\n\
    \\n\
    \\ETX\a\ETX\STX\DC2\ETXC\a%\n\
    \\n\
    \\n\
    \\ETX\a\ETX\ENQ\DC2\ETXs\STX\b\n\
    \\n\
    \\n\
    \\ETX\a\ETX\SOH\DC2\ETXs\t\DC4\n\
    \\n\
    \\n\
    \\ETX\a\ETX\ETX\DC2\ETXs\ETB \n\
    \7\n\
    \\STX\EOT\NUL\DC2\ENQw\NUL\131\SOH\SOH\SUB* Required information for every language.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\EOT\NUL\SOH\DC2\ETXw\b\RS\n\
    \\143\SOH\n\
    \\EOT\EOT\NUL\STX\NUL\DC2\ETXz\STX4\SUB\129\SOH Link to automatically generated reference documentation.  Example:\n\
    \ https://cloud.google.com/nodejs/docs/reference/asset/latest\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ENQ\DC2\ETXz\STX\b\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\SOH\DC2\ETXz\t\ESC\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ETX\DC2\ETXz\RS\US\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\b\DC2\ETXz 3\n\
    \\r\n\
    \\ACK\EOT\NUL\STX\NUL\b\ETX\DC2\ETXz!2\n\
    \X\n\
    \\EOT\EOT\NUL\STX\SOH\DC2\ETX}\STX5\SUBK The destination where API teams want this client library to be published.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\EOT\DC2\ETX}\STX\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\ACK\DC2\ETX}\v#\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\SOH\DC2\ETX}$0\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\ETX\DC2\ETX}34\n\
    \\138\SOH\n\
    \\EOT\EOT\NUL\STX\STX\DC2\EOT\130\SOH\STX:\SUB| Configuration for which RPCs should be generated in the GAPIC client.\n\
    \\n\
    \ Note: This field should not be used in most cases.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\STX\ACK\DC2\EOT\130\SOH\STX\SUB\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\STX\SOH\DC2\EOT\130\SOH\ESC5\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\STX\ETX\DC2\EOT\130\SOH89\n\
    \H\n\
    \\STX\EOT\SOH\DC2\ACK\134\SOH\NUL\170\SOH\SOH\SUB: Details about how and where to publish client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\SOH\SOH\DC2\EOT\134\SOH\b\GS\n\
    \\218\SOH\n\
    \\EOT\EOT\SOH\STX\NUL\DC2\EOT\138\SOH\STX\NAK\SUB\203\SOH Version of the API to apply these settings to. This is the full protobuf\n\
    \ package for the API, ending in the version element.\n\
    \ Examples: \"google.cloud.speech.v1\" and \"google.spanner.admin.database.v1\".\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\NUL\ENQ\DC2\EOT\138\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\NUL\SOH\DC2\EOT\138\SOH\t\DLE\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\NUL\ETX\DC2\EOT\138\SOH\DC3\DC4\n\
    \8\n\
    \\EOT\EOT\SOH\STX\SOH\DC2\EOT\141\SOH\STX\US\SUB* Launch stage of this version of the API.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\SOH\ACK\DC2\EOT\141\SOH\STX\r\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\SOH\SOH\DC2\EOT\141\SOH\SO\SUB\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\SOH\ETX\DC2\EOT\141\SOH\GS\RS\n\
    \p\n\
    \\EOT\EOT\SOH\STX\STX\DC2\EOT\145\SOH\STX\RS\SUBb When using transport=rest, the client request will encode enums as\n\
    \ numbers rather than strings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\STX\ENQ\DC2\EOT\145\SOH\STX\ACK\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\STX\SOH\DC2\EOT\145\SOH\a\EM\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\STX\ETX\DC2\EOT\145\SOH\FS\GS\n\
    \Q\n\
    \\EOT\EOT\SOH\STX\ETX\DC2\EOT\148\SOH\STX\"\SUBC Settings for legacy Java features, supported in the Service YAML.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ETX\ACK\DC2\EOT\148\SOH\STX\SO\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ETX\SOH\DC2\EOT\148\SOH\SI\FS\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ETX\ETX\DC2\EOT\148\SOH\US!\n\
    \2\n\
    \\EOT\EOT\SOH\STX\EOT\DC2\EOT\151\SOH\STX \SUB$ Settings for C++ client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\EOT\ACK\DC2\EOT\151\SOH\STX\r\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\EOT\SOH\DC2\EOT\151\SOH\SO\SUB\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\EOT\ETX\DC2\EOT\151\SOH\GS\US\n\
    \2\n\
    \\EOT\EOT\SOH\STX\ENQ\DC2\EOT\154\SOH\STX \SUB$ Settings for PHP client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ENQ\ACK\DC2\EOT\154\SOH\STX\r\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ENQ\SOH\DC2\EOT\154\SOH\SO\SUB\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ENQ\ETX\DC2\EOT\154\SOH\GS\US\n\
    \5\n\
    \\EOT\EOT\SOH\STX\ACK\DC2\EOT\157\SOH\STX&\SUB' Settings for Python client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ACK\ACK\DC2\EOT\157\SOH\STX\DLE\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ACK\SOH\DC2\EOT\157\SOH\DC1 \n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\ACK\ETX\DC2\EOT\157\SOH#%\n\
    \3\n\
    \\EOT\EOT\SOH\STX\a\DC2\EOT\160\SOH\STX\"\SUB% Settings for Node client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\a\ACK\DC2\EOT\160\SOH\STX\SO\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\a\SOH\DC2\EOT\160\SOH\SI\FS\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\a\ETX\DC2\EOT\160\SOH\US!\n\
    \3\n\
    \\EOT\EOT\SOH\STX\b\DC2\EOT\163\SOH\STX&\SUB% Settings for .NET client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\b\ACK\DC2\EOT\163\SOH\STX\DLE\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\b\SOH\DC2\EOT\163\SOH\DC1 \n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\b\ETX\DC2\EOT\163\SOH#%\n\
    \3\n\
    \\EOT\EOT\SOH\STX\t\DC2\EOT\166\SOH\STX\"\SUB% Settings for Ruby client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\t\ACK\DC2\EOT\166\SOH\STX\SO\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\t\SOH\DC2\EOT\166\SOH\SI\FS\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\t\ETX\DC2\EOT\166\SOH\US!\n\
    \1\n\
    \\EOT\EOT\SOH\STX\n\
    \\DC2\EOT\169\SOH\STX\RS\SUB# Settings for Go client libraries.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\n\
    \\ACK\DC2\EOT\169\SOH\STX\f\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\n\
    \\SOH\DC2\EOT\169\SOH\r\CAN\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\n\
    \\ETX\DC2\EOT\169\SOH\ESC\GS\n\
    \\196\SOH\n\
    \\STX\EOT\STX\DC2\ACK\175\SOH\NUL\219\SOH\SOH\SUB\181\SOH This message configures the settings for publishing [Google Cloud Client\n\
    \ libraries](https://cloud.google.com/apis/docs/cloud-client-libraries)\n\
    \ generated from the service config.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\STX\SOH\DC2\EOT\175\SOH\b\DC2\n\
    \z\n\
    \\EOT\EOT\STX\STX\NUL\DC2\EOT\178\SOH\STX.\SUBl A list of API method settings, e.g. the behavior for methods that use the\n\
    \ long-running operation pattern.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\EOT\DC2\EOT\178\SOH\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\ACK\DC2\EOT\178\SOH\v\EM\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\SOH\DC2\EOT\178\SOH\SUB)\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\ETX\DC2\EOT\178\SOH,-\n\
    \\158\SOH\n\
    \\EOT\EOT\STX\STX\SOH\DC2\EOT\182\SOH\STX\GS\SUB\143\SOH Link to a *public* URI where users can report issues.  Example:\n\
    \ https://issuetracker.google.com/issues/new?component=190865&template=1161103\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\ENQ\DC2\EOT\182\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\SOH\DC2\EOT\182\SOH\t\SYN\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\ETX\DC2\EOT\182\SOH\EM\FS\n\
    \l\n\
    \\EOT\EOT\STX\STX\STX\DC2\EOT\186\SOH\STX!\SUB^ Link to product home page.  Example:\n\
    \ https://cloud.google.com/asset-inventory/docs/overview\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\ENQ\DC2\EOT\186\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\SOH\DC2\EOT\186\SOH\t\SUB\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\ETX\DC2\EOT\186\SOH\GS \n\
    \\183\SOH\n\
    \\EOT\EOT\STX\STX\ETX\DC2\EOT\191\SOH\STX\RS\SUB\168\SOH Used as a tracking tag when collecting data about the APIs developer\n\
    \ relations artifacts like docs, packages delivered to package managers,\n\
    \ etc.  Example: \"speech\".\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\ENQ\DC2\EOT\191\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\SOH\DC2\EOT\191\SOH\t\ETB\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\ETX\DC2\EOT\191\SOH\SUB\GS\n\
    \V\n\
    \\EOT\EOT\STX\STX\EOT\DC2\EOT\194\SOH\STX\FS\SUBH GitHub label to apply to issues and pull requests opened for this API.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\EOT\ENQ\DC2\EOT\194\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\EOT\SOH\DC2\EOT\194\SOH\t\NAK\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\EOT\ETX\DC2\EOT\194\SOH\CAN\ESC\n\
    \\145\SOH\n\
    \\EOT\EOT\STX\STX\ENQ\DC2\EOT\198\SOH\STX/\SUB\130\SOH GitHub teams to be added to CODEOWNERS in the directory in GitHub\n\
    \ containing source code for the client libraries for this API.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ENQ\EOT\DC2\EOT\198\SOH\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ENQ\ENQ\DC2\EOT\198\SOH\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ENQ\SOH\DC2\EOT\198\SOH\DC2(\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ENQ\ETX\DC2\EOT\198\SOH+.\n\
    \e\n\
    \\EOT\EOT\STX\STX\ACK\DC2\EOT\202\SOH\STX\RS\SUBW A prefix used in sample code when demarking regions to be included in\n\
    \ documentation.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ACK\ENQ\DC2\EOT\202\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ACK\SOH\DC2\EOT\202\SOH\t\ETB\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ACK\ETX\DC2\EOT\202\SOH\SUB\GS\n\
    \?\n\
    \\EOT\EOT\STX\STX\a\DC2\EOT\205\SOH\STX/\SUB1 For whom the client library is being published.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\a\ACK\DC2\EOT\205\SOH\STX\ESC\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\a\SOH\DC2\EOT\205\SOH\FS(\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\a\ETX\DC2\EOT\205\SOH+.\n\
    \\208\SOH\n\
    \\EOT\EOT\STX\STX\b\DC2\EOT\210\SOH\STX8\SUB\193\SOH Client library settings.  If the same version string appears multiple\n\
    \ times in this list, then the last one wins.  Settings from earlier\n\
    \ settings with the same version string are discarded.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\b\EOT\DC2\EOT\210\SOH\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\b\ACK\DC2\EOT\210\SOH\v \n\
    \\r\n\
    \\ENQ\EOT\STX\STX\b\SOH\DC2\EOT\210\SOH!1\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\b\ETX\DC2\EOT\210\SOH47\n\
    \\130\SOH\n\
    \\EOT\EOT\STX\STX\t\DC2\EOT\214\SOH\STX1\SUBt Optional link to proto reference documentation.  Example:\n\
    \ https://cloud.google.com/pubsub/lite/docs/reference/rpc\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\t\ENQ\DC2\EOT\214\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\t\SOH\DC2\EOT\214\SOH\t*\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\t\ETX\DC2\EOT\214\SOH-0\n\
    \\130\SOH\n\
    \\EOT\EOT\STX\STX\n\
    \\DC2\EOT\218\SOH\STX0\SUBt Optional link to REST reference documentation.  Example:\n\
    \ https://cloud.google.com/pubsub/lite/docs/reference/rest\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\n\
    \\ENQ\DC2\EOT\218\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\n\
    \\SOH\DC2\EOT\218\SOH\t)\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\n\
    \\ETX\DC2\EOT\218\SOH,/\n\
    \3\n\
    \\STX\EOT\ETX\DC2\ACK\222\SOH\NUL\255\SOH\SOH\SUB% Settings for Java client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ETX\SOH\DC2\EOT\222\SOH\b\DC4\n\
    \\199\ETX\n\
    \\EOT\EOT\ETX\STX\NUL\DC2\EOT\235\SOH\STX\GS\SUB\184\ETX The package name to use in Java. Clobbers the java_package option\n\
    \ set in the protobuf. This should be used **only** by APIs\n\
    \ who have already set the language_settings.java.package_name\" field\n\
    \ in gapic.yaml. API teams should use the protobuf java_package option\n\
    \ where possible.\n\
    \\n\
    \ Example of a YAML configuration::\n\
    \\n\
    \     publishing:\n\
    \       library_settings:\n\
    \         java_settings:\n\
    \           library_package: com.google.cloud.pubsub.v1\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\ENQ\DC2\EOT\235\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\SOH\DC2\EOT\235\SOH\t\CAN\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\ETX\DC2\EOT\235\SOH\ESC\FS\n\
    \\197\EOT\n\
    \\EOT\EOT\ETX\STX\SOH\DC2\EOT\251\SOH\STX.\SUB\182\EOT Configure the Java class name to use instead of the service's for its\n\
    \ corresponding generated GAPIC client. Keys are fully-qualified\n\
    \ service names as they appear in the protobuf (including the full\n\
    \ the language_settings.java.interface_names\" field in gapic.yaml. API\n\
    \ teams should otherwise use the service name as it appears in the\n\
    \ protobuf.\n\
    \\n\
    \ Example of a YAML configuration::\n\
    \\n\
    \     publishing:\n\
    \       java_settings:\n\
    \         service_class_names:\n\
    \           - google.pubsub.v1.Publisher: TopicAdmin\n\
    \           - google.pubsub.v1.Subscriber: SubscriptionAdmin\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\SOH\ACK\DC2\EOT\251\SOH\STX\NAK\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\SOH\SOH\DC2\EOT\251\SOH\SYN)\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\SOH\ETX\DC2\EOT\251\SOH,-\n\
    \\RS\n\
    \\EOT\EOT\ETX\STX\STX\DC2\EOT\254\SOH\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\ACK\DC2\EOT\254\SOH\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\SOH\DC2\EOT\254\SOH\EM\US\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\ETX\DC2\EOT\254\SOH\"#\n\
    \2\n\
    \\STX\EOT\EOT\DC2\ACK\130\STX\NUL\133\STX\SOH\SUB$ Settings for C++ client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\EOT\SOH\DC2\EOT\130\STX\b\DC3\n\
    \\RS\n\
    \\EOT\EOT\EOT\STX\NUL\DC2\EOT\132\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\ACK\DC2\EOT\132\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\SOH\DC2\EOT\132\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\ETX\DC2\EOT\132\STX\"#\n\
    \2\n\
    \\STX\EOT\ENQ\DC2\ACK\136\STX\NUL\153\STX\SOH\SUB$ Settings for Php client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ENQ\SOH\DC2\EOT\136\STX\b\DC3\n\
    \\RS\n\
    \\EOT\EOT\ENQ\STX\NUL\DC2\EOT\138\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\ACK\DC2\EOT\138\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\SOH\DC2\EOT\138\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\ETX\DC2\EOT\138\STX\"#\n\
    \\194\ETX\n\
    \\EOT\EOT\ENQ\STX\SOH\DC2\EOT\152\STX\STX\GS\SUB\179\ETX The package name to use in Php. Clobbers the php_namespace option\n\
    \ set in the protobuf. This should be used **only** by APIs\n\
    \ who have already set the language_settings.php.package_name\" field\n\
    \ in gapic.yaml. API teams should use the protobuf php_namespace option\n\
    \ where possible.\n\
    \\n\
    \ Example of a YAML configuration::\n\
    \\n\
    \     publishing:\n\
    \       library_settings:\n\
    \         php_settings:\n\
    \           library_package: Google\\Cloud\\PubSub\\V1\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\SOH\ENQ\DC2\EOT\152\STX\STX\b\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\SOH\SOH\DC2\EOT\152\STX\t\CAN\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\SOH\ETX\DC2\EOT\152\STX\ESC\FS\n\
    \5\n\
    \\STX\EOT\ACK\DC2\ACK\156\STX\NUL\185\STX\SOH\SUB' Settings for Python client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ACK\SOH\DC2\EOT\156\STX\b\SYN\n\
    \\177\SOH\n\
    \\EOT\EOT\ACK\ETX\NUL\DC2\ACK\160\STX\STX\178\STX\ETX\SUB\160\SOH Experimental features to be included during client library generation.\n\
    \ These fields will be deprecated once the feature graduates and is enabled\n\
    \ by default.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ACK\ETX\NUL\SOH\DC2\EOT\160\STX\n\
    \\RS\n\
    \\131\STX\n\
    \\ACK\EOT\ACK\ETX\NUL\STX\NUL\DC2\EOT\165\STX\EOT#\SUB\242\SOH Enables generation of asynchronous REST clients if `rest` transport is\n\
    \ enabled. By default, asynchronous REST clients will not be generated.\n\
    \ This feature will be enabled by default 1 month after launching the\n\
    \ feature in preview packages.\n\
    \\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\NUL\ENQ\DC2\EOT\165\STX\EOT\b\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\NUL\SOH\DC2\EOT\165\STX\t\RS\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\NUL\ETX\DC2\EOT\165\STX!\"\n\
    \\235\SOH\n\
    \\ACK\EOT\ACK\ETX\NUL\STX\SOH\DC2\EOT\171\STX\EOT-\SUB\218\SOH Enables generation of protobuf code using new types that are more\n\
    \ Pythonic which are included in `protobuf>=5.29.x`. This feature will be\n\
    \ enabled by default 1 month after launching the feature in preview\n\
    \ packages.\n\
    \\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\SOH\ENQ\DC2\EOT\171\STX\EOT\b\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\SOH\SOH\DC2\EOT\171\STX\t(\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\SOH\ETX\DC2\EOT\171\STX+,\n\
    \\139\STX\n\
    \\ACK\EOT\ACK\ETX\NUL\STX\STX\DC2\EOT\177\STX\EOT*\SUB\250\SOH Disables generation of an unversioned Python package for this client\n\
    \ library. This means that the module names will need to be versioned in\n\
    \ import statements. For example `import google.cloud.library_v2` instead\n\
    \ of `import google.cloud.library`.\n\
    \\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\STX\ENQ\DC2\EOT\177\STX\EOT\b\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\STX\SOH\DC2\EOT\177\STX\t%\n\
    \\SI\n\
    \\a\EOT\ACK\ETX\NUL\STX\STX\ETX\DC2\EOT\177\STX()\n\
    \\RS\n\
    \\EOT\EOT\ACK\STX\NUL\DC2\EOT\181\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\NUL\ACK\DC2\EOT\181\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\NUL\SOH\DC2\EOT\181\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\NUL\ETX\DC2\EOT\181\STX\"#\n\
    \V\n\
    \\EOT\EOT\ACK\STX\SOH\DC2\EOT\184\STX\STX1\SUBH Experimental features to be included during client library generation.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\SOH\ACK\DC2\EOT\184\STX\STX\SYN\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\SOH\SOH\DC2\EOT\184\STX\ETB,\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\SOH\ETX\DC2\EOT\184\STX/0\n\
    \3\n\
    \\STX\EOT\a\DC2\ACK\188\STX\NUL\191\STX\SOH\SUB% Settings for Node client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\a\SOH\DC2\EOT\188\STX\b\DC4\n\
    \\RS\n\
    \\EOT\EOT\a\STX\NUL\DC2\EOT\190\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\a\STX\NUL\ACK\DC2\EOT\190\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\a\STX\NUL\SOH\DC2\EOT\190\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\a\STX\NUL\ETX\DC2\EOT\190\STX\"#\n\
    \5\n\
    \\STX\EOT\b\DC2\ACK\194\STX\NUL\227\STX\SOH\SUB' Settings for Dotnet client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\b\SOH\DC2\EOT\194\STX\b\SYN\n\
    \\RS\n\
    \\EOT\EOT\b\STX\NUL\DC2\EOT\196\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\NUL\ACK\DC2\EOT\196\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\b\STX\NUL\SOH\DC2\EOT\196\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\b\STX\NUL\ETX\DC2\EOT\196\STX\"#\n\
    \\230\SOH\n\
    \\EOT\EOT\b\STX\SOH\DC2\EOT\203\STX\STX+\SUB\215\SOH Map from original service names to renamed versions.\n\
    \ This is used when the default generated types\n\
    \ would cause a naming conflict. (Neither name is\n\
    \ fully-qualified.)\n\
    \ Example: Subscriber to SubscriberServiceApi.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\SOH\ACK\DC2\EOT\203\STX\STX\NAK\n\
    \\r\n\
    \\ENQ\EOT\b\STX\SOH\SOH\DC2\EOT\203\STX\SYN&\n\
    \\r\n\
    \\ENQ\EOT\b\STX\SOH\ETX\DC2\EOT\203\STX)*\n\
    \\141\STX\n\
    \\EOT\EOT\b\STX\STX\DC2\EOT\210\STX\STX,\SUB\254\SOH Map from full resource types to the effective short name\n\
    \ for the resource. This is used when otherwise resource\n\
    \ named from different services would cause naming collisions.\n\
    \ Example entry:\n\
    \ \"datalabeling.googleapis.com/Dataset\": \"DataLabelingDataset\"\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\STX\ACK\DC2\EOT\210\STX\STX\NAK\n\
    \\r\n\
    \\ENQ\EOT\b\STX\STX\SOH\DC2\EOT\210\STX\SYN'\n\
    \\r\n\
    \\ENQ\EOT\b\STX\STX\ETX\DC2\EOT\210\STX*+\n\
    \\158\STX\n\
    \\EOT\EOT\b\STX\ETX\DC2\EOT\217\STX\STX(\SUB\143\STX List of full resource types to ignore during generation.\n\
    \ This is typically used for API-specific Location resources,\n\
    \ which should be handled by the generator as if they were actually\n\
    \ the common Location resources.\n\
    \ Example entry: \"documentai.googleapis.com/Location\"\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ETX\EOT\DC2\EOT\217\STX\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ETX\ENQ\DC2\EOT\217\STX\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ETX\SOH\DC2\EOT\217\STX\DC2#\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ETX\ETX\DC2\EOT\217\STX&'\n\
    \}\n\
    \\EOT\EOT\b\STX\EOT\DC2\EOT\221\STX\STX/\SUBo Namespaces which must be aliased in snippets due to\n\
    \ a known (but non-generator-predictable) naming collision\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\EOT\EOT\DC2\EOT\221\STX\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\EOT\ENQ\DC2\EOT\221\STX\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\b\STX\EOT\SOH\DC2\EOT\221\STX\DC2*\n\
    \\r\n\
    \\ENQ\EOT\b\STX\EOT\ETX\DC2\EOT\221\STX-.\n\
    \\199\SOH\n\
    \\EOT\EOT\b\STX\ENQ\DC2\EOT\226\STX\STX-\SUB\184\SOH Method signatures (in the form \"service.method(signature)\")\n\
    \ which are provided separately, so shouldn't be generated.\n\
    \ Snippets *calling* these methods are still generated, however.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ENQ\EOT\DC2\EOT\226\STX\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ENQ\ENQ\DC2\EOT\226\STX\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ENQ\SOH\DC2\EOT\226\STX\DC2(\n\
    \\r\n\
    \\ENQ\EOT\b\STX\ENQ\ETX\DC2\EOT\226\STX+,\n\
    \3\n\
    \\STX\EOT\t\DC2\ACK\230\STX\NUL\233\STX\SOH\SUB% Settings for Ruby client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\t\SOH\DC2\EOT\230\STX\b\DC4\n\
    \\RS\n\
    \\EOT\EOT\t\STX\NUL\DC2\EOT\232\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\t\STX\NUL\ACK\DC2\EOT\232\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\t\STX\NUL\SOH\DC2\EOT\232\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\t\STX\NUL\ETX\DC2\EOT\232\STX\"#\n\
    \1\n\
    \\STX\EOT\n\
    \\DC2\ACK\236\STX\NUL\251\STX\SOH\SUB# Settings for Go client libraries.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\n\
    \\SOH\DC2\EOT\236\STX\b\DC2\n\
    \\RS\n\
    \\EOT\EOT\n\
    \\STX\NUL\DC2\EOT\238\STX\STX$\SUB\DLE Some settings.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\n\
    \\STX\NUL\ACK\DC2\EOT\238\STX\STX\CAN\n\
    \\r\n\
    \\ENQ\EOT\n\
    \\STX\NUL\SOH\DC2\EOT\238\STX\EM\US\n\
    \\r\n\
    \\ENQ\EOT\n\
    \\STX\NUL\ETX\DC2\EOT\238\STX\"#\n\
    \\161\STX\n\
    \\EOT\EOT\n\
    \\STX\SOH\DC2\EOT\250\STX\STX+\SUB\146\STX Map of service names to renamed services. Keys are the package relative\n\
    \ service names and values are the name to be used for the service client\n\
    \ and call options.\n\
    \\n\
    \ Example:\n\
    \\n\
    \     publishing:\n\
    \       go_settings:\n\
    \         renamed_services:\n\
    \           Publisher: TopicAdmin\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\n\
    \\STX\SOH\ACK\DC2\EOT\250\STX\STX\NAK\n\
    \\r\n\
    \\ENQ\EOT\n\
    \\STX\SOH\SOH\DC2\EOT\250\STX\SYN&\n\
    \\r\n\
    \\ENQ\EOT\n\
    \\STX\SOH\ETX\DC2\EOT\250\STX)*\n\
    \C\n\
    \\STX\EOT\v\DC2\ACK\254\STX\NUL\203\ETX\SOH\SUB5 Describes the generator configuration for a method.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\v\SOH\DC2\EOT\254\STX\b\SYN\n\
    \\144\ETX\n\
    \\EOT\EOT\v\ETX\NUL\DC2\ACK\132\ETX\STX\149\ETX\ETX\SUB\255\STX Describes settings to use when generating API methods that use the\n\
    \ long-running operation pattern.\n\
    \ All default values below are from those used in the client library\n\
    \ generators (e.g.\n\
    \ [Java](https://github.com/googleapis/gapic-generator-java/blob/04c2faa191a9b5a10b92392fe8482279c4404803/src/main/java/com/google/api/generator/gapic/composer/common/RetrySettingsComposer.java)).\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\v\ETX\NUL\SOH\DC2\EOT\132\ETX\n\
    \\NAK\n\
    \k\n\
    \\ACK\EOT\v\ETX\NUL\STX\NUL\DC2\EOT\135\ETX\EOT4\SUB[ Initial delay after which the first poll request will be made.\n\
    \ Default value: 5 seconds.\n\
    \\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\NUL\ACK\DC2\EOT\135\ETX\EOT\FS\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\NUL\SOH\DC2\EOT\135\ETX\GS/\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\NUL\ETX\DC2\EOT\135\ETX23\n\
    \\136\SOH\n\
    \\ACK\EOT\v\ETX\NUL\STX\SOH\DC2\EOT\140\ETX\EOT$\SUBx Multiplier to gradually increase delay between subsequent polls until it\n\
    \ reaches max_poll_delay.\n\
    \ Default value: 1.5.\n\
    \\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\SOH\ENQ\DC2\EOT\140\ETX\EOT\t\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\SOH\SOH\DC2\EOT\140\ETX\n\
    \\US\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\SOH\ETX\DC2\EOT\140\ETX\"#\n\
    \`\n\
    \\ACK\EOT\v\ETX\NUL\STX\STX\DC2\EOT\144\ETX\EOT0\SUBP Maximum time between two subsequent poll requests.\n\
    \ Default value: 45 seconds.\n\
    \\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\STX\ACK\DC2\EOT\144\ETX\EOT\FS\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\STX\SOH\DC2\EOT\144\ETX\GS+\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\STX\ETX\DC2\EOT\144\ETX./\n\
    \C\n\
    \\ACK\EOT\v\ETX\NUL\STX\ETX\DC2\EOT\148\ETX\EOT4\SUB3 Total polling timeout.\n\
    \ Default value: 5 minutes.\n\
    \\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\ETX\ACK\DC2\EOT\148\ETX\EOT\FS\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\ETX\SOH\DC2\EOT\148\ETX\GS/\n\
    \\SI\n\
    \\a\EOT\v\ETX\NUL\STX\ETX\ETX\DC2\EOT\148\ETX23\n\
    \\191\STX\n\
    \\EOT\EOT\v\STX\NUL\DC2\EOT\160\ETX\STX\SYN\SUB\176\STX The fully qualified name of the method, for which the options below apply.\n\
    \ This is used to find the method to apply the options.\n\
    \\n\
    \ Example:\n\
    \\n\
    \     publishing:\n\
    \       method_settings:\n\
    \       - selector: google.storage.control.v2.StorageControl.CreateFolder\n\
    \         # method settings for CreateFolder...\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\v\STX\NUL\ENQ\DC2\EOT\160\ETX\STX\b\n\
    \\r\n\
    \\ENQ\EOT\v\STX\NUL\SOH\DC2\EOT\160\ETX\t\DC1\n\
    \\r\n\
    \\ENQ\EOT\v\STX\NUL\ETX\DC2\EOT\160\ETX\DC4\NAK\n\
    \\152\EOT\n\
    \\EOT\EOT\v\STX\SOH\DC2\EOT\176\ETX\STX\US\SUB\137\EOT Describes settings to use for long-running operations when generating\n\
    \ API methods for RPCs. Complements RPCs that use the annotations in\n\
    \ google/longrunning/operations.proto.\n\
    \\n\
    \ Example of a YAML configuration::\n\
    \\n\
    \     publishing:\n\
    \       method_settings:\n\
    \       - selector: google.cloud.speech.v2.Speech.BatchRecognize\n\
    \         long_running:\n\
    \           initial_poll_delay: 60s # 1 minute\n\
    \           poll_delay_multiplier: 1.5\n\
    \           max_poll_delay: 360s # 6 minutes\n\
    \           total_poll_timeout: 54000s # 90 minutes\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\v\STX\SOH\ACK\DC2\EOT\176\ETX\STX\r\n\
    \\r\n\
    \\ENQ\EOT\v\STX\SOH\SOH\DC2\EOT\176\ETX\SO\SUB\n\
    \\r\n\
    \\ENQ\EOT\v\STX\SOH\ETX\DC2\EOT\176\ETX\GS\RS\n\
    \\153\ETX\n\
    \\EOT\EOT\v\STX\STX\DC2\EOT\189\ETX\STX,\SUB\138\ETX List of top-level fields of the request message, that should be\n\
    \ automatically populated by the client libraries based on their\n\
    \ (google.api.field_info).format. Currently supported format: UUID4.\n\
    \\n\
    \ Example of a YAML configuration:\n\
    \\n\
    \     publishing:\n\
    \       method_settings:\n\
    \       - selector: google.example.v1.ExampleService.CreateExample\n\
    \         auto_populated_fields:\n\
    \         - request_id\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\v\STX\STX\EOT\DC2\EOT\189\ETX\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\v\STX\STX\ENQ\DC2\EOT\189\ETX\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\v\STX\STX\SOH\DC2\EOT\189\ETX\DC2'\n\
    \\r\n\
    \\ENQ\EOT\v\STX\STX\ETX\DC2\EOT\189\ETX*+\n\
    \\241\STX\n\
    \\EOT\EOT\v\STX\ETX\DC2\EOT\202\ETX\STX#\SUB\226\STX Batching configuration for an API method in client libraries.\n\
    \\n\
    \ Example of a YAML configuration:\n\
    \\n\
    \     publishing:\n\
    \       method_settings:\n\
    \       - selector: google.example.v1.ExampleService.BatchCreateExample\n\
    \         batching:\n\
    \           element_count_threshold: 1000\n\
    \           request_byte_threshold: 100000000\n\
    \           delay_threshold_millis: 10\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\v\STX\ETX\ACK\DC2\EOT\202\ETX\STX\NAK\n\
    \\r\n\
    \\ENQ\EOT\v\STX\ETX\SOH\DC2\EOT\202\ETX\SYN\RS\n\
    \\r\n\
    \\ENQ\EOT\v\STX\ETX\ETX\DC2\EOT\202\ETX!\"\n\
    \\143\SOH\n\
    \\STX\ENQ\NUL\DC2\ACK\207\ETX\NUL\231\ETX\SOH\SUB\128\SOH The organization for which the client libraries are being published.\n\
    \ Affects the url where generated docs are published, etc.\n\
    \\n\
    \\v\n\
    \\ETX\ENQ\NUL\SOH\DC2\EOT\207\ETX\ENQ\RS\n\
    \\ESC\n\
    \\EOT\ENQ\NUL\STX\NUL\DC2\EOT\209\ETX\STX.\SUB\r Not useful.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\NUL\SOH\DC2\EOT\209\ETX\STX)\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\NUL\STX\DC2\EOT\209\ETX,-\n\
    \*\n\
    \\EOT\ENQ\NUL\STX\SOH\DC2\EOT\212\ETX\STX\f\SUB\FS Google Cloud Platform Org.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\SOH\SOH\DC2\EOT\212\ETX\STX\a\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\SOH\STX\DC2\EOT\212\ETX\n\
    \\v\n\
    \&\n\
    \\EOT\ENQ\NUL\STX\STX\DC2\EOT\215\ETX\STX\n\
    \\SUB\CAN Ads (Advertising) Org.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\STX\SOH\DC2\EOT\215\ETX\STX\ENQ\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\STX\STX\DC2\EOT\215\ETX\b\t\n\
    \\ESC\n\
    \\EOT\ENQ\NUL\STX\ETX\DC2\EOT\218\ETX\STX\r\SUB\r Photos Org.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\ETX\SOH\DC2\EOT\218\ETX\STX\b\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\ETX\STX\DC2\EOT\218\ETX\v\f\n\
    \ \n\
    \\EOT\ENQ\NUL\STX\EOT\DC2\EOT\221\ETX\STX\DC2\SUB\DC2 Street View Org.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\EOT\SOH\DC2\EOT\221\ETX\STX\r\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\EOT\STX\DC2\EOT\221\ETX\DLE\DC1\n\
    \\GS\n\
    \\EOT\ENQ\NUL\STX\ENQ\DC2\EOT\224\ETX\STX\SI\SUB\SI Shopping Org.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\ENQ\SOH\DC2\EOT\224\ETX\STX\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\ENQ\STX\DC2\EOT\224\ETX\r\SO\n\
    \\CAN\n\
    \\EOT\ENQ\NUL\STX\ACK\DC2\EOT\227\ETX\STX\n\
    \\SUB\n\
    \ Geo Org.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\ACK\SOH\DC2\EOT\227\ETX\STX\ENQ\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\ACK\STX\DC2\EOT\227\ETX\b\t\n\
    \F\n\
    \\EOT\ENQ\NUL\STX\a\DC2\EOT\230\ETX\STX\DC4\SUB8 Generative AI - https://developers.generativeai.google\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\a\SOH\DC2\EOT\230\ETX\STX\SI\n\
    \\r\n\
    \\ENQ\ENQ\NUL\STX\a\STX\DC2\EOT\230\ETX\DC2\DC3\n\
    \>\n\
    \\STX\ENQ\SOH\DC2\ACK\234\ETX\NUL\245\ETX\SOH\SUB0 To where should client libraries be published?\n\
    \\n\
    \\v\n\
    \\ETX\ENQ\SOH\SOH\DC2\EOT\234\ETX\ENQ\GS\n\
    \^\n\
    \\EOT\ENQ\SOH\STX\NUL\DC2\EOT\237\ETX\STX-\SUBP Client libraries will neither be generated nor published to package\n\
    \ managers.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\SOH\STX\NUL\SOH\DC2\EOT\237\ETX\STX(\n\
    \\r\n\
    \\ENQ\ENQ\SOH\STX\NUL\STX\DC2\EOT\237\ETX+,\n\
    \}\n\
    \\EOT\ENQ\SOH\STX\SOH\DC2\EOT\241\ETX\STX\SO\SUBo Generate the client library in a repo under github.com/googleapis,\n\
    \ but don't publish it to package managers.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\SOH\STX\SOH\SOH\DC2\EOT\241\ETX\STX\b\n\
    \\r\n\
    \\ENQ\ENQ\SOH\STX\SOH\STX\DC2\EOT\241\ETX\v\r\n\
    \U\n\
    \\EOT\ENQ\SOH\STX\STX\DC2\EOT\244\ETX\STX\ETB\SUBG Publish the library to package managers like nuget.org and npmjs.com.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\SOH\STX\STX\SOH\DC2\EOT\244\ETX\STX\DC1\n\
    \\r\n\
    \\ENQ\ENQ\SOH\STX\STX\STX\DC2\EOT\244\ETX\DC4\SYN\n\
    \\180\SOH\n\
    \\STX\EOT\f\DC2\ACK\251\ETX\NUL\135\EOT\SOH\SUB\165\SOH This message is used to configure the generation of a subset of the RPCs in\n\
    \ a service for client libraries.\n\
    \\n\
    \ Note: This feature should not be used in most cases.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\f\SOH\DC2\EOT\251\ETX\b \n\
    \u\n\
    \\EOT\EOT\f\STX\NUL\DC2\EOT\254\ETX\STX\RS\SUBg An allowlist of the fully qualified names of RPCs that should be included\n\
    \ on public client surfaces.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\f\STX\NUL\EOT\DC2\EOT\254\ETX\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\f\STX\NUL\ENQ\DC2\EOT\254\ETX\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\f\STX\NUL\SOH\DC2\EOT\254\ETX\DC2\EM\n\
    \\r\n\
    \\ENQ\EOT\f\STX\NUL\ETX\DC2\EOT\254\ETX\FS\GS\n\
    \\161\ETX\n\
    \\EOT\EOT\f\STX\SOH\DC2\EOT\134\EOT\STX(\SUB\146\ETX Setting this to true indicates to the client generators that methods\n\
    \ that would be excluded from the generation should instead be generated\n\
    \ in a way that indicates these methods should not be consumed by\n\
    \ end users. How this is expressed is up to individual language\n\
    \ implementations to decide. Some examples may be: added annotations,\n\
    \ obfuscated identifiers, or other language idiomatic patterns.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\f\STX\SOH\ENQ\DC2\EOT\134\EOT\STX\ACK\n\
    \\r\n\
    \\ENQ\EOT\f\STX\SOH\SOH\DC2\EOT\134\EOT\a#\n\
    \\r\n\
    \\ENQ\EOT\f\STX\SOH\ETX\DC2\EOT\134\EOT&'\n\
    \[\n\
    \\STX\EOT\r\DC2\ACK\138\EOT\NUL\144\EOT\SOH\SUBM `BatchingConfigProto` defines the batching configuration for an API method.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\r\SOH\DC2\EOT\138\EOT\b\ESC\n\
    \J\n\
    \\EOT\EOT\r\STX\NUL\DC2\EOT\140\EOT\STX'\SUB< The thresholds which trigger a batched request to be sent.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\r\STX\NUL\ACK\DC2\EOT\140\EOT\STX\ETB\n\
    \\r\n\
    \\ENQ\EOT\r\STX\NUL\SOH\DC2\EOT\140\EOT\CAN\"\n\
    \\r\n\
    \\ENQ\EOT\r\STX\NUL\ETX\DC2\EOT\140\EOT%&\n\
    \A\n\
    \\EOT\EOT\r\STX\SOH\DC2\EOT\143\EOT\STX/\SUB3 The request and response fields used in batching.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\r\STX\SOH\ACK\DC2\EOT\143\EOT\STX\EM\n\
    \\r\n\
    \\ENQ\EOT\r\STX\SOH\SOH\DC2\EOT\143\EOT\SUB*\n\
    \\r\n\
    \\ENQ\EOT\r\STX\SOH\ETX\DC2\EOT\143\EOT-.\n\
    \\205\SOH\n\
    \\STX\EOT\SO\DC2\ACK\149\EOT\NUL\179\EOT\SOH\SUB\190\SOH `BatchingSettingsProto` specifies a set of batching thresholds, each of\n\
    \ which acts as a trigger to send a batch of messages as a request. At least\n\
    \ one threshold must be positive nonzero.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\SO\SOH\DC2\EOT\149\EOT\b\GS\n\
    \z\n\
    \\EOT\EOT\SO\STX\NUL\DC2\EOT\152\EOT\STX$\SUBl The number of elements of a field collected into a batch which, if\n\
    \ exceeded, causes the batch to be sent.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\NUL\ENQ\DC2\EOT\152\EOT\STX\a\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\NUL\SOH\DC2\EOT\152\EOT\b\US\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\NUL\ETX\DC2\EOT\152\EOT\"#\n\
    \\226\SOH\n\
    \\EOT\EOT\SO\STX\SOH\DC2\EOT\157\EOT\STX#\SUB\211\SOH The aggregated size of the batched field which, if exceeded, causes the\n\
    \ batch to be sent. This size is computed by aggregating the sizes of the\n\
    \ request field to be batched, not of the entire request message.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\SOH\ENQ\DC2\EOT\157\EOT\STX\a\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\SOH\SOH\DC2\EOT\157\EOT\b\RS\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\SOH\ETX\DC2\EOT\157\EOT!\"\n\
    \\128\SOH\n\
    \\EOT\EOT\SO\STX\STX\DC2\EOT\161\EOT\STX/\SUBr The duration after which a batch should be sent, starting from the addition\n\
    \ of the first message to that batch.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\STX\ACK\DC2\EOT\161\EOT\STX\SUB\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\STX\SOH\DC2\EOT\161\EOT\ESC*\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\STX\ETX\DC2\EOT\161\EOT-.\n\
    \f\n\
    \\EOT\EOT\SO\STX\ETX\DC2\EOT\165\EOT\STX \SUBX The maximum number of elements collected in a batch that could be accepted\n\
    \ by server.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ETX\ENQ\DC2\EOT\165\EOT\STX\a\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ETX\SOH\DC2\EOT\165\EOT\b\ESC\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ETX\ETX\DC2\EOT\165\EOT\RS\US\n\
    \Q\n\
    \\EOT\EOT\SO\STX\EOT\DC2\EOT\168\EOT\STX\US\SUBC The maximum size of the request that could be accepted by server.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\EOT\ENQ\DC2\EOT\168\EOT\STX\a\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\EOT\SOH\DC2\EOT\168\EOT\b\SUB\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\EOT\ETX\DC2\EOT\168\EOT\GS\RS\n\
    \G\n\
    \\EOT\EOT\SO\STX\ENQ\DC2\EOT\171\EOT\STX'\SUB9 The maximum number of elements allowed by flow control.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ENQ\ENQ\DC2\EOT\171\EOT\STX\a\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ENQ\SOH\DC2\EOT\171\EOT\b\"\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ENQ\ETX\DC2\EOT\171\EOT%&\n\
    \A\n\
    \\EOT\EOT\SO\STX\ACK\DC2\EOT\174\EOT\STX$\SUB3 The maximum size of data allowed by flow control.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ACK\ENQ\DC2\EOT\174\EOT\STX\a\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ACK\SOH\DC2\EOT\174\EOT\b\US\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\ACK\ETX\DC2\EOT\174\EOT\"#\n\
    \O\n\
    \\EOT\EOT\SO\STX\a\DC2\ACK\177\EOT\STX\178\EOT\b\SUB? The behavior to take when the flow control limit is exceeded.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\a\ACK\DC2\EOT\177\EOT\STX'\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\a\SOH\DC2\EOT\177\EOT(L\n\
    \\r\n\
    \\ENQ\EOT\SO\STX\a\ETX\DC2\EOT\178\EOT\ACK\a\n\
    \M\n\
    \\STX\ENQ\STX\DC2\ACK\182\EOT\NUL\194\EOT\SOH\SUB? The behavior to take when the flow control limit is exceeded.\n\
    \\n\
    \\v\n\
    \\ETX\ENQ\STX\SOH\DC2\EOT\182\EOT\ENQ*\n\
    \1\n\
    \\EOT\ENQ\STX\STX\NUL\DC2\EOT\184\EOT\STX\NAK\SUB# Default behavior, system-defined.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\NUL\SOH\DC2\EOT\184\EOT\STX\DLE\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\NUL\STX\DC2\EOT\184\EOT\DC3\DC4\n\
    \,\n\
    \\EOT\ENQ\STX\STX\SOH\DC2\EOT\187\EOT\STX\SYN\SUB\RS Stop operation, raise error.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\SOH\SOH\DC2\EOT\187\EOT\STX\DC1\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\SOH\STX\DC2\EOT\187\EOT\DC4\NAK\n\
    \3\n\
    \\EOT\ENQ\STX\STX\STX\DC2\EOT\190\EOT\STX\f\SUB% Pause operation until limit clears.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\STX\SOH\DC2\EOT\190\EOT\STX\a\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\STX\STX\DC2\EOT\190\EOT\n\
    \\v\n\
    \4\n\
    \\EOT\ENQ\STX\STX\ETX\DC2\EOT\193\EOT\STX\r\SUB& Continue operation, disregard limit.\n\
    \\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\ETX\SOH\DC2\EOT\193\EOT\STX\b\n\
    \\r\n\
    \\ENQ\ENQ\STX\STX\ETX\STX\DC2\EOT\193\EOT\v\f\n\
    \\196\SOH\n\
    \\STX\EOT\SI\DC2\ACK\199\EOT\NUL\213\EOT\SOH\SUB\181\SOH `BatchingDescriptorProto` specifies the fields of the request message to be\n\
    \ used for batching, and, optionally, the fields of the response message to be\n\
    \ used for demultiplexing.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\SI\SOH\DC2\EOT\199\EOT\b\US\n\
    \W\n\
    \\EOT\EOT\SI\STX\NUL\DC2\EOT\201\EOT\STX\ESC\SUBI The repeated field in the request message to be aggregated by batching.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\NUL\ENQ\DC2\EOT\201\EOT\STX\b\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\NUL\SOH\DC2\EOT\201\EOT\t\SYN\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\NUL\ETX\DC2\EOT\201\EOT\EM\SUB\n\
    \\214\SOH\n\
    \\EOT\EOT\SI\STX\SOH\DC2\EOT\206\EOT\STX+\SUB\199\SOH A list of the fields in the request message. Two requests will be batched\n\
    \ together only if the values of every field specified in\n\
    \ `request_discriminator_fields` is equal between the two requests.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\SOH\EOT\DC2\EOT\206\EOT\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\SOH\ENQ\DC2\EOT\206\EOT\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\SOH\SOH\DC2\EOT\206\EOT\DC2&\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\SOH\ETX\DC2\EOT\206\EOT)*\n\
    \\241\SOH\n\
    \\EOT\EOT\SI\STX\STX\DC2\EOT\212\EOT\STX\US\SUB\226\SOH Optional. When present, indicates the field in the response message to be\n\
    \ used to demultiplex the response into multiple response messages, in\n\
    \ correspondence with the multiple request messages originally batched\n\
    \ together.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\STX\ENQ\DC2\EOT\212\EOT\STX\b\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\STX\SOH\DC2\EOT\212\EOT\t\SUB\n\
    \\r\n\
    \\ENQ\EOT\SI\STX\STX\ETX\DC2\EOT\212\EOT\GS\RSb\ACKproto3"