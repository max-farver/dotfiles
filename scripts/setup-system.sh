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
BESZEL_AGENT_KEY=""
HOMELAB_BOOTSTRAP_DIR="/etc/nixos/homelab-bootstrap"
HOMELAB_BOOTSTRAP_FLAKE="$HOMELAB_BOOTSTRAP_DIR"
HOMELAB_OPERATOR_NAME=""
HOMELAB_OPERATOR_UID=""
HOMELAB_OPERATOR_GROUP=""
HOMELAB_OPERATOR_GID=""
HOMELAB_OPERATOR_HOME=""
HOMELAB_IDENTITY_NIX=""
HOMELAB_FLAKE_NIX=""

usage() {
  cat <<EOF
Usage: scripts/setup-system.sh [--dry-run] [--system NAME] [--repo-url URL] [--git-dir PATH] [--work-tree PATH] [--sync-hardware] [--hardware-src PATH] [--hardware-dest PATH] [--beszel-agent-key KEY] [--print-host-key] [--enroll-host-key] [--initialize-homelab-secrets] [--linkwarden-env-file PATH] [--checks] [--skip-rebuild] [--skip-neovim-check] [--force-neovim-check] [-h|--help]

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
  --beszel-agent-key KEY
                         One SSH public-key line for the Beszel agent; optional on first homelab setup.
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
    run sudo nixos-rebuild build --flake "$HOMELAB_BOOTSTRAP_FLAKE#homelab" --option experimental-features "$NIX_EXPERIMENTAL_FEATURES"
  else
    run sudo nixos-rebuild switch --flake "$NIXOS_FLAKE#$SYSTEM" --option experimental-features "$NIX_EXPERIMENTAL_FEATURES"
  fi
}

