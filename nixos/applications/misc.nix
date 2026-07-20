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
    pkgs.chromium
    # pkgs.krita
    # pkgs.winboat
    # pkgs.openscad
  ];

  home.sessionVariables = {
    PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
  };
}
