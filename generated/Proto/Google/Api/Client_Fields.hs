{- This file was auto-generated from google/api/client.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Google.Api.Client_Fields where
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
apiShortName ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "apiShortName" a) =>
  Lens.Family2.LensLike' f s a
apiShortName = Data.ProtoLens.Field.field @"apiShortName"
autoPopulatedFields ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "autoPopulatedFields" a) =>
  Lens.Family2.LensLike' f s a
autoPopulatedFields
  = Data.ProtoLens.Field.field @"autoPopulatedFields"
batchDescriptor ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "batchDescriptor" a) =>
  Lens.Family2.LensLike' f s a
batchDescriptor = Data.ProtoLens.Field.field @"batchDescriptor"
batchedField ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "batchedField" a) =>
  Lens.Family2.LensLike' f s a
batchedField = Data.ProtoLens.Field.field @"batchedField"
batching ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "batching" a) =>
  Lens.Family2.LensLike' f s a
batching = Data.ProtoLens.Field.field @"batching"
codeownerGithubTeams ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "codeownerGithubTeams" a) =>
  Lens.Family2.LensLike' f s a
codeownerGithubTeams
  = Data.ProtoLens.Field.field @"codeownerGithubTeams"
common ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "common" a) =>
  Lens.Family2.LensLike' f s a
common = Data.ProtoLens.Field.field @"common"
cppSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "cppSettings" a) =>
  Lens.Family2.LensLike' f s a
cppSettings = Data.ProtoLens.Field.field @"cppSettings"
delayThreshold ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "delayThreshold" a) =>
  Lens.Family2.LensLike' f s a
delayThreshold = Data.ProtoLens.Field.field @"delayThreshold"
destinations ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "destinations" a) =>
  Lens.Family2.LensLike' f s a
destinations = Data.ProtoLens.Field.field @"destinations"
discriminatorFields ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "discriminatorFields" a) =>
  Lens.Family2.LensLike' f s a
discriminatorFields
  = Data.ProtoLens.Field.field @"discriminatorFields"
docTagPrefix ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "docTagPrefix" a) =>
  Lens.Family2.LensLike' f s a
docTagPrefix = Data.ProtoLens.Field.field @"docTagPrefix"
documentationUri ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "documentationUri" a) =>
  Lens.Family2.LensLike' f s a
documentationUri = Data.ProtoLens.Field.field @"documentationUri"
dotnetSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "dotnetSettings" a) =>
  Lens.Family2.LensLike' f s a
dotnetSettings = Data.ProtoLens.Field.field @"dotnetSettings"
elementCountLimit ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "elementCountLimit" a) =>
  Lens.Family2.LensLike' f s a
elementCountLimit = Data.ProtoLens.Field.field @"elementCountLimit"
elementCountThreshold ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "elementCountThreshold" a) =>
  Lens.Family2.LensLike' f s a
elementCountThreshold
  = Data.ProtoLens.Field.field @"elementCountThreshold"
experimentalFeatures ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "experimentalFeatures" a) =>
  Lens.Family2.LensLike' f s a
experimentalFeatures
  = Data.ProtoLens.Field.field @"experimentalFeatures"
flowControlByteLimit ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "flowControlByteLimit" a) =>
  Lens.Family2.LensLike' f s a
flowControlByteLimit
  = Data.ProtoLens.Field.field @"flowControlByteLimit"
flowControlElementLimit ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "flowControlElementLimit" a) =>
  Lens.Family2.LensLike' f s a
flowControlElementLimit
  = Data.ProtoLens.Field.field @"flowControlElementLimit"
flowControlLimitExceededBehavior ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "flowControlLimitExceededBehavior" a) =>
  Lens.Family2.LensLike' f s a
flowControlLimitExceededBehavior
  = Data.ProtoLens.Field.field @"flowControlLimitExceededBehavior"
forcedNamespaceAliases ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "forcedNamespaceAliases" a) =>
  Lens.Family2.LensLike' f s a
forcedNamespaceAliases
  = Data.ProtoLens.Field.field @"forcedNamespaceAliases"
generateOmittedAsInternal ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "generateOmittedAsInternal" a) =>
  Lens.Family2.LensLike' f s a
