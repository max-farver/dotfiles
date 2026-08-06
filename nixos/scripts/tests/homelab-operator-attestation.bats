#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  OPERATOR_MODULE="$REPO_ROOT/system-specific/machines/homelab/operator.nix"
}

evaluate_secret_attestation() {
  local secrets_validated="$1"

  run env \
    OPERATOR_MODULE="$OPERATOR_MODULE" \
    SECRETS_VALIDATED="$secrets_validated" \
    nix eval --impure --raw --expr '
      let
        operator = import (builtins.getEnv "OPERATOR_MODULE") {
          config = {
            homelab.operator = {
              validated = true;
              secretsValidated = builtins.fromJSON (builtins.getEnv "SECRETS_VALIDATED");
              name = "operator";
              uid = 1000;
              primaryGroup = "operator";
              primaryGid = 1000;
              home = "/home/operator";
              flakePath = "/etc/nixos/homelab-bootstrap#homelab";
              ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
          };
          };
          lib = {
            hasPrefix = prefix: value:
              builtins.substring 0 (builtins.stringLength prefix) value == prefix;
            mkIf = condition: value: if condition then value else { };
            mkMerge = values: builtins.head values;
            mkOption = value: value;
            types = { };
          };
        };
        attestation = builtins.head (builtins.filter (entry:
          entry.message == "homelab requires root-validated secret provisioning; set homelab.operator.secretsValidated = true in /etc/nixos/homelab-bootstrap/identity.nix only after fresh required-secret initialization succeeds."
        ) operator.config.assertions);
      in
        if attestation.assertion then "true" else "false"
    '
}

evaluate_valid_identity_runtime_branch() {
  run env \
    OPERATOR_MODULE="$OPERATOR_MODULE" \
    nix eval --impure --raw --expr '
      let
        operator = import (builtins.getEnv "OPERATOR_MODULE") {
          config = {
            homelab.operator = {
              validated = true;
              secretsValidated = true;
              name = "operator";
              uid = 1000;
              primaryGroup = "operator";
              primaryGid = 1000;
              home = "/home/operator";
              flakePath = "/etc/nixos/homelab-bootstrap#homelab";
              ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
            };
          };
          lib = {
            hasPrefix = prefix: value:
              builtins.substring 0 (builtins.stringLength prefix) value == prefix;
            mkIf = condition: value: if condition then value else { };
            mkMerge = values: builtins.elemAt values 1;
            mkOption = value: value;
            types = { };
          };
        };
      in
        builtins.concatStringsSep "\n" [
          operator.config.programs.nh.flake
          (builtins.concatStringsSep "\n" operator.config.age.identityPaths)
          (if operator.config ? users then "present" else "absent")
        ]
    '
}

@test "homelab operator assertion rejects an explicitly unvalidated secret state" {
  evaluate_secret_attestation false

  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "homelab operator accepts a validated secret attestation with a valid identity" {
  evaluate_secret_attestation true

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "homelab operator runtime config retains nh and age without managing users" {
  evaluate_valid_identity_runtime_branch

  [ "$status" -eq 0 ]
  [ "$output" = $'/etc/nixos/homelab-bootstrap#homelab\n/etc/ssh/ssh_host_ed25519_key\nabsent' ]
}
