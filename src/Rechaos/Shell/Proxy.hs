-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                  // rechaos // shell // proxy
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   faulting gateway: pacing, stream edits, deadlines, metadata, cancellation
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Rechaos.Shell.Proxy (handlers, grpcStatus) where

import Control.Concurrent.Async
import Control.Exception
import Control.Monad (forM_, void)
import Data.IORef
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.TypeLits (KnownSymbol, symbolVal)
import qualified Network.GRPC.Client as C
import Network.GRPC.Common
import Network.GRPC.Common.Headers
import qualified Network.GRPC.Server as S
import Rechaos.Core.Scheduler (dribbleMicros)
import Rechaos.Core.Types
import Rechaos.Shell.Protocol
import Rechaos.Shell.Runtime
import Rechaos.Shell.Wire
import qualified System.Timeout as Timeout

grpcStatus :: Status -> GrpcError
grpcStatus s = case s of
  Cancelled -> GrpcCancelled
  InvalidArgument -> GrpcInvalidArgument
  DeadlineExceeded -> GrpcDeadlineExceeded
  NotFound -> GrpcNotFound
  ResourceExhausted -> GrpcResourceExhausted
  FailedPrecondition -> GrpcFailedPrecondition
  Internal -> GrpcInternal
  Unavailable -> GrpcUnavailable
  DataLoss -> GrpcDataLoss

grpcException :: GrpcError -> Text -> GrpcException
grpcException s msg = GrpcException s (Just msg) Nothing []

handler ::
  forall service method.
  (KnownSymbol service, KnownSymbol method) =>
  Runtime -> C.Connection -> Int -> S.SomeRpcHandler IO
handler runtime connection maxSeconds = S.someRpcHandler $
  S.mkRpcHandlerNoDefMetadata $ \(downstream :: S.Call (Wire service method)) -> do
    let method = T.pack (symbolVal (Proxy @service) ++ "/" ++ symbolVal (Proxy @method))
    (occurrence, started) <- beginCall runtime method
    S.setResponseInitialMetadataAndTrailers downstream [] Nothing
    result <- try $ do
      metadata <- S.getRequestMetadata downstream
      headers <- S.getRequestHeaders downstream
      required <-
        either
          (const (throwIO (grpcException GrpcInvalidArgument "invalid required request headers")))
          pure
          (verifyRequired headers)
      let incoming = requiredRequestTimeout required
          capMicros = toInteger maxSeconds * 1000000
          budget = fromInteger (maybe capMicros (min capMicros . toInteger . C.timeoutToMicro) incoming)
          upstreamTimeout = fromMaybe (C.Timeout C.Second (C.TimeoutValue (fromIntegral maxSeconds))) incoming
          params = def{C.callRequestMetadata = metadata, C.callTimeout = Just upstreamTimeout}
      done <- withIsolatedFailure connection params (Proxy @(Wire service method)) $ \upstream -> Timeout.timeout budget $ do
        size <- newIORef Nothing
        let apply direction index bytes send = do
              if direction == Request
                then case blobSize method bytes of
                  Just n -> writeIORef size (Just n)
                  Nothing -> pure ()
                else pure ()
              currentSize <- readIORef size
              chosen <-
                decide runtime method occurrence started direction index currentSize bytes
                  >>= either (throwIO . grpcException GrpcFailedPrecondition) pure
              case chosen of
                Nothing -> send bytes >> pure False
                Just (Delay micros) -> sleepMicros micros >> send bytes >> pure False
                Just (Abort status) -> throwIO (grpcException (grpcStatus status) "rechaos injected abort")
                Just (Dribble rate chunk) -> do
                  parts <-
                    either
                      (throwIO . grpcException GrpcInvalidArgument . T.pack)
                      pure
                      (payloadChunks method direction chunk bytes)
                  forM_ parts $ \(n, part) -> do
                    micros <-
                      maybe (throwIO (grpcException GrpcInvalidArgument "zero dribble rate")) pure (dribbleMicros rate n)
                    sleepMicros micros
                    send part
                  pure False
                Just (Truncate keep) -> do
                  shortened <-
                    either
                      (throwIO . grpcException GrpcInvalidArgument . T.pack)
                      pure
                      (truncatePayload method direction keep bytes)
                  _ <- send shortened
                  pure True
            pumpInput index = do
              item <- S.recvInput downstream
              case item of
                NoMoreElems NoMetadata -> C.sendEndOfInput upstream
                StreamElem bytes -> do
                  stop <- apply Request index bytes (C.sendNextInput upstream)
                  if stop then C.sendEndOfInput upstream else pumpInput (index + 1)
                FinalElem bytes NoMetadata -> do
                  void (apply Request index bytes (C.sendNextInput upstream))
                  C.sendEndOfInput upstream
            pumpOutput index = do
              item <- C.recvOutput upstream
              case item of
                NoMoreElems trailers -> S.sendTrailers downstream trailers
                StreamElem bytes -> do
                  stop <- apply Response index bytes (S.sendNextOutput downstream)
                  if stop then S.sendTrailers downstream [] else pumpOutput (index + 1)
                FinalElem bytes trailers -> do
                  stop <- apply Response index bytes (S.sendNextOutput downstream)
                  S.sendTrailers downstream (if stop then [] else trailers)
            responses = do
              md <- C.recvResponseMetadata upstream
              case md of
                ResponseInitialMetadata initial -> do
                  S.setResponseInitialMetadataAndTrailers downstream initial Nothing
                  pumpOutput 1
                ResponseTrailingMetadata trailers -> S.sendTrailers downstream trailers
        -- If a response ends early, cancel the request pump. If input half-closes,
        -- keep reading responses. Either failure cancels its sibling and upstream.
        withAsync (pumpInput 1) $ \input -> withAsync responses $ \output -> do
          first <- waitEitherCatch input output
          case first of
            Left (Right ()) -> wait output
            Left (Left e) -> throwIO e
            Right (Right ()) -> cancel input
            Right (Left e) -> throwIO e
      case done of
        Nothing -> throwIO (grpcException GrpcDeadlineExceeded "rechaos call deadline")
        Just () -> pure ()
    case result of
      Right () -> logOutcome runtime method occurrence started "OK"
      Left (e :: SomeException) -> do
        -- Preserve gRPC status, details and trailing metadata verbatim.
        case fromException e of
          Just grpc -> do
            logOutcome runtime method occurrence started (T.pack (show (grpcError grpc)))
            S.sendGrpcException downstream grpc
          Nothing -> do
            logOutcome runtime method occurrence started "transport-or-cancellation"
            throwIO e

