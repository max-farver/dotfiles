{
  description = "A Nix-flake-based development environment with common tools";

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

              # Version control
              git
              gh
              lazygit

              # Modern unix tools
              ripgrep
              fd
              bat
              eza

              # File inspection
              jq
              fzf
              delta

              # Build tools
              gnumake
              cmake

              # Other utilities
              tree
              htop
              btop
            ];

            shellHook = ''
              export PAGER=less
              export LESS="-R"
              echo "Base development environment activated"
              echo "Available tools: git, lazygit, ripgrep, fd, bat, eza, jq, fzf, delta"
            '';
          };
        }
      );
    };
}
