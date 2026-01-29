{
  description = "A Nix-flake-based Go development environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              bashInteractive
              go
              gopls
              gofumpt
              delve
              gotools
            ];

            shellHook = ''
              export GOPATH=$HOME/go
              export GOBIN=$GOPATH/bin
              echo "Go development environment activated"
              echo "Go: $(go version)"
              echo "Available commands: go, gopls, gofumpt, dlv"
            '';
          };
        }
      );
    };
}
