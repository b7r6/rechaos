{- This file was auto-generated from build/bazel/remote/execution/v2/remote_execution.proto by the proto-lens-protoc program. -}
{-# LANGUAGE ScopedTypeVariables, DataKinds, TypeFamilies, UndecidableInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, FlexibleContexts, FlexibleInstances, PatternSynonyms, MagicHash, NoImplicitPrelude, DataKinds, BangPatterns, TypeApplications, OverloadedStrings, DerivingStrategies#-}
{-# OPTIONS_GHC -Wno-unused-imports#-}
{-# OPTIONS_GHC -Wno-duplicate-exports#-}
{-# OPTIONS_GHC -Wno-dodgy-exports#-}
module Proto.Build.Bazel.Remote.Execution.V2.RemoteExecution_Fields where
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
import qualified Proto.Build.Bazel.Semver.Semver
import qualified Proto.Google.Api.Annotations
import qualified Proto.Google.Longrunning.Operations
import qualified Proto.Google.Protobuf.Any
import qualified Proto.Google.Protobuf.Duration
import qualified Proto.Google.Protobuf.Timestamp
import qualified Proto.Google.Protobuf.Wrappers
import qualified Proto.Google.Rpc.Status
acceptableCompressors ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "acceptableCompressors" a) =>
  Lens.Family2.LensLike' f s a
acceptableCompressors
  = Data.ProtoLens.Field.field @"acceptableCompressors"
actionCacheUpdateCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "actionCacheUpdateCapabilities" a) =>
  Lens.Family2.LensLike' f s a
actionCacheUpdateCapabilities
  = Data.ProtoLens.Field.field @"actionCacheUpdateCapabilities"
actionDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "actionDigest" a) =>
  Lens.Family2.LensLike' f s a
actionDigest = Data.ProtoLens.Field.field @"actionDigest"
actionId ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "actionId" a) =>
  Lens.Family2.LensLike' f s a
actionId = Data.ProtoLens.Field.field @"actionId"
actionMnemonic ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "actionMnemonic" a) =>
  Lens.Family2.LensLike' f s a
actionMnemonic = Data.ProtoLens.Field.field @"actionMnemonic"
actionResult ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "actionResult" a) =>
  Lens.Family2.LensLike' f s a
actionResult = Data.ProtoLens.Field.field @"actionResult"
arguments ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "arguments" a) =>
  Lens.Family2.LensLike' f s a
arguments = Data.ProtoLens.Field.field @"arguments"
auxiliaryMetadata ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "auxiliaryMetadata" a) =>
  Lens.Family2.LensLike' f s a
auxiliaryMetadata = Data.ProtoLens.Field.field @"auxiliaryMetadata"
avgChunkSizeBytes ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "avgChunkSizeBytes" a) =>
  Lens.Family2.LensLike' f s a
avgChunkSizeBytes = Data.ProtoLens.Field.field @"avgChunkSizeBytes"
blobDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "blobDigest" a) =>
  Lens.Family2.LensLike' f s a
blobDigest = Data.ProtoLens.Field.field @"blobDigest"
blobDigests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "blobDigests" a) =>
  Lens.Family2.LensLike' f s a
blobDigests = Data.ProtoLens.Field.field @"blobDigests"
cacheCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "cacheCapabilities" a) =>
  Lens.Family2.LensLike' f s a
cacheCapabilities = Data.ProtoLens.Field.field @"cacheCapabilities"
cachePriorityCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "cachePriorityCapabilities" a) =>
  Lens.Family2.LensLike' f s a
cachePriorityCapabilities
  = Data.ProtoLens.Field.field @"cachePriorityCapabilities"
cachedResult ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "cachedResult" a) =>
  Lens.Family2.LensLike' f s a
cachedResult = Data.ProtoLens.Field.field @"cachedResult"
children ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "children" a) =>
  Lens.Family2.LensLike' f s a
children = Data.ProtoLens.Field.field @"children"
chunkDigests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "chunkDigests" a) =>
  Lens.Family2.LensLike' f s a
chunkDigests = Data.ProtoLens.Field.field @"chunkDigests"
chunkingFunction ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "chunkingFunction" a) =>
  Lens.Family2.LensLike' f s a
chunkingFunction = Data.ProtoLens.Field.field @"chunkingFunction"
commandDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "commandDigest" a) =>
  Lens.Family2.LensLike' f s a
commandDigest = Data.ProtoLens.Field.field @"commandDigest"
compressor ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "compressor" a) =>
  Lens.Family2.LensLike' f s a
compressor = Data.ProtoLens.Field.field @"compressor"
configurationId ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "configurationId" a) =>
  Lens.Family2.LensLike' f s a
