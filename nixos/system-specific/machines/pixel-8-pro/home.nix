{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  username = "droid";
  homeDir = "/home/${username}";
in
{
  imports = [
    ../../../terminal/ai.nix
    ../../../terminal/git.nix
    ../../../terminal/neovim.nix
    ../../../terminal/zsh.nix
  ];

  home.username = username;
  home.homeDirectory = homeDir;

  xdg.enable = true;
  targets.genericLinux.enable = true;

  nixpkgs = {
    overlays = [
      inputs.nur.overlays.default
    ];
    config = {
      allowUnfree = true;
    };
  };

  home.packages = with pkgs; [
    bat
    btop
    dos2unix
    fd
    jq
    ripgrep
  ];

  programs = {
    bash.enable = true;

    fzf = {
      enable = true;
      enableZshIntegration = false;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "${homeDir}/.config/nixos";
    };
  };

  programs.zsh.shellAliases = {
    rebuild_switch = lib.mkForce "home-manager switch --flake ~/.config/nixos#pixel-8-pro";
    rebuild_boot = lib.mkForce "echo 'Not supported on Debian; use home-manager switch --flake ~/.config/nixos#pixel-8-pro'";
  };

  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;
}
