{ pkgs, inputs, ... }:

let
  # DigitalOcean Ubuntu default user is usually "ubuntu".
  username = "ubuntu";
in
{
  imports = [
    ../../../terminal/git.nix
    ../../../terminal/homelab.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  nixpkgs = {
    overlays = [
      inputs.nur.overlays.default
    ];
    config = {
      allowUnfree = true;
    };
  };

  programs.home-manager.enable = true;

  # Keep this pinned to first HM deploy version.
  home.stateVersion = "25.05";
}
