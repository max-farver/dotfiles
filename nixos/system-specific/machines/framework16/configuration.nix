{
  pkgs,
  config,
  lib,
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
  networking.hostName = "framework16";

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
  virtualisation.docker.enable = true;
  # systemd 258 provides Android device uaccess rules; keep adbusers as an explicit login group for existing workflows.
  users.groups.adbusers = { };

  boot.kernelParams = lib.mkForce [
    "resume_offset=702464"
    # Framework 16 iGPU glitch workaround: keep the local 0x410 value so PSR and Panel Replay are disabled once, instead of also inheriting nixos-hardware's narrower 0x10 value.
    "amdgpu.dcdebugmask=0x410"
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/21d58950-6d40-4862-9dc4-3de2ce8b55b0";
  hardware.framework.enableKmod = true;



  powerManagement.enable = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024; # 32GB in MB
    }
  ];

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

    secrets.framework16-paseo-env = {
      file = ../../../secrets/framework16-paseo.env.age;
      mode = "0440";
      owner = "mfarver";
      group = "paseo";
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
    trusted-users = [
      "root"
      "mfarver"
    ];

    substituters = [
      "https://cache.nixos.org"
      "https://codex-desktop-linux.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
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

  networking.firewall = rec {
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };

  services.resolved = {
    enable = true;
  };

  services.paseo = {
    enable = true;
    user = "mfarver";
    inheritUserEnvironment = true;
    listenAddress = "127.0.0.1";
    port = 6767;
    openFirewall = false;
    hostnames = [ ".tailf2b6d7.ts.net" ];

    relay = {
      enable = false;
    };

    settings = {
      version = 1;
      features.webUi.enabled = true;
      agents.providers.omp = {
        enabled = true;
        command = [ "/etc/profiles/per-user/mfarver/bin/omp" ];
      };
    };
  };

  systemd.services.paseo.serviceConfig.EnvironmentFile = config.age.secrets.framework16-paseo-env.path;

  systemd.services.tailscale-paseo-serve = {
    description = "Expose Paseo through Tailscale Serve";
    after = [
      "network-online.target"
      "tailscaled.service"
      "paseo.service"
    ];
    wants = [
      "network-online.target"
      "paseo.service"
    ];
    requires = [
      "tailscaled.service"
      "paseo.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      tailscale="${lib.getExe config.services.tailscale.package}"
      jq_bin="${lib.getExe pkgs.jq}"
      curl_bin="${lib.getExe pkgs.curl}"

      backend_state="Unknown"
      tailnet_ip=""
      for _ in {1..90}; do
        backend_state="$($tailscale status --json --peers=false | $jq_bin -r '.BackendState // "Unknown"')"
        tailnet_ip="$($tailscale ip -4 2>/dev/null | head -n1 || true)"
        if [[ "$backend_state" == "Running" && -n "$tailnet_ip" ]]; then
          break
        fi
        sleep 1
      done

      if [[ "$backend_state" != "Running" || -z "$tailnet_ip" ]]; then
        echo "tailscaled never became ready for Paseo Serve (state=$backend_state, ip=$tailnet_ip)" >&2
        exit 1
      fi

      for _ in {1..60}; do
        if "$curl_bin" -fsS http://127.0.0.1:6767/api/health >/dev/null; then
          paseo_ready=true
          break
        fi
        sleep 1
      done

      if [[ "''${paseo_ready:-false}" != "true" ]]; then
        echo "Paseo never became healthy on http://127.0.0.1:6767/api/health" >&2
        exit 1
      fi

      "$tailscale" serve --yes --bg http://127.0.0.1:6767
    '';
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
    extraGroups = [
      "adbusers"
      "docker"
      "kvm"
    ];
  };

}
