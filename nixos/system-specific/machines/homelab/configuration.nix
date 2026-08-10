{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../../desktop-environments/plasma.nix
    ../../x86_64-linux/server.nix
  ];

  networking.hostName = "homelab";

  programs.firefox.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = false;
    };
  };

  services.glance = {
    enable = true;
    openFirewall = false;
    settings = {
      server = {
        host = "127.0.0.1";
        port = 8080;
      };
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "full";
              widgets = [
                { type = "clock"; }
                { type = "calendar"; }
                {
                  type = "bookmarks";
                  groups = [
                    {
                      title = "Infrastructure";
                      links = [
                        {
                          title = "GitHub";
                          url = "https://github.com";
                        }
                      ];
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = lib.mkForce [ ];
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "25.05";
}
