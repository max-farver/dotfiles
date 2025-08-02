{ config, pkgs, lib, ... }:

{
  imports = [
    ./3d-printing.nix
    ./discord.nix
  ];
}
