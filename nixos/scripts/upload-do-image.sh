#!/usr/bin/env bash
set -euo pipefail

# Create a DigitalOcean custom image from a remotely accessible Spaces URL.
#
# Usage:
#   ./scripts/upload-do-image.sh [options]
#
# Options:
#   --image-name <name>     Custom image name (required or DO_IMAGE_NAME)
#   --spaces-url <url>      Public URL to the image file (required or DO_SPACES_URL)
#   --region <slug>         DigitalOcean region slug (required or DO_REGION)
#   --distribution <slug>   Image distribution slug (default: Unknown)
#   --description <text>    Optional image description
#   --tag-names <csv>       Optional comma-separated tag list
#   --dry-run               Print command without executing it
#   -h, --help              Show help

IMAGE_NAME="${DO_IMAGE_NAME:-}"
SPACES_URL="${DO_SPACES_URL:-}"
REGION="${DO_REGION:-}"
DISTRIBUTION="${DO_IMAGE_DISTRIBUTION:-Unknown}"
DESCRIPTION="${DO_IMAGE_DESCRIPTION:-}"
TAG_NAMES="${DO_IMAGE_TAG_NAMES:-}"
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

command -v doctl >/dev/null || die "Missing command: doctl"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-name)
      IMAGE_NAME="${2:-}"
      shift 2
      ;;
    --spaces-url)
      SPACES_URL="${2:-}"
      shift 2
      ;;
    --region)
      REGION="${2:-}"
      shift 2
      ;;
    --distribution)
      DISTRIBUTION="${2:-}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:-}"
      shift 2
      ;;
    --tag-names)
      TAG_NAMES="${2:-}"
      shift 2
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

[[ -n "$IMAGE_NAME" ]] || die "Missing image name. Use --image-name or DO_IMAGE_NAME"
[[ -n "$SPACES_URL" ]] || die "Missing Spaces URL. Use --spaces-url or DO_SPACES_URL"
[[ -n "$REGION" ]] || die "Missing region. Use --region or DO_REGION"

case "$SPACES_URL" in
  https://*) ;;
  *) die "Spaces URL must begin with https://" ;;
esac

if [[ "$SPACES_URL" != *"digitaloceanspaces.com"* ]]; then
  die "Expected a DigitalOcean Spaces URL containing digitaloceanspaces.com"
fi

cmd=(
  doctl compute image create "$IMAGE_NAME"
  --image-url "$SPACES_URL"
  --region "$REGION"
  --image-distribution "$DISTRIBUTION"
)

if [[ -n "$DESCRIPTION" ]]; then
  cmd+=(--image-description "$DESCRIPTION")
fi

if [[ -n "$TAG_NAMES" ]]; then
  cmd+=(--tag-names "$TAG_NAMES")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run command:"
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

log "Uploading custom image '$IMAGE_NAME' to region '$REGION'"
"${cmd[@]}"
