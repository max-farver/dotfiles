{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = [
    pkgs.obsidian
    pkgs.gimp
    pkgs.proton-vpn
    # pkgs.krita
    # pkgs.winboat
    # pkgs.openscad
  ];
}
