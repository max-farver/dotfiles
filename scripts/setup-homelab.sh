#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/max-farver/dotfiles"
DEFAULT_GIT_DIR='${HOME}/.cfg'
DEFAULT_WORK_TREE='${HOME}/.config'
DEFAULT_HARDWARE_SRC="/etc/nixos/hardware-configuration.nix"
NIX_EXPERIMENTAL_FEATURES="nix-command flakes"
HOMELAB_BOOTSTRAP_DIR="/etc/nixos/homelab-bootstrap"
HOMELAB_BOOTSTRAP_FLAKE="$HOMELAB_BOOTSTRAP_DIR"
HOST_PRIVATE_KEY="/etc/ssh/ssh_host_ed25519_key"
HOST_PUBLIC_KEY="${HOST_PRIVATE_KEY}.pub"

REPO_URL="${DOTFILES_REPO_URL:-$DEFAULT_REPO_URL}"
GIT_DIR="${DOTFILES_GIT_DIR:-$HOME/.cfg}"
WORK_TREE="${DOTFILES_WORK_TREE:-$HOME/.config}"
HARDWARE_SRC="$DEFAULT_HARDWARE_SRC"
DRY_RUN=0
SKIP_REBUILD=0
SYNC_HARDWARE=0
INITIALIZE_HOMELAB_SECRETS=0
LINKWARDEN_ENV_FILE=""
HOMELAB_OPERATOR_NAME=""
HOMELAB_OPERATOR_UID=""
HOMELAB_OPERATOR_GROUP=""
HOMELAB_OPERATOR_GID=""
HOMELAB_OPERATOR_HOME=""
HOMELAB_OPERATOR_SHELL=""
HOMELAB_IDENTITY_NIX=""
HOMELAB_FLAKE_NIX=""
GENERATED_CIPHERTEXT=""
GENERATED_CIPHERTEXT_DIR=""
MIGRATED_OLD_CIPHERTEXT=0
cleanup_generated_ciphertext() {
  if [[ -n "$GENERATED_CIPHERTEXT_DIR" ]]; then
    rm -rf -- "$GENERATED_CIPHERTEXT_DIR"
  fi
}
trap cleanup_generated_ciphertext EXIT

usage() {
  cat <<EOF
Usage: scripts/setup-homelab.sh [--dry-run] [--repo-url URL] [--git-dir PATH] [--work-tree PATH] [--sync-hardware] [--hardware-src PATH] [--initialize-homelab-secrets] [--linkwarden-env-file PATH] [--skip-rebuild] [-h|--help]

Stage the machine-local homelab bootstrap without activating it.

Options:
  --dry-run              Print commands without mutating files or rebuilding.
  --repo-url URL         Bare repository clone URL. Default: $DEFAULT_REPO_URL.
  --git-dir PATH         Git metadata directory. Default: $DEFAULT_GIT_DIR.
  --work-tree PATH       Dotfiles work tree. Default: $DEFAULT_WORK_TREE.
  --sync-hardware        Copy generated hardware config into the machine-local wrapper.
  --hardware-src PATH    Hardware config source. Default: $DEFAULT_HARDWARE_SRC.
  --initialize-homelab-secrets
                         Generate or replace the machine-local Linkwarden ciphertext.
  --linkwarden-env-file PATH
                         Env file to encrypt for Linkwarden instead of generating NEXTAUTH_SECRET.
  --skip-rebuild         Skip the staged nixos-rebuild build.
  -h, --help             Show this help.

Environment overrides:
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
  elif (( EUID == 0 )); then
    run "$@"
  else
    run sudo "$@"
  fi
}

nix_cmd() {
  run nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" "$@"
}

need_cmd() {
  local cmd="$1"
  local hint="$2"
  command -v "$cmd" >/dev/null 2>&1 || die "$hint"
}

