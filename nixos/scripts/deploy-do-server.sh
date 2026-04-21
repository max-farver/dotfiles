#!/usr/bin/env bash
set -euo pipefail

# Deploy the do-server NixOS configuration to a remote DigitalOcean droplet.
#
# Usage:
#   ./scripts/deploy-do-server.sh [options] [-- <extra nixos-rebuild args>]
#
# Options:
#   --target-host <user@host>   Explicit ssh target host (overrides auto-resolve)
#   --droplet-name <name>       Droplet name for auto-resolve (default: nixos-personal-server)
#   --ssh-key <path>            SSH key for target host auth (default: ~/.ssh/id_ed25519)
#   --flake <ref>               Flake ref for deploy (default: ~/.config/nixos#do-server)
#   --no-sudo                   Do not wrap nixos-rebuild with sudo
#   --dry-run                   Print resolved command and exit
#   -h, --help                  Show help
#
# Environment overrides:
#   DO_SERVER_TARGET_HOST
#   DO_SERVER_DROPLET_NAME
#   DO_SERVER_SSH_KEY
#   DO_SERVER_FLAKE

TARGET_HOST="${DO_SERVER_TARGET_HOST:-}"
DROPLET_NAME="${DO_SERVER_DROPLET_NAME:-nixos-personal-server}"
SSH_KEY="${DO_SERVER_SSH_KEY:-${HOME}/.ssh/id_ed25519}"
FLAKE_REF="${DO_SERVER_FLAKE:-${HOME}/.config/nixos#do-server}"
USE_SUDO=true
DRY_RUN=false
EXTRA_ARGS=()

usage() {
  sed -n '1,32p' "$0"
}

die() {
  echo "[!] $*" >&2
  exit 1
}

log() {
  echo "[+] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-host)
      TARGET_HOST="${2:-}"
      shift 2
      ;;
    --droplet-name)
      DROPLET_NAME="${2:-}"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="${2:-}"
      shift 2
      ;;
    --flake)
      FLAKE_REF="${2:-}"
      shift 2
      ;;
    --no-sudo)
      USE_SUDO=false
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
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

[[ -n "$FLAKE_REF" ]] || die "Flake ref cannot be empty"
[[ -n "$SSH_KEY" ]] || die "SSH key path cannot be empty"
[[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY"

if [[ -z "$TARGET_HOST" ]]; then
  command -v doctl >/dev/null || die "Missing command: doctl (required unless --target-host is set)"
  command -v jq >/dev/null || die "Missing command: jq (required unless --target-host is set)"

  ip="$(doctl compute droplet list --output json | jq -r --arg name "$DROPLET_NAME" '.[] | select(.name == $name) | .networks.v4[] | select(.type == "public") | .ip_address' | head -n1)"
  [[ -n "$ip" && "$ip" != "null" ]] || die "Could not resolve public IPv4 for droplet '$DROPLET_NAME'"

  TARGET_HOST="root@${ip}"
  log "Resolved target host: $TARGET_HOST"
fi

SSH_OPTS="-o IdentitiesOnly=yes -i $SSH_KEY"
if [[ -n "${NIX_SSHOPTS:-}" ]]; then
  SSH_OPTS="$SSH_OPTS ${NIX_SSHOPTS}"
fi

cmd=(
  nixos-rebuild switch
  --flake "$FLAKE_REF"
  --target-host "$TARGET_HOST"
)

if [[ "${#EXTRA_ARGS[@]}" -gt 0 ]]; then
  cmd+=("${EXTRA_ARGS[@]}")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run with NIX_SSHOPTS=$SSH_OPTS"
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

log "Deploying $FLAKE_REF to $TARGET_HOST"

if [[ "$USE_SUDO" == "true" && "$EUID" -ne 0 ]]; then
  sudo --preserve-env=SSH_AUTH_SOCK NIX_SSHOPTS="$SSH_OPTS" "${cmd[@]}"
else
  NIX_SSHOPTS="$SSH_OPTS" "${cmd[@]}"
fi
