{ config, pkgs, lib, ... }:

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
  home.packages = with pkgs; [
    ghostty
    
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

    bash.enable = true; # see note on other shells below
  };
}
