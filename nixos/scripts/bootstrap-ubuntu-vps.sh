#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Ubuntu VPS with Nix + Home Manager config from this repo.
# Usage:
#   ./scripts/bootstrap-ubuntu-vps.sh [--dry-run] <repo-url> [target-dir] [home-config]
# Examples:
#   ./scripts/bootstrap-ubuntu-vps.sh git@github.com:you/nixos-config.git ~/.config/nixos ubuntu-vps
#   ./scripts/bootstrap-ubuntu-vps.sh https://github.com/you/nixos-config.git ~/.config/nixos ubuntu-vps
#   ./scripts/bootstrap-ubuntu-vps.sh --dry-run git@github.com:you/nixos-config.git ~/.config/nixos ubuntu-vps

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

REPO_URL="${1:-}"
TARGET_DIR="${2:-$HOME/.config/nixos}"
HOME_CONFIG="${3:-ubuntu-vps}"

if [[ -z "$REPO_URL" && ! -f "$TARGET_DIR/flake.nix" ]]; then
  echo "[!] Provide a repo URL (arg 1), or ensure $TARGET_DIR already contains your flake."
  exit 1
fi

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi

  echo "[+] Installing Nix (Determinate installer)..."
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install

  # Try to load nix into current shell session
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi

  if ! command -v nix >/dev/null 2>&1; then
    echo "[!] Nix installed but not yet in this shell PATH."
    echo "    Open a new shell, then rerun this script."
    exit 1
  fi
}

ensure_flakes_enabled() {
  mkdir -p "$HOME/.config/nix"
  if [[ ! -f "$HOME/.config/nix/nix.conf" ]] || ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf"; then
    echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
  elif ! grep -q "flakes" "$HOME/.config/nix/nix.conf"; then
    sed -i 's/^experimental-features = \(.*\)$/experimental-features = \1 flakes/' "$HOME/.config/nix/nix.conf"
  fi
}

check_repo_access_mode() {
  if [[ -z "$REPO_URL" ]]; then
    return 0
  fi

  if [[ "$REPO_URL" == git@* || "$REPO_URL" == ssh://* ]]; then
    echo "[i] Using SSH git URL. Ensure this VPS has an SSH key loaded in your git host account."
  elif [[ "$REPO_URL" == https://* ]]; then
    echo "[i] Using HTTPS git URL. For private repos, use a PAT/credential helper."
  fi
}

sync_repo() {
  mkdir -p "$(dirname "$TARGET_DIR")"

  if [[ -e "$TARGET_DIR" && ! -d "$TARGET_DIR/.git" && -n "$(ls -A "$TARGET_DIR" 2>/dev/null || true)" ]]; then
    echo "[!] $TARGET_DIR exists and is not a git repo. Move/remove it or choose a different target dir."
    exit 1
  fi

  if [[ -n "$REPO_URL" ]]; then
    if [[ -d "$TARGET_DIR/.git" ]]; then
      echo "[+] Updating existing repo at $TARGET_DIR"
      git -C "$TARGET_DIR" fetch --all --prune
      git -C "$TARGET_DIR" pull --ff-only
    else
      echo "[+] Cloning $REPO_URL -> $TARGET_DIR"
      git clone "$REPO_URL" "$TARGET_DIR"
    fi
  else
    echo "[+] Using existing flake at $TARGET_DIR"
  fi
}

ensure_nix
ensure_flakes_enabled

if ! command -v git >/dev/null 2>&1; then
  echo "[+] Installing git via nix profile"
  nix profile install nixpkgs#git
fi

check_repo_access_mode
sync_repo

echo "[+] Validating flake outputs"
nix flake show --no-write-lock-file "$TARGET_DIR"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[+] Dry run enabled; skipping Home Manager apply"
  echo "    Would run: nix run github:nix-community/home-manager -- switch --flake \"$TARGET_DIR#$HOME_CONFIG\""
  echo "[+] Done (dry run)"
else
  echo "[+] Applying Home Manager config: $HOME_CONFIG"
  nix run github:nix-community/home-manager -- switch --flake "$TARGET_DIR#$HOME_CONFIG"
  echo "[+] Done"
fi