-- A locally injected exception must cancel this HTTP/2 stream with CANCEL.
-- Grapesy forwards an exception escaping withRPC to outBodyCancel; passing a
-- timeout exception there can terminate the shared connection. Save the result
-- inside the bracket, let its normal teardown cancel the stream, then rethrow
-- the original exception. No RPC is retried here.
withIsolatedFailure ::
  forall rpc a.
  (SupportsClientRpc rpc) =>
  C.Connection -> C.CallParams rpc -> Proxy rpc -> (C.Call rpc -> IO a) -> IO a
withIsolatedFailure connection params proxy action = do
  saved <- newIORef Nothing
  transport <- try $ C.withRPC connection params proxy $ \call -> do
    result <- try (action call)
    writeIORef saved (Just (result :: Either SomeException a))
  result <- readIORef saved
  case result of
    Just (Left e) -> throwIO e
    Just (Right value) -> case transport of
      Right () -> pure value
      Left e
        | Just grpc <- fromException e, grpcError grpc == GrpcCancelled -> pure value
        | otherwise -> throwIO (e :: SomeException)
    Nothing -> case transport of
      Left e -> throwIO (e :: SomeException)
      Right () -> throwIO (grpcException GrpcInternal "missing RPC result")

handlers :: Runtime -> C.Connection -> Int -> [S.SomeRpcHandler IO]
handlers r c cap =
  [ handler @"google.bytestream.ByteStream" @"Read" r c cap
  , handler @"google.bytestream.ByteStream" @"Write" r c cap
  , handler @"google.bytestream.ByteStream" @"QueryWriteStatus" r c cap
  , handler @"build.bazel.remote.execution.v2.ContentAddressableStorage" @"FindMissingBlobs" r c cap
  , handler @"build.bazel.remote.execution.v2.ContentAddressableStorage" @"BatchReadBlobs" r c cap
  , handler @"build.bazel.remote.execution.v2.ContentAddressableStorage" @"BatchUpdateBlobs" r c cap
  , handler @"build.bazel.remote.execution.v2.ContentAddressableStorage" @"GetTree" r c cap
  , handler @"build.bazel.remote.execution.v2.ContentAddressableStorage" @"SplitBlob" r c cap
  , handler @"build.bazel.remote.execution.v2.ContentAddressableStorage" @"SpliceBlob" r c cap
  , handler @"build.bazel.remote.execution.v2.Capabilities" @"GetCapabilities" r c cap
  , handler @"build.bazel.remote.execution.v2.ActionCache" @"GetActionResult" r c cap
  , handler @"build.bazel.remote.execution.v2.ActionCache" @"UpdateActionResult" r c cap
  , handler @"build.bazel.remote.execution.v2.Execution" @"Execute" r c cap
  , handler @"build.bazel.remote.execution.v2.Execution" @"WaitExecution" r c cap
  , handler @"google.longrunning.Operations" @"GetOperation" r c cap
  , handler @"google.longrunning.Operations" @"ListOperations" r c cap
  , handler @"google.longrunning.Operations" @"CancelOperation" r c cap
  , handler @"google.longrunning.Operations" @"DeleteOperation" r c cap
  , handler @"google.longrunning.Operations" @"WaitOperation" r c cap
  , handler @"grpc.health.v1.Health" @"Check" r c cap
  ]
