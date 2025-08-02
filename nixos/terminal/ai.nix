{ config, pkgs, lib, inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.nur.overlay
  ];

  home.packages = with pkgs; [
    nur.repos.charmbracelet.crush
  ];
}
