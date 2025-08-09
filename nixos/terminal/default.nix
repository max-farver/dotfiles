{ config, pkgs, lib, inputs, ... }:

let
  ghostty = pkgs.ghostty.overrideAttrs (_: {
    preBuild = ''
        shopt -s globstar
        sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
        shopt -u globstar
      '';
  });
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  imports = [
    ./ai.nix
    ./git.nix
    ./neovim.nix
    ./tmux.nix
    ./zsh.nix
  ];

  nixpkgs.overlays = [
    inputs.nur.overlay
  ];

  home.packages = with pkgs; [
    ghostty

    nur.repos.charmbracelet.freeze
    
    fzf
    ripgrep
    fd
    bat
  ];

  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "/home/mfarver/.config/nixos/flake.nix"; # sets NH_OS_FLAKE variable for you
    };

    bash.enable = true; # see note on other shells below
  };
}