require_value() {
  local option="$1"
  local value="${2-}"
  [[ -n "$value" ]] || die "$option requires a non-empty value"
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

is_git_dir() {
  local path="$1"
  [[ -f "$path/config" && -d "$path/objects" ]]
}

config_git() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

validate_git_origin() {
  local origin_urls=()
  is_git_dir "$GIT_DIR" || return 0
  mapfile -t origin_urls < <(git --git-dir="$GIT_DIR" remote get-url --all origin) \
    || die "Existing Git metadata has no readable origin remote: $GIT_DIR"
  [[ ${#origin_urls[@]} -eq 1 && "${origin_urls[0]}" == "$REPO_URL" ]] \
    || die "Existing Git origin must exactly match --repo-url; expected $REPO_URL"
}

require_root_owned_file() {
  local path="$1"
  local owner_uid mode
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
  local owner_uid mode
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

# Atomically replace TARGET with a root-owned copy of SOURCE.  The source is
# deliberately checked before the root temporary is made so symlinks cannot be
# followed into the trusted wrapper.
stage_root_owned_file() {
  local source="$1"
  local target="$2"
  local mode="$3"
  local target_dir temp

  [[ -f "$source" && ! -L "$source" ]] || die "Source must be a regular non-symlink file: $source"
  [[ "$mode" =~ ^0?[0-7]{3,4}$ ]] || die "Invalid mode for root-owned staging: $mode"
  target_dir="$(dirname -- "$target")"

  if (( DRY_RUN )); then
    printf '[dry-run] atomically install %s as root-owned mode %s at %s\n' "$source" "$mode" "$target"
    return 0
  fi

  sudo test -d "$target_dir" && ! sudo test -L "$target_dir" \
    || die "Target directory must be a non-symlink directory: $target_dir"
  temp="$(sudo mktemp "$target_dir/.${target##*/}.XXXXXX")" \
    || die "Could not create root-owned temporary file beside $target"
  if ! run_as_root install -o root -g root -m "$mode" -- "$source" "$temp"; then
    run_as_root rm -f -- "$temp"
    die "Could not stage root-owned file: $target"
  fi
  if ! run_as_root mv -f -- "$temp" "$target"; then
    run_as_root rm -f -- "$temp"
    die "Could not atomically install root-owned file: $target"
  fi
}

ensure_host_key() {
  if (( DRY_RUN )); then
    run sudo mkdir -p /etc/ssh
    run sudo ssh-keygen -A
    run sudo sh -c 'if test ! -e /etc/ssh/ssh_host_ed25519_key; then ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key; fi; test -f /etc/ssh/ssh_host_ed25519_key && ! test -L /etc/ssh/ssh_host_ed25519_key && test -r /etc/ssh/ssh_host_ed25519_key && ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key >/dev/null && ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
    run sudo test -r "$HOST_PUBLIC_KEY"
    return 0
  fi

  run_as_root mkdir -p /etc/ssh
  if ! sudo test -e "$HOST_PRIVATE_KEY"; then
    run_as_root ssh-keygen -A
  fi
  if ! sudo test -e "$HOST_PRIVATE_KEY"; then
    run_as_root ssh-keygen -t ed25519 -N "" -f "$HOST_PRIVATE_KEY"
  fi
  sudo test -f "$HOST_PRIVATE_KEY" && ! sudo test -L "$HOST_PRIVATE_KEY" && sudo test -r "$HOST_PRIVATE_KEY" \
    || die "SSH host ed25519 private key is unavailable: $HOST_PRIVATE_KEY"
  sudo ssh-keygen -y -f "$HOST_PRIVATE_KEY" >/dev/null \
    || die "SSH host ed25519 age identity is not a readable private key: $HOST_PRIVATE_KEY"
  run_as_root sh -c 'ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
  sudo test -f "$HOST_PUBLIC_KEY" && ! sudo test -L "$HOST_PUBLIC_KEY" && sudo test -r "$HOST_PUBLIC_KEY" \
    || die "SSH host ed25519 public key is unavailable after deriving it from $HOST_PRIVATE_KEY"
}

read_host_key() {
  if (( EUID == 0 )); then
    cat "$HOST_PUBLIC_KEY"
  else
    sudo cat "$HOST_PUBLIC_KEY"
  fi
}

is_ssh_public_key_line() {
  local key="$1"
  [[ -n "$key" && "$key" != *$'\n'* && "$key" != *$'\r'* ]] \
    && command -v ssh-keygen >/dev/null 2>&1 \
    && ssh-keygen -lf <(printf '%s\n' "$key") >/dev/null 2>&1
}

detect_homelab_operator() {
  local passwd_entry group_entry nss_uid home_owner_uid

  (( EUID != 0 )) || die "Homelab bootstrap must be invoked directly by the intended non-root operator, not through sudo or as root"
  need_cmd getent "getent is required to resolve the invoking homelab operator through NSS"
  HOMELAB_OPERATOR_UID="$(id -u)"
  [[ "$HOMELAB_OPERATOR_UID" =~ ^[1-9][0-9]*$ ]] || die "Homelab bootstrap requires a non-root numeric UID"
  passwd_entry="$(getent passwd "$HOMELAB_OPERATOR_UID")" || die "No NSS passwd entry exists for UID $HOMELAB_OPERATOR_UID"
  IFS=: read -r HOMELAB_OPERATOR_NAME _ nss_uid HOMELAB_OPERATOR_GID _ HOMELAB_OPERATOR_HOME HOMELAB_OPERATOR_SHELL <<< "$passwd_entry"
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
  case "$HOMELAB_OPERATOR_SHELL" in
    /sbin/nologin|/usr/sbin/nologin|/bin/false|/usr/bin/false)
      die "Homelab operator has a non-login shell: $HOMELAB_OPERATOR_SHELL"
      ;;
  esac
  [[ "$HOMELAB_OPERATOR_SHELL" == /* && -f "$HOMELAB_OPERATOR_SHELL" && -x "$HOMELAB_OPERATOR_SHELL" ]] \
    || die "Homelab operator login shell is not an executable regular file: ${HOMELAB_OPERATOR_SHELL:-unset}"

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
    linkwardenSecretFile = ./linkwarden.env.age;
    secretsValidated = false;
  };
}
EOF
)"
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

  printf '[i] Homelab operator: %s (uid=%s, primary-group=%s, gid=%s, home=%s, shell=%s)\n' \
    "$HOMELAB_OPERATOR_NAME" "$HOMELAB_OPERATOR_UID" "$HOMELAB_OPERATOR_GROUP" "$HOMELAB_OPERATOR_GID" "$HOMELAB_OPERATOR_HOME" "$HOMELAB_OPERATOR_SHELL"
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
  local hardware_content root_mount
  local root_assignment_regex='fileSystems[[:space:]]*\.[[:space:]]*"/"[[:space:]]*=[[:space:]]*\{([^}]*)\}'
  local device_regex='(^|[[:space:];])device[[:space:]]*=[[:space:]]*"[^"]+"[[:space:]]*;'
  local fs_type_regex='(^|[[:space:];])fsType[[:space:]]*=[[:space:]]*"[^"]+"[[:space:]]*;'
  local placeholder_device_regex='(^|[[:space:];])device[[:space:]]*=[[:space:]]*"/dev/root"[[:space:]]*;'

  sudo test -f "$HARDWARE_SRC" && ! sudo test -L "$HARDWARE_SRC" && sudo test -s "$HARDWARE_SRC" \
    || die "Homelab hardware source must be a nonempty regular file: $HARDWARE_SRC"
  need_cmd nix-instantiate "nix-instantiate is required to parse the homelab hardware source"
  sudo nix-instantiate --parse "$HARDWARE_SRC" >/dev/null \
    || die "Homelab hardware source is not valid Nix syntax: $HARDWARE_SRC"
  hardware_content="$(sudo cat "$HARDWARE_SRC")" || die "Could not read homelab hardware source: $HARDWARE_SRC"
  [[ "$hardware_content" != *REPLACE* ]] || die "Homelab hardware configuration still contains a REPLACE placeholder: $HARDWARE_SRC"
  [[ "$hardware_content" =~ $root_assignment_regex ]] \
    || die "Homelab hardware source must declare fileSystems.\"/\" as a concrete root filesystem mount: $HARDWARE_SRC"
  root_mount="${BASH_REMATCH[1]}"
  [[ "$root_mount" =~ $device_regex && "$root_mount" =~ $fs_type_regex ]] \
    || die "Homelab hardware source root filesystem mount must have nonempty device and fsType values: $HARDWARE_SRC"
  [[ ! "$root_mount" =~ $placeholder_device_regex ]] \
    || die "Homelab hardware source root filesystem mount must not use the /dev/root placeholder: $HARDWARE_SRC"
}

validate_existing_homelab_identity() {
  local identity="$1"
  local expected_name expected_group expected_home expected_flake
  expected_name="$(nix_escape "$HOMELAB_OPERATOR_NAME")"
  expected_group="$(nix_escape "$HOMELAB_OPERATOR_GROUP")"
  expected_home="$(nix_escape "$HOMELAB_OPERATOR_HOME")"
  expected_flake="$(nix_escape "$HOMELAB_BOOTSTRAP_DIR#homelab")"
  [[ "$identity" == *"validated = true;"* ]] \
    && [[ "$identity" == *"name = \"$expected_name\";"* ]] \
    && [[ "$identity" == *"uid = $HOMELAB_OPERATOR_UID;"* ]] \
    && [[ "$identity" == *"primaryGroup = \"$expected_group\";"* ]] \
    && [[ "$identity" == *"primaryGid = $HOMELAB_OPERATOR_GID;"* ]] \
    && [[ "$identity" == *"home = \"$expected_home\";"* ]] \
    && [[ "$identity" == *"flakePath = \"$expected_flake\";"* ]] \
    && [[ "$identity" == *'ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";'* ]] \
    || die "Machine-local homelab identity does not match the detected account; refusing to replace it"
  [[ "$identity" != *beszelAgentKey* ]] \
    || die "Machine-local homelab identity contains an unsupported retired Beszel field"
}

identity_secret_state() {
  local identity="$1" line state="missing" count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*secretsValidated[[:space:]]*=[[:space:]]*(true|false)\;[[:space:]]*$ ]]; then
      state="${BASH_REMATCH[1]}"
      ((count += 1))
    fi
  done <<< "$identity"
  (( count <= 1 )) || die "Machine-local homelab identity must contain at most one secret provisioning state"
  printf '%s' "$state"
}

identity_has_local_secret_path() {
  local identity="$1" line count=0 valid=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*linkwardenSecretFile[[:space:]]*= ]]; then
      ((count += 1))
      [[ "$line" =~ ^[[:space:]]*linkwardenSecretFile[[:space:]]*=[[:space:]]*\./linkwarden\.env\.age\;[[:space:]]*$ ]] && valid=1
    fi
  done <<< "$identity"
  (( count <= 1 )) || die "Machine-local homelab identity must contain at most one Linkwarden ciphertext path"
  (( count == 1 && valid == 1 ))
}

render_identity_with_local_secret() {
  local identity="$1" line rendered="" local_count=0 secret_count=0 existing_local_count=0 existing_state
  existing_state="$(identity_secret_state "$identity")"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*linkwardenSecretFile[[:space:]]*= ]]; then
      ((existing_local_count += 1))
    fi
  done <<< "$identity"
  (( existing_local_count <= 1 )) || die "Machine-local homelab identity has duplicate Linkwarden ciphertext paths"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*linkwardenSecretFile[[:space:]]*= ]]; then
      ((local_count += 1))
      rendered+='    linkwardenSecretFile = ./linkwarden.env.age;'$'\n'
      [[ "$existing_state" != "missing" ]] || rendered+='    secretsValidated = true;'$'\n'
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*secretsValidated[[:space:]]*=[[:space:]]*(true|false)\;[[:space:]]*$ ]]; then
      ((secret_count += 1))
      rendered+='    secretsValidated = true;'$'\n'
      continue
    fi
    rendered+="$line"$'\n'
    if [[ "$line" =~ ^[[:space:]]*ageIdentityPath[[:space:]]*=[[:space:]]*.*\;[[:space:]]*$ ]] && (( existing_local_count == 0 )); then
      rendered+='    linkwardenSecretFile = ./linkwarden.env.age;'$'\n'
      [[ "$existing_state" != "missing" ]] || rendered+='    secretsValidated = true;'$'\n'
      local_count=1
    fi
  done <<< "$identity"
  (( local_count == 1 && secret_count <= 1 )) || die "Machine-local homelab identity has duplicate or missing secret fields"
  printf '%s' "$rendered"
}

update_existing_identity_for_local_secret() {
  local identity updated stage
  require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
  require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
  identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")" || die "Could not read machine-local homelab identity"
  validate_existing_homelab_identity "$identity"
  updated="$(render_identity_with_local_secret "$identity")"
  if (( DRY_RUN )); then
    printf '[dry-run] atomically add the local Linkwarden ciphertext path and validated secret attestation to %s/identity.nix\n' "$HOMELAB_BOOTSTRAP_DIR"
    return 0
  fi
  stage="$(mktemp)" || die "Could not create local identity staging file"
  if ! printf '%s' "$updated" > "$stage"; then
    rm -f -- "$stage"
    die "Could not stage machine-local homelab identity"
  fi
  chmod 0600 "$stage"
  stage_root_owned_file "$stage" "$HOMELAB_BOOTSTRAP_DIR/identity.nix" 0644
  rm -f -- "$stage"
}

age_encrypt() {
  local recipient="$1" plaintext="$2" ciphertext="$3"
  if command -v age >/dev/null 2>&1; then
    age -r "$recipient" -o "$ciphertext" < "$plaintext"
  else
    need_cmd nix "age is not installed and nix is required to encrypt the Linkwarden ciphertext"
    nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run nixpkgs#age -- -r "$recipient" -o "$ciphertext" < "$plaintext"
  fi
}

age_verify() {
  local ciphertext="$1"
  if command -v age >/dev/null 2>&1; then
    sudo age --decrypt --identity "$HOST_PRIVATE_KEY" --output /dev/null "$ciphertext"
  else
    need_cmd nix "age is not installed and nix is required to verify the Linkwarden ciphertext"
    sudo nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run nixpkgs#age -- --decrypt --identity "$HOST_PRIVATE_KEY" --output /dev/null "$ciphertext"
  fi
}

create_verified_local_ciphertext() {
  local plaintext recipient
  ensure_host_key
  if (( DRY_RUN )); then
    printf '[dry-run] encrypt and verify fresh machine-local Linkwarden ciphertext for %s\n' "$HOST_PRIVATE_KEY"
    return 0
  fi
  if [[ -n "$LINKWARDEN_ENV_FILE" ]]; then
    [[ -f "$LINKWARDEN_ENV_FILE" && ! -L "$LINKWARDEN_ENV_FILE" && -r "$LINKWARDEN_ENV_FILE" ]] \
      || die "Linkwarden env file is not a readable regular file: $LINKWARDEN_ENV_FILE"
    plaintext="$LINKWARDEN_ENV_FILE"
  else
    plaintext="$(mktemp)" || die "Could not create Linkwarden plaintext staging file"
    chmod 0600 "$plaintext"
    if ! printf 'NEXTAUTH_SECRET=%s\n' "$(random_secret)" > "$plaintext"; then
      rm -f -- "$plaintext"
      die "Could not generate Linkwarden secret"
    fi
  fi
  GENERATED_CIPHERTEXT_DIR="$(mktemp -d)" || { [[ "$plaintext" == "$LINKWARDEN_ENV_FILE" ]] || rm -f -- "$plaintext"; die "Could not create Linkwarden ciphertext staging directory"; }
  chmod 0700 "$GENERATED_CIPHERTEXT_DIR"
  GENERATED_CIPHERTEXT="$GENERATED_CIPHERTEXT_DIR/linkwarden.env.age"
  recipient="$(read_host_key)" || die "Could not read the homelab host public key"
  is_ssh_public_key_line "$recipient" || die "Homelab host public key is invalid"
  if ! age_encrypt "$recipient" "$plaintext" "$GENERATED_CIPHERTEXT" || ! age_verify "$GENERATED_CIPHERTEXT"; then
    rm -rf -- "$GENERATED_CIPHERTEXT_DIR"
    GENERATED_CIPHERTEXT=""
    GENERATED_CIPHERTEXT_DIR=""
    [[ "$plaintext" == "$LINKWARDEN_ENV_FILE" ]] || rm -f -- "$plaintext"
    die "Could not encrypt and verify the machine-local Linkwarden ciphertext"
  fi
  [[ "$plaintext" == "$LINKWARDEN_ENV_FILE" ]] || rm -f -- "$plaintext"
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

verify_local_ciphertext() {
  local ciphertext="$HOMELAB_BOOTSTRAP_DIR/linkwarden.env.age"
  require_root_owned_file "$ciphertext"
  if (( DRY_RUN )); then
    printf '[dry-run] decrypt and verify %s with %s\n' "$ciphertext" "$HOST_PRIVATE_KEY"
    return 0
  fi
  age_verify "$ciphertext" || die "Machine-local Linkwarden ciphertext is not decryptable by this homelab host key; rerun with --initialize-homelab-secrets"
}

verify_old_work_tree_ciphertext() {
  local old_secret="$NIXOS_FLAKE/secrets/linkwarden.env.age"
  local secrets_file="$NIXOS_FLAKE/secrets/secrets.nix"
  local host_key escaped_host_key secrets_content
  [[ -f "$secrets_file" && ! -L "$secrets_file" && -s "$secrets_file" ]] \
    || die "Missing or unsafe homelab secret recipient configuration: $secrets_file"
  [[ -f "$old_secret" && ! -L "$old_secret" && -s "$old_secret" ]] \
    || die "Missing or unsafe Linkwarden ciphertext: $old_secret"
  host_key="$(read_host_key)" || die "Could not read the homelab host public key"
  is_ssh_public_key_line "$host_key" || die "Homelab host public key is invalid"
  escaped_host_key="$(nix_escape "$host_key")"
  secrets_content="$(cat "$secrets_file")" || die "Could not read $secrets_file"
  [[ "$secrets_content" == *"homelab = \"$escaped_host_key\";"* ]] \
    || die "Homelab recipient configuration does not match this host key; rerun with --initialize-homelab-secrets"
  if (( DRY_RUN )); then
    printf '[dry-run] decrypt and migrate verified work-tree Linkwarden ciphertext to %s\n' "$HOMELAB_BOOTSTRAP_DIR/linkwarden.env.age"
    return 0
  fi
  age_verify "$old_secret" || die "Linkwarden ciphertext is not decryptable by this homelab host key; rerun with --initialize-homelab-secrets"
  stage_root_owned_file "$old_secret" "$HOMELAB_BOOTSTRAP_DIR/linkwarden.env.age" 0644
  MIGRATED_OLD_CIPHERTEXT=1
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

sync_homelab_hardware() {
  stage_root_owned_file "$HARDWARE_SRC" "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix" 0644
}

validate_existing_wrapper() {
  local identity flake hardware
  require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
  require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
  require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/flake.nix"
  require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"
  identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")" || die "Could not read machine-local homelab identity"
  flake="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/flake.nix"; printf '\037')"
  hardware="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix")"
  validate_existing_homelab_identity "$identity"
  [[ "$flake" == "$HOMELAB_FLAKE_NIX"$'\n\037' ]] \
    || die "Machine-local homelab wrapper does not match this checkout; refusing to replace it"
  [[ "$hardware" != *REPLACE* ]] || die "Machine-local homelab hardware configuration still contains a REPLACE placeholder"
}

prepare_existing_secret_before_checkout() {
  local identity state
  [[ -e "$HOMELAB_BOOTSTRAP_DIR" || -L "$HOMELAB_BOOTSTRAP_DIR" ]] || return 0
  validate_existing_wrapper
  identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
  state="$(identity_secret_state "$identity")"
  ensure_host_key
  if (( INITIALIZE_HOMELAB_SECRETS )); then
    return 0
  fi
  if identity_has_local_secret_path "$identity"; then
    [[ "$state" == "true" ]] || die "Machine-local homelab secrets are unvalidated. Rerun with --initialize-homelab-secrets before staging a generation"
    verify_local_ciphertext
    return 0
  fi
  verify_old_work_tree_ciphertext
}

create_fresh_wrapper() {
  local local_stage root_stage
  [[ "$HOMELAB_IDENTITY_NIX" == *"secretsValidated = true;"* ]] \
    || die "Fresh homelab secret provisioning is required before staging a generation; rerun with --initialize-homelab-secrets"
  if (( DRY_RUN )); then
    printf '[dry-run] atomically create root-owned wrapper flake at %s with identity.nix, hardware-configuration.nix, and linkwarden.env.age\n' "$HOMELAB_BOOTSTRAP_DIR"
    return 0
  fi
  [[ -n "$GENERATED_CIPHERTEXT" ]] || die "Fresh homelab secret provisioning is required before staging a generation; rerun with --initialize-homelab-secrets"
  local_stage="$(mktemp -d)" || die "Could not create local bootstrap staging directory"
  printf '%s\n' "$HOMELAB_IDENTITY_NIX" > "$local_stage/identity.nix"
  printf '%s\n' "$HOMELAB_FLAKE_NIX" > "$local_stage/flake.nix"
  chmod 0600 "$local_stage/identity.nix" "$local_stage/flake.nix"
  run_as_root install -d -o root -g root -m 0755 /etc/nixos
  root_stage="$(sudo mktemp -d /etc/nixos/.homelab-bootstrap.XXXXXX)" || { rm -rf -- "$local_stage"; die "Could not create root-owned bootstrap staging directory"; }
  if ! run_as_root install -o root -g root -m 0644 "$local_stage/identity.nix" "$root_stage/identity.nix" \
    || ! run_as_root install -o root -g root -m 0644 "$local_stage/flake.nix" "$root_stage/flake.nix" \
    || ! run_as_root install -o root -g root -m 0644 "$HARDWARE_SRC" "$root_stage/hardware-configuration.nix" \
    || ! run_as_root install -o root -g root -m 0644 "$GENERATED_CIPHERTEXT" "$root_stage/linkwarden.env.age"; then
    run_as_root rm -rf -- "$root_stage"
    rm -rf -- "$local_stage"
    die "Could not stage root-owned homelab bootstrap files"
  fi
  rm -rf -- "$local_stage"
  if ! run_as_root mv -T -n "$root_stage" "$HOMELAB_BOOTSTRAP_DIR"; then
    run_as_root rm -rf -- "$root_stage"
    die "Could not install the homelab bootstrap wrapper"
  fi
  if sudo test -e "$root_stage"; then
    run_as_root rm -rf -- "$root_stage"
    die "Homelab bootstrap path appeared during setup; refusing to replace it"
  fi
  run_as_root chmod 0755 "$HOMELAB_BOOTSTRAP_DIR"
}

require_homelab_login_preservation() {
  local mutable_users operator_managed

  mutable_users="$(nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" eval --no-write-lock-file --json "$HOMELAB_BOOTSTRAP_FLAKE#nixosConfigurations.homelab.config.users.mutableUsers")" \
    || die "Could not evaluate users.mutableUsers for the staged homelab configuration"
  [[ "$mutable_users" == "true" ]] \
    || die "Refusing to stage homelab configuration with users.mutableUsers=$mutable_users; the bootstrap preserves an existing unmanaged administrator"

  operator_managed="$(nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" eval --no-write-lock-file --json "$HOMELAB_BOOTSTRAP_FLAKE#nixosConfigurations.homelab.config.users.users" --apply "users: builtins.hasAttr \"$HOMELAB_OPERATOR_NAME\" users")" \
    || die "Could not verify whether the staged homelab configuration manages $HOMELAB_OPERATOR_NAME"
  [[ "$operator_managed" == "false" ]] \
    || die "Refusing to stage homelab configuration because it declaratively manages existing local operator $HOMELAB_OPERATOR_NAME"

  printf '[i] Local login preservation is verified for %s: executable login shell, unlocked password, mutable users, and no declarative user management\n' "$HOMELAB_OPERATOR_NAME"
}

verify_staged_homelab_login_shell() {
  local toplevel shell_name staged_shell

  shell_name="${HOMELAB_OPERATOR_SHELL##*/}"
  [[ "$shell_name" =~ ^[A-Za-z0-9._+-]+$ ]] \
    || die "Homelab operator login shell has an unsupported basename: $HOMELAB_OPERATOR_SHELL"
  toplevel="$(nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" eval --no-write-lock-file --raw "$HOMELAB_BOOTSTRAP_FLAKE#nixosConfigurations.homelab.config.system.build.toplevel")" \
    || die "Could not evaluate the staged homelab system toplevel for local login verification"
  staged_shell="$toplevel/sw/bin/$shell_name"
  [[ -x "$staged_shell" ]] \
    || die "Staged homelab system does not provide the existing operator login shell: $staged_shell"

  printf '[i] Staged homelab system provides the existing operator login shell: %s\n' "$staged_shell"
}

ensure_homelab_unlock_password() {
  local password_status password_state
  password_status="$(sudo passwd --status "$HOMELAB_OPERATOR_NAME")" \
    || die "Could not determine local password status for $HOMELAB_OPERATOR_NAME"
  read -r _ password_state _ <<< "$password_status"
  [[ "$password_state" == "P" ]] \
    || die "$HOMELAB_OPERATOR_NAME has no usable local password (state: ${password_state:-unknown}). Set one with: sudo passwd $HOMELAB_OPERATOR_NAME"
  printf '[i] Local unlock password is configured for %s\n' "$HOMELAB_OPERATOR_NAME"
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-url) require_value "$1" "${2-}"; REPO_URL="$2"; shift 2 ;;
    --git-dir) require_value "$1" "${2-}"; GIT_DIR="$2"; shift 2 ;;
    --work-tree) require_value "$1" "${2-}"; WORK_TREE="$2"; shift 2 ;;
    --sync-hardware) SYNC_HARDWARE=1; shift ;;
    --hardware-src) require_value "$1" "${2-}"; HARDWARE_SRC="$2"; shift 2 ;;
    --initialize-homelab-secrets) INITIALIZE_HOMELAB_SECRETS=1; shift ;;
    --linkwarden-env-file) require_value "$1" "${2-}"; LINKWARDEN_ENV_FILE="$2"; shift 2 ;;
    --skip-rebuild) SKIP_REBUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -z "$LINKWARDEN_ENV_FILE" || "$INITIALIZE_HOMELAB_SECRETS" -eq 1 ]] \
  || die "--linkwarden-env-file requires --initialize-homelab-secrets"

