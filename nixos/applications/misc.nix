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
    # inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.v3
    # pkgs.openscad
  ];
}
