{
  description = "Nix flake for pi - an AI coding agent from pi-mono";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        pi = pkgs.buildNpmPackage rec {
          pname = "pi";
          version = "0.50.6";

          src = pkgs.fetchFromGitHub {
            owner = "badlogic";
            repo = "pi-mono";
            rev = "main";
            hash = "sha256-yZLU6YvaU1WqqG/m7UdT8u3bpPUKZdT6a+Hq2RLNImk=";
          };

          npmDepsHash = "sha256-f+z+5P/FkRLB7GfH+/aJI9W6PEwDjcUtqXukIQENaI0=";

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

          preBuild = ''
            substituteInPlace packages/ai/package.json \
              --replace-fail '"build": "npm run generate-models && tsgo -p tsconfig.build.json"' \
                              '"build": "tsgo -p tsconfig.build.json"'
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
              --prefix PATH : ${pkgs.lib.makeBinPath [
                pkgs.ripgrep
                pkgs.fd
                pkgs.git
              ]}

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
      in
      {
        packages = {
          default = pi;
          pi = pi;
        };

        apps.default = {
          type = "app";
          program = "${pi}/bin/pi";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_22
            ripgrep
            fd
            git
          ];
        };
      }
    );
}
