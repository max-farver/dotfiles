#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SYSTEM="framework16"
DEFAULT_REPO_URL="https://github.com/max-farver/dotfiles"
DEFAULT_GIT_DIR='${HOME}/.cfg'
DEFAULT_WORK_TREE='${HOME}/.config'
DEFAULT_HARDWARE_SRC="/etc/nixos/hardware-configuration.nix"
NIX_EXPERIMENTAL_FEATURES="nix-command flakes"

SYSTEM="${DOTFILES_SYSTEM:-$DEFAULT_SYSTEM}"
REPO_URL="${DOTFILES_REPO_URL:-$DEFAULT_REPO_URL}"
GIT_DIR="${DOTFILES_GIT_DIR:-$HOME/.cfg}"
WORK_TREE="${DOTFILES_WORK_TREE:-$HOME/.config}"
HARDWARE_SRC="$DEFAULT_HARDWARE_SRC"
HARDWARE_DEST=""
DRY_RUN=0
SKIP_REBUILD=0
SKIP_NEOVIM_CHECK=0
FORCE_NEOVIM_CHECK=0
SYNC_HARDWARE=0
PRINT_HOST_KEY=0
RUN_CHECKS=0
ENROLL_HOST_KEY=0
INITIALIZE_HOMELAB_SECRETS=0
LINKWARDEN_ENV_FILE=""
HOMELAB_BOOTSTRAP_DIR="/etc/nixos/homelab-bootstrap"
HOMELAB_BOOTSTRAP_FLAKE="$HOMELAB_BOOTSTRAP_DIR"
HOMELAB_OPERATOR_NAME=""
HOMELAB_OPERATOR_UID=""
HOMELAB_OPERATOR_GROUP=""
HOMELAB_OPERATOR_GID=""
HOMELAB_OPERATOR_HOME=""
HOMELAB_IDENTITY_NIX=""
HOMELAB_FLAKE_NIX=""
HOMELAB_PREVIOUS_FLAKE_NIX=""
HOMELAB_SECRETS_BACKUP_DIR=""
HOMELAB_SECRETS_INITIALIZED=0

usage() {
  cat <<EOF
Usage: scripts/setup-system.sh [--dry-run] [--system NAME] [--repo-url URL] [--git-dir PATH] [--work-tree PATH] [--sync-hardware] [--hardware-src PATH] [--hardware-dest PATH] [--print-host-key] [--enroll-host-key] [--initialize-homelab-secrets] [--linkwarden-env-file PATH] [--checks] [--skip-rebuild] [--skip-neovim-check] [--force-neovim-check] [-h|--help]

Post-install bootstrap for this dotfiles repository.

Options:
  --dry-run              Print commands without mutating files or rebuilding.
  --system NAME          NixOS configuration output to apply. Default: $DEFAULT_SYSTEM.
  --repo-url URL         Bare repository clone URL. Default: $DEFAULT_REPO_URL.
  --git-dir PATH         Git metadata directory. Default: $DEFAULT_GIT_DIR.
  --work-tree PATH       Dotfiles work tree. Default: $DEFAULT_WORK_TREE.
  --sync-hardware        Copy generated hardware config into the selected machine config. Homelab captures it in the local wrapper.
  --hardware-src PATH    Hardware config source. Default: $DEFAULT_HARDWARE_SRC.
  --hardware-dest PATH   Hardware config destination. Default: \$NIXOS_FLAKE/system-specific/machines/\$SYSTEM/hardware-configuration.nix (non-homelab only).
  --print-host-key       Print /etc/ssh/ssh_host_ed25519_key.pub for agenix enrollment.
  --enroll-host-key      Replace the homelab agenix recipient with this host key and rekey secrets.
  --initialize-homelab-secrets
                         Create or re-encrypt the Linkwarden secret to this host key before first boot.
  --linkwarden-env-file PATH
                         Env file to encrypt for Linkwarden instead of generating NEXTAUTH_SECRET.
  --checks               Run homelab service health checks after rebuild handling.
  --skip-rebuild         Skip the selected NixOS rebuild action.
  --skip-neovim-check    Skip the post-rebuild nvim startup check.
  --force-neovim-check   Run the nvim startup check for homelab.
  -h, --help             Show this help.

Environment overrides:
  DOTFILES_SYSTEM        Default value for --system. Default: $DEFAULT_SYSTEM.
  DOTFILES_REPO_URL      Default value for --repo-url. Default: $DEFAULT_REPO_URL.
  DOTFILES_GIT_DIR       Default value for --git-dir. Default: $DEFAULT_GIT_DIR.
  DOTFILES_WORK_TREE     Default value for --work-tree. Default: $DEFAULT_WORK_TREE.
EOF
}

die() {
  printf '[!] %s\n' "$*" >&2
  exit 1
}

quote_cmd() {
  local quoted=()
  local arg
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    quoted+=("$arg")
  done
  printf '%s' "${quoted[*]}"
}

run() {
  if (( DRY_RUN )); then
    printf '[dry-run] %s\n' "$(quote_cmd "$@")"
    return 0
  fi

  printf '[+] %s\n' "$(quote_cmd "$@")"
  "$@"
}

run_as_root() {
  if (( DRY_RUN )); then
    run sudo "$@"
    return 0
  fi

  if (( EUID == 0 )); then
    run "$@"
  else
    run sudo "$@"
  fi
}

nix_cmd() {
  run nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" "$@"
}

nixos_rebuild() {
  if [[ "$SYSTEM" == "homelab" ]]; then
    run sudo nixos-rebuild build --no-write-lock-file --flake "$HOMELAB_BOOTSTRAP_FLAKE#homelab" --option experimental-features "$NIX_EXPERIMENTAL_FEATURES"
  else
    run sudo nixos-rebuild switch --flake "$NIXOS_FLAKE#$SYSTEM" --option experimental-features "$NIX_EXPERIMENTAL_FEATURES"
  fi
}

require_homelab_mutable_users() {
  local mutable_users

  [[ "$SYSTEM" == "homelab" ]] || return 0

  mutable_users="$(nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" eval --no-write-lock-file --raw "$HOMELAB_BOOTSTRAP_FLAKE#nixosConfigurations.homelab.config.users.mutableUsers")" \
    || die "Could not evaluate users.mutableUsers for the staged homelab configuration"
  [[ "$mutable_users" == "true" ]] \
    || die "Refusing to stage homelab configuration with users.mutableUsers=$mutable_users; the bootstrap preserves an existing unmanaged administrator"
}

