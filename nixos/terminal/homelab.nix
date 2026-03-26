{ pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    wget
    jq
    yq
    tree
    age
    sops
    tailscale
    caddy
  ];

  home.shellAliases = {
    dc = "docker compose";
    dps = "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'";
  };
}
