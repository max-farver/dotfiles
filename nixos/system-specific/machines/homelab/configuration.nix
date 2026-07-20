{
  config,
  lib,
  pkgs,
  ...
}:
let
  tailscaleServicesConfigFile = pkgs.writeText "tailscale-serve.json" (builtins.readFile ./tailscale-serve.json);
in
{
  imports = [
    ./hardware-configuration.nix
    ../../../desktop-environments/plasma.nix
    ../../x86_64-linux/server.nix
  ];

  networking.hostName = "homelab";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Bootstrap secret decryption with operator key until homelab host SSH key is enrolled in secrets.nix.
  age.identityPaths = [ "/home/mfarver/.ssh/id_ed25519" ];

  age.secrets.linkwarden-env = {
    file = ../../../secrets/linkwarden.env.age;
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

  services.beszel = {
    hub = {
      enable = true;
      host = "127.0.0.1";
      port = 8090;
    };

    agent = {
      enable = true;
      openFirewall = false;
      environment = {
        HUB_URL = "http://127.0.0.1:8090";
        LISTEN = "0.0.0.0:45876";
        KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXVLydaYfu79T2qdDxKyL6pyLGdHu/RnqZcjCTao+6V mfarver@nixos";
      };
    };
  };

  services.linkwarden = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    openFirewall = false;
    enableRegistration = false;
    database.createLocally = true;
    environmentFile = config.age.secrets.linkwarden-env.path;
    environment = {
      NEXTAUTH_URL = "https://linkwarden.tailf2b6d7.ts.net";
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [ "--advertise-tags=tag:server" ];
    # Don't use `services.tailscale.serve.configFile` for HTTPS service endpoints.
    # Upstream bug: `serve set-config --all` can downgrade `--https` services to HTTP.
    # Ref: https://github.com/tailscale/tailscale/issues/18381
  };

  systemd.services.tailscale-services = {
    description = "Provision Tailscale Services endpoints";
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      tailscale="${lib.getExe config.services.tailscale.package}"
      jq_bin="${lib.getExe pkgs.jq}"
      config_file=${lib.escapeShellArg (toString tailscaleServicesConfigFile)}

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
        echo "tailscaled never became ready for Serve (state=$backend_state, ip=$tailnet_ip)" >&2
        exit 1
      fi

      "$tailscale" serve reset

      while IFS=$'\t' read -r service endpoint target; do
        case "$endpoint" in
          tcp:*) port="''${endpoint#tcp:}" ;;
          *)
            echo "Unsupported endpoint '$endpoint' for $service" >&2
            exit 1
            ;;
        esac

        case "$target" in
          http://*|https://*) destination="''${target#*://}" ;;
          *)
            echo "Unsupported target '$target' for $service" >&2
            exit 1
            ;;
        esac

        echo "Configuring $service: https:$port -> $destination"
        "$tailscale" serve --service="$service" --https="$port" "$destination"
      done < <(
        $jq_bin -r '.services
          | to_entries[]
          | .key as $service
          | .value.endpoints
          | to_entries[]
          | [$service, .key, .value]
          | @tsv' "$config_file"
      )

      while IFS= read -r service; do
        echo "Advertising $service"
        "$tailscale" serve advertise "$service"
      done < <(
        $jq_bin -r '.services
          | to_entries[]
          | select(.value.advertised != false)
          | .key' "$config_file"
      )
    '';
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "25.05";
}
