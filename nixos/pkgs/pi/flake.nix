{
  description = "Nix flake for pi coding agents (pi-mono and oh-my-pi)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pi-mono = {
      url = "github:badlogic/pi-mono/main";
      flake = false;
    };
    oh-my-pi-src = {
      url = "github:can1357/oh-my-pi/v13.19.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pi-mono,
      oh-my-pi-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # ── pi-mono (original, built from source) ──────────────────────────
        xlsxSrc = pkgs.fetchurl {
          url = "https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz";
          hash = "sha512-oLDq3jw7AcLqKWH2AhCpVTZl8mf6X2YReP+Neh0SJUzV/BdZYjth94tG5toiMB1PPrYtxOCfaoUCkvtuH+3AJA==";
        };

        piPackageLock =
          let
            lock = builtins.fromJSON (builtins.readFile "${pi-mono}/package-lock.json");
          in
          lock
          // {
            packages = lock.packages // {
              "packages/web-ui" = lock.packages."packages/web-ui" // {
                dependencies = lock.packages."packages/web-ui".dependencies // {
                  xlsx = "file:${xlsxSrc}";
                };
              };
            };
          };

        pi = pkgs.buildNpmPackage rec {
          pname = "pi";
          version = "main";

          src = pi-mono;

          npmDeps = pkgs.importNpmLock {
            npmRoot = src;
            packageLock = piPackageLock;
            packageSourceOverrides = {
              "node_modules/xlsx" = xlsxSrc;
            };
          };
          npmConfigHook = pkgs.importNpmLock.npmConfigHook;

          nodejs = pkgs.nodejs_22;

          nativeBuildInputs = with pkgs; [
            pkg-config
            python3
            makeWrapper
          ];

          buildInputs = with pkgs; [
            cairo
            pango
            libjpeg
            giflib
            librsvg
            pixman
          ];

          npmBuildScript = "build";

          postPatch = ''
            substituteInPlace packages/ai/package.json \
              --replace-fail '"build": "npm run generate-models && tsgo -p tsconfig.build.json"' \
                              '"build": "tsgo -p tsconfig.build.json"'

            substituteInPlace packages/web-ui/package.json \
              --replace-fail '"xlsx": "https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz"' \
                              '"xlsx": "file:${xlsxSrc}"'
          '';

          dontNpmInstall = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/node_modules/pi-monorepo
            cp -r . $out/lib/node_modules/pi-monorepo/
            rm -rf $out/lib/node_modules/pi-monorepo/node_modules/.bin

            mkdir -p $out/bin

            makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/pi \
              --add-flags "$out/lib/node_modules/pi-monorepo/packages/coding-agent/dist/cli.js" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  pkgs.ripgrep
                  pkgs.fd
                  pkgs.git
                ]
              }

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "An AI coding agent that can read/write files, execute commands, and edit code";
            homepage = "https://github.com/badlogic/pi-mono";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        # ── oh-my-pi (fork, built with bun from source) ──────────────────
        #
        # Bun needs network to `bun install`, so we use a two-phase build:
        #   1. FOD (fixed-output derivation) that downloads all deps into a tarball
        #   2. Main derivation that unpacks deps + source and wraps the CLI
        #
        # To update the FOD hash, run:
        #   nix build .#oh-my-pi-deps
        # and copy the hash from the error message.
        #

        # Phase 1: prefetch all bun dependencies as a tarball
        oh-my-pi-deps = pkgs.stdenv.mkDerivation {
          name = "oh-my-pi-deps-13.19.0-hoisted";
          src = oh-my-pi-src;

          nativeBuildInputs = [ pkgs.bun ];

          # Fixed-output derivation — hash locks the dependency set
          outputHashMode = "recursive";
          outputHash = "sha256-yDrmbRj4LduLtwW52/KnFuLsHyfmk4KIizU09ZB3G9k=";

          buildPhase = ''
            export HOME=$TMPDIR/bun-home
            mkdir -p $HOME

            # Use hoisted linker so packages are directly in node_modules (not .bun cache)
            sed -i 's/linker = "isolated"/linker = "hoisted"/' bunfig.toml

            bun install --frozen-lockfile

            # Pack node_modules into a tarball
            tar czf $out -C . node_modules
          '';

          installPhase = "true";
        };

        # Prebuilt native Rust addons (N-API .node files)
        ompNativeModern = pkgs.fetchurl {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v13.19.0/pi_natives.linux-x64-modern.node";
          hash = "sha256-cvyDPTQiYyFIbhU9EwCKoyfA4S2NgAFt9EL5Kx+b+Bo=";
        };
        ompNativeBaseline = pkgs.fetchurl {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v13.19.0/pi_natives.linux-x64-baseline.node";
          hash = "sha256-KveYoHuIpPUXOBh86qjW0CSM6LPtbNO8h5ZfuOxOSNA=";
        };

        oh-my-pi = pkgs.stdenv.mkDerivation {
          pname = "oh-my-pi";
          version = "13.19.0";

          src = oh-my-pi-src;

          nativeBuildInputs = with pkgs; [
            bun
            makeWrapper
            autoPatchelfHook
          ];

          buildInputs = with pkgs; [
            stdenv.cc.cc.lib
            zlib
          ];

          autoPatchelfIgnoreMissingDeps = [
            "libc.musl-x86_64.so.1"
          ];

          configurePhase = ''
            runHook preConfigure
            # Unpack prefetched node_modules
            tar xf ${oh-my-pi-deps} -C .
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            # Generate the docs index that's required at runtime
            bun --cwd=packages/coding-agent run generate-docs-index
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/oh-my-pi
            cp -r . $out/lib/oh-my-pi/

            # Install prebuilt native Rust addons
            mkdir -p $out/lib/oh-my-pi/packages/natives/native
            cp ${ompNativeModern} $out/lib/oh-my-pi/packages/natives/native/pi_natives.linux-x64-modern.node
            cp ${ompNativeBaseline} $out/lib/oh-my-pi/packages/natives/native/pi_natives.linux-x64-baseline.node

            mkdir -p $out/bin
            makeWrapper ${pkgs.bun}/bin/bun $out/bin/omp \
              --add-flags "run" \
              --add-flags "$out/lib/oh-my-pi/packages/coding-agent/src/cli.ts" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  pkgs.ripgrep
                  pkgs.fd
                  pkgs.git
                ]
              }

            runHook postInstall
          '';

          dontStrip = true;
          dontPatchELF = true;

          meta = with pkgs.lib; {
            description = "AI coding agent for the terminal (fork of pi-mono) — hash-anchored edits, LSP, Python, browser, subagents";
            homepage = "https://github.com/can1357/oh-my-pi";
            license = licenses.mit;
            platforms = pkgs.lib.platforms.unix;
          };
        };
      in
      {
        packages = {
          default = oh-my-pi;
          inherit pi oh-my-pi oh-my-pi-deps;
        };

        apps = {
          default = {
            type = "app";
            program = "${oh-my-pi}/bin/omp";
          };
          pi = {
            type = "app";
            program = "${pi}/bin/pi";
          };
          omp = {
            type = "app";
            program = "${oh-my-pi}/bin/omp";
          };
        };
      }
    );
}