ensure_homelab_unlock_password() {
  local password_state

  [[ "$SYSTEM" == "homelab" ]] || return 0

  if (( DRY_RUN )); then
    printf '[dry-run] verify %s has a usable local password; prompt with passwd if needed\n' "$HOMELAB_OPERATOR_NAME"
    return 0
  fi

  read -r _ password_state _ < <(sudo passwd --status "$HOMELAB_OPERATOR_NAME")
  if [[ "$password_state" == "P" ]]; then
    printf '[i] Local unlock password is configured for %s\n' "$HOMELAB_OPERATOR_NAME"
    return 0
  fi

  printf '[!] %s has no usable local password (state: %s). Set one to enable SDDM and Plasma screen-unlock authentication.\n' "$HOMELAB_OPERATOR_NAME" "$password_state" >&2
  run sudo passwd "$HOMELAB_OPERATOR_NAME"
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
nix_unescape() {
  local value="$1"
  local result=""
  local char
  local i

  for ((i = 0; i < ${#value}; i += 1)); do
    char="${value:i:1}"
    if [[ "$char" != "\\" ]]; then
      result+="$char"
      continue
    fi

    i=$((i + 1))
    (( i < ${#value} )) || return 1
    char="${value:i:1}"
    case "$char" in
      \\|\"|\$) result+="$char" ;;
      n) result+=$'\n' ;;
      r) result+=$'\r' ;;
      *) return 1 ;;
    esac
  done

  printf '%s' "$result"
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

  local beszel_agent_key_nix="null"

  if [[ -n "$BESZEL_AGENT_KEY" ]]; then
    is_ssh_public_key_line "$BESZEL_AGENT_KEY" || die "--beszel-agent-key must be one nonempty SSH public-key line"
    beszel_agent_key_nix="\"$(nix_escape "$BESZEL_AGENT_KEY")\""
  fi

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
    beszelAgentKey = $beszel_agent_key_nix;
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
  [[ "$SYSTEM" == "homelab" ]] || return 0

  if (( DRY_RUN )); then
    if [[ -r "$HARDWARE_SRC" ]]; then
      grep -q 'REPLACE' "$HARDWARE_SRC" && die "Homelab hardware configuration still contains a REPLACE placeholder: $HARDWARE_SRC"
    else
      printf '[dry-run] validate generated hardware configuration at %s has no REPLACE placeholders\n' "$HARDWARE_SRC"
    fi
    return 0
  fi

  sudo test -r "$HARDWARE_SRC" || die "Hardware source is not readable: $HARDWARE_SRC"
  if sudo grep -q 'REPLACE' "$HARDWARE_SRC"; then
    die "Homelab hardware configuration still contains a REPLACE placeholder: $HARDWARE_SRC"
  fi
}

require_root_owned_file() {
  local path="$1"
  local owner_uid

  sudo test -f "$path" && ! sudo test -L "$path" || die "Expected a regular file at $path"
  owner_uid="$(sudo stat -c '%u' -- "$path")" || die "Could not read ownership of $path"
  [[ "$owner_uid" == "0" ]] || die "Refusing non-root-owned bootstrap file: $path"
}
require_root_owned_directory() {
  local path="$1"
  local owner_uid

  sudo test -d "$path" && ! sudo test -L "$path" || die "Expected a directory at $path"
  owner_uid="$(sudo stat -c '%u' -- "$path")" || die "Could not read ownership of $path"
  [[ "$owner_uid" == "0" ]] || die "Refusing non-root-owned bootstrap directory: $path"
}
validate_existing_homelab_identity() {
  local identity="$1"
  local line
  local persisted_beszel_key=""
  local persisted_beszel_key_source=""
  local persisted_beszel_key_count=0
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

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*beszelAgentKey[[:space:]]*=[[:space:]]*\"(([^\"\\]|\\.)*)\"\;[[:space:]]*$ ]]; then
      persisted_beszel_key_source="${BASH_REMATCH[1]}"
      ((persisted_beszel_key_count += 1))
    elif [[ "$line" =~ ^[[:space:]]*beszelAgentKey[[:space:]]*=[[:space:]]*null\;[[:space:]]*$ ]]; then
      ((persisted_beszel_key_count += 1))
    fi
  done <<< "$identity"
  (( persisted_beszel_key_count == 1 )) \
    || die "Machine-local homelab identity must contain exactly one Beszel agent key"
  if [[ -n "$persisted_beszel_key_source" ]]; then
    if ! persisted_beszel_key="$(nix_unescape "$persisted_beszel_key_source")"; then
      die "Machine-local homelab identity has an invalid escaped Beszel agent public key"
    fi
    is_ssh_public_key_line "$persisted_beszel_key" \
      || die "Machine-local homelab identity has an invalid Beszel agent public key"
  fi
}

update_homelab_beszel_agent_key() {
  local identity="$1"
  local line
  local updated_identity=""
  local local_stage
  local root_stage
  local replacement="\"$(nix_escape "$BESZEL_AGENT_KEY")\""

  [[ -n "$BESZEL_AGENT_KEY" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([[:space:]]*beszelAgentKey[[:space:]]*=[[:space:]]*)(\"([^\"\\]|\\.)*\"|null)(\;[[:space:]]*)$ ]]; then
      line="${BASH_REMATCH[1]}$replacement${BASH_REMATCH[4]}"
    fi
    updated_identity+="$line"$'\n'
  done <<< "$identity"

  [[ "$updated_identity" != "$identity"$'\n' ]] || return 0
  local_stage="$(mktemp)" || die "Could not create local identity staging file"
  if ! printf '%s' "$updated_identity" > "$local_stage"; then
    rm -f "$local_stage"
    die "Could not stage updated Beszel agent key"
  fi
  chmod 0600 "$local_stage"
  root_stage="$(sudo mktemp "$HOMELAB_BOOTSTRAP_DIR/.identity.nix.XXXXXX")" || {
    rm -f "$local_stage"
    die "Could not create root-owned identity staging file"
  }
  if ! run_as_root install -o root -g root -m 0644 "$local_stage" "$root_stage"; then
    run_as_root rm -f "$root_stage"
    rm -f "$local_stage"
    die "Could not stage updated Beszel agent key"
  fi
  rm -f "$local_stage"
  if ! run_as_root mv -f "$root_stage" "$HOMELAB_BOOTSTRAP_DIR/identity.nix"; then
    run_as_root rm -f "$root_stage"
    die "Could not atomically update the Beszel agent key"
  fi
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

  [[ "$SYSTEM" == "homelab" ]] || return 0
  validate_homelab_hardware_source
  ensure_host_key

  if [[ -e "$HOMELAB_BOOTSTRAP_DIR" || -L "$HOMELAB_BOOTSTRAP_DIR" ]]; then
    if (( DRY_RUN )); then
      printf '[dry-run] verify existing root-owned homelab bootstrap at %s without replacing its identity\n' "$HOMELAB_BOOTSTRAP_DIR"
      if [[ -n "$BESZEL_AGENT_KEY" ]]; then
        printf '[dry-run] validate immutable homelab identity fields, then atomically update only its Beszel agent key\n'
      fi
      (( SYNC_HARDWARE )) && sync_homelab_hardware
      return 0
    fi

    require_root_owned_directory "$HOMELAB_BOOTSTRAP_DIR"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/identity.nix"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/flake.nix"
    require_root_owned_file "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"
    actual_identity="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/identity.nix")"
    actual_flake="$(sudo cat "$HOMELAB_BOOTSTRAP_DIR/flake.nix")"
    validate_existing_homelab_identity "$actual_identity"
    [[ "$actual_flake" == "$HOMELAB_FLAKE_NIX" ]] || die "Machine-local homelab wrapper does not match this checkout; refusing to replace it"
    if sudo grep -q 'REPLACE' "$HOMELAB_BOOTSTRAP_DIR/hardware-configuration.nix"; then
      die "Machine-local homelab hardware configuration still contains a REPLACE placeholder"
    fi
    if [[ -n "$BESZEL_AGENT_KEY" && "$SYNC_HARDWARE" -eq 1 ]]; then
      die "--sync-hardware cannot be combined with --beszel-agent-key enrollment"
    fi
    update_homelab_beszel_agent_key "$actual_identity"
    (( SYNC_HARDWARE )) && sync_homelab_hardware
    return 0
  fi

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
    --beszel-agent-key)
      require_value "$1" "${2-}"
      BESZEL_AGENT_KEY="$2"
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

detect_homelab_operator

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

run git --git-dir="$GIT_DIR" config status.showUntrackedFiles no
run mkdir -p "$WORK_TREE"
run git --git-dir="$GIT_DIR" fetch --all --prune

if (( DRY_RUN )); then
  run git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" checkout main -- .
elif ! config_git checkout main -- .; then
  printf '[!] Move or back up the conflicting file, then rerun the script.\n' >&2
  exit 1
fi

if [[ "$SYSTEM" == "homelab" ]]; then
  bootstrap_homelab_flake
elif (( SYNC_HARDWARE )); then
  [[ -r "$HARDWARE_SRC" ]] || die "Hardware source is not readable: $HARDWARE_SRC"
  [[ -d "$(dirname -- "$HARDWARE_DEST")" ]] || die "Destination directory missing: $(dirname -- "$HARDWARE_DEST")"
  run_as_root install -m 0644 "$HARDWARE_SRC" "$HARDWARE_DEST"
fi

if (( PRINT_HOST_KEY || ENROLL_HOST_KEY || INITIALIZE_HOMELAB_SECRETS )); then
  ensure_host_key
  printf '[i] Host SSH key for agenix recipient enrollment:\n'
  run_as_root cat /etc/ssh/ssh_host_ed25519_key.pub

  if (( INITIALIZE_HOMELAB_SECRETS )); then
    if (( DRY_RUN )); then
      initialize_homelab_secrets "ssh-ed25519 <host-key> homelab"
    else
      initialize_homelab_secrets "$(read_host_key)"
    fi
  elif (( ENROLL_HOST_KEY )); then
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
  nix_cmd eval --raw "$VALIDATION_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
elif (( DRY_RUN )); then
  nix_cmd flake show --no-write-lock-file "$VALIDATION_FLAKE"
  nix_cmd eval --raw "$VALIDATION_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
  printf '[i] Skipping flake validation because dry-run did not create %s\n' "$VALIDATION_FLAKE"
else
  die "Missing NixOS flake at $VALIDATION_FLAKE/flake.nix after checkout"
fi

if (( SKIP_REBUILD )); then
  printf '[i] Skipping nixos-rebuild\n'
else
  nixos_rebuild
fi
ensure_homelab_unlock_password

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
    beszel-hub
    beszel-agent
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
