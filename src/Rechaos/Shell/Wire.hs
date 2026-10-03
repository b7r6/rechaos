-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                                                   // rechaos // shell // wire
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   grapesy transport glue
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module Rechaos.Shell.Wire where

import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy as L
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)
import Network.GRPC.Common

-- Forward unknown protobuf fields byte-for-byte. Decode only targeted messages
-- for blob sizes and valid ByteStream edits, using generated proto-lens types.
data Wire (service :: Symbol) (method :: Symbol)
type instance Input (Wire s m) = L.ByteString
type instance Output (Wire s m) = L.ByteString
type instance RequestMetadata (Wire s m) = [CustomMetadata]
type instance ResponseInitialMetadata (Wire s m) = [CustomMetadata]
type instance ResponseTrailingMetadata (Wire s m) = [CustomMetadata]
instance (KnownSymbol s, KnownSymbol m) => IsRPC (Wire s m) where
  rpcContentType _ = "application/grpc+proto"
  rpcServiceName _ = B.pack (symbolVal (Proxy @s))
  rpcMethodName _ = B.pack (symbolVal (Proxy @m))
  rpcMessageType _ = Nothing
instance (KnownSymbol s, KnownSymbol m) => SupportsClientRpc (Wire s m) where
  rpcSerializeInput _ = id
  rpcDeserializeOutput _ = Right
instance (KnownSymbol s, KnownSymbol m) => SupportsServerRpc (Wire s m) where
  rpcDeserializeInput _ = Right
  rpcSerializeOutput _ = id

type ReadRPC = Wire "google.bytestream.ByteStream" "Read"
type WriteRPC = Wire "google.bytestream.ByteStream" "Write"
type MissingRPC =
  Wire "build.bazel.remote.execution.v2.ContentAddressableStorage" "FindMissingBlobs"
