{ config, pkgs, ... }:


{
  imports = [
      ../../../desktop-environments/plasma.nix
      ../../x86_64-linux/linux.nix
      ./hardware-configuration.nix
  ];
  environment.systemPackages = with pkgs; [
    plasma5Packages.plasma-thunderbolt
    wl-clipboard
  ];

  powerManagement.enable = true;

  services.power-profiles-daemon.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Set up ZSH
  programs.zsh.enable = true;
  users.users.mfarver.shell = pkgs.zsh;
}
