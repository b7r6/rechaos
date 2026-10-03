{- This file was auto-generated from build/bazel/semver/semver.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Build.Bazel.Semver.Semver (
        SemVer()
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
     
         * 'Proto.Build.Bazel.Semver.Semver_Fields.major' @:: Lens' SemVer Data.Int.Int32@
         * 'Proto.Build.Bazel.Semver.Semver_Fields.minor' @:: Lens' SemVer Data.Int.Int32@
         * 'Proto.Build.Bazel.Semver.Semver_Fields.patch' @:: Lens' SemVer Data.Int.Int32@
         * 'Proto.Build.Bazel.Semver.Semver_Fields.prerelease' @:: Lens' SemVer Data.Text.Text@ -}
data SemVer
  = SemVer'_constructor {_SemVer'major :: !Data.Int.Int32,
                         _SemVer'minor :: !Data.Int.Int32,
                         _SemVer'patch :: !Data.Int.Int32,
                         _SemVer'prerelease :: !Data.Text.Text,
                         _SemVer'_unknownFields :: !Data.ProtoLens.FieldSet}
  deriving stock (Prelude.Eq, Prelude.Ord)
instance Prelude.Show SemVer where
  showsPrec _ __x __s
    = Prelude.showChar
        '{'
        (Prelude.showString
           (Data.ProtoLens.showMessageShort __x) (Prelude.showChar '}' __s))
instance Data.ProtoLens.Field.HasField SemVer "major" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SemVer'major (\ x__ y__ -> x__ {_SemVer'major = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField SemVer "minor" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SemVer'minor (\ x__ y__ -> x__ {_SemVer'minor = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField SemVer "patch" Data.Int.Int32 where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SemVer'patch (\ x__ y__ -> x__ {_SemVer'patch = y__}))
        Prelude.id
instance Data.ProtoLens.Field.HasField SemVer "prerelease" Data.Text.Text where
  fieldOf _
    = (Prelude..)
        (Lens.Family2.Unchecked.lens
           _SemVer'prerelease (\ x__ y__ -> x__ {_SemVer'prerelease = y__}))
        Prelude.id
