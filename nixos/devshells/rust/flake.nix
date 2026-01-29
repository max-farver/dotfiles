{
  description = "A Nix-flake-based Rust development environment";

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
              rustc
              cargo
              rust-analyzer
              rustfmt
              clippy
            ];

            RUST_SRC_PATH = "${pkgs.rustc}/lib/rustlib/src/rust/library";

            shellHook = ''
              echo "Rust development environment activated"
              echo "Rust: $(rustc --version)"
              echo "Available commands: rustc, cargo, rustfmt, clippy, rust-analyzer"
            '';
          };
        }
      );
    };
}