NIXOS_FLAKE="$WORK_TREE/nixos"
detect_homelab_operator
validate_homelab_hardware_source
ensure_homelab_unlock_password
if [[ ! -e "$HOMELAB_BOOTSTRAP_DIR" && ! -L "$HOMELAB_BOOTSTRAP_DIR" ]] && (( ! INITIALIZE_HOMELAB_SECRETS )); then
  die "Fresh homelab secret provisioning is required before checkout; rerun with --initialize-homelab-secrets"
fi
prepare_existing_secret_before_checkout

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
      if [[ -d "$GIT_DIR" ]] && [[ -z "$(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then :; else die "Git dir exists but is not recognized as bare Git metadata: $GIT_DIR"; fi
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

if (( INITIALIZE_HOMELAB_SECRETS )); then
  create_verified_local_ciphertext
  if [[ -e "$HOMELAB_BOOTSTRAP_DIR" || -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
    if (( DRY_RUN )); then
      printf '[dry-run] atomically install fresh machine-local Linkwarden ciphertext at %s/linkwarden.env.age\n' "$HOMELAB_BOOTSTRAP_DIR"
    else
      stage_root_owned_file "$GENERATED_CIPHERTEXT" "$HOMELAB_BOOTSTRAP_DIR/linkwarden.env.age" 0644
    fi
    update_existing_identity_for_local_secret
  else
    HOMELAB_IDENTITY_NIX="${HOMELAB_IDENTITY_NIX/secretsValidated = false;/secretsValidated = true;}"
  fi
elif (( MIGRATED_OLD_CIPHERTEXT )); then
  update_existing_identity_for_local_secret
fi

if [[ -e "$HOMELAB_BOOTSTRAP_DIR" || -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
  validate_existing_wrapper
  identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
  identity_has_local_secret_path "$identity" \
    || die "Machine-local homelab identity is missing linkwardenSecretFile; rerun with --initialize-homelab-secrets"
  [[ "$(identity_secret_state "$identity")" == "true" ]] \
    || die "Machine-local homelab secrets are unvalidated. Rerun with --initialize-homelab-secrets before staging a generation"
  verify_local_ciphertext
  (( SYNC_HARDWARE )) && sync_homelab_hardware
  cleanup_homelab_wrapper_lock
else
  create_fresh_wrapper
fi

if [[ -n "$GENERATED_CIPHERTEXT_DIR" ]]; then
  rm -rf -- "$GENERATED_CIPHERTEXT_DIR"
fi
GENERATED_CIPHERTEXT=""
GENERATED_CIPHERTEXT_DIR=""
need_cmd nix "nix is required; run this from NixOS or install Nix before using this bootstrap script."
if [[ -f "$HOMELAB_BOOTSTRAP_FLAKE/flake.nix" ]]; then
  nix_cmd flake show --no-write-lock-file "$HOMELAB_BOOTSTRAP_FLAKE"
  nix_cmd eval --no-write-lock-file --raw "$HOMELAB_BOOTSTRAP_FLAKE#nixosConfigurations.homelab.config.networking.hostName"
  require_homelab_login_preservation
elif (( DRY_RUN )); then
  nix_cmd flake show --no-write-lock-file "$HOMELAB_BOOTSTRAP_FLAKE"
  nix_cmd eval --no-write-lock-file --raw "$HOMELAB_BOOTSTRAP_FLAKE#nixosConfigurations.homelab.config.networking.hostName"
  printf '[i] Skipping flake validation because dry-run did not create %s\n' "$HOMELAB_BOOTSTRAP_FLAKE"
else
  die "Missing NixOS flake at $HOMELAB_BOOTSTRAP_FLAKE/flake.nix after checkout"
fi
if (( SKIP_REBUILD )); then
  printf '[i] Skipping nixos-rebuild\n'
else
  run sudo nixos-rebuild build --no-write-lock-file --flake "$HOMELAB_BOOTSTRAP_FLAKE#homelab" --option experimental-features "$NIX_EXPERIMENTAL_FEATURES"
  if (( ! DRY_RUN )); then
    verify_staged_homelab_login_shell
  fi
fi
if (( INITIALIZE_HOMELAB_SECRETS )); then
  printf '[i] Tailscale enrollment is deferred until the staged homelab generation boots; after boot, run: sudo tailscale up --advertise-tags=tag:server\n'
fi
printf '[i] Homelab configuration build is staged only and was not activated; review it before manually activating it.\n'
printf '[+] Done\n'
