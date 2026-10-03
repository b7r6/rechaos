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
          package = pkgs.stdenv.mkDerivation {
            pname = "rechaos";
            version = "0.1.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [ ./app ./src ./generated ./scripts/build.sh ./test/CoreSpec.hs ];
            };
            nativeBuildInputs = [ toolchain ];
            buildPhase = "bash scripts/build.sh";
            doCheck = true;
            checkPhase = ''
              ghc --make -O0 -Wall -isrc -itest -outputdir .build/core test/CoreSpec.hs -o .build/core-tests
              .build/core-tests
              bin/rechaos validate /dev/stdin <<'JSON'
              {"version":1,"seed":0,"rules":[]}
              JSON
            '';
            installPhase = ''
              mkdir -p "$out/bin"
              cp bin/rechaos "$out/bin/"
            '';
          };
        in { inherit pkgs toolchain python package; };
    in {
      packages = eachSystem (system: { default = (build system).package; });
      checks = eachSystem (system: { core = (build system).package; });
      devShells = eachSystem (system:
        let b = build system;
        in { default = b.pkgs.mkShell {
          packages = [ b.toolchain b.python b.pkgs.protobuf b.pkgs.openssl b.pkgs.bazel_8 b.pkgs.jdk21_headless b.pkgs.cabal-install b.pkgs.ripgrep ];
        }; });
    };
}
