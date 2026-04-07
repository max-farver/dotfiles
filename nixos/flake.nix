{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";
    pi-local.url = "path:./pkgs/pi";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty";
    affinity-nix.url = "github:mrshmllow/affinity-nix";
    devenv = {
      url = "github:cachix/devenv";
    };

    # Pin to last known-good Hermes before upstream issue #5502
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.4.3";

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
      hermes-agent,
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
            hermes-agent.nixosModules.default
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

      homeConfigurations = {
        pixel-8-pro = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "aarch64-linux";
            config.allowUnfree = true;
            overlays = [
              nur.overlays.default
            ];
          };

          extraSpecialArgs = {
            inherit inputs;
          };

          modules = [
            ./system-specific/machines/pixel-8-pro/home.nix
          ];
        };

        ubuntu-vps = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
            overlays = [
              nur.overlays.default
            ];
          };

          extraSpecialArgs = {
            inherit inputs;
          };

          modules = [
            ./system-specific/machines/ubuntu-vps/home.nix
          ];
        };
      };

    };
}
