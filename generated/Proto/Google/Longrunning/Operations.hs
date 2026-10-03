{- This file was auto-generated from google/longrunning/operations.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Google.Longrunning.Operations (
        Operations(..), CancelOperationRequest(), DeleteOperationRequest(),
        GetOperationRequest(), ListOperationsRequest(),
        ListOperationsResponse(), Operation(), Operation'Result(..),
        _Operation'Error, _Operation'Response, OperationInfo(),
        WaitOperationRequest()
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
import qualified Proto.Google.Api.Annotations
import qualified Proto.Google.Api.Client
import qualified Proto.Google.Api.FieldBehavior
import qualified Proto.Google.Protobuf.Any
import qualified Proto.Google.Protobuf.Descriptor
import qualified Proto.Google.Protobuf.Duration
import qualified Proto.Google.Protobuf.Empty
import qualified Proto.Google.Rpc.Status
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.name' @:: Lens' CancelOperationRequest Data.Text.Text@ -}
data CancelOperationRequest
  = CancelOperationRequest'_constructor {_CancelOperationRequest'name :: !Data.Text.Text,
                                         _CancelOperationRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show CancelOperationRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField CancelOperationRequest "name" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _CancelOperationRequest'name
           (\ x__ y__ -> x__ {_CancelOperationRequest'name = y__}))
        Prelude.id
instance Data.ProtoLens.Message CancelOperationRequest where
  messageName _
    = Data.Text.pack "google.longrunning.CancelOperationRequest"
  packedMessageDescriptor _
    = "\n\
      \\SYNCancelOperationRequest\DC2\DC2\n\
      \\EOTname\CAN\SOH \SOH(\tR\EOTname"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        name__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"name")) ::
              Data.ProtoLens.FieldDescriptor CancelOperationRequest
      in
        Data.Map.fromList [(Data.ProtoLens.Tag 1, name__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _CancelOperationRequest'_unknownFields
        (\ x__ y__ -> x__ {_CancelOperationRequest'_unknownFields = y__})
  defMessage
    = CancelOperationRequest'_constructor
        {_CancelOperationRequest'name = Data.ProtoLens.fieldDefault,
         _CancelOperationRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          CancelOperationRequest
          -> Data.ProtoLens.Encoding.Bytes.Parser CancelOperationRequest
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
                                       "name"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"name") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "CancelOperationRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"name") _x
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
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData CancelOperationRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_CancelOperationRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq (_CancelOperationRequest'name x__) ())
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.name' @:: Lens' DeleteOperationRequest Data.Text.Text@ -}
data DeleteOperationRequest
  = DeleteOperationRequest'_constructor {_DeleteOperationRequest'name :: !Data.Text.Text,
                                         _DeleteOperationRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show DeleteOperationRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField DeleteOperationRequest "name" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _DeleteOperationRequest'name
           (\ x__ y__ -> x__ {_DeleteOperationRequest'name = y__}))
        Prelude.id
instance Data.ProtoLens.Message DeleteOperationRequest where
  messageName _
    = Data.Text.pack "google.longrunning.DeleteOperationRequest"
  packedMessageDescriptor _
    = "\n\
      \\SYNDeleteOperationRequest\DC2\DC2\n\
      \\EOTname\CAN\SOH \SOH(\tR\EOTname"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        name__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"name")) ::
              Data.ProtoLens.FieldDescriptor DeleteOperationRequest
      in
        Data.Map.fromList [(Data.ProtoLens.Tag 1, name__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _DeleteOperationRequest'_unknownFields
        (\ x__ y__ -> x__ {_DeleteOperationRequest'_unknownFields = y__})
  defMessage
    = DeleteOperationRequest'_constructor
        {_DeleteOperationRequest'name = Data.ProtoLens.fieldDefault,
         _DeleteOperationRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          DeleteOperationRequest
          -> Data.ProtoLens.Encoding.Bytes.Parser DeleteOperationRequest
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
                                       "name"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"name") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "DeleteOperationRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"name") _x
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
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData DeleteOperationRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_DeleteOperationRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq (_DeleteOperationRequest'name x__) ())
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.name' @:: Lens' GetOperationRequest Data.Text.Text@ -}
data GetOperationRequest
  = GetOperationRequest'_constructor {_GetOperationRequest'name :: !Data.Text.Text,
                                      _GetOperationRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show GetOperationRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField GetOperationRequest "name" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _GetOperationRequest'name
           (\ x__ y__ -> x__ {_GetOperationRequest'name = y__}))
        Prelude.id
instance Data.ProtoLens.Message GetOperationRequest where
  messageName _
    = Data.Text.pack "google.longrunning.GetOperationRequest"
  packedMessageDescriptor _
    = "\n\
      \\DC3GetOperationRequest\DC2\DC2\n\
      \\EOTname\CAN\SOH \SOH(\tR\EOTname"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        name__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"name")) ::
              Data.ProtoLens.FieldDescriptor GetOperationRequest
      in
        Data.Map.fromList [(Data.ProtoLens.Tag 1, name__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _GetOperationRequest'_unknownFields
        (\ x__ y__ -> x__ {_GetOperationRequest'_unknownFields = y__})
  defMessage
    = GetOperationRequest'_constructor
        {_GetOperationRequest'name = Data.ProtoLens.fieldDefault,
         _GetOperationRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          GetOperationRequest
          -> Data.ProtoLens.Encoding.Bytes.Parser GetOperationRequest
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
                                       "name"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"name") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "GetOperationRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"name") _x
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
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData GetOperationRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_GetOperationRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq (_GetOperationRequest'name x__) ())
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.name' @:: Lens' ListOperationsRequest Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.filter' @:: Lens' ListOperationsRequest Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.pageSize' @:: Lens' ListOperationsRequest Data.Int.Int32@
         * 'Proto.Google.Longrunning.Operations_Fields.pageToken' @:: Lens' ListOperationsRequest Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.returnPartialSuccess' @:: Lens' ListOperationsRequest Prelude.Bool@ -}
data ListOperationsRequest
  = ListOperationsRequest'_constructor {_ListOperationsRequest'name :: !Data.Text.Text,
                                        _ListOperationsRequest'filter :: !Data.Text.Text,
                                        _ListOperationsRequest'pageSize :: !Data.Int.Int32,
                                        _ListOperationsRequest'pageToken :: !Data.Text.Text,
                                        _ListOperationsRequest'returnPartialSuccess :: !Prelude.Bool,
                                        _ListOperationsRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show ListOperationsRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField ListOperationsRequest "name" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsRequest'name
           (\ x__ y__ -> x__ {_ListOperationsRequest'name = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ListOperationsRequest "filter" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsRequest'filter
           (\ x__ y__ -> x__ {_ListOperationsRequest'filter = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ListOperationsRequest "pageSize" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsRequest'pageSize
           (\ x__ y__ -> x__ {_ListOperationsRequest'pageSize = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ListOperationsRequest "pageToken" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsRequest'pageToken
           (\ x__ y__ -> x__ {_ListOperationsRequest'pageToken = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ListOperationsRequest "returnPartialSuccess" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsRequest'returnPartialSuccess
           (\ x__ y__
              -> x__ {_ListOperationsRequest'returnPartialSuccess = y__}))
        Prelude.id
instance Data.ProtoLens.Message ListOperationsRequest where
  messageName _
    = Data.Text.pack "google.longrunning.ListOperationsRequest"
  packedMessageDescriptor _
    = "\n\
      \\NAKListOperationsRequest\DC2\DC2\n\
      \\EOTname\CAN\EOT \SOH(\tR\EOTname\DC2\SYN\n\
      \\ACKfilter\CAN\SOH \SOH(\tR\ACKfilter\DC2\ESC\n\
      \\tpage_size\CAN\STX \SOH(\ENQR\bpageSize\DC2\GS\n\
      \\n\
      \page_token\CAN\ETX \SOH(\tR\tpageToken\DC24\n\
      \\SYNreturn_partial_success\CAN\ENQ \SOH(\bR\DC4returnPartialSuccess"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        name__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"name")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsRequest
        filter__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "filter"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"filter")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsRequest
        pageSize__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "page_size"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"pageSize")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsRequest
        pageToken__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "page_token"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"pageToken")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsRequest
        returnPartialSuccess__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "return_partial_success"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"returnPartialSuccess")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsRequest
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 4, name__field_descriptor),
           (Data.ProtoLens.Tag 1, filter__field_descriptor),
           (Data.ProtoLens.Tag 2, pageSize__field_descriptor),
           (Data.ProtoLens.Tag 3, pageToken__field_descriptor),
           (Data.ProtoLens.Tag 5, returnPartialSuccess__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _ListOperationsRequest'_unknownFields
        (\ x__ y__ -> x__ {_ListOperationsRequest'_unknownFields = y__})
  defMessage
    = ListOperationsRequest'_constructor
        {_ListOperationsRequest'name = Data.ProtoLens.fieldDefault,
         _ListOperationsRequest'filter = Data.ProtoLens.fieldDefault,
         _ListOperationsRequest'pageSize = Data.ProtoLens.fieldDefault,
         _ListOperationsRequest'pageToken = Data.ProtoLens.fieldDefault,
         _ListOperationsRequest'returnPartialSuccess = Data.ProtoLens.fieldDefault,
         _ListOperationsRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          ListOperationsRequest
          -> Data.ProtoLens.Encoding.Bytes.Parser ListOperationsRequest
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
                        34
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "name"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"name") y x)
                        10
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "filter"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"filter") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "page_size"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"pageSize") y x)
                        26
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "page_token"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"pageToken") y x)
                        40
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "return_partial_success"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"returnPartialSuccess") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "ListOperationsRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"name") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 34)
                      ((Prelude..)
                         (\ bs
                            -> (Data.Monoid.<>)
                                 (Data.ProtoLens.Encoding.Bytes.putVarInt
                                    (Prelude.fromIntegral (Data.ByteString.length bs)))
                                 (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         Data.Text.Encoding.encodeUtf8 _v))
             ((Data.Monoid.<>)
                (let
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"filter") _x
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
                      _v = Lens.Family2.view (Data.ProtoLens.Field.field @"pageSize") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 16)
                            ((Prelude..)
                               Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
                   ((Data.Monoid.<>)
                      (let
                         _v = Lens.Family2.view (Data.ProtoLens.Field.field @"pageToken") _x
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
                      ((Data.Monoid.<>)
                         (let
                            _v
                              = Lens.Family2.view
                                  (Data.ProtoLens.Field.field @"returnPartialSuccess") _x
                          in
                            if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                                Data.Monoid.mempty
                            else
                                (Data.Monoid.<>)
                                  (Data.ProtoLens.Encoding.Bytes.putVarInt 40)
                                  ((Prelude..)
                                     Data.ProtoLens.Encoding.Bytes.putVarInt
                                     (\ b -> if b then 1 else 0) _v))
                         (Data.ProtoLens.Encoding.Wire.buildFieldSet
                            (Lens.Family2.view Data.ProtoLens.unknownFields _x))))))
instance Control.DeepSeq.NFData ListOperationsRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_ListOperationsRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_ListOperationsRequest'name x__)
                (Control.DeepSeq.deepseq
                   (_ListOperationsRequest'filter x__)
                   (Control.DeepSeq.deepseq
                      (_ListOperationsRequest'pageSize x__)
                      (Control.DeepSeq.deepseq
                         (_ListOperationsRequest'pageToken x__)
                         (Control.DeepSeq.deepseq
                            (_ListOperationsRequest'returnPartialSuccess x__) ())))))
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.operations' @:: Lens' ListOperationsResponse [Operation]@
         * 'Proto.Google.Longrunning.Operations_Fields.vec'operations' @:: Lens' ListOperationsResponse (Data.Vector.Vector Operation)@
         * 'Proto.Google.Longrunning.Operations_Fields.nextPageToken' @:: Lens' ListOperationsResponse Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.unreachable' @:: Lens' ListOperationsResponse [Data.Text.Text]@
         * 'Proto.Google.Longrunning.Operations_Fields.vec'unreachable' @:: Lens' ListOperationsResponse (Data.Vector.Vector Data.Text.Text)@ -}
data ListOperationsResponse
  = ListOperationsResponse'_constructor {_ListOperationsResponse'operations :: !(Data.Vector.Vector Operation),
                                         _ListOperationsResponse'nextPageToken :: !Data.Text.Text,
                                         _ListOperationsResponse'unreachable :: !(Data.Vector.Vector Data.Text.Text),
                                         _ListOperationsResponse'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show ListOperationsResponse where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField ListOperationsResponse "operations" [Operation] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsResponse'operations
           (\ x__ y__ -> x__ {_ListOperationsResponse'operations = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField ListOperationsResponse "vec'operations" (Data.Vector.Vector Operation) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsResponse'operations
           (\ x__ y__ -> x__ {_ListOperationsResponse'operations = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ListOperationsResponse "nextPageToken" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsResponse'nextPageToken
           (\ x__ y__ -> x__ {_ListOperationsResponse'nextPageToken = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ListOperationsResponse "unreachable" [Data.Text.Text] where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsResponse'unreachable
           (\ x__ y__ -> x__ {_ListOperationsResponse'unreachable = y__}))
        (Lens.Family2.Unchecked.lens
           Data.Vector.Generic.toList
           (\ _ y__ -> Data.Vector.Generic.fromList y__))
instance Data.ProtoLens.Field.HasField ListOperationsResponse "vec'unreachable" (Data.Vector.Vector Data.Text.Text) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ListOperationsResponse'unreachable
           (\ x__ y__ -> x__ {_ListOperationsResponse'unreachable = y__}))
        Prelude.id
instance Data.ProtoLens.Message ListOperationsResponse where
  messageName _
    = Data.Text.pack "google.longrunning.ListOperationsResponse"
  packedMessageDescriptor _
    = "\n\
      \\SYNListOperationsResponse\DC2=\n\
      \\n\
      \operations\CAN\SOH \ETX(\v2\GS.google.longrunning.OperationR\n\
      \operations\DC2&\n\
      \\SInext_page_token\CAN\STX \SOH(\tR\rnextPageToken\DC2%\n\
      \\vunreachable\CAN\ETX \ETX(\tR\vunreachableB\ETX\224A\ACK"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        operations__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "operations"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Operation)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"operations")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsResponse
        nextPageToken__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "next_page_token"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"nextPageToken")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsResponse
        unreachable__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "unreachable"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.RepeatedField
                 Data.ProtoLens.Unpacked
                 (Data.ProtoLens.Field.field @"unreachable")) ::
              Data.ProtoLens.FieldDescriptor ListOperationsResponse
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, operations__field_descriptor),
           (Data.ProtoLens.Tag 2, nextPageToken__field_descriptor),
           (Data.ProtoLens.Tag 3, unreachable__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _ListOperationsResponse'_unknownFields
        (\ x__ y__ -> x__ {_ListOperationsResponse'_unknownFields = y__})
  defMessage
    = ListOperationsResponse'_constructor
        {_ListOperationsResponse'operations = Data.Vector.Generic.empty,
         _ListOperationsResponse'nextPageToken = Data.ProtoLens.fieldDefault,
         _ListOperationsResponse'unreachable = Data.Vector.Generic.empty,
         _ListOperationsResponse'_unknownFields = []}
  parseMessage
    = let
        loop ::
          ListOperationsResponse
          -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Operation
             -> Data.ProtoLens.Encoding.Growing.Growing Data.Vector.Vector Data.ProtoLens.Encoding.Growing.RealWorld Data.Text.Text
                -> Data.ProtoLens.Encoding.Bytes.Parser ListOperationsResponse
        loop x mutable'operations mutable'unreachable
          = do end <- Data.ProtoLens.Encoding.Bytes.atEnd
               if end then
                   do frozen'operations <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                             (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                mutable'operations)
                      frozen'unreachable <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                              (Data.ProtoLens.Encoding.Growing.unsafeFreeze
                                                 mutable'unreachable)
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
                              (Data.ProtoLens.Field.field @"vec'operations") frozen'operations
                              (Lens.Family2.set
                                 (Data.ProtoLens.Field.field @"vec'unreachable") frozen'unreachable
                                 x)))
               else
                   do tag <- Data.ProtoLens.Encoding.Bytes.getVarInt
                      case tag of
                        10
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.isolate
                                              (Prelude.fromIntegral len)
                                              Data.ProtoLens.parseMessage)
                                        "operations"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append mutable'operations y)
                                loop x v mutable'unreachable
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "next_page_token"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"nextPageToken") y x)
                                  mutable'operations mutable'unreachable
                        26
                          -> do !y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                        (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                            Data.ProtoLens.Encoding.Bytes.getText
                                              (Prelude.fromIntegral len))
                                        "unreachable"
                                v <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       (Data.ProtoLens.Encoding.Growing.append
                                          mutable'unreachable y)
                                loop x mutable'operations v
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
                                  mutable'operations mutable'unreachable
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do mutable'operations <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                      Data.ProtoLens.Encoding.Growing.new
              mutable'unreachable <- Data.ProtoLens.Encoding.Parser.Unsafe.unsafeLiftIO
                                       Data.ProtoLens.Encoding.Growing.new
              loop
                Data.ProtoLens.defMessage mutable'operations mutable'unreachable)
          "ListOperationsResponse"
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
                           Data.ProtoLens.encodeMessage _v))
                (Lens.Family2.view
                   (Data.ProtoLens.Field.field @"vec'operations") _x))
             ((Data.Monoid.<>)
                (let
                   _v
                     = Lens.Family2.view
                         (Data.ProtoLens.Field.field @"nextPageToken") _x
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
                         (Data.ProtoLens.Field.field @"vec'unreachable") _x))
                   (Data.ProtoLens.Encoding.Wire.buildFieldSet
                      (Lens.Family2.view Data.ProtoLens.unknownFields _x))))
instance Control.DeepSeq.NFData ListOperationsResponse where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_ListOperationsResponse'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_ListOperationsResponse'operations x__)
                (Control.DeepSeq.deepseq
                   (_ListOperationsResponse'nextPageToken x__)
                   (Control.DeepSeq.deepseq
                      (_ListOperationsResponse'unreachable x__) ())))
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.name' @:: Lens' Operation Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.metadata' @:: Lens' Operation Proto.Google.Protobuf.Any.Any@
         * 'Proto.Google.Longrunning.Operations_Fields.maybe'metadata' @:: Lens' Operation (Prelude.Maybe Proto.Google.Protobuf.Any.Any)@
         * 'Proto.Google.Longrunning.Operations_Fields.done' @:: Lens' Operation Prelude.Bool@
         * 'Proto.Google.Longrunning.Operations_Fields.maybe'result' @:: Lens' Operation (Prelude.Maybe Operation'Result)@
         * 'Proto.Google.Longrunning.Operations_Fields.maybe'error' @:: Lens' Operation (Prelude.Maybe Proto.Google.Rpc.Status.Status)@
         * 'Proto.Google.Longrunning.Operations_Fields.error' @:: Lens' Operation Proto.Google.Rpc.Status.Status@
         * 'Proto.Google.Longrunning.Operations_Fields.maybe'response' @:: Lens' Operation (Prelude.Maybe Proto.Google.Protobuf.Any.Any)@
         * 'Proto.Google.Longrunning.Operations_Fields.response' @:: Lens' Operation Proto.Google.Protobuf.Any.Any@ -}
data Operation
  = Operation'_constructor {_Operation'name :: !Data.Text.Text,
                            _Operation'metadata :: !(Prelude.Maybe Proto.Google.Protobuf.Any.Any),
                            _Operation'done :: !Prelude.Bool,
                            _Operation'result :: !(Prelude.Maybe Operation'Result),
                            _Operation'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show Operation where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
data Operation'Result
  = Operation'Error !Proto.Google.Rpc.Status.Status |
    Operation'Response !Proto.Google.Protobuf.Any.Any
  deriving stock (Prelude.Show, Prelude.Eq, Prelude.Ord)
instance Data.ProtoLens.Field.HasField Operation "name" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'name (\ x__ y__ -> x__ {_Operation'name = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Operation "metadata" Proto.Google.Protobuf.Any.Any where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'metadata (\ x__ y__ -> x__ {_Operation'metadata = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField Operation "maybe'metadata" (Prelude.Maybe Proto.Google.Protobuf.Any.Any) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'metadata (\ x__ y__ -> x__ {_Operation'metadata = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Operation "done" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'done (\ x__ y__ -> x__ {_Operation'done = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Operation "maybe'result" (Prelude.Maybe Operation'Result) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'result (\ x__ y__ -> x__ {_Operation'result = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField Operation "maybe'error" (Prelude.Maybe Proto.Google.Rpc.Status.Status) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'result (\ x__ y__ -> x__ {_Operation'result = y__}))
        (Lens.Family2.Unchecked.lens
           (\ x__
              -> case x__ of
                   (Prelude.Just (Operation'Error x__val)) -> Prelude.Just x__val
                   _otherwise -> Prelude.Nothing)
           (\ _ y__ -> Prelude.fmap Operation'Error y__))
instance Data.ProtoLens.Field.HasField Operation "error" Proto.Google.Rpc.Status.Status where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'result (\ x__ y__ -> x__ {_Operation'result = y__}))
        ((Prelude..)
           (Lens.Family2.Unchecked.lens
              (\ x__
                 -> case x__ of
                      (Prelude.Just (Operation'Error x__val)) -> Prelude.Just x__val
                      _otherwise -> Prelude.Nothing)
              (\ _ y__ -> Prelude.fmap Operation'Error y__))
           (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage))
instance Data.ProtoLens.Field.HasField Operation "maybe'response" (Prelude.Maybe Proto.Google.Protobuf.Any.Any) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'result (\ x__ y__ -> x__ {_Operation'result = y__}))
        (Lens.Family2.Unchecked.lens
           (\ x__
              -> case x__ of
                   (Prelude.Just (Operation'Response x__val)) -> Prelude.Just x__val
                   _otherwise -> Prelude.Nothing)
           (\ _ y__ -> Prelude.fmap Operation'Response y__))
instance Data.ProtoLens.Field.HasField Operation "response" Proto.Google.Protobuf.Any.Any where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _Operation'result (\ x__ y__ -> x__ {_Operation'result = y__}))
        ((Prelude..)
           (Lens.Family2.Unchecked.lens
              (\ x__
                 -> case x__ of
                      (Prelude.Just (Operation'Response x__val)) -> Prelude.Just x__val
                      _otherwise -> Prelude.Nothing)
              (\ _ y__ -> Prelude.fmap Operation'Response y__))
           (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage))
instance Data.ProtoLens.Message Operation where
  messageName _ = Data.Text.pack "google.longrunning.Operation"
  packedMessageDescriptor _
    = "\n\
      \\tOperation\DC2\DC2\n\
      \\EOTname\CAN\SOH \SOH(\tR\EOTname\DC20\n\
      \\bmetadata\CAN\STX \SOH(\v2\DC4.google.protobuf.AnyR\bmetadata\DC2\DC2\n\
      \\EOTdone\CAN\ETX \SOH(\bR\EOTdone\DC2*\n\
      \\ENQerror\CAN\EOT \SOH(\v2\DC2.google.rpc.StatusH\NULR\ENQerror\DC22\n\
      \\bresponse\CAN\ENQ \SOH(\v2\DC4.google.protobuf.AnyH\NULR\bresponseB\b\n\
      \\ACKresult"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        name__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"name")) ::
              Data.ProtoLens.FieldDescriptor Operation
        metadata__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "metadata"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Any.Any)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'metadata")) ::
              Data.ProtoLens.FieldDescriptor Operation
        done__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "done"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"done")) ::
              Data.ProtoLens.FieldDescriptor Operation
        error__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "error"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Rpc.Status.Status)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'error")) ::
              Data.ProtoLens.FieldDescriptor Operation
        response__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "response"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Any.Any)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'response")) ::
              Data.ProtoLens.FieldDescriptor Operation
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, name__field_descriptor),
           (Data.ProtoLens.Tag 2, metadata__field_descriptor),
           (Data.ProtoLens.Tag 3, done__field_descriptor),
           (Data.ProtoLens.Tag 4, error__field_descriptor),
           (Data.ProtoLens.Tag 5, response__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _Operation'_unknownFields
        (\ x__ y__ -> x__ {_Operation'_unknownFields = y__})
  defMessage
    = Operation'_constructor
        {_Operation'name = Data.ProtoLens.fieldDefault,
         _Operation'metadata = Prelude.Nothing,
         _Operation'done = Data.ProtoLens.fieldDefault,
         _Operation'result = Prelude.Nothing,
         _Operation'_unknownFields = []}
  parseMessage
    = let
        loop :: Operation -> Data.ProtoLens.Encoding.Bytes.Parser Operation
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
                                       "name"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"name") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "metadata"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"metadata") y x)
                        24
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "done"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"done") y x)
                        34
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "error"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"error") y x)
                        42
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "response"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"response") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "Operation"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"name") _x
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
                     Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'metadata") _x
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
                   (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"done") _x
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
                           Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'result") _x
                       of
                         Prelude.Nothing -> Data.Monoid.mempty
                         (Prelude.Just (Operation'Error v))
                           -> (Data.Monoid.<>)
                                (Data.ProtoLens.Encoding.Bytes.putVarInt 34)
                                ((Prelude..)
                                   (\ bs
                                      -> (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt
                                              (Prelude.fromIntegral (Data.ByteString.length bs)))
                                           (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                   Data.ProtoLens.encodeMessage v)
                         (Prelude.Just (Operation'Response v))
                           -> (Data.Monoid.<>)
                                (Data.ProtoLens.Encoding.Bytes.putVarInt 42)
                                ((Prelude..)
                                   (\ bs
                                      -> (Data.Monoid.<>)
                                           (Data.ProtoLens.Encoding.Bytes.putVarInt
                                              (Prelude.fromIntegral (Data.ByteString.length bs)))
                                           (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                   Data.ProtoLens.encodeMessage v))
                      (Data.ProtoLens.Encoding.Wire.buildFieldSet
                         (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))
instance Control.DeepSeq.NFData Operation where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_Operation'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_Operation'name x__)
                (Control.DeepSeq.deepseq
                   (_Operation'metadata x__)
                   (Control.DeepSeq.deepseq
                      (_Operation'done x__)
                      (Control.DeepSeq.deepseq (_Operation'result x__) ()))))
instance Control.DeepSeq.NFData Operation'Result where
  rnf (Operation'Error x__) = Control.DeepSeq.rnf x__
  rnf (Operation'Response x__) = Control.DeepSeq.rnf x__
_Operation'Error ::
  Data.ProtoLens.Prism.Prism' Operation'Result Proto.Google.Rpc.Status.Status
_Operation'Error
  = Data.ProtoLens.Prism.prism'
      Operation'Error
      (\ p__
         -> case p__ of
              (Operation'Error p__val) -> Prelude.Just p__val
              _otherwise -> Prelude.Nothing)
_Operation'Response ::
  Data.ProtoLens.Prism.Prism' Operation'Result Proto.Google.Protobuf.Any.Any
_Operation'Response
  = Data.ProtoLens.Prism.prism'
      Operation'Response
      (\ p__
         -> case p__ of
              (Operation'Response p__val) -> Prelude.Just p__val
              _otherwise -> Prelude.Nothing)
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.responseType' @:: Lens' OperationInfo Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.metadataType' @:: Lens' OperationInfo Data.Text.Text@ -}
data OperationInfo
  = OperationInfo'_constructor {_OperationInfo'responseType :: !Data.Text.Text,
                                _OperationInfo'metadataType :: !Data.Text.Text,
                                _OperationInfo'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show OperationInfo where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField OperationInfo "responseType" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _OperationInfo'responseType
           (\ x__ y__ -> x__ {_OperationInfo'responseType = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField OperationInfo "metadataType" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _OperationInfo'metadataType
           (\ x__ y__ -> x__ {_OperationInfo'metadataType = y__}))
        Prelude.id
instance Data.ProtoLens.Message OperationInfo where
  messageName _ = Data.Text.pack "google.longrunning.OperationInfo"
  packedMessageDescriptor _
    = "\n\
      \\rOperationInfo\DC2#\n\
      \\rresponse_type\CAN\SOH \SOH(\tR\fresponseType\DC2#\n\
      \\rmetadata_type\CAN\STX \SOH(\tR\fmetadataType"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        responseType__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "response_type"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"responseType")) ::
              Data.ProtoLens.FieldDescriptor OperationInfo
        metadataType__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "metadata_type"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"metadataType")) ::
              Data.ProtoLens.FieldDescriptor OperationInfo
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, responseType__field_descriptor),
           (Data.ProtoLens.Tag 2, metadataType__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _OperationInfo'_unknownFields
        (\ x__ y__ -> x__ {_OperationInfo'_unknownFields = y__})
  defMessage
    = OperationInfo'_constructor
        {_OperationInfo'responseType = Data.ProtoLens.fieldDefault,
         _OperationInfo'metadataType = Data.ProtoLens.fieldDefault,
         _OperationInfo'_unknownFields = []}
  parseMessage
    = let
        loop ::
          OperationInfo -> Data.ProtoLens.Encoding.Bytes.Parser OperationInfo
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
                                       "response_type"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"responseType") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "metadata_type"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"metadataType") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "OperationInfo"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view (Data.ProtoLens.Field.field @"responseType") _x
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
                     = Lens.Family2.view (Data.ProtoLens.Field.field @"metadataType") _x
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
instance Control.DeepSeq.NFData OperationInfo where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_OperationInfo'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_OperationInfo'responseType x__)
                (Control.DeepSeq.deepseq (_OperationInfo'metadataType x__) ()))
{- | Fields :
     
         * 'Proto.Google.Longrunning.Operations_Fields.name' @:: Lens' WaitOperationRequest Data.Text.Text@
         * 'Proto.Google.Longrunning.Operations_Fields.timeout' @:: Lens' WaitOperationRequest Proto.Google.Protobuf.Duration.Duration@
         * 'Proto.Google.Longrunning.Operations_Fields.maybe'timeout' @:: Lens' WaitOperationRequest (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration)@ -}
data WaitOperationRequest
  = WaitOperationRequest'_constructor {_WaitOperationRequest'name :: !Data.Text.Text,
                                       _WaitOperationRequest'timeout :: !(Prelude.Maybe Proto.Google.Protobuf.Duration.Duration),
                                       _WaitOperationRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show WaitOperationRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField WaitOperationRequest "name" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WaitOperationRequest'name
           (\ x__ y__ -> x__ {_WaitOperationRequest'name = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField WaitOperationRequest "timeout" Proto.Google.Protobuf.Duration.Duration where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WaitOperationRequest'timeout
           (\ x__ y__ -> x__ {_WaitOperationRequest'timeout = y__}))
        (Data.ProtoLens.maybeLens Data.ProtoLens.defMessage)
instance Data.ProtoLens.Field.HasField WaitOperationRequest "maybe'timeout" (Prelude.Maybe Proto.Google.Protobuf.Duration.Duration) where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WaitOperationRequest'timeout
           (\ x__ y__ -> x__ {_WaitOperationRequest'timeout = y__}))
        Prelude.id
instance Data.ProtoLens.Message WaitOperationRequest where
  messageName _
    = Data.Text.pack "google.longrunning.WaitOperationRequest"
  packedMessageDescriptor _
    = "\n\
      \\DC4WaitOperationRequest\DC2\DC2\n\
      \\EOTname\CAN\SOH \SOH(\tR\EOTname\DC23\n\
      \\atimeout\CAN\STX \SOH(\v2\EM.google.protobuf.DurationR\atimeout"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        name__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"name")) ::
              Data.ProtoLens.FieldDescriptor WaitOperationRequest
        timeout__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "timeout"
              (Data.ProtoLens.MessageField Data.ProtoLens.MessageType ::
                 Data.ProtoLens.FieldTypeDescriptor Proto.Google.Protobuf.Duration.Duration)
              (Data.ProtoLens.OptionalField
                 (Data.ProtoLens.Field.field @"maybe'timeout")) ::
              Data.ProtoLens.FieldDescriptor WaitOperationRequest
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, name__field_descriptor),
           (Data.ProtoLens.Tag 2, timeout__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _WaitOperationRequest'_unknownFields
        (\ x__ y__ -> x__ {_WaitOperationRequest'_unknownFields = y__})
  defMessage
    = WaitOperationRequest'_constructor
        {_WaitOperationRequest'name = Data.ProtoLens.fieldDefault,
         _WaitOperationRequest'timeout = Prelude.Nothing,
         _WaitOperationRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          WaitOperationRequest
          -> Data.ProtoLens.Encoding.Bytes.Parser WaitOperationRequest
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
                                       "name"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"name") y x)
                        18
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.isolate
                                             (Prelude.fromIntegral len) Data.ProtoLens.parseMessage)
                                       "timeout"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"timeout") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "WaitOperationRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let _v = Lens.Family2.view (Data.ProtoLens.Field.field @"name") _x
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
                     Lens.Family2.view (Data.ProtoLens.Field.field @"maybe'timeout") _x
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
instance Control.DeepSeq.NFData WaitOperationRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_WaitOperationRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_WaitOperationRequest'name x__)
                (Control.DeepSeq.deepseq (_WaitOperationRequest'timeout x__) ()))
data Operations = Operations {}
instance Data.ProtoLens.Service.Types.Service Operations where
  type ServiceName Operations = "Operations"
  type ServicePackage Operations = "google.longrunning"
  type ServiceMethods Operations = '["cancelOperation",
                                     "deleteOperation",
                                     "getOperation",
                                     "listOperations",
                                     "waitOperation"]
  packedServiceDescriptor _
    = "\n\
      \\n\
      \Operations\DC2\148\SOH\n\
      \\SOListOperations\DC2).google.longrunning.ListOperationsRequest\SUB*.google.longrunning.ListOperationsResponse\"+\218A\vname,filter\130\211\228\147\STX\ETB\DC2\NAK/v1/{name=operations}\DC2\DEL\n\
      \\fGetOperation\DC2'.google.longrunning.GetOperationRequest\SUB\GS.google.longrunning.Operation\"'\218A\EOTname\130\211\228\147\STX\SUB\DC2\CAN/v1/{name=operations/**}\DC2~\n\
      \\SIDeleteOperation\DC2*.google.longrunning.DeleteOperationRequest\SUB\SYN.google.protobuf.Empty\"'\218A\EOTname\130\211\228\147\STX\SUB*\CAN/v1/{name=operations/**}\DC2\136\SOH\n\
      \\SICancelOperation\DC2*.google.longrunning.CancelOperationRequest\SUB\SYN.google.protobuf.Empty\"1\218A\EOTname\130\211\228\147\STX$\"\US/v1/{name=operations/**}:cancel:\SOH*\DC2Z\n\
      \\rWaitOperation\DC2(.google.longrunning.WaitOperationRequest\SUB\GS.google.longrunning.Operation\"\NUL\SUB\GS\202A\SUBlongrunning.googleapis.com"
instance Data.ProtoLens.Service.Types.HasMethodImpl Operations "listOperations" where
  type MethodName Operations "listOperations" = "ListOperations"
  type MethodInput Operations "listOperations" = ListOperationsRequest
  type MethodOutput Operations "listOperations" = ListOperationsResponse
  type MethodStreamingType Operations "listOperations" = 'Data.ProtoLens.Service.Types.NonStreaming
instance Data.ProtoLens.Service.Types.HasMethodImpl Operations "getOperation" where
  type MethodName Operations "getOperation" = "GetOperation"
  type MethodInput Operations "getOperation" = GetOperationRequest
  type MethodOutput Operations "getOperation" = Operation
  type MethodStreamingType Operations "getOperation" = 'Data.ProtoLens.Service.Types.NonStreaming
instance Data.ProtoLens.Service.Types.HasMethodImpl Operations "deleteOperation" where
  type MethodName Operations "deleteOperation" = "DeleteOperation"
  type MethodInput Operations "deleteOperation" = DeleteOperationRequest
  type MethodOutput Operations "deleteOperation" = Proto.Google.Protobuf.Empty.Empty
  type MethodStreamingType Operations "deleteOperation" = 'Data.ProtoLens.Service.Types.NonStreaming
instance Data.ProtoLens.Service.Types.HasMethodImpl Operations "cancelOperation" where
  type MethodName Operations "cancelOperation" = "CancelOperation"
  type MethodInput Operations "cancelOperation" = CancelOperationRequest
  type MethodOutput Operations "cancelOperation" = Proto.Google.Protobuf.Empty.Empty
  type MethodStreamingType Operations "cancelOperation" = 'Data.ProtoLens.Service.Types.NonStreaming
instance Data.ProtoLens.Service.Types.HasMethodImpl Operations "waitOperation" where
  type MethodName Operations "waitOperation" = "WaitOperation"
  type MethodInput Operations "waitOperation" = WaitOperationRequest
  type MethodOutput Operations "waitOperation" = Operation
  type MethodStreamingType Operations "waitOperation" = 'Data.ProtoLens.Service.Types.NonStreaming
packedFileDescriptor :: Data.ByteString.ByteString
packedFileDescriptor
  = "\n\
    \#google/longrunning/operations.proto\DC2\DC2google.longrunning\SUB\FSgoogle/api/annotations.proto\SUB\ETBgoogle/api/client.proto\SUB\USgoogle/api/field_behavior.proto\SUB\EMgoogle/protobuf/any.proto\SUB google/protobuf/descriptor.proto\SUB\RSgoogle/protobuf/duration.proto\SUB\ESCgoogle/protobuf/empty.proto\SUB\ETBgoogle/rpc/status.proto\"\207\SOH\n\
    \\tOperation\DC2\DC2\n\
    \\EOTname\CAN\SOH \SOH(\tR\EOTname\DC20\n\
    \\bmetadata\CAN\STX \SOH(\v2\DC4.google.protobuf.AnyR\bmetadata\DC2\DC2\n\
    \\EOTdone\CAN\ETX \SOH(\bR\EOTdone\DC2*\n\
    \\ENQerror\CAN\EOT \SOH(\v2\DC2.google.rpc.StatusH\NULR\ENQerror\DC22\n\
    \\bresponse\CAN\ENQ \SOH(\v2\DC4.google.protobuf.AnyH\NULR\bresponseB\b\n\
    \\ACKresult\")\n\
    \\DC3GetOperationRequest\DC2\DC2\n\
    \\EOTname\CAN\SOH \SOH(\tR\EOTname\"\181\SOH\n\
    \\NAKListOperationsRequest\DC2\DC2\n\
    \\EOTname\CAN\EOT \SOH(\tR\EOTname\DC2\SYN\n\
    \\ACKfilter\CAN\SOH \SOH(\tR\ACKfilter\DC2\ESC\n\
    \\tpage_size\CAN\STX \SOH(\ENQR\bpageSize\DC2\GS\n\
    \\n\
    \page_token\CAN\ETX \SOH(\tR\tpageToken\DC24\n\
    \\SYNreturn_partial_success\CAN\ENQ \SOH(\bR\DC4returnPartialSuccess\"\166\SOH\n\
    \\SYNListOperationsResponse\DC2=\n\
    \\n\
    \operations\CAN\SOH \ETX(\v2\GS.google.longrunning.OperationR\n\
    \operations\DC2&\n\
    \\SInext_page_token\CAN\STX \SOH(\tR\rnextPageToken\DC2%\n\
    \\vunreachable\CAN\ETX \ETX(\tR\vunreachableB\ETX\224A\ACK\",\n\
    \\SYNCancelOperationRequest\DC2\DC2\n\
    \\EOTname\CAN\SOH \SOH(\tR\EOTname\",\n\
    \\SYNDeleteOperationRequest\DC2\DC2\n\
    \\EOTname\CAN\SOH \SOH(\tR\EOTname\"_\n\
    \\DC4WaitOperationRequest\DC2\DC2\n\
    \\EOTname\CAN\SOH \SOH(\tR\EOTname\DC23\n\
    \\atimeout\CAN\STX \SOH(\v2\EM.google.protobuf.DurationR\atimeout\"Y\n\
    \\rOperationInfo\DC2#\n\
    \\rresponse_type\CAN\SOH \SOH(\tR\fresponseType\DC2#\n\
    \\rmetadata_type\CAN\STX \SOH(\tR\fmetadataType2\170\ENQ\n\
    \\n\
    \Operations\DC2\148\SOH\n\
    \\SOListOperations\DC2).google.longrunning.ListOperationsRequest\SUB*.google.longrunning.ListOperationsResponse\"+\218A\vname,filter\130\211\228\147\STX\ETB\DC2\NAK/v1/{name=operations}\DC2\DEL\n\
    \\fGetOperation\DC2'.google.longrunning.GetOperationRequest\SUB\GS.google.longrunning.Operation\"'\218A\EOTname\130\211\228\147\STX\SUB\DC2\CAN/v1/{name=operations/**}\DC2~\n\
    \\SIDeleteOperation\DC2*.google.longrunning.DeleteOperationRequest\SUB\SYN.google.protobuf.Empty\"'\218A\EOTname\130\211\228\147\STX\SUB*\CAN/v1/{name=operations/**}\DC2\136\SOH\n\
    \\SICancelOperation\DC2*.google.longrunning.CancelOperationRequest\SUB\SYN.google.protobuf.Empty\"1\218A\EOTname\130\211\228\147\STX$\"\US/v1/{name=operations/**}:cancel:\SOH*\DC2Z\n\
    \\rWaitOperation\DC2(.google.longrunning.WaitOperationRequest\SUB\GS.google.longrunning.Operation\"\NUL\SUB\GS\202A\SUBlongrunning.googleapis.com:i\n\
    \\SOoperation_info\CAN\153\b \SOH(\v2!.google.longrunning.OperationInfo\DC2\RS.google.protobuf.MethodOptionsR\roperationInfoB\162\SOH\n\
    \\SYNcom.google.longrunningB\SIOperationsProtoP\SOHZCcloud.google.com/go/longrunning/autogen/longrunningpb;longrunningpb\162\STX\ENQGLRUN\170\STX\DC2Google.LongRunning\202\STX\DC2Google\\LongRunningJ\236O\n\
    \\a\DC2\ENQ\SO\NUL\136\STX\SOH\n\
    \\188\EOT\n\
    \\SOH\f\DC2\ETX\SO\NUL\DC22\177\EOT Copyright 2025 Google LLC\n\
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
    \\SOH\STX\DC2\ETX\DLE\NUL\ESC\n\
    \\t\n\
    \\STX\ETX\NUL\DC2\ETX\DC2\NUL&\n\
    \\t\n\
    \\STX\ETX\SOH\DC2\ETX\DC3\NUL!\n\
    \\t\n\
    \\STX\ETX\STX\DC2\ETX\DC4\NUL)\n\
    \\t\n\
    \\STX\ETX\ETX\DC2\ETX\NAK\NUL#\n\
    \\t\n\
    \\STX\ETX\EOT\DC2\ETX\SYN\NUL*\n\
    \\t\n\
    \\STX\ETX\ENQ\DC2\ETX\ETB\NUL(\n\
    \\t\n\
    \\STX\ETX\ACK\DC2\ETX\CAN\NUL%\n\
    \\t\n\
    \\STX\ETX\a\DC2\ETX\EM\NUL!\n\
    \\b\n\
    \\SOH\b\DC2\ETX\ESC\NUL/\n\
    \\t\n\
    \\STX\b%\DC2\ETX\ESC\NUL/\n\
    \\b\n\
    \\SOH\b\DC2\ETX\FS\NULZ\n\
    \\t\n\
    \\STX\b\v\DC2\ETX\FS\NULZ\n\
    \\b\n\
    \\SOH\b\DC2\ETX\GS\NUL\"\n\
    \\t\n\
    \\STX\b\n\
    \\DC2\ETX\GS\NUL\"\n\
    \\b\n\
    \\SOH\b\DC2\ETX\RS\NUL0\n\
    \\t\n\
    \\STX\b\b\DC2\ETX\RS\NUL0\n\
    \\b\n\
    \\SOH\b\DC2\ETX\US\NUL/\n\
    \\t\n\
    \\STX\b\SOH\DC2\ETX\US\NUL/\n\
    \\b\n\
    \\SOH\b\DC2\ETX \NUL#\n\
    \\t\n\
    \\STX\b$\DC2\ETX \NUL#\n\
    \\b\n\
    \\SOH\b\DC2\ETX!\NUL-\n\
    \\t\n\
    \\STX\b)\DC2\ETX!\NUL-\n\
    \\t\n\
    \\SOH\a\DC2\EOT#\NUL+\SOH\n\
    \\248\SOH\n\
    \\STX\a\NUL\DC2\ETX*\STX9\SUB\236\SOH Additional information regarding long-running operations.\n\
    \ In particular, this specifies the types that are returned from\n\
    \ long-running operations.\n\
    \\n\
    \ Required for methods that return `google.longrunning.Operation`; invalid\n\
    \ otherwise.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\a\NUL\STX\DC2\ETX#\a$\n\
    \\n\
    \\n\
    \\ETX\a\NUL\ACK\DC2\ETX*\STX\"\n\
    \\n\
    \\n\
    \\ETX\a\NUL\SOH\DC2\ETX*#1\n\
    \\n\
    \\n\
    \\ETX\a\NUL\ETX\DC2\ETX*48\n\
    \\197\EOT\n\
    \\STX\ACK\NUL\DC2\EOT6\NULt\SOH\SUB\184\EOT Manages long-running operations with an API service.\n\
    \\n\
    \ When an API method normally takes long time to complete, it can be designed\n\
    \ to return [Operation][google.longrunning.Operation] to the client, and the\n\
    \ client can use this interface to receive the real response asynchronously by\n\
    \ polling the operation resource, or pass the operation resource to another API\n\
    \ (such as Pub/Sub API) to receive the response.  Any API service that returns\n\
    \ long-running operations should implement the `Operations` interface so\n\
    \ developers can have a consistent client experience.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\ACK\NUL\SOH\DC2\ETX6\b\DC2\n\
    \\n\
    \\n\
    \\ETX\ACK\NUL\ETX\DC2\ETX7\STXB\n\
    \\f\n\
    \\ENQ\ACK\NUL\ETX\153\b\DC2\ETX7\STXB\n\
    \\153\SOH\n\
    \\EOT\ACK\NUL\STX\NUL\DC2\EOT;\STX@\ETX\SUB\138\SOH Lists operations that match the specified filter in the request. If the\n\
    \ server doesn't support this method, it returns `UNIMPLEMENTED`.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\SOH\DC2\ETX;\ACK\DC4\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\STX\DC2\ETX;\NAK*\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\ETX\DC2\ETX;5K\n\
    \\r\n\
    \\ENQ\ACK\NUL\STX\NUL\EOT\DC2\EOT<\EOT>\ACK\n\
    \\DC1\n\
    \\t\ACK\NUL\STX\NUL\EOT\176\202\188\"\DC2\EOT<\EOT>\ACK\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\EOT\DC2\ETX?\EOT9\n\
    \\SI\n\
    \\b\ACK\NUL\STX\NUL\EOT\155\b\NUL\DC2\ETX?\EOT9\n\
    \\175\SOH\n\
    \\EOT\ACK\NUL\STX\SOH\DC2\EOTE\STXJ\ETX\SUB\160\SOH Gets the latest state of a long-running operation.  Clients can use this\n\
    \ method to poll the operation result at intervals as recommended by the API\n\
    \ service.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\SOH\DC2\ETXE\ACK\DC2\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\STX\DC2\ETXE\DC3&\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\ETX\DC2\ETXE1:\n\
    \\r\n\
    \\ENQ\ACK\NUL\STX\SOH\EOT\DC2\EOTF\EOTH\ACK\n\
    \\DC1\n\
    \\t\ACK\NUL\STX\SOH\EOT\176\202\188\"\DC2\EOTF\EOTH\ACK\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\EOT\DC2\ETXI\EOT2\n\
    \\SI\n\
    \\b\ACK\NUL\STX\SOH\EOT\155\b\NUL\DC2\ETXI\EOT2\n\
    \\133\STX\n\
    \\EOT\ACK\NUL\STX\STX\DC2\EOTP\STXU\ETX\SUB\246\SOH Deletes a long-running operation. This method indicates that the client is\n\
    \ no longer interested in the operation result. It does not cancel the\n\
    \ operation. If the server doesn't support this method, it returns\n\
    \ `google.rpc.Code.UNIMPLEMENTED`.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\SOH\DC2\ETXP\ACK\NAK\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\STX\DC2\ETXP\SYN,\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\ETX\DC2\ETXP7L\n\
    \\r\n\
    \\ENQ\ACK\NUL\STX\STX\EOT\DC2\EOTQ\EOTS\ACK\n\
    \\DC1\n\
    \\t\ACK\NUL\STX\STX\EOT\176\202\188\"\DC2\EOTQ\EOTS\ACK\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\EOT\DC2\ETXT\EOT2\n\
    \\SI\n\
    \\b\ACK\NUL\STX\STX\EOT\155\b\NUL\DC2\ETXT\EOT2\n\
    \\215\ENQ\n\
    \\EOT\ACK\NUL\STX\ETX\DC2\EOTb\STXh\ETX\SUB\200\ENQ Starts asynchronous cancellation on a long-running operation.  The server\n\
    \ makes a best effort to cancel the operation, but success is not\n\
    \ guaranteed.  If the server doesn't support this method, it returns\n\
    \ `google.rpc.Code.UNIMPLEMENTED`.  Clients can use\n\
    \ [Operations.GetOperation][google.longrunning.Operations.GetOperation] or\n\
    \ other methods to check whether the cancellation succeeded or whether the\n\
    \ operation completed despite cancellation. On successful cancellation,\n\
    \ the operation is not deleted; instead, it becomes an operation with\n\
    \ an [Operation.error][google.longrunning.Operation.error] value with a\n\
    \ [google.rpc.Status.code][google.rpc.Status.code] of `1`, corresponding to\n\
    \ `Code.CANCELLED`.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\ETX\SOH\DC2\ETXb\ACK\NAK\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\ETX\STX\DC2\ETXb\SYN,\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\ETX\ETX\DC2\ETXb7L\n\
    \\r\n\
    \\ENQ\ACK\NUL\STX\ETX\EOT\DC2\EOTc\EOTf\ACK\n\
    \\DC1\n\
    \\t\ACK\NUL\STX\ETX\EOT\176\202\188\"\DC2\EOTc\EOTf\ACK\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\ETX\EOT\DC2\ETXg\EOT2\n\
    \\SI\n\
    \\b\ACK\NUL\STX\ETX\EOT\155\b\NUL\DC2\ETXg\EOT2\n\
    \\246\EOT\n\
    \\EOT\ACK\NUL\STX\EOT\DC2\ETXs\STX@\SUB\232\EOT Waits until the specified long-running operation is done or reaches at most\n\
    \ a specified timeout, returning the latest state.  If the operation is\n\
    \ already done, the latest state is immediately returned.  If the timeout\n\
    \ specified is greater than the default HTTP/RPC timeout, the HTTP/RPC\n\
    \ timeout is used.  If the server does not support this method, it returns\n\
    \ `google.rpc.Code.UNIMPLEMENTED`.\n\
    \ Note that this method is on a best-effort basis.  It may return the latest\n\
    \ state before the specified timeout (including immediately), meaning even an\n\
    \ immediate response is no guarantee that the operation is done.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\EOT\SOH\DC2\ETXs\ACK\DC3\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\EOT\STX\DC2\ETXs\DC4(\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\EOT\ETX\DC2\ETXs3<\n\
    \k\n\
    \\STX\EOT\NUL\DC2\ENQx\NUL\155\SOH\SOH\SUB^ This resource represents a long-running operation that is the result of a\n\
    \ network API call.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\EOT\NUL\SOH\DC2\ETXx\b\DC1\n\
    \\228\SOH\n\
    \\EOT\EOT\NUL\STX\NUL\DC2\ETX|\STX\DC2\SUB\214\SOH The server-assigned name, which is only unique within the same service that\n\
    \ originally returns it. If you use the default HTTP mapping, the\n\
    \ `name` should be a resource name ending with `operations/{unique_id}`.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ENQ\DC2\ETX|\STX\b\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\SOH\DC2\ETX|\t\r\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ETX\DC2\ETX|\DLE\DC1\n\
    \\173\STX\n\
    \\EOT\EOT\NUL\STX\SOH\DC2\EOT\130\SOH\STX#\SUB\158\STX Service-specific metadata associated with the operation.  It typically\n\
    \ contains progress information and common metadata such as create time.\n\
    \ Some services might not provide such metadata.  Any method that returns a\n\
    \ long-running operation should document the metadata type, if any.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\SOH\ACK\DC2\EOT\130\SOH\STX\NAK\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\SOH\SOH\DC2\EOT\130\SOH\SYN\RS\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\SOH\ETX\DC2\EOT\130\SOH!\"\n\
    \\174\SOH\n\
    \\EOT\EOT\NUL\STX\STX\DC2\EOT\135\SOH\STX\DLE\SUB\159\SOH If the value is `false`, it means the operation is still in progress.\n\
    \ If `true`, the operation is completed, and either `error` or `response` is\n\
    \ available.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\STX\ENQ\DC2\EOT\135\SOH\STX\ACK\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\STX\SOH\DC2\EOT\135\SOH\a\v\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\STX\ETX\DC2\EOT\135\SOH\SO\SI\n\
    \\144\STX\n\
    \\EOT\EOT\NUL\b\NUL\DC2\ACK\141\SOH\STX\154\SOH\ETX\SUB\255\SOH The operation result, which can be either an `error` or a valid `response`.\n\
    \ If `done` == `false`, neither `error` nor `response` is set.\n\
    \ If `done` == `true`, exactly one of `error` or `response` can be set.\n\
    \ Some services might not provide the result.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\NUL\b\NUL\SOH\DC2\EOT\141\SOH\b\SO\n\
    \U\n\
    \\EOT\EOT\NUL\STX\ETX\DC2\EOT\143\SOH\EOT \SUBG The error result of the operation in case of failure or cancellation.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\ETX\ACK\DC2\EOT\143\SOH\EOT\NAK\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\ETX\SOH\DC2\EOT\143\SOH\SYN\ESC\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\ETX\ETX\DC2\EOT\143\SOH\RS\US\n\
    \\253\ETX\n\
    \\EOT\EOT\NUL\STX\EOT\DC2\EOT\153\SOH\EOT%\SUB\238\ETX The normal, successful response of the operation.  If the original\n\
    \ method returns no data on success, such as `Delete`, the response is\n\
    \ `google.protobuf.Empty`.  If the original method is standard\n\
    \ `Get`/`Create`/`Update`, the response should be the resource.  For other\n\
    \ methods, the response should have the type `XxxResponse`, where `Xxx`\n\
    \ is the original method name.  For example, if the original method name\n\
    \ is `TakeSnapshot()`, the inferred response type is\n\
    \ `TakeSnapshotResponse`.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\EOT\ACK\DC2\EOT\153\SOH\EOT\ETB\n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\EOT\SOH\DC2\EOT\153\SOH\CAN \n\
    \\r\n\
    \\ENQ\EOT\NUL\STX\EOT\ETX\DC2\EOT\153\SOH#$\n\
    \o\n\
    \\STX\EOT\SOH\DC2\ACK\159\SOH\NUL\162\SOH\SOH\SUBa The request message for\n\
    \ [Operations.GetOperation][google.longrunning.Operations.GetOperation].\n\
    \\n\
    \\v\n\
    \\ETX\EOT\SOH\SOH\DC2\EOT\159\SOH\b\ESC\n\
    \3\n\
    \\EOT\EOT\SOH\STX\NUL\DC2\EOT\161\SOH\STX\DC2\SUB% The name of the operation resource.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\NUL\ENQ\DC2\EOT\161\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\NUL\SOH\DC2\EOT\161\SOH\t\r\n\
    \\r\n\
    \\ENQ\EOT\SOH\STX\NUL\ETX\DC2\EOT\161\SOH\DLE\DC1\n\
    \s\n\
    \\STX\EOT\STX\DC2\ACK\166\SOH\NUL\190\SOH\SOH\SUBe The request message for\n\
    \ [Operations.ListOperations][google.longrunning.Operations.ListOperations].\n\
    \\n\
    \\v\n\
    \\ETX\EOT\STX\SOH\DC2\EOT\166\SOH\b\GS\n\
    \<\n\
    \\EOT\EOT\STX\STX\NUL\DC2\EOT\168\SOH\STX\DC2\SUB. The name of the operation's parent resource.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\ENQ\DC2\EOT\168\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\SOH\DC2\EOT\168\SOH\t\r\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\ETX\DC2\EOT\168\SOH\DLE\DC1\n\
    \)\n\
    \\EOT\EOT\STX\STX\SOH\DC2\EOT\171\SOH\STX\DC4\SUB\ESC The standard list filter.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\ENQ\DC2\EOT\171\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\SOH\DC2\EOT\171\SOH\t\SI\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\ETX\DC2\EOT\171\SOH\DC2\DC3\n\
    \,\n\
    \\EOT\EOT\STX\STX\STX\DC2\EOT\174\SOH\STX\SYN\SUB\RS The standard list page size.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\ENQ\DC2\EOT\174\SOH\STX\a\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\SOH\DC2\EOT\174\SOH\b\DC1\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\ETX\DC2\EOT\174\SOH\DC4\NAK\n\
    \-\n\
    \\EOT\EOT\STX\STX\ETX\DC2\EOT\177\SOH\STX\CAN\SUB\US The standard list page token.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\ENQ\DC2\EOT\177\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\SOH\DC2\EOT\177\SOH\t\DC3\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\ETX\DC2\EOT\177\SOH\SYN\ETB\n\
    \\232\ETX\n\
    \\EOT\EOT\STX\STX\EOT\DC2\EOT\189\SOH\STX\"\SUB\217\ETX When set to `true`, operations that are reachable are returned as normal,\n\
    \ and those that are unreachable are returned in the\n\
    \ [ListOperationsResponse.unreachable] field.\n\
    \\n\
    \ This can only be `true` when reading across collections e.g. when `parent`\n\
    \ is set to `\"projects/example/locations/-\"`.\n\
    \\n\
    \ This field is not by default supported and will result in an\n\
    \ `UNIMPLEMENTED` error if set unless explicitly documented otherwise in\n\
    \ service or product specific documentation.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\EOT\ENQ\DC2\EOT\189\SOH\STX\ACK\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\EOT\SOH\DC2\EOT\189\SOH\a\GS\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\EOT\ETX\DC2\EOT\189\SOH !\n\
    \t\n\
    \\STX\EOT\ETX\DC2\ACK\194\SOH\NUL\207\SOH\SOH\SUBf The response message for\n\
    \ [Operations.ListOperations][google.longrunning.Operations.ListOperations].\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ETX\SOH\DC2\EOT\194\SOH\b\RS\n\
    \V\n\
    \\EOT\EOT\ETX\STX\NUL\DC2\EOT\196\SOH\STX$\SUBH A list of operations that matches the specified filter in the request.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\EOT\DC2\EOT\196\SOH\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\ACK\DC2\EOT\196\SOH\v\DC4\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\SOH\DC2\EOT\196\SOH\NAK\US\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\ETX\DC2\EOT\196\SOH\"#\n\
    \2\n\
    \\EOT\EOT\ETX\STX\SOH\DC2\EOT\199\SOH\STX\GS\SUB$ The standard List next-page token.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\SOH\ENQ\DC2\EOT\199\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\SOH\SOH\DC2\EOT\199\SOH\t\CAN\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\SOH\ETX\DC2\EOT\199\SOH\ESC\FS\n\
    \\243\SOH\n\
    \\EOT\EOT\ETX\STX\STX\DC2\ACK\205\SOH\STX\206\SOH5\SUB\226\SOH Unordered list. Unreachable resources. Populated when the request sets\n\
    \ `ListOperationsRequest.return_partial_success` and reads across\n\
    \ collections e.g. when attempting to list all resources across all supported\n\
    \ locations.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\EOT\DC2\EOT\205\SOH\STX\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\ENQ\DC2\EOT\205\SOH\v\DC1\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\SOH\DC2\EOT\205\SOH\DC2\GS\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\ETX\DC2\EOT\205\SOH !\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\STX\b\DC2\EOT\206\SOH\ACK4\n\
    \\DLE\n\
    \\b\EOT\ETX\STX\STX\b\156\b\NUL\DC2\EOT\206\SOH\a3\n\
    \u\n\
    \\STX\EOT\EOT\DC2\ACK\211\SOH\NUL\214\SOH\SOH\SUBg The request message for\n\
    \ [Operations.CancelOperation][google.longrunning.Operations.CancelOperation].\n\
    \\n\
    \\v\n\
    \\ETX\EOT\EOT\SOH\DC2\EOT\211\SOH\b\RS\n\
    \C\n\
    \\EOT\EOT\EOT\STX\NUL\DC2\EOT\213\SOH\STX\DC2\SUB5 The name of the operation resource to be cancelled.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\ENQ\DC2\EOT\213\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\SOH\DC2\EOT\213\SOH\t\r\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\ETX\DC2\EOT\213\SOH\DLE\DC1\n\
    \u\n\
    \\STX\EOT\ENQ\DC2\ACK\218\SOH\NUL\221\SOH\SOH\SUBg The request message for\n\
    \ [Operations.DeleteOperation][google.longrunning.Operations.DeleteOperation].\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ENQ\SOH\DC2\EOT\218\SOH\b\RS\n\
    \A\n\
    \\EOT\EOT\ENQ\STX\NUL\DC2\EOT\220\SOH\STX\DC2\SUB3 The name of the operation resource to be deleted.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\ENQ\DC2\EOT\220\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\SOH\DC2\EOT\220\SOH\t\r\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\ETX\DC2\EOT\220\SOH\DLE\DC1\n\
    \q\n\
    \\STX\EOT\ACK\DC2\ACK\225\SOH\NUL\233\SOH\SOH\SUBc The request message for\n\
    \ [Operations.WaitOperation][google.longrunning.Operations.WaitOperation].\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ACK\SOH\DC2\EOT\225\SOH\b\FS\n\
    \>\n\
    \\EOT\EOT\ACK\STX\NUL\DC2\EOT\227\SOH\STX\DC2\SUB0 The name of the operation resource to wait on.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\NUL\ENQ\DC2\EOT\227\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\NUL\SOH\DC2\EOT\227\SOH\t\r\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\NUL\ETX\DC2\EOT\227\SOH\DLE\DC1\n\
    \\235\SOH\n\
    \\EOT\EOT\ACK\STX\SOH\DC2\EOT\232\SOH\STX'\SUB\220\SOH The maximum duration to wait before timing out. If left blank, the wait\n\
    \ will be at most the time permitted by the underlying HTTP/RPC protocol.\n\
    \ If RPC context deadline is also specified, the shorter one will be used.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\SOH\ACK\DC2\EOT\232\SOH\STX\SUB\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\SOH\SOH\DC2\EOT\232\SOH\ESC\"\n\
    \\r\n\
    \\ENQ\EOT\ACK\STX\SOH\ETX\DC2\EOT\232\SOH%&\n\
    \\200\STX\n\
    \\STX\EOT\a\DC2\ACK\245\SOH\NUL\136\STX\SOH\SUB\185\STX A message representing the message types used by a long-running operation.\n\
    \\n\
    \ Example:\n\
    \\n\
    \     rpc Export(ExportRequest) returns (google.longrunning.Operation) {\n\
    \       option (google.longrunning.operation_info) = {\n\
    \         response_type: \"ExportResponse\"\n\
    \         metadata_type: \"ExportMetadata\"\n\
    \       };\n\
    \     }\n\
    \\n\
    \\v\n\
    \\ETX\EOT\a\SOH\DC2\EOT\245\SOH\b\NAK\n\
    \\230\STX\n\
    \\EOT\EOT\a\STX\NUL\DC2\EOT\254\SOH\STX\ESC\SUB\215\STX Required. The message name of the primary return type for this\n\
    \ long-running operation.\n\
    \ This type will be used to deserialize the LRO's response.\n\
    \\n\
    \ If the response is in a different package from the rpc, a fully-qualified\n\
    \ message name must be used (e.g. `google.protobuf.Struct`).\n\
    \\n\
    \ Note: Altering this value constitutes a breaking change.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\a\STX\NUL\ENQ\DC2\EOT\254\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\a\STX\NUL\SOH\DC2\EOT\254\SOH\t\SYN\n\
    \\r\n\
    \\ENQ\EOT\a\STX\NUL\ETX\DC2\EOT\254\SOH\EM\SUB\n\
    \\165\STX\n\
    \\EOT\EOT\a\STX\SOH\DC2\EOT\135\STX\STX\ESC\SUB\150\STX Required. The message name of the metadata type for this long-running\n\
    \ operation.\n\
    \\n\
    \ If the response is in a different package from the rpc, a fully-qualified\n\
    \ message name must be used (e.g. `google.protobuf.Struct`).\n\
    \\n\
    \ Note: Altering this value constitutes a breaking change.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\a\STX\SOH\ENQ\DC2\EOT\135\STX\STX\b\n\
    \\r\n\
    \\ENQ\EOT\a\STX\SOH\SOH\DC2\EOT\135\STX\t\SYN\n\
    \\r\n\
    \\ENQ\EOT\a\STX\SOH\ETX\DC2\EOT\135\STX\EM\SUBb\ACKproto3"