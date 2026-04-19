#!/usr/bin/env bash
set -euo pipefail

# Build and push a flake closure to a local Attic cache.
#
# Usage:
#   ./scripts/push-attic-closure.sh [options]
#
# Options:
#   --installable <ref>   Nix installable to publish
#                         (default: $HOME/.config/nixos#nixosConfigurations.nixos.config.system.build.toplevel)
#   --cache <name>        Attic cache name (default: nixos-local)
#   --no-build            Skip `nix build` and only push existing closure
#   --dry-run             Print what would run, but do not push
#   -h, --help            Show help

INSTALLABLE="${HOME}/.config/nixos#nixosConfigurations.nixos.config.system.build.toplevel"
CACHE_NAME="nixos-local"
DO_BUILD=true
DRY_RUN=false

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

for cmd in nix attic; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --installable)
      INSTALLABLE="${2:-}"
      shift 2
      ;;
    --cache)
      CACHE_NAME="${2:-}"
      shift 2
      ;;
    --no-build)
      DO_BUILD=false
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

[[ -n "$INSTALLABLE" ]] || die "Installable cannot be empty"
[[ -n "$CACHE_NAME" ]] || die "Cache name cannot be empty"

# Confirm cache access before spending time building.
attic cache info "$CACHE_NAME" >/dev/null 2>&1 || die "Cannot access cache '$CACHE_NAME'. Run attic login/use first."

if [[ "$DO_BUILD" == "true" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] nix build $INSTALLABLE --no-link"
  else
    log "Building installable: $INSTALLABLE"
    nix build "$INSTALLABLE" --no-link
  fi
fi

log "Collecting closure paths for: $INSTALLABLE"
mapfile -t CLOSURE_PATHS < <(nix path-info -r "$INSTALLABLE")

if [[ "${#CLOSURE_PATHS[@]}" -eq 0 ]]; then
  die "No closure paths found for $INSTALLABLE"
fi

log "Resolved ${#CLOSURE_PATHS[@]} paths"

if [[ "$DRY_RUN" == "true" ]]; then
  log "[dry-run] Would push to cache '$CACHE_NAME'"
  printf '%s\n' "${CLOSURE_PATHS[@]}"
  exit 0
fi

printf '%s\n' "${CLOSURE_PATHS[@]}" | attic push "$CACHE_NAME" --stdin

log "Push complete: ${#CLOSURE_PATHS[@]} paths -> $CACHE_NAME"