configurationId = Data.ProtoLens.Field.field @"configurationId"
contents ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "contents" a) =>
  Lens.Family2.LensLike' f s a
contents = Data.ProtoLens.Field.field @"contents"
correlatedInvocationsId ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "correlatedInvocationsId" a) =>
  Lens.Family2.LensLike' f s a
correlatedInvocationsId
  = Data.ProtoLens.Field.field @"correlatedInvocationsId"
data' ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "data'" a) =>
  Lens.Family2.LensLike' f s a
data' = Data.ProtoLens.Field.field @"data'"
deprecatedApiVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "deprecatedApiVersion" a) =>
  Lens.Family2.LensLike' f s a
deprecatedApiVersion
  = Data.ProtoLens.Field.field @"deprecatedApiVersion"
digest ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "digest" a) =>
  Lens.Family2.LensLike' f s a
digest = Data.ProtoLens.Field.field @"digest"
digestFunction ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "digestFunction" a) =>
  Lens.Family2.LensLike' f s a
digestFunction = Data.ProtoLens.Field.field @"digestFunction"
digestFunctions ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "digestFunctions" a) =>
  Lens.Family2.LensLike' f s a
digestFunctions = Data.ProtoLens.Field.field @"digestFunctions"
digests ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "digests" a) =>
  Lens.Family2.LensLike' f s a
digests = Data.ProtoLens.Field.field @"digests"
directories ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "directories" a) =>
  Lens.Family2.LensLike' f s a
directories = Data.ProtoLens.Field.field @"directories"
doNotCache ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "doNotCache" a) =>
  Lens.Family2.LensLike' f s a
doNotCache = Data.ProtoLens.Field.field @"doNotCache"
environmentVariables ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "environmentVariables" a) =>
  Lens.Family2.LensLike' f s a
environmentVariables
  = Data.ProtoLens.Field.field @"environmentVariables"
execEnabled ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "execEnabled" a) =>
  Lens.Family2.LensLike' f s a
execEnabled = Data.ProtoLens.Field.field @"execEnabled"
executionCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "executionCapabilities" a) =>
  Lens.Family2.LensLike' f s a
executionCapabilities
  = Data.ProtoLens.Field.field @"executionCapabilities"
executionCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "executionCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
executionCompletedTimestamp
  = Data.ProtoLens.Field.field @"executionCompletedTimestamp"
executionMetadata ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "executionMetadata" a) =>
  Lens.Family2.LensLike' f s a
executionMetadata = Data.ProtoLens.Field.field @"executionMetadata"
executionPolicy ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "executionPolicy" a) =>
  Lens.Family2.LensLike' f s a
executionPolicy = Data.ProtoLens.Field.field @"executionPolicy"
executionPriorityCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "executionPriorityCapabilities" a) =>
  Lens.Family2.LensLike' f s a
executionPriorityCapabilities
  = Data.ProtoLens.Field.field @"executionPriorityCapabilities"
executionStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "executionStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
executionStartTimestamp
  = Data.ProtoLens.Field.field @"executionStartTimestamp"
exitCode ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "exitCode" a) =>
  Lens.Family2.LensLike' f s a
exitCode = Data.ProtoLens.Field.field @"exitCode"
fastCdc2020Params ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "fastCdc2020Params" a) =>
  Lens.Family2.LensLike' f s a
fastCdc2020Params = Data.ProtoLens.Field.field @"fastCdc2020Params"
files ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "files" a) =>
  Lens.Family2.LensLike' f s a
files = Data.ProtoLens.Field.field @"files"
hash ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "hash" a) =>
  Lens.Family2.LensLike' f s a
hash = Data.ProtoLens.Field.field @"hash"
highApiVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "highApiVersion" a) =>
  Lens.Family2.LensLike' f s a
highApiVersion = Data.ProtoLens.Field.field @"highApiVersion"
horizonSizeBytes ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "horizonSizeBytes" a) =>
  Lens.Family2.LensLike' f s a
horizonSizeBytes = Data.ProtoLens.Field.field @"horizonSizeBytes"
humanReadable ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "humanReadable" a) =>
  Lens.Family2.LensLike' f s a
humanReadable = Data.ProtoLens.Field.field @"humanReadable"
inlineOutputFiles ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "inlineOutputFiles" a) =>
  Lens.Family2.LensLike' f s a
inlineOutputFiles = Data.ProtoLens.Field.field @"inlineOutputFiles"
inlineStderr ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "inlineStderr" a) =>
  Lens.Family2.LensLike' f s a
inlineStderr = Data.ProtoLens.Field.field @"inlineStderr"
inlineStdout ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "inlineStdout" a) =>
  Lens.Family2.LensLike' f s a
