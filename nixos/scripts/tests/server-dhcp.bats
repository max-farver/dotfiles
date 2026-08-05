#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SERVER_MODULE="$REPO_ROOT/system-specific/x86_64-linux/server.nix"
}

evaluate_gateway_assertion() {
  local networking_override="$1"

  run env \
    SERVER_MODULE="$SERVER_MODULE" \
    NETWORKING_OVERRIDE="$networking_override" \
    nix eval --impure --raw --expr '
      let
        override = builtins.getEnv "NETWORKING_OVERRIDE";
        networking = if override == "false-with-gateway" then {
          useDHCP = false;
          defaultGateway = "192.0.2.1";
        } else {
          useDHCP = false;
          defaultGateway = null;
        };
        server = import (builtins.getEnv "SERVER_MODULE") {
          config = { inherit networking; };
          lib = {
            mkDefault = value: value;
          };
          pkgs = { };
        };
      in
        if (builtins.head server.assertions).assertion then "true" else "false"
    '
}

@test "static networking with a gateway satisfies the DHCP safety assertion" {
  evaluate_gateway_assertion false-with-gateway

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "static networking without a gateway fails the DHCP safety assertion" {
  evaluate_gateway_assertion false-without-gateway

  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}
