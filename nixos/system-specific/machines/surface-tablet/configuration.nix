{ pkgs, config, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ../../../desktop-environments/plasma.nix
    ../../x86_64-linux/linux.nix
  ];

  networking.hostName = "surface-tablet"; # Define your hostname.

  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];

  powerManagement.enable = true;

  services.power-profiles-daemon.enable = true;

  services.resolved = {
    enable = true;
  };

  # Set up ZSH
  programs.zsh = {
    enable = true;
  };
  users.users.mfarver.shell = pkgs.zsh;
}