inlineStdout = Data.ProtoLens.Field.field @"inlineStdout"
inputFetchCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "inputFetchCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
inputFetchCompletedTimestamp
  = Data.ProtoLens.Field.field @"inputFetchCompletedTimestamp"
inputFetchStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "inputFetchStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
inputFetchStartTimestamp
  = Data.ProtoLens.Field.field @"inputFetchStartTimestamp"
inputRootDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "inputRootDigest" a) =>
  Lens.Family2.LensLike' f s a
inputRootDigest = Data.ProtoLens.Field.field @"inputRootDigest"
instanceName ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "instanceName" a) =>
  Lens.Family2.LensLike' f s a
instanceName = Data.ProtoLens.Field.field @"instanceName"
isExecutable ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "isExecutable" a) =>
  Lens.Family2.LensLike' f s a
isExecutable = Data.ProtoLens.Field.field @"isExecutable"
isTopologicallySorted ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "isTopologicallySorted" a) =>
  Lens.Family2.LensLike' f s a
isTopologicallySorted
  = Data.ProtoLens.Field.field @"isTopologicallySorted"
key ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "key" a) =>
  Lens.Family2.LensLike' f s a
key = Data.ProtoLens.Field.field @"key"
lowApiVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "lowApiVersion" a) =>
  Lens.Family2.LensLike' f s a
lowApiVersion = Data.ProtoLens.Field.field @"lowApiVersion"
maxBatchTotalSizeBytes ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maxBatchTotalSizeBytes" a) =>
  Lens.Family2.LensLike' f s a
maxBatchTotalSizeBytes
  = Data.ProtoLens.Field.field @"maxBatchTotalSizeBytes"
maxCasBlobSizeBytes ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maxCasBlobSizeBytes" a) =>
  Lens.Family2.LensLike' f s a
maxCasBlobSizeBytes
  = Data.ProtoLens.Field.field @"maxCasBlobSizeBytes"
maxPriority ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maxPriority" a) =>
  Lens.Family2.LensLike' f s a
maxPriority = Data.ProtoLens.Field.field @"maxPriority"
maybe'actionCacheUpdateCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'actionCacheUpdateCapabilities" a) =>
  Lens.Family2.LensLike' f s a
maybe'actionCacheUpdateCapabilities
  = Data.ProtoLens.Field.field @"maybe'actionCacheUpdateCapabilities"
maybe'actionDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'actionDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'actionDigest
  = Data.ProtoLens.Field.field @"maybe'actionDigest"
maybe'actionResult ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'actionResult" a) =>
  Lens.Family2.LensLike' f s a
maybe'actionResult
  = Data.ProtoLens.Field.field @"maybe'actionResult"
maybe'blobDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'blobDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'blobDigest = Data.ProtoLens.Field.field @"maybe'blobDigest"
maybe'cacheCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'cacheCapabilities" a) =>
  Lens.Family2.LensLike' f s a
maybe'cacheCapabilities
  = Data.ProtoLens.Field.field @"maybe'cacheCapabilities"
maybe'cachePriorityCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'cachePriorityCapabilities" a) =>
  Lens.Family2.LensLike' f s a
maybe'cachePriorityCapabilities
  = Data.ProtoLens.Field.field @"maybe'cachePriorityCapabilities"
maybe'commandDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'commandDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'commandDigest
  = Data.ProtoLens.Field.field @"maybe'commandDigest"
maybe'deprecatedApiVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'deprecatedApiVersion" a) =>
  Lens.Family2.LensLike' f s a
maybe'deprecatedApiVersion
  = Data.ProtoLens.Field.field @"maybe'deprecatedApiVersion"
maybe'digest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'digest" a) =>
  Lens.Family2.LensLike' f s a
maybe'digest = Data.ProtoLens.Field.field @"maybe'digest"
maybe'executionCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'executionCapabilities" a) =>
  Lens.Family2.LensLike' f s a
maybe'executionCapabilities
  = Data.ProtoLens.Field.field @"maybe'executionCapabilities"
maybe'executionCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'executionCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'executionCompletedTimestamp
  = Data.ProtoLens.Field.field @"maybe'executionCompletedTimestamp"
maybe'executionMetadata ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'executionMetadata" a) =>
  Lens.Family2.LensLike' f s a
maybe'executionMetadata
  = Data.ProtoLens.Field.field @"maybe'executionMetadata"
maybe'executionPolicy ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'executionPolicy" a) =>
  Lens.Family2.LensLike' f s a
maybe'executionPolicy
  = Data.ProtoLens.Field.field @"maybe'executionPolicy"
maybe'executionPriorityCapabilities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'executionPriorityCapabilities" a) =>
  Lens.Family2.LensLike' f s a
