{
  description = "A Nix-flake-based JavaScript/TypeScript development environment";

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
              nodejs_24
              typescript
              pnpm
              nodePackages.prettier
            ];

            shellHook = ''
              export NODE_ENV=development
              echo "JavaScript/TypeScript development environment activated"
              echo "Node: $(node --version)"
              echo "TypeScript: $(tsc --version)"
              echo "Available commands: node, npm, pnpm, tsc, prettier"
            '';
          };
        }
      );
    };
}
