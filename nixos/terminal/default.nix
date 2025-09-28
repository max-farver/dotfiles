{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  ghostty = pkgs.ghostty.overrideAttrs (_: {
    preBuild = ''
      shopt -s globstar
      sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
      shopt -u globstar
    '';
  });
in
{
  imports = [
    ./ai.nix
    ./git.nix
    ./neovim.nix
    ./tmux.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    nur.repos.charmbracelet.freeze
    oauth2c
    taskwarrior3
    taskwarrior-tui
    nix-search-cli
    posting

    ripgrep
    fd
    bat
    jq
    btop
  ];

  programs = {
    ghostty = {
      enable = true;
      settings = {
        theme = "Dracula";
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "/home/mfarver/.config/nixos"; # sets NH_OS_FLAKE variable for you
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        keymap_mode = "auto";
        keymap_cursor = {
          emacs = "blink-block";
          vim_insert = "blink-block";
          vim_normal = "steady-block";
        };
      };
    };

    fzf = {
      enable = true;
      enableZshIntegration = false;
    };

    bash.enable = true; # see note on other shells below
  };
}