maybe'executionPriorityCapabilities
  = Data.ProtoLens.Field.field @"maybe'executionPriorityCapabilities"
maybe'executionStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'executionStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'executionStartTimestamp
  = Data.ProtoLens.Field.field @"maybe'executionStartTimestamp"
maybe'fastCdc2020Params ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'fastCdc2020Params" a) =>
  Lens.Family2.LensLike' f s a
maybe'fastCdc2020Params
  = Data.ProtoLens.Field.field @"maybe'fastCdc2020Params"
maybe'highApiVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'highApiVersion" a) =>
  Lens.Family2.LensLike' f s a
maybe'highApiVersion
  = Data.ProtoLens.Field.field @"maybe'highApiVersion"
maybe'inputFetchCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'inputFetchCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'inputFetchCompletedTimestamp
  = Data.ProtoLens.Field.field @"maybe'inputFetchCompletedTimestamp"
maybe'inputFetchStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'inputFetchStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'inputFetchStartTimestamp
  = Data.ProtoLens.Field.field @"maybe'inputFetchStartTimestamp"
maybe'inputRootDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'inputRootDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'inputRootDigest
  = Data.ProtoLens.Field.field @"maybe'inputRootDigest"
maybe'lowApiVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'lowApiVersion" a) =>
  Lens.Family2.LensLike' f s a
maybe'lowApiVersion
  = Data.ProtoLens.Field.field @"maybe'lowApiVersion"
maybe'mtime ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'mtime" a) =>
  Lens.Family2.LensLike' f s a
maybe'mtime = Data.ProtoLens.Field.field @"maybe'mtime"
maybe'nodeProperties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'nodeProperties" a) =>
  Lens.Family2.LensLike' f s a
maybe'nodeProperties
  = Data.ProtoLens.Field.field @"maybe'nodeProperties"
maybe'outputUploadCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'outputUploadCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'outputUploadCompletedTimestamp
  = Data.ProtoLens.Field.field
      @"maybe'outputUploadCompletedTimestamp"
maybe'outputUploadStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'outputUploadStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'outputUploadStartTimestamp
  = Data.ProtoLens.Field.field @"maybe'outputUploadStartTimestamp"
maybe'partialExecutionMetadata ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'partialExecutionMetadata" a) =>
  Lens.Family2.LensLike' f s a
maybe'partialExecutionMetadata
  = Data.ProtoLens.Field.field @"maybe'partialExecutionMetadata"
maybe'platform ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'platform" a) =>
  Lens.Family2.LensLike' f s a
maybe'platform = Data.ProtoLens.Field.field @"maybe'platform"
maybe'queuedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'queuedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'queuedTimestamp
  = Data.ProtoLens.Field.field @"maybe'queuedTimestamp"
maybe'repMaxCdcParams ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'repMaxCdcParams" a) =>
  Lens.Family2.LensLike' f s a
maybe'repMaxCdcParams
  = Data.ProtoLens.Field.field @"maybe'repMaxCdcParams"
maybe'result ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'result" a) =>
  Lens.Family2.LensLike' f s a
maybe'result = Data.ProtoLens.Field.field @"maybe'result"
maybe'resultsCachePolicy ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'resultsCachePolicy" a) =>
  Lens.Family2.LensLike' f s a
maybe'resultsCachePolicy
  = Data.ProtoLens.Field.field @"maybe'resultsCachePolicy"
maybe'root ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'root" a) =>
  Lens.Family2.LensLike' f s a
maybe'root = Data.ProtoLens.Field.field @"maybe'root"
maybe'rootDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'rootDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'rootDigest = Data.ProtoLens.Field.field @"maybe'rootDigest"
maybe'rootDirectoryDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'rootDirectoryDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'rootDirectoryDigest
  = Data.ProtoLens.Field.field @"maybe'rootDirectoryDigest"
maybe'status ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'status" a) =>
  Lens.Family2.LensLike' f s a
maybe'status = Data.ProtoLens.Field.field @"maybe'status"
maybe'stderrDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'stderrDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'stderrDigest
  = Data.ProtoLens.Field.field @"maybe'stderrDigest"
maybe'stdoutDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'stdoutDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'stdoutDigest
  = Data.ProtoLens.Field.field @"maybe'stdoutDigest"
maybe'timeout ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'timeout" a) =>
  Lens.Family2.LensLike' f s a
maybe'timeout = Data.ProtoLens.Field.field @"maybe'timeout"
maybe'toolDetails ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'toolDetails" a) =>
  Lens.Family2.LensLike' f s a
maybe'toolDetails = Data.ProtoLens.Field.field @"maybe'toolDetails"
maybe'treeDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'treeDigest" a) =>
  Lens.Family2.LensLike' f s a
