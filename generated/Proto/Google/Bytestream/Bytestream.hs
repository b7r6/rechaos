{- This file was auto-generated from google/bytestream/bytestream.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Google.Bytestream.Bytestream (
        ByteStream(..), QueryWriteStatusRequest(),
        QueryWriteStatusResponse(), ReadRequest(), ReadResponse(),
        WriteRequest(), WriteResponse()
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
{- | Fields :
     
         * 'Proto.Google.Bytestream.Bytestream_Fields.resourceName' @:: Lens' QueryWriteStatusRequest Data.Text.Text@ -}
data QueryWriteStatusRequest
  = QueryWriteStatusRequest'_constructor {_QueryWriteStatusRequest'resourceName :: !Data.Text.Text,
                                          _QueryWriteStatusRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show QueryWriteStatusRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField QueryWriteStatusRequest "resourceName" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _QueryWriteStatusRequest'resourceName
           (\ x__ y__ -> x__ {_QueryWriteStatusRequest'resourceName = y__}))
        Prelude.id
instance Data.ProtoLens.Message QueryWriteStatusRequest where
  messageName _
    = Data.Text.pack "google.bytestream.QueryWriteStatusRequest"
  packedMessageDescriptor _
    = "\n\
      \\ETBQueryWriteStatusRequest\DC2#\n\
      \\rresource_name\CAN\SOH \SOH(\tR\fresourceName"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        resourceName__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "resource_name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"resourceName")) ::
              Data.ProtoLens.FieldDescriptor QueryWriteStatusRequest
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, resourceName__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _QueryWriteStatusRequest'_unknownFields
        (\ x__ y__ -> x__ {_QueryWriteStatusRequest'_unknownFields = y__})
  defMessage
    = QueryWriteStatusRequest'_constructor
        {_QueryWriteStatusRequest'resourceName = Data.ProtoLens.fieldDefault,
         _QueryWriteStatusRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          QueryWriteStatusRequest
          -> Data.ProtoLens.Encoding.Bytes.Parser QueryWriteStatusRequest
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
                                       "resource_name"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"resourceName") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "QueryWriteStatusRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view (Data.ProtoLens.Field.field @"resourceName") _x
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
instance Control.DeepSeq.NFData QueryWriteStatusRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_QueryWriteStatusRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_QueryWriteStatusRequest'resourceName x__) ())
{- | Fields :
     
         * 'Proto.Google.Bytestream.Bytestream_Fields.committedSize' @:: Lens' QueryWriteStatusResponse Data.Int.Int64@
         * 'Proto.Google.Bytestream.Bytestream_Fields.complete' @:: Lens' QueryWriteStatusResponse Prelude.Bool@ -}
data QueryWriteStatusResponse
  = QueryWriteStatusResponse'_constructor {_QueryWriteStatusResponse'committedSize :: !Data.Int.Int64,
                                           _QueryWriteStatusResponse'complete :: !Prelude.Bool,
                                           _QueryWriteStatusResponse'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show QueryWriteStatusResponse where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField QueryWriteStatusResponse "committedSize" Data.Int.Int64 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _QueryWriteStatusResponse'committedSize
           (\ x__ y__ -> x__ {_QueryWriteStatusResponse'committedSize = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField QueryWriteStatusResponse "complete" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _QueryWriteStatusResponse'complete
           (\ x__ y__ -> x__ {_QueryWriteStatusResponse'complete = y__}))
        Prelude.id
instance Data.ProtoLens.Message QueryWriteStatusResponse where
  messageName _
    = Data.Text.pack "google.bytestream.QueryWriteStatusResponse"
  packedMessageDescriptor _
    = "\n\
      \\CANQueryWriteStatusResponse\DC2%\n\
      \\SOcommitted_size\CAN\SOH \SOH(\ETXR\rcommittedSize\DC2\SUB\n\
      \\bcomplete\CAN\STX \SOH(\bR\bcomplete"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        committedSize__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "committed_size"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int64Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int64)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"committedSize")) ::
              Data.ProtoLens.FieldDescriptor QueryWriteStatusResponse
        complete__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "complete"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"complete")) ::
              Data.ProtoLens.FieldDescriptor QueryWriteStatusResponse
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, committedSize__field_descriptor),
           (Data.ProtoLens.Tag 2, complete__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _QueryWriteStatusResponse'_unknownFields
        (\ x__ y__ -> x__ {_QueryWriteStatusResponse'_unknownFields = y__})
  defMessage
    = QueryWriteStatusResponse'_constructor
        {_QueryWriteStatusResponse'committedSize = Data.ProtoLens.fieldDefault,
         _QueryWriteStatusResponse'complete = Data.ProtoLens.fieldDefault,
         _QueryWriteStatusResponse'_unknownFields = []}
  parseMessage
    = let
        loop ::
          QueryWriteStatusResponse
          -> Data.ProtoLens.Encoding.Bytes.Parser QueryWriteStatusResponse
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
                                       "committed_size"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"committedSize") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "complete"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"complete") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "QueryWriteStatusResponse"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view
                      (Data.ProtoLens.Field.field @"committedSize") _x
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
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"complete") _x
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
instance Control.DeepSeq.NFData QueryWriteStatusResponse where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_QueryWriteStatusResponse'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_QueryWriteStatusResponse'committedSize x__)
                (Control.DeepSeq.deepseq
                   (_QueryWriteStatusResponse'complete x__) ()))
{- | Fields :
     
         * 'Proto.Google.Bytestream.Bytestream_Fields.resourceName' @:: Lens' ReadRequest Data.Text.Text@
         * 'Proto.Google.Bytestream.Bytestream_Fields.readOffset' @:: Lens' ReadRequest Data.Int.Int64@
         * 'Proto.Google.Bytestream.Bytestream_Fields.readLimit' @:: Lens' ReadRequest Data.Int.Int64@ -}
data ReadRequest
  = ReadRequest'_constructor {_ReadRequest'resourceName :: !Data.Text.Text,
                              _ReadRequest'readOffset :: !Data.Int.Int64,
                              _ReadRequest'readLimit :: !Data.Int.Int64,
                              _ReadRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show ReadRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField ReadRequest "resourceName" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ReadRequest'resourceName
           (\ x__ y__ -> x__ {_ReadRequest'resourceName = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ReadRequest "readOffset" Data.Int.Int64 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ReadRequest'readOffset
           (\ x__ y__ -> x__ {_ReadRequest'readOffset = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField ReadRequest "readLimit" Data.Int.Int64 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ReadRequest'readLimit
           (\ x__ y__ -> x__ {_ReadRequest'readLimit = y__}))
        Prelude.id
instance Data.ProtoLens.Message ReadRequest where
  messageName _ = Data.Text.pack "google.bytestream.ReadRequest"
  packedMessageDescriptor _
    = "\n\
      \\vReadRequest\DC2#\n\
      \\rresource_name\CAN\SOH \SOH(\tR\fresourceName\DC2\US\n\
      \\vread_offset\CAN\STX \SOH(\ETXR\n\
      \readOffset\DC2\GS\n\
      \\n\
      \read_limit\CAN\ETX \SOH(\ETXR\treadLimit"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        resourceName__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "resource_name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"resourceName")) ::
              Data.ProtoLens.FieldDescriptor ReadRequest
        readOffset__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "read_offset"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int64Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int64)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"readOffset")) ::
              Data.ProtoLens.FieldDescriptor ReadRequest
        readLimit__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "read_limit"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int64Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int64)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"readLimit")) ::
              Data.ProtoLens.FieldDescriptor ReadRequest
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, resourceName__field_descriptor),
           (Data.ProtoLens.Tag 2, readOffset__field_descriptor),
           (Data.ProtoLens.Tag 3, readLimit__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _ReadRequest'_unknownFields
        (\ x__ y__ -> x__ {_ReadRequest'_unknownFields = y__})
  defMessage
    = ReadRequest'_constructor
        {_ReadRequest'resourceName = Data.ProtoLens.fieldDefault,
         _ReadRequest'readOffset = Data.ProtoLens.fieldDefault,
         _ReadRequest'readLimit = Data.ProtoLens.fieldDefault,
         _ReadRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          ReadRequest -> Data.ProtoLens.Encoding.Bytes.Parser ReadRequest
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
                                       "resource_name"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"resourceName") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "read_offset"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"readOffset") y x)
                        24
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "read_limit"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"readLimit") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "ReadRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view (Data.ProtoLens.Field.field @"resourceName") _x
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
                     = Lens.Family2.view (Data.ProtoLens.Field.field @"readOffset") _x
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
                      _v = Lens.Family2.view (Data.ProtoLens.Field.field @"readLimit") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 24)
                            ((Prelude..)
                               Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
                   (Data.ProtoLens.Encoding.Wire.buildFieldSet
                      (Lens.Family2.view Data.ProtoLens.unknownFields _x))))
instance Control.DeepSeq.NFData ReadRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_ReadRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_ReadRequest'resourceName x__)
                (Control.DeepSeq.deepseq
                   (_ReadRequest'readOffset x__)
                   (Control.DeepSeq.deepseq (_ReadRequest'readLimit x__) ())))
{- | Fields :
     
         * 'Proto.Google.Bytestream.Bytestream_Fields.data'' @:: Lens' ReadResponse Data.ByteString.ByteString@ -}
data ReadResponse
  = ReadResponse'_constructor {_ReadResponse'data' :: !Data.ByteString.ByteString,
                               _ReadResponse'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show ReadResponse where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField ReadResponse "data'" Data.ByteString.ByteString where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _ReadResponse'data' (\ x__ y__ -> x__ {_ReadResponse'data' = y__}))
        Prelude.id
instance Data.ProtoLens.Message ReadResponse where
  messageName _ = Data.Text.pack "google.bytestream.ReadResponse"
  packedMessageDescriptor _
    = "\n\
      \\fReadResponse\DC2\DC2\n\
      \\EOTdata\CAN\n\
      \ \SOH(\fR\EOTdata"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        data'__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "data"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BytesField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.ByteString.ByteString)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"data'")) ::
              Data.ProtoLens.FieldDescriptor ReadResponse
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 10, data'__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _ReadResponse'_unknownFields
        (\ x__ y__ -> x__ {_ReadResponse'_unknownFields = y__})
  defMessage
    = ReadResponse'_constructor
        {_ReadResponse'data' = Data.ProtoLens.fieldDefault,
         _ReadResponse'_unknownFields = []}
  parseMessage
    = let
        loop ::
          ReadResponse -> Data.ProtoLens.Encoding.Bytes.Parser ReadResponse
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
                        82
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getBytes
                                             (Prelude.fromIntegral len))
                                       "data"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"data'") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "ReadResponse"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v = Lens.Family2.view (Data.ProtoLens.Field.field @"data'") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 82)
                      ((\ bs
                          -> (Data.Monoid.<>)
                               (Data.ProtoLens.Encoding.Bytes.putVarInt
                                  (Prelude.fromIntegral (Data.ByteString.length bs)))
                               (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                         _v))
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData ReadResponse where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_ReadResponse'_unknownFields x__)
             (Control.DeepSeq.deepseq (_ReadResponse'data' x__) ())
{- | Fields :
     
         * 'Proto.Google.Bytestream.Bytestream_Fields.resourceName' @:: Lens' WriteRequest Data.Text.Text@
         * 'Proto.Google.Bytestream.Bytestream_Fields.writeOffset' @:: Lens' WriteRequest Data.Int.Int64@
         * 'Proto.Google.Bytestream.Bytestream_Fields.finishWrite' @:: Lens' WriteRequest Prelude.Bool@
         * 'Proto.Google.Bytestream.Bytestream_Fields.data'' @:: Lens' WriteRequest Data.ByteString.ByteString@ -}
data WriteRequest
  = WriteRequest'_constructor {_WriteRequest'resourceName :: !Data.Text.Text,
                               _WriteRequest'writeOffset :: !Data.Int.Int64,
                               _WriteRequest'finishWrite :: !Prelude.Bool,
                               _WriteRequest'data' :: !Data.ByteString.ByteString,
                               _WriteRequest'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show WriteRequest where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField WriteRequest "resourceName" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WriteRequest'resourceName
           (\ x__ y__ -> x__ {_WriteRequest'resourceName = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField WriteRequest "writeOffset" Data.Int.Int64 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WriteRequest'writeOffset
           (\ x__ y__ -> x__ {_WriteRequest'writeOffset = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField WriteRequest "finishWrite" Prelude.Bool where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WriteRequest'finishWrite
           (\ x__ y__ -> x__ {_WriteRequest'finishWrite = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField WriteRequest "data'" Data.ByteString.ByteString where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WriteRequest'data' (\ x__ y__ -> x__ {_WriteRequest'data' = y__}))
        Prelude.id
instance Data.ProtoLens.Message WriteRequest where
  messageName _ = Data.Text.pack "google.bytestream.WriteRequest"
  packedMessageDescriptor _
    = "\n\
      \\fWriteRequest\DC2#\n\
      \\rresource_name\CAN\SOH \SOH(\tR\fresourceName\DC2!\n\
      \\fwrite_offset\CAN\STX \SOH(\ETXR\vwriteOffset\DC2!\n\
      \\ffinish_write\CAN\ETX \SOH(\bR\vfinishWrite\DC2\DC2\n\
      \\EOTdata\CAN\n\
      \ \SOH(\fR\EOTdata"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        resourceName__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "resource_name"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"resourceName")) ::
              Data.ProtoLens.FieldDescriptor WriteRequest
        writeOffset__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "write_offset"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int64Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int64)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"writeOffset")) ::
              Data.ProtoLens.FieldDescriptor WriteRequest
        finishWrite__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "finish_write"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BoolField ::
                 Data.ProtoLens.FieldTypeDescriptor Prelude.Bool)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"finishWrite")) ::
              Data.ProtoLens.FieldDescriptor WriteRequest
        data'__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "data"
              (Data.ProtoLens.ScalarField Data.ProtoLens.BytesField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.ByteString.ByteString)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"data'")) ::
              Data.ProtoLens.FieldDescriptor WriteRequest
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, resourceName__field_descriptor),
           (Data.ProtoLens.Tag 2, writeOffset__field_descriptor),
           (Data.ProtoLens.Tag 3, finishWrite__field_descriptor),
           (Data.ProtoLens.Tag 10, data'__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _WriteRequest'_unknownFields
        (\ x__ y__ -> x__ {_WriteRequest'_unknownFields = y__})
  defMessage
    = WriteRequest'_constructor
        {_WriteRequest'resourceName = Data.ProtoLens.fieldDefault,
         _WriteRequest'writeOffset = Data.ProtoLens.fieldDefault,
         _WriteRequest'finishWrite = Data.ProtoLens.fieldDefault,
         _WriteRequest'data' = Data.ProtoLens.fieldDefault,
         _WriteRequest'_unknownFields = []}
  parseMessage
    = let
        loop ::
          WriteRequest -> Data.ProtoLens.Encoding.Bytes.Parser WriteRequest
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
                                       "resource_name"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"resourceName") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "write_offset"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"writeOffset") y x)
                        24
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          ((Prelude./=) 0) Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "finish_write"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"finishWrite") y x)
                        82
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getBytes
                                             (Prelude.fromIntegral len))
                                       "data"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"data'") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "WriteRequest"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view (Data.ProtoLens.Field.field @"resourceName") _x
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
                     = Lens.Family2.view (Data.ProtoLens.Field.field @"writeOffset") _x
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
                      _v
                        = Lens.Family2.view (Data.ProtoLens.Field.field @"finishWrite") _x
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
                      (let
                         _v = Lens.Family2.view (Data.ProtoLens.Field.field @"data'") _x
                       in
                         if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                             Data.Monoid.mempty
                         else
                             (Data.Monoid.<>)
                               (Data.ProtoLens.Encoding.Bytes.putVarInt 82)
                               ((\ bs
                                   -> (Data.Monoid.<>)
                                        (Data.ProtoLens.Encoding.Bytes.putVarInt
                                           (Prelude.fromIntegral (Data.ByteString.length bs)))
                                        (Data.ProtoLens.Encoding.Bytes.putBytes bs))
                                  _v))
                      (Data.ProtoLens.Encoding.Wire.buildFieldSet
                         (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))
instance Control.DeepSeq.NFData WriteRequest where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_WriteRequest'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_WriteRequest'resourceName x__)
                (Control.DeepSeq.deepseq
                   (_WriteRequest'writeOffset x__)
                   (Control.DeepSeq.deepseq
                      (_WriteRequest'finishWrite x__)
                      (Control.DeepSeq.deepseq (_WriteRequest'data' x__) ()))))
{- | Fields :
     
         * 'Proto.Google.Bytestream.Bytestream_Fields.committedSize' @:: Lens' WriteResponse Data.Int.Int64@ -}
data WriteResponse
  = WriteResponse'_constructor {_WriteResponse'committedSize :: !Data.Int.Int64,
                                _WriteResponse'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show WriteResponse where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField WriteResponse "committedSize" Data.Int.Int64 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _WriteResponse'committedSize
           (\ x__ y__ -> x__ {_WriteResponse'committedSize = y__}))
        Prelude.id
instance Data.ProtoLens.Message WriteResponse where
  messageName _ = Data.Text.pack "google.bytestream.WriteResponse"
  packedMessageDescriptor _
    = "\n\
      \\rWriteResponse\DC2%\n\
      \\SOcommitted_size\CAN\SOH \SOH(\ETXR\rcommittedSize"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        committedSize__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "committed_size"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int64Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int64)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"committedSize")) ::
              Data.ProtoLens.FieldDescriptor WriteResponse
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, committedSize__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _WriteResponse'_unknownFields
        (\ x__ y__ -> x__ {_WriteResponse'_unknownFields = y__})
  defMessage
    = WriteResponse'_constructor
        {_WriteResponse'committedSize = Data.ProtoLens.fieldDefault,
         _WriteResponse'_unknownFields = []}
  parseMessage
    = let
        loop ::
          WriteResponse -> Data.ProtoLens.Encoding.Bytes.Parser WriteResponse
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
                                       "committed_size"
                                loop
                                  (Lens.Family2.set
                                     (Data.ProtoLens.Field.field @"committedSize") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "WriteResponse"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v
                  = Lens.Family2.view
                      (Data.ProtoLens.Field.field @"committedSize") _x
              in
                if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                    Data.Monoid.mempty
                else
                    (Data.Monoid.<>)
                      (Data.ProtoLens.Encoding.Bytes.putVarInt 8)
                      ((Prelude..)
                         Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
             (Data.ProtoLens.Encoding.Wire.buildFieldSet
                (Lens.Family2.view Data.ProtoLens.unknownFields _x))
instance Control.DeepSeq.NFData WriteResponse where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_WriteResponse'_unknownFields x__)
             (Control.DeepSeq.deepseq (_WriteResponse'committedSize x__) ())
data ByteStream = ByteStream {}
instance Data.ProtoLens.Service.Types.Service ByteStream where
  type ServiceName ByteStream = "ByteStream"
  type ServicePackage ByteStream = "google.bytestream"
  type ServiceMethods ByteStream = '["queryWriteStatus",
                                     "read",
                                     "write"]
  packedServiceDescriptor _
    = "\n\
      \\n\
      \ByteStream\DC2I\n\
      \\EOTRead\DC2\RS.google.bytestream.ReadRequest\SUB\US.google.bytestream.ReadResponse0\SOH\DC2L\n\
      \\ENQWrite\DC2\US.google.bytestream.WriteRequest\SUB .google.bytestream.WriteResponse(\SOH\DC2k\n\
      \\DLEQueryWriteStatus\DC2*.google.bytestream.QueryWriteStatusRequest\SUB+.google.bytestream.QueryWriteStatusResponse"
instance Data.ProtoLens.Service.Types.HasMethodImpl ByteStream "read" where
  type MethodName ByteStream "read" = "Read"
  type MethodInput ByteStream "read" = ReadRequest
  type MethodOutput ByteStream "read" = ReadResponse
  type MethodStreamingType ByteStream "read" = 'Data.ProtoLens.Service.Types.ServerStreaming
instance Data.ProtoLens.Service.Types.HasMethodImpl ByteStream "write" where
  type MethodName ByteStream "write" = "Write"
  type MethodInput ByteStream "write" = WriteRequest
  type MethodOutput ByteStream "write" = WriteResponse
  type MethodStreamingType ByteStream "write" = 'Data.ProtoLens.Service.Types.ClientStreaming
instance Data.ProtoLens.Service.Types.HasMethodImpl ByteStream "queryWriteStatus" where
  type MethodName ByteStream "queryWriteStatus" = "QueryWriteStatus"
  type MethodInput ByteStream "queryWriteStatus" = QueryWriteStatusRequest
  type MethodOutput ByteStream "queryWriteStatus" = QueryWriteStatusResponse
  type MethodStreamingType ByteStream "queryWriteStatus" = 'Data.ProtoLens.Service.Types.NonStreaming
packedFileDescriptor :: Data.ByteString.ByteString
packedFileDescriptor
  = "\n\
    \\"google/bytestream/bytestream.proto\DC2\DC1google.bytestream\"r\n\
    \\vReadRequest\DC2#\n\
    \\rresource_name\CAN\SOH \SOH(\tR\fresourceName\DC2\US\n\
    \\vread_offset\CAN\STX \SOH(\ETXR\n\
    \readOffset\DC2\GS\n\
    \\n\
    \read_limit\CAN\ETX \SOH(\ETXR\treadLimit\"\"\n\
    \\fReadResponse\DC2\DC2\n\
    \\EOTdata\CAN\n\
    \ \SOH(\fR\EOTdata\"\141\SOH\n\
    \\fWriteRequest\DC2#\n\
    \\rresource_name\CAN\SOH \SOH(\tR\fresourceName\DC2!\n\
    \\fwrite_offset\CAN\STX \SOH(\ETXR\vwriteOffset\DC2!\n\
    \\ffinish_write\CAN\ETX \SOH(\bR\vfinishWrite\DC2\DC2\n\
    \\EOTdata\CAN\n\
    \ \SOH(\fR\EOTdata\"6\n\
    \\rWriteResponse\DC2%\n\
    \\SOcommitted_size\CAN\SOH \SOH(\ETXR\rcommittedSize\">\n\
    \\ETBQueryWriteStatusRequest\DC2#\n\
    \\rresource_name\CAN\SOH \SOH(\tR\fresourceName\"]\n\
    \\CANQueryWriteStatusResponse\DC2%\n\
    \\SOcommitted_size\CAN\SOH \SOH(\ETXR\rcommittedSize\DC2\SUB\n\
    \\bcomplete\CAN\STX \SOH(\bR\bcomplete2\146\STX\n\
    \\n\
    \ByteStream\DC2I\n\
    \\EOTRead\DC2\RS.google.bytestream.ReadRequest\SUB\US.google.bytestream.ReadResponse0\SOH\DC2L\n\
    \\ENQWrite\DC2\US.google.bytestream.WriteRequest\SUB .google.bytestream.WriteResponse(\SOH\DC2k\n\
    \\DLEQueryWriteStatus\DC2*.google.bytestream.QueryWriteStatusRequest\SUB+.google.bytestream.QueryWriteStatusResponseBe\n\
    \\NAKcom.google.bytestreamB\SIByteStreamProtoZ;google.golang.org/genproto/googleapis/bytestream;bytestreamJ\227\&9\n\
    \\a\DC2\ENQ\SO\NUL\177\SOH\SOH\n\
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
    \\SOH\STX\DC2\ETX\DLE\NUL\SUB\n\
    \\b\n\
    \\SOH\b\DC2\ETX\DC2\NULR\n\
    \\t\n\
    \\STX\b\v\DC2\ETX\DC2\NULR\n\
    \\b\n\
    \\SOH\b\DC2\ETX\DC3\NUL0\n\
    \\t\n\
    \\STX\b\b\DC2\ETX\DC3\NUL0\n\
    \\b\n\
    \\SOH\b\DC2\ETX\DC4\NUL.\n\
    \\t\n\
    \\STX\b\SOH\DC2\ETX\DC4\NUL.\n\
    \\191\ACK\n\
    \\STX\ACK\NUL\DC2\EOT-\NUL[\SOH\SUB\178\ACK #### Introduction\n\
    \\n\
    \ The Byte Stream API enables a client to read and write a stream of bytes to\n\
    \ and from a resource. Resources have names, and these names are supplied in\n\
    \ the API calls below to identify the resource that is being read from or\n\
    \ written to.\n\
    \\n\
    \ All implementations of the Byte Stream API export the interface defined here:\n\
    \\n\
    \ * `Read()`: Reads the contents of a resource.\n\
    \\n\
    \ * `Write()`: Writes the contents of a resource. The client can call `Write()`\n\
    \   multiple times with the same resource and can check the status of the write\n\
    \   by calling `QueryWriteStatus()`.\n\
    \\n\
    \ #### Service parameters and metadata\n\
    \\n\
    \ The ByteStream API provides no direct way to access/modify any metadata\n\
    \ associated with the resource.\n\
    \\n\
    \ #### Errors\n\
    \\n\
    \ The errors returned by the service are in the Google canonical error space.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\ACK\NUL\SOH\DC2\ETX-\b\DC2\n\
    \\227\SOH\n\
    \\EOT\ACK\NUL\STX\NUL\DC2\ETX1\STX6\SUB\213\SOH `Read()` is used to retrieve the contents of a resource as a sequence\n\
    \ of bytes. The bytes are returned in a sequence of responses, and the\n\
    \ responses are delivered as the results of a server-side streaming RPC.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\SOH\DC2\ETX1\ACK\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\STX\DC2\ETX1\v\SYN\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\ACK\DC2\ETX1!'\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\NUL\ETX\DC2\ETX1(4\n\
    \\203\t\n\
    \\EOT\ACK\NUL\STX\SOH\DC2\ETXI\STX9\SUB\189\t `Write()` is used to send the contents of a resource as a sequence of\n\
    \ bytes. The bytes are sent in a sequence of request protos of a client-side\n\
    \ streaming RPC.\n\
    \\n\
    \ A `Write()` action is resumable. If there is an error or the connection is\n\
    \ broken during the `Write()`, the client should check the status of the\n\
    \ `Write()` by calling `QueryWriteStatus()` and continue writing from the\n\
    \ returned `committed_size`. This may be less than the amount of data the\n\
    \ client previously sent.\n\
    \\n\
    \ Calling `Write()` on a resource name that was previously written and\n\
    \ finalized could cause an error, depending on whether the underlying service\n\
    \ allows over-writing of previously written resources.\n\
    \\n\
    \ When the client closes the request channel, the service will respond with\n\
    \ a `WriteResponse`. The service will not view the resource as `complete`\n\
    \ until the client has sent a `WriteRequest` with `finish_write` set to\n\
    \ `true`. Sending any requests on a stream after sending a request with\n\
    \ `finish_write` set to `true` will cause an error. The client **should**\n\
    \ check the `WriteResponse` it receives to determine how much data the\n\
    \ service was able to commit and whether the service views the resource as\n\
    \ `complete` or not.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\SOH\DC2\ETXI\ACK\v\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\ENQ\DC2\ETXI\f\DC2\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\STX\DC2\ETXI\DC3\US\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\SOH\ETX\DC2\ETXI*7\n\
    \\224\ENQ\n\
    \\EOT\ACK\NUL\STX\STX\DC2\EOTY\STXZ)\SUB\209\ENQ `QueryWriteStatus()` is used to find the `committed_size` for a resource\n\
    \ that is being written, which can then be used as the `write_offset` for\n\
    \ the next `Write()` call.\n\
    \\n\
    \ If the resource does not exist (i.e., the resource has been deleted, or the\n\
    \ first `Write()` has not yet reached the service), this method returns the\n\
    \ error `NOT_FOUND`.\n\
    \\n\
    \ The client **may** call `QueryWriteStatus()` at any time to determine how\n\
    \ much data has been processed for this resource. This is useful if the\n\
    \ client is buffering data and needs to know which data can be safely\n\
    \ evicted. For any sequence of `QueryWriteStatus()` calls for a given\n\
    \ resource name, the sequence of returned `committed_size` values will be\n\
    \ non-decreasing.\n\
    \\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\SOH\DC2\ETXY\ACK\SYN\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\STX\DC2\ETXY\ETB.\n\
    \\f\n\
    \\ENQ\ACK\NUL\STX\STX\ETX\DC2\ETXZ\SI'\n\
    \1\n\
    \\STX\EOT\NUL\DC2\EOT^\NULq\SOH\SUB% Request object for ByteStream.Read.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\EOT\NUL\SOH\DC2\ETX^\b\DC3\n\
    \0\n\
    \\EOT\EOT\NUL\STX\NUL\DC2\ETX`\STX\ESC\SUB# The name of the resource to read.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ENQ\DC2\ETX`\STX\b\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\SOH\DC2\ETX`\t\SYN\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ETX\DC2\ETX`\EM\SUB\n\
    \\221\SOH\n\
    \\EOT\EOT\NUL\STX\SOH\DC2\ETXg\STX\CAN\SUB\207\SOH The offset for the first byte to return in the read, relative to the start\n\
    \ of the resource.\n\
    \\n\
    \ A `read_offset` that is negative or greater than the size of the resource\n\
    \ will cause an `OUT_OF_RANGE` error.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\ENQ\DC2\ETXg\STX\a\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\SOH\DC2\ETXg\b\DC3\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\ETX\DC2\ETXg\SYN\ETB\n\
    \\151\ETX\n\
    \\EOT\EOT\NUL\STX\STX\DC2\ETXp\STX\ETB\SUB\137\ETX The maximum number of `data` bytes the server is allowed to return in the\n\
    \ sum of all `ReadResponse` messages. A `read_limit` of zero indicates that\n\
    \ there is no limit, and a negative `read_limit` will cause an error.\n\
    \\n\
    \ If the stream returns fewer bytes than allowed by the `read_limit` and no\n\
    \ error occurred, the stream includes all data from the `read_offset` to the\n\
    \ end of the resource.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\STX\ENQ\DC2\ETXp\STX\a\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\STX\SOH\DC2\ETXp\b\DC2\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\STX\ETX\DC2\ETXp\NAK\SYN\n\
    \2\n\
    \\STX\EOT\SOH\DC2\EOTt\NULz\SOH\SUB& Response object for ByteStream.Read.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\EOT\SOH\SOH\DC2\ETXt\b\DC4\n\
    \\132\STX\n\
    \\EOT\EOT\SOH\STX\NUL\DC2\ETXy\STX\DC2\SUB\246\SOH A portion of the data for the resource. The service **may** leave `data`\n\
    \ empty for any given `ReadResponse`. This enables the service to inform the\n\
    \ client that the request is still live while it is running an operation to\n\
    \ generate more data.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\SOH\STX\NUL\ENQ\DC2\ETXy\STX\a\n\
    \\f\n\
    \\ENQ\EOT\SOH\STX\NUL\SOH\DC2\ETXy\b\f\n\
    \\f\n\
    \\ENQ\EOT\SOH\STX\NUL\ETX\DC2\ETXy\SI\DC1\n\
    \3\n\
    \\STX\EOT\STX\DC2\ENQ}\NUL\155\SOH\SOH\SUB& Request object for ByteStream.Write.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\EOT\STX\SOH\DC2\ETX}\b\DC4\n\
    \\212\SOH\n\
    \\EOT\EOT\STX\STX\NUL\DC2\EOT\129\SOH\STX\ESC\SUB\197\SOH The name of the resource to write. This **must** be set on the first\n\
    \ `WriteRequest` of each `Write()` action. If it is set on subsequent calls,\n\
    \ it **must** match the value of the first request.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\ENQ\DC2\EOT\129\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\SOH\DC2\EOT\129\SOH\t\SYN\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\NUL\ETX\DC2\EOT\129\SOH\EM\SUB\n\
    \\191\EOT\n\
    \\EOT\EOT\STX\STX\SOH\DC2\EOT\143\SOH\STX\EM\SUB\176\EOT The offset from the beginning of the resource at which the data should be\n\
    \ written. It is required on all `WriteRequest`s.\n\
    \\n\
    \ In the first `WriteRequest` of a `Write()` action, it indicates\n\
    \ the initial offset for the `Write()` call. The value **must** be equal to\n\
    \ the `committed_size` that a call to `QueryWriteStatus()` would return.\n\
    \\n\
    \ On subsequent calls, this value **must** be set and **must** be equal to\n\
    \ the sum of the first `write_offset` and the sizes of all `data` bundles\n\
    \ sent previously on this stream.\n\
    \\n\
    \ An incorrect value will cause an error.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\ENQ\DC2\EOT\143\SOH\STX\a\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\SOH\DC2\EOT\143\SOH\b\DC4\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\SOH\ETX\DC2\EOT\143\SOH\ETB\CAN\n\
    \\173\SOH\n\
    \\EOT\EOT\STX\STX\STX\DC2\EOT\148\SOH\STX\CAN\SUB\158\SOH If `true`, this indicates that the write is complete. Sending any\n\
    \ `WriteRequest`s subsequent to one in which `finish_write` is `true` will\n\
    \ cause an error.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\ENQ\DC2\EOT\148\SOH\STX\ACK\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\SOH\DC2\EOT\148\SOH\a\DC3\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\STX\ETX\DC2\EOT\148\SOH\SYN\ETB\n\
    \\132\STX\n\
    \\EOT\EOT\STX\STX\ETX\DC2\EOT\154\SOH\STX\DC2\SUB\245\SOH A portion of the data for the resource. The client **may** leave `data`\n\
    \ empty for any given `WriteRequest`. This enables the client to inform the\n\
    \ service that the request is still live while it is running an operation to\n\
    \ generate more data.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\ENQ\DC2\EOT\154\SOH\STX\a\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\SOH\DC2\EOT\154\SOH\b\f\n\
    \\r\n\
    \\ENQ\EOT\STX\STX\ETX\ETX\DC2\EOT\154\SOH\SI\DC1\n\
    \5\n\
    \\STX\EOT\ETX\DC2\ACK\158\SOH\NUL\161\SOH\SOH\SUB' Response object for ByteStream.Write.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ETX\SOH\DC2\EOT\158\SOH\b\NAK\n\
    \T\n\
    \\EOT\EOT\ETX\STX\NUL\DC2\EOT\160\SOH\STX\ESC\SUBF The number of bytes that have been processed for the given resource.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\ENQ\DC2\EOT\160\SOH\STX\a\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\SOH\DC2\EOT\160\SOH\b\SYN\n\
    \\r\n\
    \\ENQ\EOT\ETX\STX\NUL\ETX\DC2\EOT\160\SOH\EM\SUB\n\
    \?\n\
    \\STX\EOT\EOT\DC2\ACK\164\SOH\NUL\167\SOH\SOH\SUB1 Request object for ByteStream.QueryWriteStatus.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\EOT\SOH\DC2\EOT\164\SOH\b\US\n\
    \O\n\
    \\EOT\EOT\EOT\STX\NUL\DC2\EOT\166\SOH\STX\ESC\SUBA The name of the resource whose write status is being requested.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\ENQ\DC2\EOT\166\SOH\STX\b\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\SOH\DC2\EOT\166\SOH\t\SYN\n\
    \\r\n\
    \\ENQ\EOT\EOT\STX\NUL\ETX\DC2\EOT\166\SOH\EM\SUB\n\
    \@\n\
    \\STX\EOT\ENQ\DC2\ACK\170\SOH\NUL\177\SOH\SOH\SUB2 Response object for ByteStream.QueryWriteStatus.\n\
    \\n\
    \\v\n\
    \\ETX\EOT\ENQ\SOH\DC2\EOT\170\SOH\b \n\
    \T\n\
    \\EOT\EOT\ENQ\STX\NUL\DC2\EOT\172\SOH\STX\ESC\SUBF The number of bytes that have been processed for the given resource.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\ENQ\DC2\EOT\172\SOH\STX\a\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\SOH\DC2\EOT\172\SOH\b\SYN\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\NUL\ETX\DC2\EOT\172\SOH\EM\SUB\n\
    \\159\SOH\n\
    \\EOT\EOT\ENQ\STX\SOH\DC2\EOT\176\SOH\STX\DC4\SUB\144\SOH `complete` is `true` only if the client has sent a `WriteRequest` with\n\
    \ `finish_write` set to true, and the server has processed that request.\n\
    \\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\SOH\ENQ\DC2\EOT\176\SOH\STX\ACK\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\SOH\SOH\DC2\EOT\176\SOH\a\SI\n\
    \\r\n\
    \\ENQ\EOT\ENQ\STX\SOH\ETX\DC2\EOT\176\SOH\DC2\DC3b\ACKproto3"