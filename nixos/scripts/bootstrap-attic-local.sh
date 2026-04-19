#!/usr/bin/env bash
set -euo pipefail

# Bootstrap local Attic on this machine (idempotent):
# - Ensure /etc/atticd.env exists
# - Optionally apply NixOS config via nixos-rebuild test
# - Mint an admin token
# - Login, create cache, and configure `attic use`
# - Optional smoke test: push + pull a local store path
#
# Usage:
#   ./scripts/bootstrap-attic-local.sh [options]
#
# Options:
#   --flake <flake-ref>        NixOS flake target (default: $HOME/.config/nixos#nixos)
#   --server <server-alias>    Attic server alias for `attic login` (default: local)
#   --endpoint <url>           Attic API endpoint (default: http://127.0.0.1:8080)
#   --cache <cache-name>       Cache name to create/use (default: nixos-local)
#   --skip-rebuild             Skip `nixos-rebuild test`
#   --no-smoke-test            Skip push/pull smoke test
#   -h, --help                 Show help

FLAKE_REF="${HOME}/.config/nixos#nixos"
SERVER_ALIAS="local"
ENDPOINT="http://127.0.0.1:8080"
CACHE_NAME="nixos-local"
SKIP_REBUILD=false
RUN_SMOKE_TEST=true

usage() {
  sed -n '1,40p' "$0"
}

die() {
  echo "[!] $*" >&2
  exit 1
}

log() {
  echo "[+] $*"
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flake)
      FLAKE_REF="${2:-}"
      shift 2
      ;;
    --server)
      SERVER_ALIAS="${2:-}"
      shift 2
      ;;
    --endpoint)
      ENDPOINT="${2:-}"
      shift 2
      ;;
    --cache)
      CACHE_NAME="${2:-}"
      shift 2
      ;;
    --skip-rebuild)
      SKIP_REBUILD=true
      shift
      ;;
    --no-smoke-test)
      RUN_SMOKE_TEST=false
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

for cmd in nix attic; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
done

command -v atticd-atticadm >/dev/null 2>&1 || die "Missing command: atticd-atticadm"

ensure_attic_env_file() {
  if run_as_root test -s /etc/atticd.env; then
    log "/etc/atticd.env already exists"
    return
  fi

  log "Generating /etc/atticd.env"
  local key
  key="$(nix run nixpkgs#openssl -- genrsa -traditional 4096 | base64 -w0)"

  run_as_root install -m 600 /dev/null /etc/atticd.env
  printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="%s"\n' "$key" | run_as_root tee /etc/atticd.env >/dev/null
  run_as_root chmod 600 /etc/atticd.env
  run_as_root chown root:root /etc/atticd.env
}

apply_config_if_needed() {
  if [[ "$SKIP_REBUILD" == "true" ]]; then
    log "Skipping nixos-rebuild test"
    return
  fi

  log "Applying system config via nixos-rebuild test"
  run_as_root nixos-rebuild test --flake "$FLAKE_REF"
}

ensure_attic_service_up() {
  log "Checking atticd service"
  run_as_root systemctl is-active --quiet atticd.service || die "atticd.service is not active"
}

make_admin_token() {
  log "Minting admin token"
  (
    cd /
    run_as_root atticd-atticadm make-token \
      --sub local-admin \
      --validity 1y \
      --create-cache '*' \
      --pull '*' \
      --push '*' \
      --delete '*' \
      --configure-cache '*' \
      --configure-cache-retention '*'
  )
}

login_and_prepare_cache() {
  local token="$1"

  log "Logging in to Attic server alias '$SERVER_ALIAS'"
  attic login "$SERVER_ALIAS" "$ENDPOINT" "$token" --set-default >/dev/null

  if attic cache info "$CACHE_NAME" >/dev/null 2>&1; then
    log "Cache '$CACHE_NAME' already exists"
  else
    log "Creating cache '$CACHE_NAME'"
    attic cache create "$CACHE_NAME" >/dev/null
  fi

  log "Configuring local user Nix client via attic use"
  attic use "$CACHE_NAME" >/dev/null
}

run_smoke_test() {
  local tmpdir payload store_path alt_store fetched

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  payload="$tmpdir/attic-bootstrap-smoke.txt"
  printf 'attic bootstrap smoke test\n' > "$payload"

  store_path="$(nix-store --add "$payload")"
  log "Pushing smoke-test path to cache"
  attic push "$CACHE_NAME" "$store_path" >/dev/null

  alt_store="$tmpdir/alt-store"
  mkdir -p "$alt_store"

  log "Fetching smoke-test path from cache into alternate store"
  nix-store --store "$alt_store" -r "$store_path" >/dev/null

  fetched="$alt_store$store_path"
  [[ -f "$fetched" ]] || die "Smoke test fetch path missing: $fetched"
  grep -q 'attic bootstrap smoke test' "$fetched" || die "Smoke test content mismatch"

  log "Smoke test passed"
}

ensure_attic_env_file
apply_config_if_needed
ensure_attic_service_up

ADMIN_TOKEN="$(make_admin_token)"
login_and_prepare_cache "$ADMIN_TOKEN"

if [[ "$RUN_SMOKE_TEST" == "true" ]]; then
  run_smoke_test
else
  log "Skipping smoke test"
fi

log "Attic local bootstrap complete"