maybe'treeDigest = Data.ProtoLens.Field.field @"maybe'treeDigest"
maybe'unixMode ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'unixMode" a) =>
  Lens.Family2.LensLike' f s a
maybe'unixMode = Data.ProtoLens.Field.field @"maybe'unixMode"
maybe'value ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'value" a) =>
  Lens.Family2.LensLike' f s a
maybe'value = Data.ProtoLens.Field.field @"maybe'value"
maybe'virtualExecutionDuration ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'virtualExecutionDuration" a) =>
  Lens.Family2.LensLike' f s a
maybe'virtualExecutionDuration
  = Data.ProtoLens.Field.field @"maybe'virtualExecutionDuration"
maybe'workerCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'workerCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'workerCompletedTimestamp
  = Data.ProtoLens.Field.field @"maybe'workerCompletedTimestamp"
maybe'workerStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "maybe'workerStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
maybe'workerStartTimestamp
  = Data.ProtoLens.Field.field @"maybe'workerStartTimestamp"
message ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "message" a) =>
  Lens.Family2.LensLike' f s a
message = Data.ProtoLens.Field.field @"message"
minChunkSizeBytes ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "minChunkSizeBytes" a) =>
  Lens.Family2.LensLike' f s a
minChunkSizeBytes = Data.ProtoLens.Field.field @"minChunkSizeBytes"
minPriority ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "minPriority" a) =>
  Lens.Family2.LensLike' f s a
minPriority = Data.ProtoLens.Field.field @"minPriority"
missingBlobDigests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "missingBlobDigests" a) =>
  Lens.Family2.LensLike' f s a
missingBlobDigests
  = Data.ProtoLens.Field.field @"missingBlobDigests"
mtime ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "mtime" a) =>
  Lens.Family2.LensLike' f s a
mtime = Data.ProtoLens.Field.field @"mtime"
name ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "name" a) =>
  Lens.Family2.LensLike' f s a
name = Data.ProtoLens.Field.field @"name"
nextPageToken ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "nextPageToken" a) =>
  Lens.Family2.LensLike' f s a
nextPageToken = Data.ProtoLens.Field.field @"nextPageToken"
nodeProperties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "nodeProperties" a) =>
  Lens.Family2.LensLike' f s a
nodeProperties = Data.ProtoLens.Field.field @"nodeProperties"
outputDirectories ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputDirectories" a) =>
  Lens.Family2.LensLike' f s a
outputDirectories = Data.ProtoLens.Field.field @"outputDirectories"
outputDirectoryFormat ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputDirectoryFormat" a) =>
  Lens.Family2.LensLike' f s a
outputDirectoryFormat
  = Data.ProtoLens.Field.field @"outputDirectoryFormat"
outputDirectorySymlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputDirectorySymlinks" a) =>
  Lens.Family2.LensLike' f s a
outputDirectorySymlinks
  = Data.ProtoLens.Field.field @"outputDirectorySymlinks"
outputFileSymlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputFileSymlinks" a) =>
  Lens.Family2.LensLike' f s a
outputFileSymlinks
  = Data.ProtoLens.Field.field @"outputFileSymlinks"
outputFiles ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputFiles" a) =>
  Lens.Family2.LensLike' f s a
outputFiles = Data.ProtoLens.Field.field @"outputFiles"
outputNodeProperties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputNodeProperties" a) =>
  Lens.Family2.LensLike' f s a
outputNodeProperties
  = Data.ProtoLens.Field.field @"outputNodeProperties"
outputPaths ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputPaths" a) =>
  Lens.Family2.LensLike' f s a
outputPaths = Data.ProtoLens.Field.field @"outputPaths"
outputSymlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputSymlinks" a) =>
  Lens.Family2.LensLike' f s a
outputSymlinks = Data.ProtoLens.Field.field @"outputSymlinks"
outputUploadCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputUploadCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
outputUploadCompletedTimestamp
  = Data.ProtoLens.Field.field @"outputUploadCompletedTimestamp"
outputUploadStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "outputUploadStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
outputUploadStartTimestamp
  = Data.ProtoLens.Field.field @"outputUploadStartTimestamp"
pageSize ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "pageSize" a) =>
  Lens.Family2.LensLike' f s a
pageSize = Data.ProtoLens.Field.field @"pageSize"
pageToken ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "pageToken" a) =>
  Lens.Family2.LensLike' f s a
pageToken = Data.ProtoLens.Field.field @"pageToken"
partialExecutionMetadata ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "partialExecutionMetadata" a) =>
  Lens.Family2.LensLike' f s a
partialExecutionMetadata
  = Data.ProtoLens.Field.field @"partialExecutionMetadata"
path ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "path" a) =>
  Lens.Family2.LensLike' f s a
path = Data.ProtoLens.Field.field @"path"
platform ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "platform" a) =>
  Lens.Family2.LensLike' f s a
platform = Data.ProtoLens.Field.field @"platform"
priorities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "priorities" a) =>
  Lens.Family2.LensLike' f s a
priorities = Data.ProtoLens.Field.field @"priorities"
priority ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "priority" a) =>
  Lens.Family2.LensLike' f s a
priority = Data.ProtoLens.Field.field @"priority"
properties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "properties" a) =>
  Lens.Family2.LensLike' f s a
properties = Data.ProtoLens.Field.field @"properties"
queuedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "queuedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
queuedTimestamp = Data.ProtoLens.Field.field @"queuedTimestamp"
repMaxCdcParams ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "repMaxCdcParams" a) =>
  Lens.Family2.LensLike' f s a
repMaxCdcParams = Data.ProtoLens.Field.field @"repMaxCdcParams"
requests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "requests" a) =>
  Lens.Family2.LensLike' f s a
requests = Data.ProtoLens.Field.field @"requests"
responses ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "responses" a) =>
  Lens.Family2.LensLike' f s a
responses = Data.ProtoLens.Field.field @"responses"
result ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "result" a) =>
  Lens.Family2.LensLike' f s a
result = Data.ProtoLens.Field.field @"result"
resultsCachePolicy ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "resultsCachePolicy" a) =>
  Lens.Family2.LensLike' f s a
resultsCachePolicy
  = Data.ProtoLens.Field.field @"resultsCachePolicy"
root ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "root" a) =>
  Lens.Family2.LensLike' f s a
root = Data.ProtoLens.Field.field @"root"
rootDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "rootDigest" a) =>
  Lens.Family2.LensLike' f s a
rootDigest = Data.ProtoLens.Field.field @"rootDigest"
rootDirectoryDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "rootDirectoryDigest" a) =>
  Lens.Family2.LensLike' f s a
rootDirectoryDigest
  = Data.ProtoLens.Field.field @"rootDirectoryDigest"
salt ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "salt" a) =>
  Lens.Family2.LensLike' f s a
salt = Data.ProtoLens.Field.field @"salt"
seed ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "seed" a) =>
  Lens.Family2.LensLike' f s a
seed = Data.ProtoLens.Field.field @"seed"
serverLogs ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "serverLogs" a) =>
  Lens.Family2.LensLike' f s a
serverLogs = Data.ProtoLens.Field.field @"serverLogs"
sizeBytes ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "sizeBytes" a) =>
  Lens.Family2.LensLike' f s a
sizeBytes = Data.ProtoLens.Field.field @"sizeBytes"
skipCacheLookup ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "skipCacheLookup" a) =>
  Lens.Family2.LensLike' f s a
skipCacheLookup = Data.ProtoLens.Field.field @"skipCacheLookup"
spliceBlobSupport ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "spliceBlobSupport" a) =>
  Lens.Family2.LensLike' f s a
spliceBlobSupport = Data.ProtoLens.Field.field @"spliceBlobSupport"
splitBlobSupport ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "splitBlobSupport" a) =>
  Lens.Family2.LensLike' f s a
splitBlobSupport = Data.ProtoLens.Field.field @"splitBlobSupport"
stage ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "stage" a) =>
  Lens.Family2.LensLike' f s a
stage = Data.ProtoLens.Field.field @"stage"
status ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "status" a) =>
  Lens.Family2.LensLike' f s a
status = Data.ProtoLens.Field.field @"status"
stderrDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "stderrDigest" a) =>
  Lens.Family2.LensLike' f s a
stderrDigest = Data.ProtoLens.Field.field @"stderrDigest"
stderrRaw ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "stderrRaw" a) =>
  Lens.Family2.LensLike' f s a
stderrRaw = Data.ProtoLens.Field.field @"stderrRaw"
stderrStreamName ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "stderrStreamName" a) =>
  Lens.Family2.LensLike' f s a
stderrStreamName = Data.ProtoLens.Field.field @"stderrStreamName"
stdoutDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "stdoutDigest" a) =>
  Lens.Family2.LensLike' f s a
stdoutDigest = Data.ProtoLens.Field.field @"stdoutDigest"
stdoutRaw ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "stdoutRaw" a) =>
  Lens.Family2.LensLike' f s a
stdoutRaw = Data.ProtoLens.Field.field @"stdoutRaw"
stdoutStreamName ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "stdoutStreamName" a) =>
  Lens.Family2.LensLike' f s a
stdoutStreamName = Data.ProtoLens.Field.field @"stdoutStreamName"
supportedBatchUpdateCompressors ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "supportedBatchUpdateCompressors" a) =>
  Lens.Family2.LensLike' f s a
