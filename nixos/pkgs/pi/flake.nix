{
  description = "Nix flake for oh-my-pi";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        version = "16.3.12";
        tag = "v${version}";

        assetNames = {
          x86_64-linux = "omp-linux-x64";
          aarch64-linux = "omp-linux-arm64";
          x86_64-darwin = "omp-darwin-x64";
          aarch64-darwin = "omp-darwin-arm64";
        };

        binaryHashes = {
          x86_64-linux = "sha256-x8sBV2xpbZa5bCHWkegpRRGb87u3MW4+ifxbF+IH27c=";
          aarch64-linux = "sha256-96AcQhttqbKFqhO2xtjl84c0e7QbBH6LnCzxrM4gsJg=";
          x86_64-darwin = "sha256-WDmI3I/rnBloIz9cD9+9oIfhjkg8pJZrKw1k2cS448I=";
          aarch64-darwin = "sha256-l7x4f75QMjWQKc7fw7lspCh9FoXJXguElLZLeXmkZvc=";
        };

        assetName = assetNames.${system} or (throw "Oh My Pi binary package does not support ${system}");

        oh-my-pi-bin = pkgs.fetchurl {
          url = "https://github.com/can1357/oh-my-pi/releases/download/${tag}/${assetName}";
          hash = binaryHashes.${system} or (throw "Missing Oh My Pi binary hash for ${system}");
        };

        oh-my-pi = pkgs.stdenv.mkDerivation {
          pname = "oh-my-pi";
          inherit version;

          src = oh-my-pi-bin;
          dontUnpack = true;

          nativeBuildInputs = [ pkgs.makeWrapper ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
          buildInputs = lib.optionals pkgs.stdenv.isLinux [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];

          installPhase = ''
            runHook preInstall

            install -Dm755 $src $out/bin/omp

            runHook postInstall
          '';

          postFixup = ''
            wrapProgram $out/bin/omp \
              --prefix PATH : ${
                lib.makeBinPath [
                  pkgs.ripgrep
                  pkgs.fd
                  pkgs.git
                ]
              }
          '';

          dontStrip = true;

          meta = with lib; {
            description = "AI coding agent for the terminal — hash-anchored edits, LSP, Python, browser, subagents";
            homepage = "https://github.com/can1357/oh-my-pi";
            license = licenses.mit;
            platforms = builtins.attrNames assetNames;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
          };
        };
      in
      {
        packages = {
          default = oh-my-pi;
          inherit oh-my-pi;
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