instance Data.ProtoLens.Message SemVer where
  messageName _ = Data.Text.pack "build.bazel.semver.SemVer"
  packedMessageDescriptor _
    = "\n\
      \\ACKSemVer\DC2\DC4\n\
      \\ENQmajor\CAN\SOH \SOH(\ENQR\ENQmajor\DC2\DC4\n\
      \\ENQminor\CAN\STX \SOH(\ENQR\ENQminor\DC2\DC4\n\
      \\ENQpatch\CAN\ETX \SOH(\ENQR\ENQpatch\DC2\RS\n\
      \\n\
      \prerelease\CAN\EOT \SOH(\tR\n\
      \prerelease"
  packedFileDescriptor _ = packedFileDescriptor
  fieldsByTag
    = let
        major__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "major"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"major")) ::
              Data.ProtoLens.FieldDescriptor SemVer
        minor__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "minor"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"minor")) ::
              Data.ProtoLens.FieldDescriptor SemVer
        patch__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "patch"
              (Data.ProtoLens.ScalarField Data.ProtoLens.Int32Field ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Int.Int32)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional (Data.ProtoLens.Field.field @"patch")) ::
              Data.ProtoLens.FieldDescriptor SemVer
        prerelease__field_descriptor
          = Data.ProtoLens.FieldDescriptor
              "prerelease"
              (Data.ProtoLens.ScalarField Data.ProtoLens.StringField ::
                 Data.ProtoLens.FieldTypeDescriptor Data.Text.Text)
              (Data.ProtoLens.PlainField
                 Data.ProtoLens.Optional
                 (Data.ProtoLens.Field.field @"prerelease")) ::
              Data.ProtoLens.FieldDescriptor SemVer
      in
        Data.Map.fromList
          [(Data.ProtoLens.Tag 1, major__field_descriptor),
           (Data.ProtoLens.Tag 2, minor__field_descriptor),
           (Data.ProtoLens.Tag 3, patch__field_descriptor),
           (Data.ProtoLens.Tag 4, prerelease__field_descriptor)]
  unknownFields
    = Lens.Family2.Unchecked.lens
        _SemVer'_unknownFields
        (\ x__ y__ -> x__ {_SemVer'_unknownFields = y__})
  defMessage
    = SemVer'_constructor
        {_SemVer'major = Data.ProtoLens.fieldDefault,
         _SemVer'minor = Data.ProtoLens.fieldDefault,
         _SemVer'patch = Data.ProtoLens.fieldDefault,
         _SemVer'prerelease = Data.ProtoLens.fieldDefault,
         _SemVer'_unknownFields = []}
  parseMessage
    = let
        loop :: SemVer -> Data.ProtoLens.Encoding.Bytes.Parser SemVer
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
                                       "major"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"major") y x)
                        16
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "minor"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"minor") y x)
                        24
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (Prelude.fmap
                                          Prelude.fromIntegral
                                          Data.ProtoLens.Encoding.Bytes.getVarInt)
                                       "patch"
                                loop (Lens.Family2.set (Data.ProtoLens.Field.field @"patch") y x)
                        34
                          -> do y <- (Data.ProtoLens.Encoding.Bytes.<?>)
                                       (do len <- Data.ProtoLens.Encoding.Bytes.getVarInt
                                           Data.ProtoLens.Encoding.Bytes.getText
                                             (Prelude.fromIntegral len))
                                       "prerelease"
                                loop
                                  (Lens.Family2.set (Data.ProtoLens.Field.field @"prerelease") y x)
                        wire
                          -> do !y <- Data.ProtoLens.Encoding.Wire.parseTaggedValueFromWire
                                        wire
                                loop
                                  (Lens.Family2.over
                                     Data.ProtoLens.unknownFields (\ !t -> (:) y t) x)
      in
        (Data.ProtoLens.Encoding.Bytes.<?>)
          (do loop Data.ProtoLens.defMessage) "SemVer"
  buildMessage
    = \ _x
        -> (Data.Monoid.<>)
             (let
                _v = Lens.Family2.view (Data.ProtoLens.Field.field @"major") _x
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
                   _v = Lens.Family2.view (Data.ProtoLens.Field.field @"minor") _x
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
                      _v = Lens.Family2.view (Data.ProtoLens.Field.field @"patch") _x
                    in
                      if (Prelude.==) _v Data.ProtoLens.fieldDefault then
                          Data.Monoid.mempty
                      else
                          (Data.Monoid.<>)
                            (Data.ProtoLens.Encoding.Bytes.putVarInt 24)
                            ((Prelude..)
                               Data.ProtoLens.Encoding.Bytes.putVarInt Prelude.fromIntegral _v))
                   ((Data.Monoid.<>)
                      (let
                         _v
                           = Lens.Family2.view (Data.ProtoLens.Field.field @"prerelease") _x
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
                      (Data.ProtoLens.Encoding.Wire.buildFieldSet
                         (Lens.Family2.view Data.ProtoLens.unknownFields _x)))))