supportedBatchUpdateCompressors
  = Data.ProtoLens.Field.field @"supportedBatchUpdateCompressors"
supportedCompressors ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "supportedCompressors" a) =>
  Lens.Family2.LensLike' f s a
supportedCompressors
  = Data.ProtoLens.Field.field @"supportedCompressors"
supportedNodeProperties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "supportedNodeProperties" a) =>
  Lens.Family2.LensLike' f s a
supportedNodeProperties
  = Data.ProtoLens.Field.field @"supportedNodeProperties"
symlinkAbsolutePathStrategy ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "symlinkAbsolutePathStrategy" a) =>
  Lens.Family2.LensLike' f s a
symlinkAbsolutePathStrategy
  = Data.ProtoLens.Field.field @"symlinkAbsolutePathStrategy"
symlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "symlinks" a) =>
  Lens.Family2.LensLike' f s a
symlinks = Data.ProtoLens.Field.field @"symlinks"
target ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "target" a) =>
  Lens.Family2.LensLike' f s a
target = Data.ProtoLens.Field.field @"target"
targetId ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "targetId" a) =>
  Lens.Family2.LensLike' f s a
targetId = Data.ProtoLens.Field.field @"targetId"
timeout ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "timeout" a) =>
  Lens.Family2.LensLike' f s a
timeout = Data.ProtoLens.Field.field @"timeout"
toolDetails ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "toolDetails" a) =>
  Lens.Family2.LensLike' f s a
toolDetails = Data.ProtoLens.Field.field @"toolDetails"
toolInvocationId ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "toolInvocationId" a) =>
  Lens.Family2.LensLike' f s a
toolInvocationId = Data.ProtoLens.Field.field @"toolInvocationId"
toolName ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "toolName" a) =>
  Lens.Family2.LensLike' f s a
toolName = Data.ProtoLens.Field.field @"toolName"
toolVersion ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "toolVersion" a) =>
  Lens.Family2.LensLike' f s a
toolVersion = Data.ProtoLens.Field.field @"toolVersion"
treeDigest ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "treeDigest" a) =>
  Lens.Family2.LensLike' f s a
treeDigest = Data.ProtoLens.Field.field @"treeDigest"
unixMode ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "unixMode" a) =>
  Lens.Family2.LensLike' f s a
unixMode = Data.ProtoLens.Field.field @"unixMode"
updateEnabled ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "updateEnabled" a) =>
  Lens.Family2.LensLike' f s a
updateEnabled = Data.ProtoLens.Field.field @"updateEnabled"
value ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "value" a) =>
  Lens.Family2.LensLike' f s a
value = Data.ProtoLens.Field.field @"value"
vec'acceptableCompressors ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'acceptableCompressors" a) =>
  Lens.Family2.LensLike' f s a
vec'acceptableCompressors
  = Data.ProtoLens.Field.field @"vec'acceptableCompressors"
vec'arguments ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'arguments" a) =>
  Lens.Family2.LensLike' f s a
vec'arguments = Data.ProtoLens.Field.field @"vec'arguments"
vec'auxiliaryMetadata ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'auxiliaryMetadata" a) =>
  Lens.Family2.LensLike' f s a
vec'auxiliaryMetadata
  = Data.ProtoLens.Field.field @"vec'auxiliaryMetadata"
vec'blobDigests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'blobDigests" a) =>
  Lens.Family2.LensLike' f s a
vec'blobDigests = Data.ProtoLens.Field.field @"vec'blobDigests"
vec'children ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'children" a) =>
  Lens.Family2.LensLike' f s a
vec'children = Data.ProtoLens.Field.field @"vec'children"
vec'chunkDigests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'chunkDigests" a) =>
  Lens.Family2.LensLike' f s a
vec'chunkDigests = Data.ProtoLens.Field.field @"vec'chunkDigests"
vec'digestFunctions ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'digestFunctions" a) =>
  Lens.Family2.LensLike' f s a
vec'digestFunctions
  = Data.ProtoLens.Field.field @"vec'digestFunctions"
vec'digests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'digests" a) =>
  Lens.Family2.LensLike' f s a
vec'digests = Data.ProtoLens.Field.field @"vec'digests"
vec'directories ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'directories" a) =>
  Lens.Family2.LensLike' f s a
vec'directories = Data.ProtoLens.Field.field @"vec'directories"
vec'environmentVariables ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'environmentVariables" a) =>
  Lens.Family2.LensLike' f s a
vec'environmentVariables
  = Data.ProtoLens.Field.field @"vec'environmentVariables"
vec'files ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'files" a) =>
  Lens.Family2.LensLike' f s a