ensure_homelab_unlock_password() {
  local password_status
  local password_state

  [[ "$SYSTEM" == "homelab" ]] || return 0

  password_status="$(sudo passwd --status "$HOMELAB_OPERATOR_NAME")" \
    || die "Could not determine local password status for $HOMELAB_OPERATOR_NAME"
  read -r _ password_state _ <<< "$password_status"
  [[ "$password_state" == "P" ]] \
    || die "$HOMELAB_OPERATOR_NAME has no usable local password (state: ${password_state:-unknown}). Set one with: sudo passwd $HOMELAB_OPERATOR_NAME"

  printf '[i] Local unlock password is configured for %s\n' "$HOMELAB_OPERATOR_NAME"
}

validate_git_origin() {
  local origin_urls=()

  is_git_dir "$GIT_DIR" || return 0
  mapfile -t origin_urls < <(git --git-dir="$GIT_DIR" remote get-url --all origin) \
    || die "Existing Git metadata has no readable origin remote: $GIT_DIR"
  [[ ${#origin_urls[@]} -eq 1 && "${origin_urls[0]}" == "$REPO_URL" ]] \
    || die "Existing Git origin must exactly match --repo-url; expected $REPO_URL"
}
ensure_host_key() {
  local key_path="/etc/ssh/ssh_host_ed25519_key.pub"
  local private_key_path="/etc/ssh/ssh_host_ed25519_key"

  if (( DRY_RUN )); then
    run sudo mkdir -p /etc/ssh
    run sudo ssh-keygen -A
    run sudo sh -c 'if test ! -e /etc/ssh/ssh_host_ed25519_key; then ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key; fi; test -f /etc/ssh/ssh_host_ed25519_key && ! test -L /etc/ssh/ssh_host_ed25519_key && test -r /etc/ssh/ssh_host_ed25519_key && ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key >/dev/null && ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
    run sudo test -r "$key_path"
    return 0
  fi

  if (( EUID == 0 )); then
    run mkdir -p /etc/ssh
    if [[ ! -e "$private_key_path" ]]; then
      run ssh-keygen -A
    fi
    if [[ ! -e "$private_key_path" ]]; then
      run ssh-keygen -t ed25519 -N "" -f "$private_key_path"
    fi
    [[ -f "$private_key_path" && ! -L "$private_key_path" && -r "$private_key_path" ]] \
      || die "SSH host ed25519 private key is unavailable: $private_key_path"
    ssh-keygen -y -f "$private_key_path" >/dev/null \
      || die "SSH host ed25519 age identity is not a readable private key: $private_key_path"
    run sh -c 'ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
    [[ -f "$key_path" && ! -L "$key_path" && -r "$key_path" ]] \
      || die "SSH host ed25519 public key is unavailable after deriving it from $private_key_path"
    return 0
  fi

  run sudo mkdir -p /etc/ssh
  if ! sudo test -e "$private_key_path"; then
    run sudo ssh-keygen -A
  fi
  if ! sudo test -e "$private_key_path"; then
    run sudo ssh-keygen -t ed25519 -N "" -f "$private_key_path"
  fi
  sudo test -f "$private_key_path" && ! sudo test -L "$private_key_path" && sudo test -r "$private_key_path" \
    || die "SSH host ed25519 private key is unavailable: $private_key_path"
  sudo ssh-keygen -y -f "$private_key_path" >/dev/null \
    || die "SSH host ed25519 age identity is not a readable private key: $private_key_path"
  run sudo sh -c 'ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
  sudo test -f "$key_path" && ! sudo test -L "$key_path" && sudo test -r "$key_path" \
    || die "SSH host ed25519 public key is unavailable after deriving it from $private_key_path"
}

run_in_dir() {
  local dir="$1"
  shift

  if (( DRY_RUN )); then
    printf '[dry-run] cd %s && %s\n' "$(quote_cmd "$dir")" "$(quote_cmd "$@")"
    return 0
  fi

  printf '[+] cd %s && %s\n' "$(quote_cmd "$dir")" "$(quote_cmd "$@")"
  (cd "$dir" && "$@")
}

read_host_key() {
  if (( EUID == 0 )); then
    cat /etc/ssh/ssh_host_ed25519_key.pub
  else
    sudo cat /etc/ssh/ssh_host_ed25519_key.pub
  fi
}

replace_line_in_file() {
  local file="$1"
  local match_prefix="$2"
  local replacement="$3"
  local tmp
  local replaced=0
  tmp="$(mktemp)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$match_prefix"* ]]; then
      printf '%s\n' "$replacement" >> "$tmp"
      replaced=1
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$file"

  (( replaced )) || {
    rm -f "$tmp"
    die "Could not find line starting with '$match_prefix' in $file"
  }

  mv "$tmp" "$file"
}

enroll_host_key() {
  local host_key="$1"
  local escaped_host_key="$host_key"
  local secrets_dir="$NIXOS_FLAKE/secrets"

  [[ "$SYSTEM" == "homelab" ]] || die "--enroll-host-key is only supported for --system homelab"
  [[ -f "$SECRETS_FILE" ]] || die "Missing agenix secrets file: $SECRETS_FILE"

  escaped_host_key="${escaped_host_key//\\/\\\\}"
  escaped_host_key="${escaped_host_key//\"/\\\"}"

  if (( DRY_RUN )); then
    printf '[dry-run] replace homelab recipient in %s with %s\n' "$(quote_cmd "$SECRETS_FILE")" "$(quote_cmd "$host_key")"
  else
    replace_line_in_file "$SECRETS_FILE" "  homelab =" "  homelab = \"$escaped_host_key\";"
  fi

  if command -v agenix >/dev/null 2>&1; then
    run_in_dir "$secrets_dir" agenix -r
  else
    need_cmd nix "agenix is not installed and nix is required to run github:ryantm/agenix"
    run_in_dir "$secrets_dir" nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run github:ryantm/agenix -- -r
  fi
}

random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import secrets; print(secrets.token_urlsafe(48))'
  else
    nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run nixpkgs#openssl -- rand -base64 48
  fi
}


linkwarden_env() {
  if [[ -n "$LINKWARDEN_ENV_FILE" ]]; then
    [[ -r "$LINKWARDEN_ENV_FILE" ]] || die "Linkwarden env file is not readable: $LINKWARDEN_ENV_FILE"
    cat "$LINKWARDEN_ENV_FILE"
    return 0
  fi

  printf 'NEXTAUTH_SECRET=%s\n' "$(random_secret)"
}

encrypt_secret_content() {
  local recipient="$1"
  local dest="$2"
  local content="$3"
  local tmp

  tmp="$(mktemp "$(dirname -- "$dest")/.tmp-$(basename -- "$dest").XXXXXX")"
  if command -v age >/dev/null 2>&1; then
    printf '%s' "$content" | age -r "$recipient" -o "$tmp"
  else
    need_cmd nix "age is not installed and nix is required to run nixpkgs#age"
    printf '%s' "$content" | nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run nixpkgs#age -- -r "$recipient" -o "$tmp"
  fi
  mv "$tmp" "$dest"
}

