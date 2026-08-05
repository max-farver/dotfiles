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

    beszelAgentKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Validated Beszel agent public key for this machine.";
    };
  };

  config = mkMerge [
    {
      assertions = [
      {
        assertion = cfg.validated;
        message = "homelab requires a validated machine-local operator identity; import /etc/nixos/homelab-bootstrap/identity.nix through the wrapper flake.";
      }
      {
        assertion = cfg.secretsValidated;
        message = "homelab requires root-validated secret provisioning; set homelab.operator.secretsValidated = true in /etc/nixos/homelab-bootstrap/identity.nix only after fresh required-secret initialization succeeds.";
      }

      {
        assertion = !cfg.validated || identityPresent;
        message = "homelab.operator.validated requires name, uid, primaryGroup, primaryGid, home, flakePath, and ageIdentityPath.";
      }
      {
        assertion = !cfg.validated || isValidName cfg.name;
        message = "homelab.operator.name must be a valid non-root local account name.";
      }
      {
        assertion = !cfg.validated || isNonRootId cfg.uid;
        message = "homelab.operator.uid must be a non-zero numeric UID.";
      }
      {
        assertion = !cfg.validated || isValidName cfg.primaryGroup;
        message = "homelab.operator.primaryGroup must be a valid non-root group name.";
      }
      {
        assertion = !cfg.validated || isNonRootId cfg.primaryGid;
        message = "homelab.operator.primaryGid must be a non-zero numeric GID.";
      }
      {
        assertion = !cfg.validated || (isAbsolutePath cfg.home && cfg.home != "/" && cfg.home != "/root");
        message = "homelab.operator.home must be an absolute, non-root home directory.";
      }
      {
        assertion = !cfg.validated || isAbsolutePath cfg.flakePath;
        message = "homelab.operator.flakePath must be an absolute wrapper flake reference.";
      }
      {
        assertion = !cfg.validated || isAbsolutePath cfg.ageIdentityPath;
        message = "homelab.operator.ageIdentityPath must be an absolute path.";
      }
      {
        assertion = !cfg.validated || !config.services.beszel.agent.enable || cfg.beszelAgentKey != null;
        message = "homelab.operator.beszelAgentKey must be set when the Beszel agent is enabled.";
      }
    ];
    }
  (mkIf identityValid {
    users.groups.${cfg.primaryGroup} = {
      gid = cfg.primaryGid;
    };

    users.users.${cfg.name} = {
      isNormalUser = true;
      uid = cfg.uid;
      group = cfg.primaryGroup;
      home = cfg.home;
      createHome = true;
      description = "Homelab operator";
      extraGroups = [ "wheel" ];
    };

    programs.nh.flake = cfg.flakePath;
    age.identityPaths = [ cfg.ageIdentityPath ];
  })
  ];
}