vec'files = Data.ProtoLens.Field.field @"vec'files"
vec'inlineOutputFiles ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'inlineOutputFiles" a) =>
  Lens.Family2.LensLike' f s a
vec'inlineOutputFiles
  = Data.ProtoLens.Field.field @"vec'inlineOutputFiles"
vec'missingBlobDigests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'missingBlobDigests" a) =>
  Lens.Family2.LensLike' f s a
vec'missingBlobDigests
  = Data.ProtoLens.Field.field @"vec'missingBlobDigests"
vec'outputDirectories ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputDirectories" a) =>
  Lens.Family2.LensLike' f s a
vec'outputDirectories
  = Data.ProtoLens.Field.field @"vec'outputDirectories"
vec'outputDirectorySymlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputDirectorySymlinks" a) =>
  Lens.Family2.LensLike' f s a
vec'outputDirectorySymlinks
  = Data.ProtoLens.Field.field @"vec'outputDirectorySymlinks"
vec'outputFileSymlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputFileSymlinks" a) =>
  Lens.Family2.LensLike' f s a
vec'outputFileSymlinks
  = Data.ProtoLens.Field.field @"vec'outputFileSymlinks"
vec'outputFiles ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputFiles" a) =>
  Lens.Family2.LensLike' f s a
vec'outputFiles = Data.ProtoLens.Field.field @"vec'outputFiles"
vec'outputNodeProperties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputNodeProperties" a) =>
  Lens.Family2.LensLike' f s a
vec'outputNodeProperties
  = Data.ProtoLens.Field.field @"vec'outputNodeProperties"
vec'outputPaths ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputPaths" a) =>
  Lens.Family2.LensLike' f s a
vec'outputPaths = Data.ProtoLens.Field.field @"vec'outputPaths"
vec'outputSymlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'outputSymlinks" a) =>
  Lens.Family2.LensLike' f s a
vec'outputSymlinks
  = Data.ProtoLens.Field.field @"vec'outputSymlinks"
vec'priorities ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'priorities" a) =>
  Lens.Family2.LensLike' f s a
vec'priorities = Data.ProtoLens.Field.field @"vec'priorities"
vec'properties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'properties" a) =>
  Lens.Family2.LensLike' f s a
vec'properties = Data.ProtoLens.Field.field @"vec'properties"
vec'requests ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'requests" a) =>
  Lens.Family2.LensLike' f s a
vec'requests = Data.ProtoLens.Field.field @"vec'requests"
vec'responses ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'responses" a) =>
  Lens.Family2.LensLike' f s a
vec'responses = Data.ProtoLens.Field.field @"vec'responses"
vec'supportedBatchUpdateCompressors ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'supportedBatchUpdateCompressors" a) =>
  Lens.Family2.LensLike' f s a
vec'supportedBatchUpdateCompressors
  = Data.ProtoLens.Field.field @"vec'supportedBatchUpdateCompressors"
vec'supportedCompressors ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'supportedCompressors" a) =>
  Lens.Family2.LensLike' f s a
vec'supportedCompressors
  = Data.ProtoLens.Field.field @"vec'supportedCompressors"
vec'supportedNodeProperties ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'supportedNodeProperties" a) =>
  Lens.Family2.LensLike' f s a
vec'supportedNodeProperties
  = Data.ProtoLens.Field.field @"vec'supportedNodeProperties"
vec'symlinks ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "vec'symlinks" a) =>
  Lens.Family2.LensLike' f s a
vec'symlinks = Data.ProtoLens.Field.field @"vec'symlinks"
virtualExecutionDuration ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "virtualExecutionDuration" a) =>
  Lens.Family2.LensLike' f s a
virtualExecutionDuration
  = Data.ProtoLens.Field.field @"virtualExecutionDuration"
worker ::
  forall f s a.
  (Prelude.Functor f, Data.ProtoLens.Field.HasField s "worker" a) =>
  Lens.Family2.LensLike' f s a
worker = Data.ProtoLens.Field.field @"worker"
workerCompletedTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "workerCompletedTimestamp" a) =>
  Lens.Family2.LensLike' f s a
workerCompletedTimestamp
  = Data.ProtoLens.Field.field @"workerCompletedTimestamp"
workerStartTimestamp ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "workerStartTimestamp" a) =>
  Lens.Family2.LensLike' f s a
workerStartTimestamp
  = Data.ProtoLens.Field.field @"workerStartTimestamp"
workingDirectory ::
  forall f s a.
  (Prelude.Functor f,
   Data.ProtoLens.Field.HasField s "workingDirectory" a) =>
  Lens.Family2.LensLike' f s a
workingDirectory = Data.ProtoLens.Field.field @"workingDirectory"