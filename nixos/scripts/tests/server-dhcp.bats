#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SERVER_MODULE="$REPO_ROOT/system-specific/x86_64-linux/server.nix"
}

evaluate_dhcp() {
  local dhcp_override="${1-}"

  run env \
    NIXOS_FLAKE="$REPO_ROOT" \
    SERVER_MODULE="$SERVER_MODULE" \
    DHCP_OVERRIDE="$dhcp_override" \
    nix eval --impure --raw --expr '
      let
        flake = builtins.getFlake (builtins.getEnv "NIXOS_FLAKE");
        override = builtins.getEnv "DHCP_OVERRIDE";
        evaluated = flake.inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import (builtins.getEnv "SERVER_MODULE"))
          ] ++ (
            if override == "" then
              [ ]
            else if override == "weaker-false" then
              [
                {
                  networking.useDHCP = flake.inputs.nixpkgs.lib.mkOverride 1001 false;
                }
              ]
            else
              [
                {
                  networking.useDHCP = builtins.fromJSON override;
                }
              ]
          );
        };
      in
        builtins.toJSON evaluated.config.networking.useDHCP
    '
}

@test "server baseline enables DHCP without host networking configuration" {
  evaluate_dhcp

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "server DHCP baseline wins over a lower-priority fallback" {
  evaluate_dhcp weaker-false

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "explicit host DHCP setting overrides the server baseline" {
  evaluate_dhcp false

  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}
