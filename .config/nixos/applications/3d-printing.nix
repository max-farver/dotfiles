{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    bambu-studio
  ];
}
