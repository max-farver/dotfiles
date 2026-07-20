{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    pi-local.url = "path:./pkgs/pi";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    paseo = {
      url = "github:getpaseo/paseo";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
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
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      nur,
      hermes-agent,
      agenix,
      paseo,
      ...
    }:
    let
      mkNixosSystem =
        {
          system ? "x86_64-linux",
          modules,
          homeModule,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules =
            modules
            ++ extraModules
            ++ [
              nur.modules.nixos.default
              hermes-agent.nixosModules.default
              agenix.nixosModules.default
              home-manager.nixosModules.home-manager
              {
                home-manager.sharedModules = [
                  agenix.homeManagerModules.default
                ];
                home-manager.useUserPackages = true;
                home-manager.users.mfarver = import homeModule;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                };
              }
            ];
        };
    in
    {
      nixosConfigurations = rec {
        framework16 = mkNixosSystem {
          modules = [
            ./system-specific/machines/framework16/configuration.nix
          ];
          homeModule = ./system-specific/machines/framework16/home.nix;
          extraModules = [
            nixos-hardware.nixosModules.framework-16-7040-amd
            paseo.nixosModules.default
          ];
        };

        nixos = framework16.extendModules {
          modules = [
            (
              { lib, ... }:
              {
                networking.hostName = lib.mkForce "nixos";
              }
            )
          ];
        };


        homelab = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          modules = [
            ./system-specific/machines/homelab/configuration.nix
            agenix.nixosModules.default
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
      };

    };
}
