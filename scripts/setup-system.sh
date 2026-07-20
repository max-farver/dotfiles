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

usage() {
  cat <<EOF
Usage: scripts/setup-system.sh [--dry-run] [--system NAME] [--repo-url URL] [--git-dir PATH] [--work-tree PATH] [--sync-hardware] [--hardware-src PATH] [--hardware-dest PATH] [--print-host-key] [--enroll-host-key] [--checks] [--skip-rebuild] [--skip-neovim-check] [--force-neovim-check] [-h|--help]

Post-install bootstrap for this dotfiles repository.

Options:
  --dry-run              Print commands without mutating files or rebuilding.
  --system NAME          NixOS configuration output to apply. Default: $DEFAULT_SYSTEM.
  --repo-url URL         Bare repository clone URL. Default: $DEFAULT_REPO_URL.
  --git-dir PATH         Git metadata directory. Default: $DEFAULT_GIT_DIR.
  --work-tree PATH       Dotfiles work tree. Default: $DEFAULT_WORK_TREE.
  --sync-hardware        Copy generated hardware config into the selected machine config.
  --hardware-src PATH    Hardware config source. Default: $DEFAULT_HARDWARE_SRC.
  --hardware-dest PATH   Hardware config destination. Default: \$NIXOS_FLAKE/system-specific/machines/\$SYSTEM/hardware-configuration.nix.
  --print-host-key       Print /etc/ssh/ssh_host_ed25519_key.pub for agenix enrollment.
  --enroll-host-key      Replace the homelab agenix recipient with this host key and rekey secrets.
  --checks               Run homelab service health checks after rebuild handling.
  --skip-rebuild         Skip sudo nixos-rebuild switch.
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

nixos_rebuild_switch() {
  run sudo nixos-rebuild switch --flake "$NIXOS_FLAKE#$SYSTEM" --option experimental-features "$NIX_EXPERIMENTAL_FEATURES"
}

ensure_host_key() {
  local key_path="/etc/ssh/ssh_host_ed25519_key.pub"
  local private_key_path="/etc/ssh/ssh_host_ed25519_key"

  if (( DRY_RUN )); then
    run sudo mkdir -p /etc/ssh
    run sudo test -r "$key_path"
    run sudo ssh-keygen -A
    run sudo sh -c 'test -r /etc/ssh/ssh_host_ed25519_key.pub || { test ! -r /etc/ssh/ssh_host_ed25519_key || ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub; }'
    run sudo test -r "$key_path"
    run sudo ssh-keygen -t ed25519 -N "" -f "$private_key_path"
    return 0
  fi

  if (( EUID == 0 )); then
    run mkdir -p /etc/ssh
    if [[ ! -r "$key_path" ]]; then
      run ssh-keygen -A
    fi
    if [[ ! -r "$key_path" && -r "$private_key_path" ]]; then
      run sh -c 'ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
    fi
    if [[ ! -r "$key_path" ]]; then
      [[ ! -e "$private_key_path" ]] || die "SSH host private key exists but public key is unavailable: $key_path"
      run ssh-keygen -t ed25519 -N "" -f "$private_key_path"
    fi
    [[ -r "$key_path" ]] || die "SSH host ed25519 public key is unavailable after key generation: $key_path"
    return 0
  fi

  run sudo mkdir -p /etc/ssh
  if ! sudo test -r "$key_path"; then
    run sudo ssh-keygen -A
  fi
  if ! sudo test -r "$key_path" && sudo test -r "$private_key_path"; then
    run sudo sh -c 'ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub'
  fi
  if ! sudo test -r "$key_path"; then
    if sudo test -e "$private_key_path"; then
      die "SSH host private key exists but public key is unavailable: $key_path"
    fi
    run sudo ssh-keygen -t ed25519 -N "" -f "$private_key_path"
  fi
  sudo test -r "$key_path" || die "SSH host ed25519 public key is unavailable after key generation: $key_path"
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
  local homelab_config="$NIXOS_FLAKE/system-specific/machines/$SYSTEM/configuration.nix"
  local secrets_dir="$NIXOS_FLAKE/secrets"

  [[ "$SYSTEM" == "homelab" ]] || die "--enroll-host-key is only supported for --system homelab"
  [[ -f "$SECRETS_FILE" ]] || die "Missing agenix secrets file: $SECRETS_FILE"
  [[ -f "$homelab_config" ]] || die "Missing homelab configuration: $homelab_config"

  escaped_host_key="${escaped_host_key//\\/\\\\}"
  escaped_host_key="${escaped_host_key//\"/\\\"}"

  if (( DRY_RUN )); then
    printf '[dry-run] replace homelab recipient in %s with %s\n' "$(quote_cmd "$SECRETS_FILE")" "$(quote_cmd "$host_key")"
    printf '[dry-run] set age.identityPaths in %s to /etc/ssh/ssh_host_ed25519_key\n' "$(quote_cmd "$homelab_config")"
  else
    replace_line_in_file "$SECRETS_FILE" "  homelab =" "  homelab = \"$escaped_host_key\";"
    replace_line_in_file "$homelab_config" "  # Bootstrap secret decryption" "  # Decrypt agenix secrets with the enrolled host SSH key."
    replace_line_in_file "$homelab_config" "  age.identityPaths =" '  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];'
  fi

  if command -v agenix >/dev/null 2>&1; then
    run_in_dir "$secrets_dir" agenix -r
  else
    need_cmd nix "agenix is not installed and nix is required to run github:ryantm/agenix"
    run_in_dir "$secrets_dir" nix --extra-experimental-features "$NIX_EXPERIMENTAL_FEATURES" run github:ryantm/agenix -- -r
  fi
}

need_cmd() {
  local cmd="$1"
  local hint="$2"
  command -v "$cmd" >/dev/null 2>&1 || die "$hint"
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
if [[ -z "$HARDWARE_DEST" ]]; then
  HARDWARE_DEST="$NIXOS_FLAKE/system-specific/machines/$SYSTEM/hardware-configuration.nix"
fi
SECRETS_FILE="$NIXOS_FLAKE/secrets/secrets.nix"

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

if (( SYNC_HARDWARE )); then
  [[ -r "$HARDWARE_SRC" ]] || die "Hardware source is not readable: $HARDWARE_SRC"
  [[ -d "$(dirname -- "$HARDWARE_DEST")" ]] || die "Destination directory missing: $(dirname -- "$HARDWARE_DEST")"
  run_as_root install -m 0644 "$HARDWARE_SRC" "$HARDWARE_DEST"
fi

if (( PRINT_HOST_KEY || ENROLL_HOST_KEY )); then
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
    printf '    1) Replace bootstrap recipient in %s\n' "$SECRETS_FILE"
    printf '       homelab = mfarver;\n'
    printf '       with the host key above\n'
    printf '    2) cd %s/secrets && agenix -r\n' "$NIXOS_FLAKE"
  fi
fi

need_cmd nix "nix is required; run this from NixOS or install Nix before using this bootstrap script."

if [[ -f "$NIXOS_FLAKE/flake.nix" ]]; then
  nix_cmd flake show --no-write-lock-file "$NIXOS_FLAKE"
  nix_cmd eval --raw "$NIXOS_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
elif (( DRY_RUN )); then
  nix_cmd flake show --no-write-lock-file "$NIXOS_FLAKE"
  nix_cmd eval --raw "$NIXOS_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
  printf '[i] Skipping flake validation because dry-run did not check out %s\n' "$NIXOS_FLAKE"
else
  die "Missing NixOS flake at $NIXOS_FLAKE/flake.nix after checkout"
fi

if (( SKIP_REBUILD )); then
  printf '[i] Skipping nixos-rebuild\n'
else
  nixos_rebuild_switch
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

printf '[+] Done\n'
