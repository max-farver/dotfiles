{
  description = "Nix flake for pi - an AI coding agent from pi-mono";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pi-mono = {
      url = "github:badlogic/pi-mono/main";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, pi-mono }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

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
      }
    );
}
