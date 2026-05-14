#!/usr/bin/env bash
set -Eeuo pipefail

# Homelab bootstrap helper for the local physical machine.
#
# Automates the repeatable parts of migration:
# - Sync generated hardware config into the repo
# - Print host SSH key for agenix enrollment
# - Optionally run nixos-rebuild switch for .#homelab
# - Optionally run post-switch service checks
#
# Usage:
#   ./scripts/bootstrap-homelab.sh [options]
#
# Options:
#   --repo-root <path>          Repo root (default: script_dir/..)
#   --hardware-src <path>       Source hardware config (default: /etc/nixos/hardware-configuration.nix)
#   --hardware-dest <path>      Destination hardware config path in repo
#   --flake <ref>               Flake for rebuild (default: <repo-root>#homelab)
#   --skip-hardware-sync        Do not copy hardware config into repo
#   --skip-host-key             Do not print host SSH key guidance
#   --switch                    Run `nixos-rebuild switch --flake <ref>`
#   --checks                    Run systemd service health checks
#   --dry-run                   Print commands without executing
#   -h, --help                  Show help

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
HARDWARE_SRC="/etc/nixos/hardware-configuration.nix"
HARDWARE_DEST="$REPO_ROOT/system-specific/machines/homelab/hardware-configuration.nix"
SECRETS_FILE="$REPO_ROOT/secrets/secrets.nix"
FLAKE_REF="$REPO_ROOT#homelab"

SYNC_HARDWARE=true
SHOW_HOST_KEY=true
RUN_SWITCH=false
RUN_CHECKS=false
DRY_RUN=false

usage() {
  sed -n '1,25p' "$0"
}

die() {
  echo "[!] $*" >&2
  exit 1
}

log() {
  echo "[+] $*"
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

run_as_root() {
  if [[ "$DRY_RUN" == "true" ]]; then
    run_cmd sudo "$@"
    return 0
  fi

  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --hardware-src)
      HARDWARE_SRC="${2:-}"
      shift 2
      ;;
    --hardware-dest)
      HARDWARE_DEST="${2:-}"
      shift 2
      ;;
    --flake)
      FLAKE_REF="${2:-}"
      shift 2
      ;;
    --skip-hardware-sync)
      SYNC_HARDWARE=false
      shift
      ;;
    --skip-host-key)
      SHOW_HOST_KEY=false
      shift
      ;;
    --switch)
      RUN_SWITCH=true
      shift
      ;;
    --checks)
      RUN_CHECKS=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -d "$REPO_ROOT" ]] || die "Repo root does not exist: $REPO_ROOT"
[[ "$FLAKE_REF" == *"#"* ]] || die "Flake ref must include host selector, e.g. /path/to/repo#homelab"

if [[ "$SYNC_HARDWARE" == "true" ]]; then
  [[ -r "$HARDWARE_SRC" ]] || die "Hardware source is not readable: $HARDWARE_SRC"
  [[ -d "$(dirname -- "$HARDWARE_DEST")" ]] || die "Destination directory missing: $(dirname -- "$HARDWARE_DEST")"

  log "Syncing hardware config"
  run_as_root install -m 0644 "$HARDWARE_SRC" "$HARDWARE_DEST"
fi

if [[ "$SHOW_HOST_KEY" == "true" ]]; then
  log "Host SSH key for agenix recipient enrollment:"
  if [[ "$DRY_RUN" == "true" ]]; then
    run_cmd sudo cat /etc/ssh/ssh_host_ed25519_key.pub
  else
    run_as_root cat /etc/ssh/ssh_host_ed25519_key.pub
  fi

  if [[ -f "$SECRETS_FILE" ]]; then
    log "Next steps:"
    echo "    1) Replace bootstrap recipient in $SECRETS_FILE"
    echo "       homelab = mfarver;"
    echo "       with the host key above"
    echo "    2) cd $REPO_ROOT/secrets && agenix -r"
  fi
fi

if [[ "$RUN_SWITCH" == "true" ]]; then
  log "Applying NixOS configuration: $FLAKE_REF"
  run_as_root nixos-rebuild switch --flake "$FLAKE_REF"
fi

if [[ "$RUN_CHECKS" == "true" ]]; then
  log "Running service health checks"
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
    run_as_root systemctl status "$svc" --no-pager
  done
fi

log "Homelab bootstrap helper complete"
