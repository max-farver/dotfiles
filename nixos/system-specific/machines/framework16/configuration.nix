{ config, pkgs, ... }:


{
  imports = [
      ../../../desktop-environments/plasma.nix
      ../../x86_64-linux/linux.nix
      ./hardware-configuration.nix
      ../../../games/steam.nix
  ];
  environment.systemPackages = with pkgs; [
    pkgs.amdgpu_top
    pkgs.virtualglLib
    pkgs.mesa-demos
    pkgs.vulkan-tools
    plasma5Packages.plasma-thunderbolt
    pkgs.dmidecode
    wl-clipboard
  ];

  boot.kernelParams = [
    "resume_offset=702464"
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/21d58950-6d40-4862-9dc4-3de2ce8b55b0";

  powerManagement.enable = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024; # 32GB in MB
    }
  ];

  services.power-profiles-daemon.enable = true;
  # Suspend first then hibernate when closing the lid
  services.logind.lidSwitch = "suspend-then-hibernate";
  # Hibernate on power button pressed
  services.logind.powerKey = "hibernate";
  services.logind.powerKeyLongPress = "poweroff";


  # Define time delay for hibernation
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
    SuspendState=mem
  '';
  
  # Framework Updates
  services.fwupd.enable = true;

  # Fix waking when lid is closed
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", ATTR{power/wakeup}="disabled", ATTR{driver/1-1.1.1.4/power/wakeup}="disabled"
    SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0014", ATTR{power/wakeup}="disabled", ATTR{driver/1-1.1.1.4/power/wakeup}="disabled"
  '';

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
      vulkan-extension-layer
    ];
  };

  # Firewall for KDE Connect
  networking.firewall = rec {
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };

  # Set up ZSH
  programs.zsh = {
    enable = true;
  };
  users.users.mfarver.shell = pkgs.zsh;
}
