{ config, lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
    ../../x86_64-linux/server.nix
  ];

  networking.hostName = "do-server";

  age.secrets.do-server-tailscale-auth = {
    file = ../../../secrets/do-server-tailscale-auth.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
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
                          title = "Tailscale Admin";
                          url = "https://login.tailscale.com/admin/machines";
                        }
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

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.do-server-tailscale-auth.path;
    openFirewall = true;
    extraUpFlags = [ "--advertise-tags=tag:server" ];
  };

  services.tailscale.serve = {
    enable = true;
    services.glance.endpoints."tcp:443" = "http://127.0.0.1:8080";
  };

  systemd.services.tailscale-serve-advertise-glance = {
    description = "Advertise glance service host";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
      "tailscale-serve.service"
    ];
    wants = [
      "tailscaled.service"
      "tailscale-serve.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe config.services.tailscale.package} serve advertise svc:glance
    '';
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "25.05";
}
