#!/usr/bin/env bash
set -euo pipefail

# Build the DigitalOcean image derivation for do-server and optionally
# materialize a writable decompressed qcow2 for manual uploads.
#
## Usage:
#   ./scripts/build-do-image.sh [options]
#
# Options:
#   --installable <ref>    Flake installable to build
#                          (default: $HOME/.config/nixos#do-server-do-image)
#   --out-link <path>      Symlink path for nix build output (default: ./result-do-image)
#   --no-link              Build without creating an output symlink
#   --decompress-dir <p>   Writable directory for decompressed .qcow2
#                          (default: ./do-image-artifacts)
#   --no-decompress        Skip decompression step
#   -h, --help             Show help

INSTALLABLE="${HOME}/.config/nixos#do-server-do-image"
OUT_LINK="result-do-image"
NO_LINK=false
DECOMPRESS=true
DECOMPRESS_DIR="${PWD}/do-image-artifacts"

usage() {
  sed -n '1,31p' "$0"
}

die() {
  echo "[!] $*" >&2
  exit 1
}

log() {
  echo "[+] $*"
}

command -v nix >/dev/null || die "Missing command: nix"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --installable)
      INSTALLABLE="${2:-}"
      shift 2
      ;;
    --out-link)
      OUT_LINK="${2:-}"
      shift 2
      ;;
    --no-link)
      NO_LINK=true
      shift
      ;;
    --decompress-dir)
      DECOMPRESS_DIR="${2:-}"
      shift 2
      ;;
    --no-decompress)
      DECOMPRESS=false
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
[[ "$DECOMPRESS" == "false" || -n "$DECOMPRESS_DIR" ]] || die "Decompress directory cannot be empty"

if [[ "$NO_LINK" == "true" ]]; then
  log "Building image without out-link: $INSTALLABLE"
  nix build "$INSTALLABLE" --no-link
else
  [[ -n "$OUT_LINK" ]] || die "Out-link cannot be empty when --no-link is not set"
  log "Building image: $INSTALLABLE"
  nix build "$INSTALLABLE" --out-link "$OUT_LINK"
fi

IMAGE_STORE_PATH="$(nix path-info "$INSTALLABLE")"
log "Image store path: $IMAGE_STORE_PATH"

if [[ "$NO_LINK" != "true" ]]; then
  log "Output symlink: $OUT_LINK"
fi

shopt -s nullglob
IMAGE_CANDIDATES=( "$IMAGE_STORE_PATH"/*.qcow2.gz )
shopt -u nullglob

if [[ "${#IMAGE_CANDIDATES[@]}" -eq 0 ]]; then
  die "No .qcow2.gz image file found under $IMAGE_STORE_PATH"
fi

if [[ "${#IMAGE_CANDIDATES[@]}" -gt 1 ]]; then
  printf '[!] Multiple .qcow2.gz files found under %s:\n' "$IMAGE_STORE_PATH" >&2
  printf ' - %s\n' "${IMAGE_CANDIDATES[@]}" >&2
  die "Refusing ambiguous decompression target"
fi

IMAGE_GZ_PATH="${IMAGE_CANDIDATES[0]}"
log "Compressed image: $IMAGE_GZ_PATH"

if [[ "$DECOMPRESS" == "true" ]]; then
  command -v gunzip >/dev/null || die "Missing command: gunzip"
  mkdir -p "$DECOMPRESS_DIR"

  IMAGE_QCOW2_BASENAME="$(basename "${IMAGE_GZ_PATH%.gz}")"
  IMAGE_QCOW2_PATH="$DECOMPRESS_DIR/$IMAGE_QCOW2_BASENAME"
  TMP_QCOW2_PATH="$(mktemp "$DECOMPRESS_DIR/.decompress.XXXXXX")"
  trap 'rm -f -- "$TMP_QCOW2_PATH"' EXIT

  log "Decompressing to writable path: $IMAGE_QCOW2_PATH"
  gunzip -c "$IMAGE_GZ_PATH" > "$TMP_QCOW2_PATH"
  mv -f "$TMP_QCOW2_PATH" "$IMAGE_QCOW2_PATH"
  trap - EXIT

  log "Writable decompressed image: $IMAGE_QCOW2_PATH"
else
  log "Skipping decompression (--no-decompress)"
fi