instance Control.DeepSeq.NFData SemVer where
  rnf
    = \ x__
        -> Control.DeepSeq.deepseq
             (_SemVer'_unknownFields x__)
             (Control.DeepSeq.deepseq
                (_SemVer'major x__)
                (Control.DeepSeq.deepseq
                   (_SemVer'minor x__)
                   (Control.DeepSeq.deepseq
                      (_SemVer'patch x__)
                      (Control.DeepSeq.deepseq (_SemVer'prerelease x__) ()))))
packedFileDescriptor :: Data.ByteString.ByteString
packedFileDescriptor
  = "\n\
    \\USbuild/bazel/semver/semver.proto\DC2\DC2build.bazel.semver\"j\n\
    \\ACKSemVer\DC2\DC4\n\
    \\ENQmajor\CAN\SOH \SOH(\ENQR\ENQmajor\DC2\DC4\n\
    \\ENQminor\CAN\STX \SOH(\ENQR\ENQminor\DC2\DC4\n\
    \\ENQpatch\CAN\ETX \SOH(\ENQR\ENQpatch\DC2\RS\n\
    \\n\
    \prerelease\CAN\EOT \SOH(\tR\n\
    \prereleaseBt\n\
    \\DC2build.bazel.semverB\vSemverProtoP\SOHZ4github.com/bazelbuild/remote-apis/build/bazel/semver\162\STX\ETXSMV\170\STX\DC2Build.Bazel.SemverJ\176\n\
    \\n\
    \\ACK\DC2\EOT\SO\NUL(\SOH\n\
    \\196\EOT\n\
    \\SOH\f\DC2\ETX\SO\NUL\DC22\185\EOT Copyright 2018 The Bazel Authors.\n\
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
    \\b\n\
    \\SOH\b\DC2\ETX\DC2\NUL/\n\
    \\t\n\
    \\STX\b%\DC2\ETX\DC2\NUL/\n\
    \\b\n\
    \\SOH\b\DC2\ETX\DC3\NULK\n\
    \\t\n\
    \\STX\b\v\DC2\ETX\DC3\NULK\n\
    \\b\n\
    \\SOH\b\DC2\ETX\DC4\NUL\"\n\
    \\t\n\
    \\STX\b\n\
    \\DC2\ETX\DC4\NUL\"\n\
    \\b\n\
    \\SOH\b\DC2\ETX\NAK\NUL,\n\
    \\t\n\
    \\STX\b\b\DC2\ETX\NAK\NUL,\n\
    \\b\n\
    \\SOH\b\DC2\ETX\SYN\NUL+\n\
    \\t\n\
    \\STX\b\SOH\DC2\ETX\SYN\NUL+\n\
    \\b\n\
    \\SOH\b\DC2\ETX\ETB\NUL!\n\
    \\t\n\
    \\STX\b$\DC2\ETX\ETB\NUL!\n\
    \/\n\
    \\STX\EOT\NUL\DC2\EOT\SUB\NUL(\SOH\SUB# The full version of a given tool.\n\
    \\n\
    \\n\
    \\n\
    \\ETX\EOT\NUL\SOH\DC2\ETX\SUB\b\SO\n\
    \4\n\
    \\EOT\EOT\NUL\STX\NUL\DC2\ETX\FS\STX\DC2\SUB' The major version, e.g 10 for 10.2.3.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ENQ\DC2\ETX\FS\STX\a\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\SOH\DC2\ETX\FS\b\r\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\NUL\ETX\DC2\ETX\FS\DLE\DC1\n\
    \4\n\
    \\EOT\EOT\NUL\STX\SOH\DC2\ETX\US\STX\DC2\SUB' The minor version, e.g. 2 for 10.2.3.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\ENQ\DC2\ETX\US\STX\a\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\SOH\DC2\ETX\US\b\r\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\SOH\ETX\DC2\ETX\US\DLE\DC1\n\
    \3\n\
    \\EOT\EOT\NUL\STX\STX\DC2\ETX\"\STX\DC2\SUB& The patch version, e.g 3 for 10.2.3.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\STX\ENQ\DC2\ETX\"\STX\a\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\STX\SOH\DC2\ETX\"\b\r\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\STX\ETX\DC2\ETX\"\DLE\DC1\n\
    \\208\SOH\n\
    \\EOT\EOT\NUL\STX\ETX\DC2\ETX'\STX\CAN\SUB\194\SOH The pre-release version. Either this field or major/minor/patch fields\n\
    \ must be filled. They are mutually exclusive. Pre-release versions are\n\
    \ assumed to be earlier than any released versions.\n\
    \\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\ETX\ENQ\DC2\ETX'\STX\b\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\ETX\SOH\DC2\ETX'\t\DC3\n\
    \\f\n\
    \\ENQ\EOT\NUL\STX\ETX\ETX\DC2\ETX'\SYN\ETBb\ACKproto3"