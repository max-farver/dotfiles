#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  OPERATOR_MODULE="$REPO_ROOT/system-specific/machines/homelab/operator.nix"
}

evaluate_assertions() {
  local name="$1"
  local secrets_validated="$2"
  local linkwarden_secret_file="$3"

  run env \
    OPERATOR_MODULE="$OPERATOR_MODULE" \
    NAME="$name" \
    SECRETS_VALIDATED="$secrets_validated" \
    LINKWARDEN_SECRET_FILE="$linkwarden_secret_file" \
    nix eval --impure --raw --expr '
      let
        operator = import (builtins.getEnv "OPERATOR_MODULE") {
          config = {
            homelab.operator = {
              validated = true;
              secretsValidated = builtins.fromJSON (builtins.getEnv "SECRETS_VALIDATED");
              name = builtins.getEnv "NAME";
              uid = 1000;
              primaryGroup = "operator";
              primaryGid = 1000;
              home = "/home/operator";
              flakePath = "/etc/nixos/homelab-bootstrap#homelab";
              ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
              linkwardenSecretFile = builtins.getEnv "LINKWARDEN_SECRET_FILE";
            };
            age.secrets.linkwarden-env.path = "/run/agenix/linkwarden-env";
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
      in
        builtins.concatStringsSep "\n" (map (entry:
          "${if entry.assertion then "true" else "false"}:${entry.message}"
        ) operator.config.assertions)
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
              linkwardenSecretFile = "/etc/nixos/homelab-bootstrap/linkwarden.env.age";
            };
            age.secrets.linkwarden-env.path = "/run/agenix/linkwarden-env";
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
          operator.config.age.secrets.linkwarden-env.file
          operator.config.age.secrets.linkwarden-env.mode
          operator.config.services.linkwarden.environmentFile
          (if operator.config ? users then "present" else "absent")
        ]
    '
}

@test "homelab operator consolidates invalid identity into one actionable assertion" {
  evaluate_assertions root true /etc/nixos/homelab-bootstrap/linkwarden.env.age

  [ "$status" -eq 0 ]
  [ "$output" = $'false:homelab requires a validated non-root operator identity with name, uid, primaryGroup, primaryGid, home, flakePath, ageIdentityPath, and linkwardenSecretFile; import /etc/nixos/homelab-bootstrap/identity.nix through the wrapper flake.\ntrue:homelab requires root-validated secret provisioning; set homelab.operator.secretsValidated = true in /etc/nixos/homelab-bootstrap/identity.nix only after fresh required-secret initialization succeeds.' ]
}

@test "homelab operator rejects an explicitly unvalidated secret state independently" {
  evaluate_assertions operator false /etc/nixos/homelab-bootstrap/linkwarden.env.age

  [ "$status" -eq 0 ]
  [ "$output" = $'true:homelab requires a validated non-root operator identity with name, uid, primaryGroup, primaryGid, home, flakePath, ageIdentityPath, and linkwardenSecretFile; import /etc/nixos/homelab-bootstrap/identity.nix through the wrapper flake.\nfalse:homelab requires root-validated secret provisioning; set homelab.operator.secretsValidated = true in /etc/nixos/homelab-bootstrap/identity.nix only after fresh required-secret initialization succeeds.' ]
}

@test "homelab operator valid identity wires the local Linkwarden ciphertext without users" {
  evaluate_valid_identity_runtime_branch

  [ "$status" -eq 0 ]
  [ "$output" = $'/etc/nixos/homelab-bootstrap#homelab\n/etc/ssh/ssh_host_ed25519_key\n/etc/nixos/homelab-bootstrap/linkwarden.env.age\n0400\n/run/agenix/linkwarden-env\nabsent' ]
}
