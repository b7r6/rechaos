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
          # The library/exe/test derivation, before justStaticExecutables
          # strips docs. Reused for the shipped executable and for the
          # haddock-enabled doc derivation below.
          rawPackage = pkgs.haskell.lib.allowInconsistentDependencies
            (pkgs.haskell.lib.overrideCabal
              (toolchain.hp.callCabal2nix "rechaos" cabalSrc {})
              (_: { src = sourceArchive; }));
          package = pkgs.haskell.lib.justStaticExecutables rawPackage;
          # Same package with Haddock generation forced on. Building this
          # derivation fails on any haddock error, which is exactly the
          # documentation-rot gate we want. The rendered HTML lives in the
          # "doc" output.
          docsPackage = pkgs.haskell.lib.doHaddock
            (pkgs.haskell.lib.dontCheck rawPackage);
          # Sources fourmolu/hlint check over, kept in sync with the cabal
          # hand-written stanzas (the generated/ tree is deliberately excluded).
          haskellSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./Setup.hs ./app ./src ./test ./scripts/gen-conformance.hs
              ./fourmolu.yaml ./.hlint.yaml
            ];
          };
          # Source tree for `cabal check`: the cabal file plus everything it
          # references via extra-source-files, so the check sees a faithful,
          # hermetic copy of what an sdist would ship.
          cabalSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./rechaos.cabal ./Setup.hs ./app ./src ./test ./generated
              ./examples ./proto ./CHANGELOG.md ./README.md ./LICENSE
            ];
          };
          # Build and test the actual source distribution, so omitted runtime
          # fixtures or modules fail the same gate as an ordinary source build.
          sourceArchive = pkgs.runCommand "rechaos-source.tar.gz" {
            nativeBuildInputs = [ pkgs.cabal-install ];
          } ''
            cp -r ${cabalSrc} ./source
            chmod -R u+w ./source
            cd ./source
            cabal check
            touch "$TMPDIR/cabal.config"
            cabal --config-file="$TMPDIR/cabal.config" sdist --output-directory="$TMPDIR/sdist"
            cp "$TMPDIR/sdist/rechaos-0.1.0.0.tar.gz" "$out"
          '';
          pythonSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [ ./scripts ./test ./proto ./examples ];
          };
          conformanceSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./src ./scripts/gen-conformance.hs ./test/golden ./lean
            ];
          };
          protoSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [ ./proto ./generated ./scripts/generate-protos.sh ];
          };
          devSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./rechaos.cabal ./Setup.hs ./app ./src ./test ./generated
              ./examples ./proto ./CHANGELOG.md ./README.md ./LICENSE ./scripts/build.sh
            ];
          };
        in { inherit pkgs toolchain python package docsPackage haskellSrc sourceArchive pythonSrc conformanceSrc protoSrc devSrc; };
    in {
      packages = eachSystem (system:
        let b = build system;
        in {
          default = b.package;
          # The rendered Haddock HTML as a browsable artifact.
          docs = b.docsPackage.doc;
        });
      # `nix run .# -- serve ...` runs the shipped executable. The cabal stanza
      # names it `rechaos`, matching the result symlink's bin/rechaos.
      apps = eachSystem (system:
        let b = build system;
        in {
          default = {
            type = "app";
            program = "${b.package}/bin/rechaos";
            meta.description = "REAPI chaos gateway and replay/oracle tools";
          };
        });
      # `nix fmt` formats the hand-written sources in place. The fourmolu flag
      # list is the single source of truth shared with checks.format below
      # (which runs the `--mode check` counterpart); keep the two in sync.
      formatter = eachSystem (system:
        let b = build system;
        in b.pkgs.writeShellApplication {
          name = "rechaos-fmt";
          runtimeInputs = [ b.pkgs.haskellPackages.fourmolu ];
          text = ''
            fourmolu --mode inplace -o -XImportQualifiedPost Setup.hs app src test scripts/gen-conformance.hs
          '';
        });
      checks = eachSystem (system:
        let b = build system;
        in {
          # The cabal test-suite (QuickCheck core properties), built and run by
          # the same derivation that produces the executable.
          test = b.package;
          # Exercise the documented developer build against the installed
          # package database as well as the Nix-packaged sdist build above.
          devBuild = b.pkgs.runCommand "rechaos-dev-build" {
            nativeBuildInputs = [ b.toolchain.ghc ];
          } ''
            cp -r ${b.devSrc} ./source
            chmod -R u+w ./source
            cd ./source
            bash scripts/build.sh
            runghc Setup.hs test --builddir=.build/cabal --show-details=direct
            touch "$out"
          '';
          wire = b.pkgs.runCommand "rechaos-wire" {
            nativeBuildInputs = [ b.python b.pkgs.ripgrep ];
          } ''
            cp -r ${b.pythonSrc} ./source
            chmod -R u+w ./source
            cd ./source
            export RECHAOS_BIN=${b.package}/bin/rechaos
            export RECHAOS_TEST_OUTPUT="$TMPDIR/integration"
            bash scripts/test-python.sh
            touch "$out"
          '';
          syntax = b.pkgs.runCommand "rechaos-script-syntax" {
            nativeBuildInputs = [ b.python b.pkgs.ripgrep ];
          } ''
            cd ${b.pythonSrc}
            export PYTHONPYCACHEPREFIX="$TMPDIR/pycache"
            python3 -m compileall -q scripts test
            while IFS= read -r script; do
              bash -n "$script"
            done < <(rg --files scripts -g '*.sh')
            touch "$out"
          '';
          conformance = b.pkgs.runCommand "rechaos-conformance-drift" {
            nativeBuildInputs = [ b.toolchain.ghc ];
          } ''
            cp -r ${b.conformanceSrc} ./source
            chmod -R u+w ./source
            cd ./source
            runghc -isrc scripts/gen-conformance.hs
            diff -ru ${b.conformanceSrc}/test/golden test/golden
            diff -ru ${b.conformanceSrc}/lean lean
            touch "$out"
          '';
          protos = b.pkgs.runCommand "rechaos-proto-drift" {
            nativeBuildInputs = [ b.toolchain.ghc b.pkgs.protobuf b.pkgs.ripgrep ];
          } ''
            cp -r ${b.protoSrc} ./source
            chmod -R u+w ./source
            cd ./source
            mv generated committed
            bash scripts/generate-protos.sh
            diff -ru committed generated
            touch "$out"
          '';
          # Formatting gate: fourmolu must report no changes over the
          # hand-written sources, honoring ./fourmolu.yaml.
          format = b.pkgs.runCommand "rechaos-format" {
            nativeBuildInputs = [ b.pkgs.haskellPackages.fourmolu ];
          } ''
            cd ${b.haskellSrc}
            fourmolu --mode check -o -XImportQualifiedPost Setup.hs app src test scripts/gen-conformance.hs
            touch "$out"
          '';
          # Lint gate: hlint honoring ./.hlint.yaml.
          lint = b.pkgs.runCommand "rechaos-lint" {
            nativeBuildInputs = [ b.pkgs.haskellPackages.hlint ];
          } ''
            cd ${b.haskellSrc}
            hlint -XImportQualifiedPost --hint=.hlint.yaml Setup.hs app src test scripts/gen-conformance.hs
            touch "$out"
          '';
          # Documentation gate: build Haddock for the whole package and fail on
          # any haddock error, so doc-comment rot is caught in CI. The build of
          # docsPackage does the work; this check just pins it into the set and
          # surfaces the HTML path.
          docs = b.pkgs.runCommand "rechaos-docs" {} ''
            test -d ${b.docsPackage.doc}/share/doc
            touch "$out"
          '';
          # Metadata check and sdist creation; test and docs consume this archive.
          cabalCheck = b.sourceArchive;
          # Proof gate: the Lean 4 verified core must compile under Lean 4.30
          # with zero proof holes. We copy ./lean into a writable tree (lake
          # writes .lake/), and run `lake build` fully offline
          # — no Mathlib, no network, pkgs.lean4 supplies the toolchain. The
          # Source guard rejects proof-hole terms and new axiom declarations,
          # ignoring documentation comments and string literals.
          lean = b.pkgs.runCommand "rechaos-lean" {
            nativeBuildInputs = [ b.pkgs.lean4 b.python ];
          } ''
            cp -r ${./lean} ./lean
            chmod -R u+w ./lean
            python3 ${./scripts/check_lean.py} ./lean
            cd ./lean
            lake build
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