initialize_homelab_secrets() {
  local host_key="$1"
  local escaped_host_key="$host_key"
  local linkwarden_secret="$NIXOS_FLAKE/secrets/linkwarden.env.age"
  local linkwarden_content

  [[ "$SYSTEM" == "homelab" ]] || die "--initialize-homelab-secrets is only supported for --system homelab"
  [[ -f "$SECRETS_FILE" ]] || die "Missing agenix secrets file: $SECRETS_FILE"
  [[ -d "$(dirname -- "$linkwarden_secret")" ]] || die "Missing secrets directory: $(dirname -- "$linkwarden_secret")"

  escaped_host_key="${escaped_host_key//\\/\\\\}"
  escaped_host_key="${escaped_host_key//\"/\\\"}"

  if (( DRY_RUN )); then
    printf '[dry-run] replace homelab recipient in %s with %s\n' "$(quote_cmd "$SECRETS_FILE")" "$(quote_cmd "$host_key")"
    printf '[dry-run] set homelab-only recipients in %s for homelab secret files\n' "$(quote_cmd "$SECRETS_FILE")"
    printf '[dry-run] encrypt fresh Linkwarden env to %s\n' "$(quote_cmd "$linkwarden_secret")"
    return 0
  fi

  linkwarden_content="$(linkwarden_env)"

  replace_line_in_file "$SECRETS_FILE" "  homelab =" "  homelab = \"$escaped_host_key\";"
  encrypt_secret_content "$host_key" "$linkwarden_secret" "$linkwarden_content"
}

need_cmd() {
  local cmd="$1"
  local hint="$2"
  command -v "$cmd" >/dev/null 2>&1 || die "$hint"
}
nix_escape() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$\{/\\\${}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}
is_ssh_public_key_line() {
  local key="$1"

  [[ -n "$key" && "$key" != *$'\n'* && "$key" != *$'\r'* ]] \
    && command -v ssh-keygen >/dev/null 2>&1 \
    && ssh-keygen -lf <(printf '%s\n' "$key") >/dev/null 2>&1
}

