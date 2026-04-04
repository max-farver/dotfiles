{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    easyeffects
    spotify
  ];
}
