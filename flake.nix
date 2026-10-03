{
  description = "rechaos: standalone Haskell REAPI chaos gateway with a pure replay/oracle core";
  inputs.nixpkgs.url = "github:sensenet-ai/nixpkgs/ddb5e98374d1f16c86ecd70d9c4e2d6c6a5e8dbc";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      build = system:
        let
          pkgs = import nixpkgs { inherit system; };
          toolchain = import ./nix/toolchain.nix { inherit pkgs; };
          python = pkgs.python3.withPackages (p: [ p.grpcio p.grpcio-tools p.protobuf ]);
          # Single source of truth: one cabal package compiling the proto
          # internal library, the main library, the rechaos executable, and the
          # core test-suite. The tests run as part of this derivation's check
          # phase (enableSeparateCheckOutput keeps the exe install lean).
          # random 1.2 (Aeson/QuickCheck closure) and random 1.3 (TLS/grapesy)
          # legitimately coexist here — the types never cross the public
          # boundary — so allow the otherwise-fatal inconsistent dependency, as
          # the toolchain already does for grapesy itself.
          package = pkgs.haskell.lib.justStaticExecutables
            (pkgs.haskell.lib.allowInconsistentDependencies
              (toolchain.hp.callCabal2nix "rechaos" ./. {}));
          # Sources fourmolu/hlint check over, kept in sync with the cabal
          # hand-written stanzas (the generated/ tree is deliberately excluded).
          haskellSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [ ./app ./src ./test ./fourmolu.yaml ./.hlint.yaml ];
          };
        in { inherit pkgs toolchain python package haskellSrc; };
    in {
      packages = eachSystem (system: { default = (build system).package; });
      checks = eachSystem (system:
        let b = build system;
        in {
          # The cabal test-suite (QuickCheck core properties), built and run by
          # the same derivation that produces the executable.
          test = b.package;
          # Formatting gate: fourmolu must report no changes over the
          # hand-written sources, honoring ./fourmolu.yaml.
          format = b.pkgs.runCommand "rechaos-format" {
            nativeBuildInputs = [ b.pkgs.haskellPackages.fourmolu ];
          } ''
            cd ${b.haskellSrc}
            fourmolu --mode check app src test
            touch "$out"
          '';
          # Lint gate: hlint honoring ./.hlint.yaml.
          lint = b.pkgs.runCommand "rechaos-lint" {
            nativeBuildInputs = [ b.pkgs.haskellPackages.hlint ];
          } ''
            cd ${b.haskellSrc}
            hlint --hint=.hlint.yaml app src test
            touch "$out"
          '';
        });
      devShells = eachSystem (system:
        let b = build system;
        in { default = b.pkgs.mkShell {
          packages = [
            b.toolchain.ghc b.python b.pkgs.protobuf b.pkgs.openssl
            b.pkgs.bazel_8 b.pkgs.jdk21_headless b.pkgs.cabal-install
            b.pkgs.ripgrep b.pkgs.haskellPackages.fourmolu b.pkgs.haskellPackages.hlint
          ];
        }; });
    };
}
