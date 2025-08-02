{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    gh
    lazygit
  ];

  programs.git = {
    enable = true;
    userName = "max.farver";
    userEmail = "maxwell.farver@gmail.com";
  };
}
