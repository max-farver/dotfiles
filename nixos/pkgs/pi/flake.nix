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

        version = "14.9.8";
        tag = "v${version}";

        assetNames = {
          x86_64-linux = "omp-linux-x64";
          aarch64-linux = "omp-linux-arm64";
          x86_64-darwin = "omp-darwin-x64";
          aarch64-darwin = "omp-darwin-arm64";
        };

        binaryHashes = {
          x86_64-linux = "sha256-Td8qnJ6WBQCrqHH07B8UAXUpYNVnetmE1j4mYYd+hN0=";
          aarch64-linux = "sha256-+Z1b5f7aWIDMg/e7LyZnnuC1oowJIAyiDRkjjeyj5lE=";
          x86_64-darwin = "sha256-RGMPNv6YSuV1j6Oc9W/TxTUnyV4pBrkM9wLQNAWTH1M=";
          aarch64-darwin = "sha256-y3EH3lP+7sGO34qSlVX/q1JZunDRRZ6MkZojhX0qLTA=";
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