generateOmittedAsInternal
  = Data.ProtoLens.Field.field @"generateOmittedAsInternal"
githubLabel ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "githubLabel" a) =>
  Lens.Family2.LensLike' f s a
githubLabel = Data.ProtoLens.Field.field @"githubLabel"
goSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "goSettings" a) =>
  Lens.Family2.LensLike' f s a
goSettings = Data.ProtoLens.Field.field @"goSettings"
handwrittenSignatures ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "handwrittenSignatures" a) =>
  Lens.Family2.LensLike' f s a
handwrittenSignatures
  = Data.ProtoLens.Field.field @"handwrittenSignatures"
ignoredResources ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "ignoredResources" a) =>
  Lens.Family2.LensLike' f s a
ignoredResources = Data.ProtoLens.Field.field @"ignoredResources"
initialPollDelay ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "initialPollDelay" a) =>
  Lens.Family2.LensLike' f s a
initialPollDelay = Data.ProtoLens.Field.field @"initialPollDelay"
javaSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "javaSettings" a) =>
  Lens.Family2.LensLike' f s a
javaSettings = Data.ProtoLens.Field.field @"javaSettings"
key ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "key" a) =>
  Lens.Family2.LensLike' f s a
key = Data.ProtoLens.Field.field @"key"
launchStage ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "launchStage" a) =>
  Lens.Family2.LensLike' f s a
launchStage = Data.ProtoLens.Field.field @"launchStage"
libraryPackage ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "libraryPackage" a) =>
  Lens.Family2.LensLike' f s a
libraryPackage = Data.ProtoLens.Field.field @"libraryPackage"
librarySettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "librarySettings" a) =>
  Lens.Family2.LensLike' f s a
librarySettings = Data.ProtoLens.Field.field @"librarySettings"
longRunning ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "longRunning" a) =>
  Lens.Family2.LensLike' f s a
longRunning = Data.ProtoLens.Field.field @"longRunning"
maxPollDelay ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maxPollDelay" a) =>
  Lens.Family2.LensLike' f s a
maxPollDelay = Data.ProtoLens.Field.field @"maxPollDelay"
maybe'batchDescriptor ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'batchDescriptor" a) =>
  Lens.Family2.LensLike' f s a
maybe'batchDescriptor
  = Data.ProtoLens.Field.field @"maybe'batchDescriptor"
maybe'batching ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'batching" a) =>
  Lens.Family2.LensLike' f s a
maybe'batching = Data.ProtoLens.Field.field @"maybe'batching"
maybe'common ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'common" a) =>
  Lens.Family2.LensLike' f s a
maybe'common = Data.ProtoLens.Field.field @"maybe'common"
maybe'cppSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'cppSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'cppSettings = Data.ProtoLens.Field.field @"maybe'cppSettings"
maybe'delayThreshold ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'delayThreshold" a) =>
  Lens.Family2.LensLike' f s a
maybe'delayThreshold
  = Data.ProtoLens.Field.field @"maybe'delayThreshold"
maybe'dotnetSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'dotnetSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'dotnetSettings
  = Data.ProtoLens.Field.field @"maybe'dotnetSettings"
maybe'experimentalFeatures ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'experimentalFeatures" a) =>
  Lens.Family2.LensLike' f s a
maybe'experimentalFeatures
  = Data.ProtoLens.Field.field @"maybe'experimentalFeatures"
maybe'goSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'goSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'goSettings = Data.ProtoLens.Field.field @"maybe'goSettings"
maybe'initialPollDelay ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'initialPollDelay" a) =>
  Lens.Family2.LensLike' f s a
maybe'initialPollDelay
  = Data.ProtoLens.Field.field @"maybe'initialPollDelay"
maybe'javaSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'javaSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'javaSettings
  = Data.ProtoLens.Field.field @"maybe'javaSettings"
maybe'longRunning ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'longRunning" a) =>
  Lens.Family2.LensLike' f s a
maybe'longRunning = Data.ProtoLens.Field.field @"maybe'longRunning"
maybe'maxPollDelay ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'maxPollDelay" a) =>
  Lens.Family2.LensLike' f s a
maybe'maxPollDelay
  = Data.ProtoLens.Field.field @"maybe'maxPollDelay"
