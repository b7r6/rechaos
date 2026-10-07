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

{- | The grapesy transport glue: a single opaque 'Wire' RPC type, indexed by
service and method type-level strings, whose payloads are raw lazy
'Data.ByteString.Lazy.ByteString's forwarded byte-for-byte.

This module is in the IO shell. It supplies the grapesy @IsRPC@,
@SupportsClientRpc@, and @SupportsServerRpc@ instances that let the proxy relay
any method without a compiled schema; unknown protobuf fields pass through
untouched, and only targeted messages are decoded elsewhere for blob sizes and
valid ByteStream edits.
-}
module Rechaos.Shell.Wire (
  -- * Schema-free RPC type
  Wire,
) where

import Data.ByteString.Char8 qualified as B
import Data.ByteString.Lazy qualified as L
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)
import Network.GRPC.Common

{- | A schema-free gRPC method, indexed by @service@ and @method@ type-level
strings; its request and response bodies are raw bytes forwarded verbatim.
-}
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

-- n.b. serialize/deserialize are identity on both sides on purpose: the proxy
-- relays payloads byte-for-byte, so unknown protobuf fields survive the hop.
-- Introducing any decode/re-encode here would silently drop unrecognized
-- fields and break the passthrough guarantee this transport exists to provide.
instance (KnownSymbol s, KnownSymbol m) => SupportsClientRpc (Wire s m) where
  rpcSerializeInput _ = id
  rpcDeserializeOutput _ = Right
instance (KnownSymbol s, KnownSymbol m) => SupportsServerRpc (Wire s m) where
  rpcDeserializeInput _ = Right
  rpcSerializeOutput _ = id
