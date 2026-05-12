{
  description = "Nix flake for oh-my-pi";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
      oh-my-pi-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # ── oh-my-pi (built with bun from source) ───────────────────────────
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
            description = "AI coding agent for the terminal — hash-anchored edits, LSP, Python, browser, subagents";
            homepage = "https://github.com/can1357/oh-my-pi";
            license = licenses.mit;
            platforms = pkgs.lib.platforms.unix;
          };
        };
      in
      {
        packages = {
          default = oh-my-pi;
          inherit oh-my-pi oh-my-pi-deps;
        };

        apps = {
          default = {
            type = "app";
            program = "${oh-my-pi}/bin/omp";
          };
          omp = {
            type = "app";
            program = "${oh-my-pi}/bin/omp";
          };
        };
      }
    );
}