maybe'nodeSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'nodeSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'nodeSettings
  = Data.ProtoLens.Field.field @"maybe'nodeSettings"
maybe'phpSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'phpSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'phpSettings = Data.ProtoLens.Field.field @"maybe'phpSettings"
maybe'pythonSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'pythonSettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'pythonSettings
  = Data.ProtoLens.Field.field @"maybe'pythonSettings"
maybe'rubySettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'rubySettings" a) =>
  Lens.Family2.LensLike' f s a
maybe'rubySettings
  = Data.ProtoLens.Field.field @"maybe'rubySettings"
maybe'selectiveGapicGeneration ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'selectiveGapicGeneration" a) =>
  Lens.Family2.LensLike' f s a
maybe'selectiveGapicGeneration
  = Data.ProtoLens.Field.field @"maybe'selectiveGapicGeneration"
maybe'thresholds ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'thresholds" a) =>
  Lens.Family2.LensLike' f s a
maybe'thresholds = Data.ProtoLens.Field.field @"maybe'thresholds"
maybe'totalPollTimeout ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'totalPollTimeout" a) =>
  Lens.Family2.LensLike' f s a
maybe'totalPollTimeout
  = Data.ProtoLens.Field.field @"maybe'totalPollTimeout"
methodSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "methodSettings" a) =>
  Lens.Family2.LensLike' f s a
methodSettings = Data.ProtoLens.Field.field @"methodSettings"
methods ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "methods" a) =>
  Lens.Family2.LensLike' f s a
methods = Data.ProtoLens.Field.field @"methods"
newIssueUri ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "newIssueUri" a) =>
  Lens.Family2.LensLike' f s a
newIssueUri = Data.ProtoLens.Field.field @"newIssueUri"
nodeSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "nodeSettings" a) =>
  Lens.Family2.LensLike' f s a
nodeSettings = Data.ProtoLens.Field.field @"nodeSettings"
organization ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "organization" a) =>
  Lens.Family2.LensLike' f s a
organization = Data.ProtoLens.Field.field @"organization"
phpSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "phpSettings" a) =>
  Lens.Family2.LensLike' f s a
phpSettings = Data.ProtoLens.Field.field @"phpSettings"
pollDelayMultiplier ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "pollDelayMultiplier" a) =>
  Lens.Family2.LensLike' f s a
pollDelayMultiplier
  = Data.ProtoLens.Field.field @"pollDelayMultiplier"
protoReferenceDocumentationUri ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "protoReferenceDocumentationUri" a) =>
  Lens.Family2.LensLike' f s a
protoReferenceDocumentationUri
  = Data.ProtoLens.Field.field @"protoReferenceDocumentationUri"
protobufPythonicTypesEnabled ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "protobufPythonicTypesEnabled" a) =>
  Lens.Family2.LensLike' f s a
protobufPythonicTypesEnabled
  = Data.ProtoLens.Field.field @"protobufPythonicTypesEnabled"
pythonSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "pythonSettings" a) =>
  Lens.Family2.LensLike' f s a
pythonSettings = Data.ProtoLens.Field.field @"pythonSettings"
referenceDocsUri ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "referenceDocsUri" a) =>
  Lens.Family2.LensLike' f s a
referenceDocsUri = Data.ProtoLens.Field.field @"referenceDocsUri"
renamedResources ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "renamedResources" a) =>
  Lens.Family2.LensLike' f s a
renamedResources = Data.ProtoLens.Field.field @"renamedResources"
renamedServices ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "renamedServices" a) =>
  Lens.Family2.LensLike' f s a
renamedServices = Data.ProtoLens.Field.field @"renamedServices"
requestByteLimit ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "requestByteLimit" a) =>
  Lens.Family2.LensLike' f s a
requestByteLimit = Data.ProtoLens.Field.field @"requestByteLimit"
requestByteThreshold ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "requestByteThreshold" a) =>
  Lens.Family2.LensLike' f s a
requestByteThreshold
  = Data.ProtoLens.Field.field @"requestByteThreshold"
restAsyncIoEnabled ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "restAsyncIoEnabled" a) =>
  Lens.Family2.LensLike' f s a
restAsyncIoEnabled
  = Data.ProtoLens.Field.field @"restAsyncIoEnabled"
