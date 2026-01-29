{
  description = "A Nix-flake-based Python development environment";

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
              python312
              pyright
              uv
              python312Packages.black
              python312Packages.ruff
              python312Packages.pytest
              python312Packages.pip
              poetry
            ];

            shellHook = ''
              export PYTHONBREAKPOINT=ipdb
              echo "Python development environment activated"
              echo "Python: $(python --version)"
              echo "Available commands: python, uv, black, ruff, pyright, pytest"
            '';
          };
        }
      );
    };
}
