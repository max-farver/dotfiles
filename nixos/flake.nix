{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty";
    affinity-nix.url = "github:mrshmllow/affinity-nix";

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixos-hardware,
      home-manager,
      nur,
      ghostty,
      affinity-nix,
      ...
    }:
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          modules = [
            ./system-specific/machines/framework16/configuration.nix
            nixos-hardware.nixosModules.framework-16-7040-amd
            nur.modules.nixos.default
            (
              { pkgs, ... }:
              {
                environment.systemPackages = [
                  ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
                ];
              }
            )

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              # home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.users.mfarver = import ./system-specific/machines/framework16/home.nix;
              home-manager.backupFileExtension = "backup";
              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
              home-manager.extraSpecialArgs = {
                inherit inputs;
              };
            }
          ];
        };
      };
    };
}