restNumericEnums ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "restNumericEnums" a) =>
  Lens.Family2.LensLike' f s a
restNumericEnums = Data.ProtoLens.Field.field @"restNumericEnums"
restReferenceDocumentationUri ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "restReferenceDocumentationUri" a) =>
  Lens.Family2.LensLike' f s a
restReferenceDocumentationUri
  = Data.ProtoLens.Field.field @"restReferenceDocumentationUri"
rubySettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "rubySettings" a) =>
  Lens.Family2.LensLike' f s a
rubySettings = Data.ProtoLens.Field.field @"rubySettings"
selectiveGapicGeneration ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "selectiveGapicGeneration" a) =>
  Lens.Family2.LensLike' f s a
selectiveGapicGeneration
  = Data.ProtoLens.Field.field @"selectiveGapicGeneration"
selector ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "selector" a) =>
  Lens.Family2.LensLike' f s a
selector = Data.ProtoLens.Field.field @"selector"
serviceClassNames ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "serviceClassNames" a) =>
  Lens.Family2.LensLike' f s a
serviceClassNames = Data.ProtoLens.Field.field @"serviceClassNames"
subresponseField ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "subresponseField" a) =>
  Lens.Family2.LensLike' f s a
subresponseField = Data.ProtoLens.Field.field @"subresponseField"
thresholds ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "thresholds" a) =>
  Lens.Family2.LensLike' f s a
thresholds = Data.ProtoLens.Field.field @"thresholds"
totalPollTimeout ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "totalPollTimeout" a) =>
  Lens.Family2.LensLike' f s a
totalPollTimeout = Data.ProtoLens.Field.field @"totalPollTimeout"
unversionedPackageDisabled ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "unversionedPackageDisabled" a) =>
  Lens.Family2.LensLike' f s a
unversionedPackageDisabled
  = Data.ProtoLens.Field.field @"unversionedPackageDisabled"
value ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "value" a) =>
  Lens.Family2.LensLike' f s a
value = Data.ProtoLens.Field.field @"value"
vec'autoPopulatedFields ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'autoPopulatedFields" a) =>
  Lens.Family2.LensLike' f s a
vec'autoPopulatedFields
  = Data.ProtoLens.Field.field @"vec'autoPopulatedFields"
vec'codeownerGithubTeams ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'codeownerGithubTeams" a) =>
  Lens.Family2.LensLike' f s a
vec'codeownerGithubTeams
  = Data.ProtoLens.Field.field @"vec'codeownerGithubTeams"
vec'destinations ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'destinations" a) =>
  Lens.Family2.LensLike' f s a
vec'destinations = Data.ProtoLens.Field.field @"vec'destinations"
vec'discriminatorFields ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'discriminatorFields" a) =>
  Lens.Family2.LensLike' f s a
vec'discriminatorFields
  = Data.ProtoLens.Field.field @"vec'discriminatorFields"
vec'forcedNamespaceAliases ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'forcedNamespaceAliases" a) =>
  Lens.Family2.LensLike' f s a
vec'forcedNamespaceAliases
  = Data.ProtoLens.Field.field @"vec'forcedNamespaceAliases"
vec'handwrittenSignatures ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'handwrittenSignatures" a) =>
  Lens.Family2.LensLike' f s a
vec'handwrittenSignatures
  = Data.ProtoLens.Field.field @"vec'handwrittenSignatures"
vec'ignoredResources ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'ignoredResources" a) =>
  Lens.Family2.LensLike' f s a
vec'ignoredResources
  = Data.ProtoLens.Field.field @"vec'ignoredResources"
vec'librarySettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'librarySettings" a) =>
  Lens.Family2.LensLike' f s a
vec'librarySettings
  = Data.ProtoLens.Field.field @"vec'librarySettings"
vec'methodSettings ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'methodSettings" a) =>
  Lens.Family2.LensLike' f s a
vec'methodSettings
  = Data.ProtoLens.Field.field @"vec'methodSettings"
vec'methods ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'methods" a) =>
  Lens.Family2.LensLike' f s a
vec'methods = Data.ProtoLens.Field.field @"vec'methods"
version ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "version" a) =>
  Lens.Family2.LensLike' f s a
version = Data.ProtoLens.Field.field @"version"