detect_homelab_operator() {
  local passwd_entry
  local group_entry
  local nss_uid
  local home_owner_uid

  [[ "$SYSTEM" == "homelab" ]] || return 0
  (( EUID != 0 )) || die "Homelab bootstrap must be invoked directly by the intended non-root operator, not through sudo or as root"
  need_cmd getent "getent is required to resolve the invoking homelab operator through NSS"

  HOMELAB_OPERATOR_UID="$(id -u)"
  [[ "$HOMELAB_OPERATOR_UID" =~ ^[1-9][0-9]*$ ]] || die "Homelab bootstrap requires a non-root numeric UID"
  passwd_entry="$(getent passwd "$HOMELAB_OPERATOR_UID")" || die "No NSS passwd entry exists for UID $HOMELAB_OPERATOR_UID"
  IFS=: read -r HOMELAB_OPERATOR_NAME _ nss_uid HOMELAB_OPERATOR_GID _ HOMELAB_OPERATOR_HOME _ <<< "$passwd_entry"
  [[ "$nss_uid" == "$HOMELAB_OPERATOR_UID" ]] || die "NSS passwd entry UID does not match invoking UID $HOMELAB_OPERATOR_UID"
  [[ "$HOMELAB_OPERATOR_NAME" =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || die "Refusing unsupported homelab operator name from NSS: $HOMELAB_OPERATOR_NAME"
  [[ "$HOMELAB_OPERATOR_GID" =~ ^[0-9]+$ && 10#$HOMELAB_OPERATOR_GID -gt 0 ]] || die "NSS primary GID must be a positive integer for $HOMELAB_OPERATOR_NAME"
  [[ "$HOMELAB_OPERATOR_HOME" =~ ^/[A-Za-z0-9._/-]+$ && "$HOMELAB_OPERATOR_HOME" != "/" ]] || die "Refusing unsupported home directory from NSS: $HOMELAB_OPERATOR_HOME"
  [[ -d "$HOMELAB_OPERATOR_HOME" ]] || die "Operator home directory is missing: $HOMELAB_OPERATOR_HOME"
  home_owner_uid="$(stat -c '%u' -- "$HOMELAB_OPERATOR_HOME")" || die "Could not read ownership of $HOMELAB_OPERATOR_HOME"
  [[ "$home_owner_uid" == "$HOMELAB_OPERATOR_UID" ]] || die "Operator home directory is not owned by UID $HOMELAB_OPERATOR_UID: $HOMELAB_OPERATOR_HOME"

  group_entry="$(getent group "$HOMELAB_OPERATOR_GID")" || die "No NSS group entry exists for GID $HOMELAB_OPERATOR_GID"
  IFS=: read -r HOMELAB_OPERATOR_GROUP _ _ _ <<< "$group_entry"
  [[ "$HOMELAB_OPERATOR_GROUP" =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || die "Refusing unsupported primary group from NSS: $HOMELAB_OPERATOR_GROUP"


  if [[ ! -e "$HOMELAB_BOOTSTRAP_DIR" && ! -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
    HOMELAB_IDENTITY_NIX="$(cat <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$(nix_escape "$HOMELAB_OPERATOR_NAME")";
    uid = $HOMELAB_OPERATOR_UID;
    primaryGroup = "$(nix_escape "$HOMELAB_OPERATOR_GROUP")";
    primaryGid = $HOMELAB_OPERATOR_GID;
    home = "$(nix_escape "$HOMELAB_OPERATOR_HOME")";
    flakePath = "$HOMELAB_BOOTSTRAP_DIR#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = false;
  };
}
EOF
)"
  fi
  [[ "$NIXOS_FLAKE" == /* ]] || die "Homelab bootstrap requires an absolute work-tree path"
  HOMELAB_FLAKE_NIX="$(cat <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$(nix_escape "$NIXOS_FLAKE")";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
)"
  HOMELAB_PREVIOUS_FLAKE_NIX="$(cat <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$(nix_escape "$NIXOS_FLAKE")";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ dotfiles.nixosModules.homelabOperator ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
)"

  printf '[i] Homelab operator: %s (uid=%s, primary-group=%s, gid=%s, home=%s)\n' \
    "$HOMELAB_OPERATOR_NAME" "$HOMELAB_OPERATOR_UID" "$HOMELAB_OPERATOR_GROUP" "$HOMELAB_OPERATOR_GID" "$HOMELAB_OPERATOR_HOME"

  if (( DRY_RUN )); then
    printf '[dry-run] validate sudo capability and require exact confirmation before creating %s\n' "$HOMELAB_BOOTSTRAP_DIR"
    return 0
  fi

  sudo -v || die "Homelab bootstrap requires sudo capability for $HOMELAB_OPERATOR_NAME"
  if [[ ! -e "$HOMELAB_BOOTSTRAP_DIR" && ! -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
    local confirmation
    read -r -p "Type '$HOMELAB_OPERATOR_NAME' to create the machine-local homelab operator identity: " confirmation
    [[ "$confirmation" == "$HOMELAB_OPERATOR_NAME" ]] || die "Confirmation did not exactly match the detected homelab operator"
  fi
}

validate_homelab_hardware_source() {
  local hardware_content
  local root_mount
  local root_assignment_regex='fileSystems[[:space:]]*\.[[:space:]]*"/"[[:space:]]*=[[:space:]]*\{([^}]*)\}'
  local device_regex='(^|[[:space:];])device[[:space:]]*=[[:space:]]*"[^"]+"[[:space:]]*;'
  local fs_type_regex='(^|[[:space:];])fsType[[:space:]]*=[[:space:]]*"[^"]+"[[:space:]]*;'
  local placeholder_device_regex='(^|[[:space:];])device[[:space:]]*=[[:space:]]*"/dev/root"[[:space:]]*;'

  [[ "$SYSTEM" == "homelab" ]] || return 0
  sudo test -f "$HARDWARE_SRC" && ! sudo test -L "$HARDWARE_SRC" && sudo test -s "$HARDWARE_SRC" \
    || die "Homelab hardware source must be a nonempty regular file: $HARDWARE_SRC"
  need_cmd nix-instantiate "nix-instantiate is required to parse the homelab hardware source"
  sudo nix-instantiate --parse "$HARDWARE_SRC" >/dev/null \
    || die "Homelab hardware source is not valid Nix syntax: $HARDWARE_SRC"
  hardware_content="$(sudo cat "$HARDWARE_SRC")" \
    || die "Could not read homelab hardware source: $HARDWARE_SRC"
  [[ "$hardware_content" != *REPLACE* ]] \
    || die "Homelab hardware configuration still contains a REPLACE placeholder: $HARDWARE_SRC"
  [[ "$hardware_content" =~ $root_assignment_regex ]] \
    || die "Homelab hardware source must declare fileSystems.\"/\" as a concrete root filesystem mount: $HARDWARE_SRC"
  root_mount="${BASH_REMATCH[1]}"
  [[ "$root_mount" =~ $device_regex && "$root_mount" =~ $fs_type_regex ]] \
    || die "Homelab hardware source root filesystem mount must have nonempty device and fsType values: $HARDWARE_SRC"
  [[ ! "$root_mount" =~ $placeholder_device_regex ]] \
    || die "Homelab hardware source root filesystem mount must not use the /dev/root placeholder: $HARDWARE_SRC"
}

require_root_owned_file() {
  local path="$1"
  local owner_uid
  local mode

  sudo test -f "$path" && ! sudo test -L "$path" || die "Expected a regular file at $path"
  owner_uid="$(sudo stat -c '%u' -- "$path")" || die "Could not read ownership of $path"
  [[ "$owner_uid" == "0" ]] || die "Refusing non-root-owned bootstrap file: $path"
  mode="$(sudo stat -c '%a' -- "$path")" || die "Could not read mode of $path"
  [[ ! "$mode" =~ ^[0-7]*[2367][0-7]$ && ! "$mode" =~ ^[0-7]*[0-7][2367]$ ]] \
    || die "Refusing group- or world-writable bootstrap file: $path"
}
require_root_owned_directory() {
  local path="$1"
  local current="$path"
  local owner_uid
  local mode

  while :; do
    sudo test -d "$current" && ! sudo test -L "$current" || die "Expected a non-symlink directory at $current"
    owner_uid="$(sudo stat -c '%u' -- "$current")" || die "Could not read ownership of $current"
    [[ "$owner_uid" == "0" ]] || die "Refusing non-root-owned bootstrap directory ancestry: $current"
    mode="$(sudo stat -c '%a' -- "$current")" || die "Could not read mode of $current"
    [[ ! "$mode" =~ ^[0-7]*[2367][0-7]$ && ! "$mode" =~ ^[0-7]*[0-7][2367]$ ]] \
      || die "Refusing group- or world-writable bootstrap directory ancestry: $current"
    [[ "$current" == / ]] && break
    current="${current%/*}"
    [[ -n "$current" ]] || current="/"
  done
}
cleanup_homelab_wrapper_lock() {
  local lock_file="$HOMELAB_BOOTSTRAP_DIR/flake.lock"

  if ! sudo test -e "$lock_file" && ! sudo test -L "$lock_file"; then
    return 0
  fi

  require_root_owned_file "$lock_file"
  printf '[i] Removing stale root-owned homelab wrapper lock at %s so the wrapper uses the live local dotfiles checkout\n' "$lock_file"
  run_as_root rm -f -- "$lock_file"
}

validate_existing_homelab_identity() {
  local identity="$1"
  local line
  local expected_operator_name
  local expected_operator_group
  local expected_operator_home
  local expected_flake_path

  expected_operator_name="$(nix_escape "$HOMELAB_OPERATOR_NAME")"
  expected_operator_group="$(nix_escape "$HOMELAB_OPERATOR_GROUP")"
  expected_operator_home="$(nix_escape "$HOMELAB_OPERATOR_HOME")"
  expected_flake_path="$(nix_escape "$HOMELAB_BOOTSTRAP_DIR#homelab")"

  [[ "$identity" == *"validated = true;"* ]] \
    && [[ "$identity" == *"name = \"$expected_operator_name\";"* ]] \
    && [[ "$identity" == *"uid = $HOMELAB_OPERATOR_UID;"* ]] \
    && [[ "$identity" == *"primaryGroup = \"$expected_operator_group\";"* ]] \
    && [[ "$identity" == *"primaryGid = $HOMELAB_OPERATOR_GID;"* ]] \
    && [[ "$identity" == *"home = \"$expected_operator_home\";"* ]] \
    && [[ "$identity" == *"flakePath = \"$expected_flake_path\";"* ]] \
    && [[ "$identity" == *"ageIdentityPath = \"/etc/ssh/ssh_host_ed25519_key\";"* ]] \
    || die "Machine-local homelab identity does not match the detected account; refusing to replace it"

}
legacy_homelab_beszel_agent_key_count() {
  local identity="$1"
  local line
  local count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*beszelAgentKey[[:space:]]*=[[:space:]]*(null|\"([^\"\\]|\\.)*\")[[:space:]]*\;[[:space:]]*$ ]]; then
      ((count += 1))
    fi
  done <<< "$identity"
  printf '%s' "$count"
}

remove_legacy_homelab_beszel_agent_key() {
  local identity="$1"
  local line
  local count
  local updated_identity=""
  local local_stage
  local root_stage

  count="$(legacy_homelab_beszel_agent_key_count "$identity")"
  (( count <= 1 )) || die "Machine-local homelab identity contains multiple legacy Beszel agent keys"
  (( count == 1 )) || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*beszelAgentKey[[:space:]]*=[[:space:]]*(null|\"([^\"\\]|\\.)*\")[[:space:]]*\;[[:space:]]*$ ]]; then
      continue
    fi
    updated_identity+="$line"$'\n'
  done <<< "$identity"

  local_stage="$(mktemp)" || die "Could not create local identity staging file"
  if ! printf '%s' "$updated_identity" > "$local_stage"; then
    rm -f "$local_stage"
    die "Could not stage legacy Beszel identity migration"
  fi
  chmod 0600 "$local_stage"
  root_stage="$(sudo mktemp "$HOMELAB_BOOTSTRAP_DIR/.identity.nix.XXXXXX")" || {
    rm -f "$local_stage"
    die "Could not create root-owned identity staging file"
  }
  if ! run_as_root install -o root -g root -m 0644 "$local_stage" "$root_stage"; then
    run_as_root rm -f "$root_stage"
    rm -f "$local_stage"
    die "Could not stage legacy Beszel identity migration"
  fi
  rm -f "$local_stage"
  if ! run_as_root mv -f "$root_stage" "$HOMELAB_BOOTSTRAP_DIR/identity.nix"; then
    run_as_root rm -f "$root_stage"
    die "Could not atomically remove the legacy Beszel agent key"
  fi
}
homelab_secret_validation_state() {
  local identity="$1"
  local line
  local state="missing"
  local state_count=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*secretsValidated[[:space:]]*=[[:space:]]*(true|false)\;[[:space:]]*$ ]]; then
      state="${BASH_REMATCH[1]}"
      ((state_count += 1))
    fi
  done <<< "$identity"
  (( state_count <= 1 )) \
    || die "Machine-local homelab identity must contain at most one secret provisioning state"
  printf '%s' "$state"
}

require_homelab_secrets_validated() {
  local identity="$1"
  local state

  state="$(homelab_secret_validation_state "$identity")"
  [[ "$state" == "true" ]] \
    || die "Machine-local homelab secrets are unvalidated. Run scripts/setup-system.sh --system homelab --initialize-homelab-secrets before staging a generation"
}

verify_homelab_linkwarden_secret() {
  local linkwarden_secret="$NIXOS_FLAKE/secrets/linkwarden.env.age"
  local host_key
  local escaped_host_key
  local secrets_content

  [[ -f "$SECRETS_FILE" && ! -L "$SECRETS_FILE" && -s "$SECRETS_FILE" ]] \
    || die "Missing or unsafe homelab secret recipient configuration: $SECRETS_FILE"
  [[ -f "$linkwarden_secret" && ! -L "$linkwarden_secret" && -s "$linkwarden_secret" ]] \
    || die "Missing or unsafe Linkwarden ciphertext: $linkwarden_secret"
  sudo test -f /etc/ssh/ssh_host_ed25519_key && ! sudo test -L /etc/ssh/ssh_host_ed25519_key \
    || die "Homelab host age identity is unavailable: /etc/ssh/ssh_host_ed25519_key"
  host_key="$(read_host_key)" || die "Could not read the homelab host public key"
  is_ssh_public_key_line "$host_key" || die "Homelab host public key is invalid"
  escaped_host_key="$(nix_escape "$host_key")"
  secrets_content="$(cat "$SECRETS_FILE")" || die "Could not read $SECRETS_FILE"
  [[ "$secrets_content" == *"homelab = \"$escaped_host_key\";"* ]] \
    || die "Homelab recipient configuration does not match this host key; initialize homelab secrets again"

  if command -v age >/dev/null 2>&1; then
    sudo age --decrypt --identity /etc/ssh/ssh_host_ed25519_key --output /dev/null "$linkwarden_secret" \
      || die "Linkwarden ciphertext is not decryptable by this homelab host key; initialize homelab secrets again"
  else
    need_cmd nix "age is not installed and nix is required to verify the Linkwarden ciphertext"
    sudo nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run nixpkgs#age -- \
      --decrypt --identity /etc/ssh/ssh_host_ed25519_key --output /dev/null "$linkwarden_secret" \
      || die "Linkwarden ciphertext is not decryptable by this homelab host key; initialize homelab secrets again"
  fi
}

backup_validated_homelab_secrets() {
  local identity
  local state

  [[ "$SYSTEM" == "homelab" ]] || return 0
  [[ -e "$HOMELAB_BOOTSTRAP_DIR" || -L "$HOMELAB_BOOTSTRAP_DIR" ]] || return 0
  require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
  require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
  identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
  validate_existing_homelab_identity "$identity"
  state="$(homelab_secret_validation_state "$identity")"
  if [[ "$state" != "true" ]]; then
    (( INITIALIZE_HOMELAB_SECRETS )) \
      || require_homelab_secrets_validated "$identity"
    return 0
  fi

  ensure_host_key
  verify_homelab_linkwarden_secret
  HOMELAB_SECRETS_BACKUP_DIR="$(mktemp -d)" || die "Could not create a Linkwarden secret backup"
  chmod 0700 "$HOMELAB_SECRETS_BACKUP_DIR"
  cp --preserve=mode -- "$SECRETS_FILE" "$HOMELAB_SECRETS_BACKUP_DIR/secrets.nix" \
    && cp --preserve=mode -- "$NIXOS_FLAKE/secrets/linkwarden.env.age" "$HOMELAB_SECRETS_BACKUP_DIR/linkwarden.env.age" \
    || die "Could not preserve verified homelab secret artifacts before checkout"
}

restore_validated_homelab_secrets() {
  [[ -n "$HOMELAB_SECRETS_BACKUP_DIR" ]] || return 0

  cp --preserve=mode -- "$HOMELAB_SECRETS_BACKUP_DIR/secrets.nix" "$SECRETS_FILE" \
    && cp --preserve=mode -- "$HOMELAB_SECRETS_BACKUP_DIR/linkwarden.env.age" "$NIXOS_FLAKE/secrets/linkwarden.env.age" \
    || die "Could not restore verified homelab secret artifacts after checkout"
  verify_homelab_linkwarden_secret
  rm -rf -- "$HOMELAB_SECRETS_BACKUP_DIR"
  HOMELAB_SECRETS_BACKUP_DIR=""
}

mark_homelab_secrets_validated() {
  local identity
  local state
  local line
  local updated_identity=""
  local inserted=0
  local local_stage
  local root_stage

  (( INITIALIZE_HOMELAB_SECRETS )) \
    || die "Homelab secret validation may only be marked after fresh Linkwarden initialization"
  HOMELAB_SECRETS_INITIALIZED=1
  if [[ ! -e "$HOMELAB_BOOTSTRAP_DIR" && ! -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
    [[ "$HOMELAB_IDENTITY_NIX" == *"secretsValidated = false;"* ]] \
      || die "Fresh homelab identity is missing its secret provisioning state"
    HOMELAB_IDENTITY_NIX="${HOMELAB_IDENTITY_NIX/secretsValidated = false;/secretsValidated = true;}"
    return 0
  fi

  require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
  require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
  identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
  validate_existing_homelab_identity "$identity"
  state="$(homelab_secret_validation_state "$identity")"
  [[ "$state" != "true" ]] || return 0
  if (( DRY_RUN )); then
    printf '[dry-run] mark machine-local homelab secret provisioning as validated after successful Linkwarden encryption\n'
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([[:space:]]*secretsValidated[[:space:]]*=[[:space:]]*)false(\;[[:space:]]*)$ ]]; then
      line="${BASH_REMATCH[1]}true${BASH_REMATCH[2]}"
    elif [[ "$state" == "missing" && "$line" =~ ^([[:space:]]*ageIdentityPath[[:space:]]*=[[:space:]]*.*\;[[:space:]]*)$ ]]; then
      updated_identity+="$line"$'\n'
      line='    secretsValidated = true;'
      inserted=1
    fi
    updated_identity+="$line"$'\n'
  done <<< "$identity"
  [[ "$state" != "missing" || "$inserted" -eq 1 ]] \
    || die "Could not add the required homelab secret provisioning state"

  local_stage="$(mktemp)" || die "Could not create local identity staging file"
  printf '%s' "$updated_identity" > "$local_stage" || { rm -f "$local_stage"; die "Could not stage homelab secret provisioning state"; }
  chmod 0600 "$local_stage"
  root_stage="$(sudo mktemp "$HOMELAB_BOOTSTRAP_DIR/.identity.nix.XXXXXX")" || { rm -f "$local_stage"; die "Could not create root-owned identity staging file"; }
  if ! run_as_root install -o root -g root -m 0644 "$local_stage" "$root_stage"; then
    run_as_root rm -f "$root_stage"
    rm -f "$local_stage"
    die "Could not stage homelab secret provisioning state"
  fi
  rm -f "$local_stage"
  if ! run_as_root mv -f "$root_stage" "$HOMELAB_BOOTSTRAP_DIR/identity.nix"; then
    run_as_root rm -f "$root_stage"
    die "Could not atomically mark homelab secret provisioning"
  fi
}


migrate_homelab_wrapper_flake() {
  local local_stage
  local root_stage

  local_stage="$(mktemp)" || die "Could not create local wrapper flake staging file"
  if ! printf '%s\n' "$HOMELAB_FLAKE_NIX" > "$local_stage"; then
    rm -f "$local_stage"
    die "Could not stage migrated homelab wrapper flake"
  fi
  chmod 0600 "$local_stage"
  root_stage="$(sudo mktemp "$HOMELAB_BOOTSTRAP_DIR/.flake.nix.XXXXXX")" || {
    rm -f "$local_stage"
    die "Could not create root-owned wrapper flake staging file"
  }
  if ! run_as_root install -o root -g root -m 0644 "$local_stage" "$root_stage"; then
    run_as_root rm -f "$root_stage"
    rm -f "$local_stage"
    die "Could not stage migrated homelab wrapper flake"
  fi
  rm -f "$local_stage"
  if ! run_as_root mv -f "$root_stage" "$HOMELAB_BOOTSTRAP_DIR/flake.nix"; then
    run_as_root rm -f "$root_stage"
    die "Could not atomically migrate the homelab wrapper flake"
  fi
  printf '[i] Migrated machine-local homelab wrapper flake to the current template\n'
}

sync_homelab_hardware() {
  local temporary_hardware
  local target="$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"

  validate_homelab_hardware_source
  if (( DRY_RUN )); then
    printf '[dry-run] atomically install %s as root-owned %s\n' "$HARDWARE_SRC" "$target"
    return 0
  fi

  temporary_hardware="$(sudo mktemp "$HOMELAB_BOOTSTRAP_DIR/.hardware-configuration.nix.XXXXXX")" || die "Could not create temporary homelab hardware configuration"
  if ! run_as_root install -o root -g root -m 0644 "$HARDWARE_SRC" "$temporary_hardware"; then
    run_as_root rm -f "$temporary_hardware"
    die "Could not stage homelab hardware configuration"
  fi
  if ! run_as_root mv -f "$temporary_hardware" "$target"; then
    run_as_root rm -f "$temporary_hardware"
    die "Could not atomically update homelab hardware configuration"
  fi
}

bootstrap_homelab_flake() {
  local local_stage
  local root_stage
  local actual_identity
  local actual_flake
  local legacy_beszel_key_count

  [[ "$SYSTEM" == "homelab" ]] || return 0
  validate_homelab_hardware_source

  if [[ -e "$HOMELAB_BOOTSTRAP_DIR" || -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
    require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
    actual_identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
    validate_existing_homelab_identity "$actual_identity"
    legacy_beszel_key_count="$(legacy_homelab_beszel_agent_key_count "$actual_identity")"
    (( legacy_beszel_key_count <= 1 )) || die "Machine-local homelab identity contains multiple legacy Beszel agent keys"
    if [[ "$HOMELAB_SECRETS_INITIALIZED" -eq 0 ]]; then
      require_homelab_secrets_validated "$actual_identity"
    fi
    if (( DRY_RUN )); then
      printf '[dry-run] verify existing root-owned homelab bootstrap at %s without replacing its identity\n' "$HOMELAB_BOOTSTRAP_DIR"
      if (( legacy_beszel_key_count == 1 )); then
        printf '[dry-run] atomically remove the legacy Beszel agent key from /etc/nixos/homelab-bootstrap/identity.nix\n'
      fi
      (( SYNC_HARDWARE )) && sync_homelab_hardware
      return 0
    fi
    remove_legacy_homelab_beszel_agent_key "$actual_identity"
    actual_identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
    validate_existing_homelab_identity "$actual_identity"
    if [[ "$HOMELAB_SECRETS_INITIALIZED" -eq 0 ]]; then
      require_homelab_secrets_validated "$actual_identity"
    fi

    require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/flake.nix"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"
    actual_identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
    actual_flake="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/flake.nix"; printf '\037')"
    validate_existing_homelab_identity "$actual_identity"
    require_homelab_secrets_validated "$actual_identity"
    if sudo grep -q 'REPLACE' "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"; then
      die "Machine-local homelab hardware configuration still contains a REPLACE placeholder"
    fi
    if [[ "$actual_flake" == "$HOMELAB_PREVIOUS_FLAKE_NIX"$'\n\037' ]]; then
      migrate_homelab_wrapper_flake
    elif [[ "$actual_flake" != "$HOMELAB_FLAKE_NIX"$'\n\037' ]]; then
      die "Machine-local homelab wrapper does not match this checkout; refusing to replace it"
    fi
    (( SYNC_HARDWARE )) && sync_homelab_hardware
    cleanup_homelab_wrapper_lock
    return 0
  fi

  [[ "$HOMELAB_IDENTITY_NIX" == *"secretsValidated = true;"* ]] \
    || die "Fresh homelab secret provisioning is required before staging a generation; rerun with --initialize-homelab-secrets"

  if (( DRY_RUN )); then
    printf '[dry-run] atomically create root-owned wrapper flake at %s with identity.nix and hardware-configuration.nix\n' "$HOMELAB_BOOTSTRAP_DIR"
    return 0
  fi

  local_stage="$(mktemp -d)" || die "Could not create local bootstrap staging directory"
  printf '%s\n' "$HOMELAB_IDENTITY_NIX" > "$local_stage/identity.nix"
  printf '%s\n' "$HOMELAB_FLAKE_NIX" > "$local_stage/flake.nix"
  chmod 0600 "$local_stage/identity.nix" "$local_stage/flake.nix"

  run_as_root install -d -o root -g root -m 0755 /etc/nixos
  root_stage="$(sudo mktemp -d /etc/nixos/.homelab-bootstrap.XXXXXX)" || {
    rm -rf "$local_stage"
    die "Could not create root-owned bootstrap staging directory"
  }
  if ! run_as_root install -o root -g root -m 0644 "$local_stage/identity.nix" "$root_stage/identity.nix" \
    || ! run_as_root install -o root -g root -m 0644 "$local_stage/flake.nix" "$root_stage/flake.nix" \
    || ! run_as_root install -o root -g root -m 0644 "$HARDWARE_SRC" "$root_stage/hardware-configuration.nix"; then
    run_as_root rm -rf "$root_stage"
    rm -rf "$local_stage"
    die "Could not stage root-owned homelab bootstrap files"
  fi
  rm -rf "$local_stage"

  if ! run_as_root mv -T -n "$root_stage" "$HOMELAB_BOOTSTRAP_DIR"; then
    run_as_root rm -rf "$root_stage"
    die "Could not install the homelab bootstrap wrapper"
  fi
  if sudo test -e "$root_stage"; then
    run_as_root rm -rf "$root_stage"
    die "Homelab bootstrap path appeared during setup; refusing to replace it"
  fi
  run_as_root chmod 0755 "$HOMELAB_BOOTSTRAP_DIR"
}

is_git_dir() {
  local path="$1"
  [[ -f "$path/config" && -d "$path/objects" ]]
}

config_git() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

require_value() {
  local option="$1"
  local value="${2-}"
  [[ -n "$value" ]] || die "$option requires a non-empty value"
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --system)
      require_value "$1" "${2-}"
      SYSTEM="$2"
      shift 2
      ;;
    --repo-url)
      require_value "$1" "${2-}"
      REPO_URL="$2"
      shift 2
      ;;
    --git-dir)
      require_value "$1" "${2-}"
      GIT_DIR="$2"
      shift 2
      ;;
    --work-tree)
      require_value "$1" "${2-}"
      WORK_TREE="$2"
      shift 2
      ;;
    --sync-hardware)
      SYNC_HARDWARE=1
      shift
      ;;
    --hardware-src)
      require_value "$1" "${2-}"
      HARDWARE_SRC="$2"
      shift 2
      ;;
    --hardware-dest)
      require_value "$1" "${2-}"
      HARDWARE_DEST="$2"
      shift 2
      ;;
    --print-host-key)
      PRINT_HOST_KEY=1
      shift
      ;;
    --enroll-host-key)
      ENROLL_HOST_KEY=1
      PRINT_HOST_KEY=1
      shift
      ;;
    --initialize-homelab-secrets)
      INITIALIZE_HOMELAB_SECRETS=1
      PRINT_HOST_KEY=1
      shift
      ;;
    --linkwarden-env-file)
      require_value "$1" "${2-}"
      LINKWARDEN_ENV_FILE="$2"
      shift 2
      ;;
    --checks)
      RUN_CHECKS=1
      shift
      ;;
    --skip-rebuild)
      SKIP_REBUILD=1
      shift
      ;;
    --skip-neovim-check)
      SKIP_NEOVIM_CHECK=1
      shift
      ;;
    --force-neovim-check)
      FORCE_NEOVIM_CHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

NIXOS_FLAKE="$WORK_TREE/nixos"
if [[ "$SYSTEM" == "homelab" ]]; then
  [[ -z "$HARDWARE_DEST" ]] || die "--hardware-dest is not supported for homelab; its hardware configuration is machine-local at $HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"
  HARDWARE_DEST="$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"
else
  if [[ -z "$HARDWARE_DEST" ]]; then
    HARDWARE_DEST="$NIXOS_FLAKE/system-specific/machines/$SYSTEM/hardware-configuration.nix"
  fi
fi
SECRETS_FILE="$NIXOS_FLAKE/secrets/secrets.nix"

if (( ENROLL_HOST_KEY && INITIALIZE_HOMELAB_SECRETS )); then
  die "--enroll-host-key and --initialize-homelab-secrets are mutually exclusive"
fi

if (( ! INITIALIZE_HOMELAB_SECRETS )) && [[ -n "$LINKWARDEN_ENV_FILE" ]]; then
  die "--linkwarden-env-file requires --initialize-homelab-secrets"
fi

if [[ "$SYSTEM" == "homelab" && "$RUN_CHECKS" -eq 1 ]]; then
  die "--checks is not supported for staged homelab builds; boot the staged generation and check its services there"
fi

detect_homelab_operator

if [[ "$SYSTEM" == "homelab" ]]; then
  validate_homelab_hardware_source
  if [[ ! -e "$HOMELAB_BOOTSTRAP_DIR" && ! -L "$HOMELAB_BOOTSTRAP_DIR" && "$INITIALIZE_HOMELAB_SECRETS" -eq 0 ]]; then
    die "Fresh homelab secret provisioning is required before checkout; rerun with --initialize-homelab-secrets"
  fi
  ensure_homelab_unlock_password
  backup_validated_homelab_secrets
fi

printf '[i] System: %s\n' "$SYSTEM"
printf '[i] Repository URL: %s\n' "$REPO_URL"
printf '[i] Git dir: %s\n' "$GIT_DIR"
printf '[i] Work tree: %s\n' "$WORK_TREE"

if ! command -v git >/dev/null 2>&1; then
  if command -v nix >/dev/null 2>&1; then
    nix_cmd profile install nixpkgs#git
  else
    die "Install git first or run from a NixOS environment with nix available."
  fi
fi
validate_git_origin

if ! is_git_dir "$GIT_DIR"; then
  if (( DRY_RUN )); then
    run git clone --bare "$REPO_URL" "$GIT_DIR"
  else
    if [[ -e "$GIT_DIR" ]]; then
      if [[ -d "$GIT_DIR" ]] && [[ -z "$(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        :
      else
        die "Git dir exists but is not recognized as bare Git metadata: $GIT_DIR"
      fi
    fi
    run git clone --bare "$REPO_URL" "$GIT_DIR"
  fi
fi
validate_git_origin

run git --git-dir="$GIT_DIR" config status.showUntrackedFiles no
run mkdir -p "$WORK_TREE"
run git --git-dir="$GIT_DIR" fetch --all --prune
run git --git-dir="$GIT_DIR" fetch origin refs/heads/main:refs/remotes/origin/main

if (( DRY_RUN )); then
  run git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" checkout origin/main -- .
elif ! config_git checkout origin/main -- .; then
  printf '[!] Move or back up the conflicting file, then rerun the script.\n' >&2
  exit 1
fi

restore_validated_homelab_secrets

if [[ "$SYSTEM" == "homelab" && "$INITIALIZE_HOMELAB_SECRETS" -eq 1 ]]; then
  ensure_host_key
  printf '[i] Host SSH key for agenix recipient enrollment:\n'
  run_as_root cat /etc/ssh/ssh_host_ed25519_key.pub
  if (( DRY_RUN )); then
    initialize_homelab_secrets "ssh-ed25519 <host-key> homelab"
  else
    initialize_homelab_secrets "$(read_host_key)"
  fi
  if (( ! DRY_RUN )); then
    verify_homelab_linkwarden_secret
  fi
  mark_homelab_secrets_validated
fi

if [[ "$SYSTEM" == "homelab" ]]; then
  bootstrap_homelab_flake
elif (( SYNC_HARDWARE )); then
  [[ -r "$HARDWARE_SRC" ]] || die "Hardware source is not readable: $HARDWARE_SRC"
  [[ -d "$(dirname -- "$HARDWARE_DEST")" ]] || die "Destination directory missing: $(dirname -- "$HARDWARE_DEST")"
  run_as_root install -m 0644 "$HARDWARE_SRC" "$HARDWARE_DEST"
fi

if (( (PRINT_HOST_KEY || ENROLL_HOST_KEY) && ! INITIALIZE_HOMELAB_SECRETS )); then
  ensure_host_key
  printf '[i] Host SSH key for agenix recipient enrollment:\n'
  run_as_root cat /etc/ssh/ssh_host_ed25519_key.pub

  if (( ENROLL_HOST_KEY )); then
    if (( DRY_RUN )); then
      enroll_host_key "ssh-ed25519 <host-key> homelab"
    else
      enroll_host_key "$(read_host_key)"
    fi
  elif [[ -f "$SECRETS_FILE" ]]; then
    printf '[i] Next steps:\n'
    printf '    1) Replace the homelab recipient in %s with the host key above\n' "$SECRETS_FILE"
    printf '    2) cd %s/secrets && agenix -r\n' "$NIXOS_FLAKE"
  fi
fi

need_cmd nix "nix is required; run this from NixOS or install Nix before using this bootstrap script."

VALIDATION_FLAKE="$NIXOS_FLAKE"
if [[ "$SYSTEM" == "homelab" ]]; then
  VALIDATION_FLAKE="$HOMELAB_BOOTSTRAP_FLAKE"
fi

if [[ -f "$VALIDATION_FLAKE/flake.nix" ]]; then
  nix_cmd flake show --no-write-lock-file "$VALIDATION_FLAKE"
  nix_cmd eval --no-write-lock-file --raw "$VALIDATION_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
  require_homelab_mutable_users
elif (( DRY_RUN )); then
  nix_cmd flake show --no-write-lock-file "$VALIDATION_FLAKE"
  nix_cmd eval --no-write-lock-file --raw "$VALIDATION_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
  printf '[i] Skipping flake validation because dry-run did not create %s\n' "$VALIDATION_FLAKE"
else
  die "Missing NixOS flake at $VALIDATION_FLAKE/flake.nix after checkout"
fi

if (( SKIP_REBUILD )); then
  printf '[i] Skipping nixos-rebuild\n'
else
  nixos_rebuild
fi

if (( INITIALIZE_HOMELAB_SECRETS )); then
  printf '[i] Tailscale enrollment is deferred until the staged homelab generation boots; after boot, run: sudo tailscale up --advertise-tags=tag:server\n'
fi

if (( RUN_CHECKS )); then
  services=(
    sshd
    tailscaled
    tailscale-services
    xrdp
    xrdp-sesman
    glance
    linkwarden
  )

  for svc in "${services[@]}"; do
    run systemctl status --no-pager "$svc"
  done
fi

if [[ "$SYSTEM" == "homelab" && "$FORCE_NEOVIM_CHECK" -eq 0 && "$SKIP_NEOVIM_CHECK" -eq 0 ]]; then
  printf '[i] Skipping nvim startup check for homelab; pass --force-neovim-check to run it.\n'
  SKIP_NEOVIM_CHECK=1
fi

if (( ! SKIP_NEOVIM_CHECK )); then
  if (( DRY_RUN )); then
    run nvim --headless '+q'
  else
    command -v nvim >/dev/null 2>&1 || die "nvim not found after rebuild; confirm nixos/terminal/neovim.nix is imported by the selected home.nix"
    run nvim --headless '+q'
  fi
fi

if [[ "$SYSTEM" == "homelab" ]]; then
  printf '[i] Homelab configuration build is staged only and was not activated; review it before manually activating it.\n'
fi
printf '[+] Done\n'
