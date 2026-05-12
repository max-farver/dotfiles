{ pkgs, ... }:
{
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.xkb.options = "caps:escape";

  # Local login via SDDM and KDE Plasma.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.autoLogin.enable = false;

  # Remote GUI via XRDP, forcing a Plasma X11 session.
  services.xrdp.enable = true;
  services.xrdp.openFirewall = false;
  services.xrdp.defaultWindowManager = "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11";
}
