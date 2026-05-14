#!/usr/bin/env bash
set -euo pipefail

# Update the pinned Oh My Pi release-binary package in the nested flake, including
# fixed-output binary hashes and the top-level path-input lock.
#
## Usage:
#   ./scripts/update-oh-my-pi.sh [VERSION|vVERSION] [--dry-run]
#
# Examples:
#   ./scripts/update-oh-my-pi.sh              # update to latest GitHub release
#   ./scripts/update-oh-my-pi.sh v14.9.8     # update to explicit release tag
#   ./scripts/update-oh-my-pi.sh --dry-run   # show intended actions only

DRY_RUN=false
REQUESTED_VERSION=""

SYSTEMS=(x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin)
ASSETS=(omp-linux-x64 omp-linux-arm64 omp-darwin-x64 omp-darwin-arm64)

usage() {
  sed -n '1,16p' "$0"
}

die() {
  echo "[!] $*" >&2
  exit 1
}

log() {
  echo "[+] $*"
}

require_cmd() {
  command -v "$1" >/dev/null || die "Missing command: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die "Unknown argument: $1"
      ;;
    *)
      [[ -z "$REQUESTED_VERSION" ]] || die "Only one version argument is supported"
      REQUESTED_VERSION="$1"
      shift
      ;;
  esac
done

for cmd in curl jq nix perl; do
  require_cmd "$cmd"
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PI_FLAKE="$REPO_ROOT/pkgs/pi/flake.nix"
PI_LOCK="$REPO_ROOT/pkgs/pi/flake.lock"
ROOT_LOCK="$REPO_ROOT/flake.lock"

[[ -f "$PI_FLAKE" ]] || die "Missing nested flake: $PI_FLAKE"
[[ -f "$ROOT_LOCK" ]] || die "Missing top-level lock: $ROOT_LOCK"

latest_tag() {
  curl --fail --silent --show-error --location \
    https://api.github.com/repos/can1357/oh-my-pi/releases/latest \
    | jq -r '.tag_name // empty'
}

normalize_tag() {
  local raw="$1"
  local tag

  [[ -n "$raw" ]] || die "Version cannot be empty"
  if [[ "$raw" == v* ]]; then
    tag="$raw"
  else
    tag="v${raw}"
  fi

  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] \
    || die "Invalid Oh My Pi release tag: $tag"

  printf '%s\n' "$tag"
}

current_version() {
  perl -ne 'print "$1\n" if /^\s*version = "([^"]+)";/; exit if $. > 80' "$PI_FLAKE"
}

json_hash() {
  jq -r '.hash // .narHash // empty'
}

prefetch_hash() {
  local url="$1"
  local hash

  hash="$(nix store prefetch-file --json --hash-type sha256 "$url" | json_hash)"
  [[ "$hash" == sha256-* ]] || die "Could not read sha256 SRI hash from nix prefetch output for $url"
  printf '%s\n' "$hash"
}

replace_once() {
  local file="$1"
  local pattern="$2"
  local replacement="$3"
  local count

  count="$(perl -0pi -e "\$count += s{$pattern}{$replacement}g; END { print \$count }" "$file")"
  [[ "$count" == "1" ]] || die "Expected exactly one replacement in $file, got $count"
}

set_release_version() {
  local version="$1"
  replace_once "$PI_FLAKE" 'version = "[^"]+";' "version = \"$version\";"
}

set_binary_hash() {
  local system="$1"
  local hash="$2"
  replace_once "$PI_FLAKE" "($system = \"sha256-)[^\"]+(\";)" "\${1}${hash#sha256-}\${2}"
}

planned() {
  printf '  - %s\n' "$*"
}

if [[ -z "$REQUESTED_VERSION" ]]; then
  log "Resolving latest Oh My Pi release"
  REQUESTED_TAG="$(latest_tag)"
  [[ -n "$REQUESTED_TAG" ]] || die "GitHub latest release response did not include tag_name"
else
  REQUESTED_TAG="$(normalize_tag "$REQUESTED_VERSION")"
fi

REQUESTED_TAG="$(normalize_tag "$REQUESTED_TAG")"
REQUESTED_VERSION="${REQUESTED_TAG#v}"
CURRENT_VERSION="$(current_version)"
[[ -n "$CURRENT_VERSION" ]] || die "Could not detect current version in $PI_FLAKE"
CURRENT_TAG="v${CURRENT_VERSION}"

log "Current Oh My Pi version: $CURRENT_TAG"
log "Requested Oh My Pi version: $REQUESTED_TAG"

if [[ "$REQUESTED_VERSION" == "$CURRENT_VERSION" ]]; then
  log "Already pinned to $REQUESTED_TAG; nothing to update"
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run; would update Oh My Pi from $CURRENT_TAG to $REQUESTED_TAG"
  planned "rewrite package version in $PI_FLAKE"
  for index in "${!SYSTEMS[@]}"; do
    planned "prefetch ${SYSTEMS[$index]} release binary: https://github.com/can1357/oh-my-pi/releases/download/${REQUESTED_TAG}/${ASSETS[$index]}"
  done
  planned "refresh nested flake lock with nix flake lock ./pkgs/pi"
  planned "refresh top-level pi-local lock with nix flake update pi-local --flake ."
  exit 0
fi

TMP_DIR="$(mktemp -d)"
COMMITTED=false
trap 'if [[ "$COMMITTED" != "true" ]]; then cp "$TMP_DIR/flake.nix" "$PI_FLAKE"; [[ -f "$TMP_DIR/pi-flake.lock" ]] && cp "$TMP_DIR/pi-flake.lock" "$PI_LOCK"; [[ -f "$TMP_DIR/root-flake.lock" ]] && cp "$TMP_DIR/root-flake.lock" "$ROOT_LOCK"; fi; rm -rf "$TMP_DIR"' EXIT

cp "$PI_FLAKE" "$TMP_DIR/flake.nix"
[[ -f "$PI_LOCK" ]] && cp "$PI_LOCK" "$TMP_DIR/pi-flake.lock"
cp "$ROOT_LOCK" "$TMP_DIR/root-flake.lock"

log "Prefetching release binary hashes"
HASHES=()
for index in "${!SYSTEMS[@]}"; do
  system="${SYSTEMS[$index]}"
  asset="${ASSETS[$index]}"
  url="https://github.com/can1357/oh-my-pi/releases/download/${REQUESTED_TAG}/${asset}"
  log "Prefetching $system: $asset"
  HASHES+=("$(prefetch_hash "$url")")
done

log "Updating $PI_FLAKE version and binary hashes"
set_release_version "$REQUESTED_VERSION"
for index in "${!SYSTEMS[@]}"; do
  set_binary_hash "${SYSTEMS[$index]}" "${HASHES[$index]}"
done

log "Refreshing nested flake lock"
(cd "$REPO_ROOT" && nix flake lock ./pkgs/pi)

log "Refreshing top-level pi-local lock"
(cd "$REPO_ROOT" && nix flake update pi-local --flake .)

COMMITTED=true
log "Updated Oh My Pi binary package pin to $REQUESTED_TAG"
log "Verify with: nix build ./pkgs/pi#oh-my-pi"
