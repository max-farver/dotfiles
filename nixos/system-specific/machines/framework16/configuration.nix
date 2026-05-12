{
  pkgs,
  config,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../../desktop-environments/plasma.nix
    ../../x86_64-linux/linux.nix
    ../../../games/steam.nix
  ];
  environment.systemPackages = with pkgs; [
    pkgs.amdgpu_top
    pkgs.virtualglLib
    pkgs.mesa-demos
    pkgs.vulkan-tools
    kdePackages.plasma-thunderbolt
    pkgs.dmidecode
    wl-clipboard
    pkgs.docker-compose # V2 plugin
    pkgs.docker-buildx # Advanced building with multi-platform support
    pkgs.compose2nix # Tool to convert docker-compose.yml to NixOS modules
    pkgs.qmk
    pkgs.attic-client
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default

  ];
  boot.kernelParams = [
    "resume_offset=702464"
    # Framework 16 iGPU glitch workaround (equivalent to modprobe option dcdebugmask=0x410)
    "amdgpu.dcdebugmask=0x410"
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/21d58950-6d40-4862-9dc4-3de2ce8b55b0";

  hardware.framework.enableKmod = false;
  boot = {
    kernelModules = [
      "cros_ec"
      "cros_ec_lpcs"
    ];
    extraModulePackages = with config.boot.kernelPackages; [
      framework-laptop-kmod
    ];
  };

  powerManagement.enable = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024; # 32GB in MB
    }
  ];

  services.power-profiles-daemon.enable = true;
  # Suspend first then hibernate when closing the lid
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  # Hibernate on power button pressed
  services.logind.settings.Login.HandlePowerKey = "hibernate";
  services.logind.settings.Login.HandlePowerKeyLongPress = "poweroff";

  # Define time delay for hibernation
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30m";
    SuspendState = "mem";
  };

  # Framework Updates
  services.fwupd.enable = true;

  # Use a passphrase-less age identity for boot-time agenix decryption.
  # The interactive SSH key cannot be used during system activation.
  age = {
    identityPaths = [ "/home/mfarver/.config/agenix/framework16-attic.agekey" ];

    secrets.framework16 = {
      file = ../../../secrets/framework16.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };

  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.framework16.path;
    settings = {
      # Local-first rollout: do not expose Attic beyond loopback yet.
      listen = "127.0.0.1:8080";
      api-endpoint = "http://127.0.0.1:8080/";
    };
  };

  nix.settings = {
    extra-substituters = [ "http://127.0.0.1:8080/nixos-local" ];
    extra-trusted-public-keys = [ "nixos-local:s9NQtkqtj3u0mp4gBRLisbkDNC1KYbhEkQvxnQfXaoU=" ];
    trusted-users = [
      "root"
      "mfarver"
    ];
  };

  # services.keyd = {
  #   enable = true;
  #   keyboards.voyager = {
  #     ids = [ "3297:1977" ];
  #     # Do not fully swap the left side: making leftcontrol -> leftmeta
  #     # breaks my macro keys that depend on left-ctrl.
  #     settings.main = {
  #       # leftmeta = "leftcontrol";
  #       # leftcontrol = "leftmeta";
  #       # rightcontrol = "rightmeta";
  #       # rightmeta = "rightcontrol";
  #     };
  #   };
  # };

  # QMK flashing permissions and keyboard bootloader automount
  services.udev.packages = [ pkgs.qmk-udev-rules ];
  services.udev.extraRules = ''
    # Mount XIAO/RP2040 bootloader volumes as soon as the keyboard enters flash mode.
    SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="XIAO-BOOT", TAG+="systemd", ENV{SYSTEMD_WANTS}+="xiao-boot-mount.service"

    SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", ATTR{power/wakeup}="disabled", ATTR{driver/1-1.1.1.4/power/wakeup}="disabled"
    SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0014", ATTR{power/wakeup}="disabled", ATTR{driver/1-1.1.1.4/power/wakeup}="disabled"
  '';

  systemd.services.xiao-boot-mount = {
    description = "Mount XIAO-BOOT keyboard bootloader volume";
    path = with pkgs; [
      coreutils
      systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      mkdir -p /run/media/mfarver/XIAO-BOOT
      systemd-mount --no-block --collect --bind-device --owner=mfarver --options=rw,noatime /dev/disk/by-label/XIAO-BOOT /run/media/mfarver/XIAO-BOOT
    '';
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
      vulkan-extension-layer
    ];
  };

  # # Firewall for KDE Connect
  # networking.firewall = rec {
  #   allowedTCPPortRanges = [
  #     {
  #       from = 1714;
  #       to = 1764;
  #     }
  #   ];
  #   allowedUDPPortRanges = allowedTCPPortRanges;
  # };

  services.resolved = {
    enable = true;
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # Set up ZSH
  programs.zsh = {
    enable = true;
  };
  users.users.mfarver = {
    shell = pkgs.zsh;
    extraGroups = [ "docker" ];
  };

}
