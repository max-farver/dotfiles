{ config, lib, ... }:
let
  inherit (lib) mkIf mkMerge mkOption types;

  cfg = config.homelab.operator;

  isAbsolutePath = value: value != null && lib.hasPrefix "/" value;
  isValidName = value:
    value != null
    && value != "root"
    && builtins.match "^[a-z_][a-z0-9_-]*[$]?$" value != null;
  isNonRootId = value: value != null && value > 0;

  identityPresent = builtins.all (value: value != null) [
    cfg.name
    cfg.uid
    cfg.primaryGroup
    cfg.primaryGid
    cfg.home
    cfg.flakePath
    cfg.ageIdentityPath
    cfg.linkwardenSecretFile
  ];

  identityValid =
    cfg.validated
    && identityPresent
    && isValidName cfg.name
    && isNonRootId cfg.uid
    && isValidName cfg.primaryGroup
    && isNonRootId cfg.primaryGid
    && isAbsolutePath cfg.home
    && cfg.home != "/"
    && cfg.home != "/root"
    && isAbsolutePath cfg.flakePath
    && isAbsolutePath cfg.ageIdentityPath;
in
{
  options.homelab.operator = {
    validated = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the machine-local bootstrap has validated the operator identity.";
    };
    secretsValidated = mkOption {
      type = types.bool;
      default = false;
      description = "Whether root-owned bootstrap freshly provisioned and validated all required secrets with the host age identity.";
    };

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Validated non-root operator account name.";
    };

    uid = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = "Validated numeric UID for the operator account.";
    };

    primaryGroup = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Validated primary group name for the operator account.";
    };

    primaryGid = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = "Validated numeric GID for the operator primary group.";
    };

    home = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Validated absolute, non-root home directory for the operator account.";
    };

    flakePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Absolute wrapper flake reference used by nh.";
    };

    ageIdentityPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Absolute SSH identity path used to decrypt bootstrap secrets.";
    };
    linkwardenSecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Machine-local encrypted Linkwarden environment file.";
    };


  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = identityValid;
          message = "homelab requires a validated non-root operator identity with name, uid, primaryGroup, primaryGid, home, flakePath, ageIdentityPath, and linkwardenSecretFile; import /etc/nixos/homelab-bootstrap/identity.nix through the wrapper flake.";
        }
        {
          assertion = cfg.secretsValidated;
          message = "homelab requires root-validated secret provisioning; set homelab.operator.secretsValidated = true in /etc/nixos/homelab-bootstrap/identity.nix only after fresh required-secret initialization succeeds.";
        }
      ];
    }
  (mkIf identityValid {

    programs.nh.flake = cfg.flakePath;
    age.identityPaths = [ cfg.ageIdentityPath ];
    age.secrets.linkwarden-env = {
      file = cfg.linkwardenSecretFile;
      mode = "0400";
      owner = "root";
      group = "root";
    };
    services.linkwarden.environmentFile = config.age.secrets.linkwarden-env.path;
  })
  ];
}
