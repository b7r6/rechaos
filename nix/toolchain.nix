{ pkgs }:
let
  pins = builtins.fromJSON (builtins.readFile ./hackage-pins.json);
  source = name: pin: pkgs.runCommand "${name}-${pin.version}-source" {
        archive = pkgs.fetchurl {
        url = "https://hackage-content.haskell.org/package/${name}-${pin.version}/${name}-${pin.version}.tar.gz";
        inherit (pin) sha256;
        };
      } ''
        mkdir -p "$out"
        tar xzf "$archive" --strip-components=1 -C "$out"
      '';
  hp = pkgs.haskellPackages.override {
    overrides = self: super:
      let
        # TLS needs random 1.3; isolating that dependency avoids rebuilding the
        # entire Nixpkgs Haskell set and keeps its tested random 1.2 ABI intact.
        tlsRandom = pkgs.haskell.lib.dontCheck (super.callCabal2nix "random" (source "random" pins.random) {});
      in builtins.mapAttrs (name: pin:
        pkgs.haskell.lib.overrideCabal (self.callCabal2nix name (source name pin)
          (pkgs.lib.optionalAttrs (name == "tls") { random = tlsRandom; })) (old: {
          doCheck = false;
          # random types do not cross the TLS/grapesy public boundary. The
          # unrelated Aeson/QuickCheck closure retains its random 1.2 instance.
          allowInconsistentDependencies = name == "grapesy";
        })
      ) (builtins.removeAttrs pins ["random"]);
  };
  ghc = hp.ghcWithPackages (h: [
    h.grapesy h.proto-lens h.proto-lens-runtime h.proto-lens-protobuf-types
    h.proto-lens-protoc h.aeson h.async h.crypton h.memory h.lens
    h.QuickCheck h.optparse-applicative h.temporary
  ]);
in {
  # The overridden Haskell package set (pinned grapesy/http2/tls closure) used
  # to build the rechaos.cabal package via callCabal2nix.
  inherit hp;
  # A bare ghc with every runtime dependency in its package database, for the
  # Cabal Setup.hs build driver in scripts/build.sh and the dev shell.
  inherit ghc;
}
