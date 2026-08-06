#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/setup-system.sh"
  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$TEST_DIR/bin"
  GIT_DIR="$TEST_DIR/dotfiles.git"
  WORK_TREE="$TEST_DIR/work-tree"
  HARDWARE_SRC="$TEST_DIR/hardware-configuration.nix"
  HARDWARE_DEST="$TEST_DIR/hardware-destination.nix"
  GIT_LOG="$TEST_DIR/git.log"
  NIX_LOG="$TEST_DIR/nix.log"
  SUDO_LOG="$TEST_DIR/sudo.log"
  NSS_LOG="$TEST_DIR/nss.log"

  mkdir -p "$MOCK_BIN" "$GIT_DIR/objects" "$WORK_TREE/nixos" "$TEST_DIR"
  : > "$GIT_DIR/config"
  : > "$WORK_TREE/nixos/flake.nix"
  : > "$GIT_LOG"; : > "$NIX_LOG"; : > "$SUDO_LOG"; : > "$NSS_LOG"
  printf 'generic hardware fixture\n' > "$HARDWARE_SRC"
  write_mock_commands
}

teardown() { rm -rf "$TEST_DIR"; }

write_mock_commands() {
  cat > "$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${GIT_LOG:?}"
if [[ "${1-}" == --git-dir=* && "${2-}" == remote && "${3-}" == get-url ]]; then
  printf '%s\n' "${MOCK_ORIGIN_URL:-https://github.com/max-farver/dotfiles}"
fi
EOF
  cat > "$MOCK_BIN/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${NIX_LOG:?}"
case "$*" in
  *config.networking.hostName) printf '%s\n' "${MOCK_HOSTNAME:-framework16}" ;;
esac
EOF
  cat > "$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SUDO_LOG:?}"
exec "$@"
EOF
  cat > "$MOCK_BIN/nixos-rebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SUDO_LOG:?}"
EOF
  cat > "$MOCK_BIN/id" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'id %s\n' "$*" >> "${NSS_LOG:?}"
[[ "${FORBID_NSS-0}" != 1 ]] || exit 99
command id "$@"
EOF
  cat > "$MOCK_BIN/getent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'getent %s\n' "$*" >> "${NSS_LOG:?}"
[[ "${FORBID_NSS-0}" != 1 ]] || exit 99
command getent "$@"
EOF
  chmod +x "$MOCK_BIN"/*
}

run_setup() {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" NSS_LOG="$NSS_LOG" "$SCRIPT" "$@"
}

@test "generic setup checks out origin/main in normal and dry-run flows" {
  run_setup --system framework16 --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild --skip-neovim-check
  [ "$status" -eq 0 ]
  [[ "$(<"$GIT_LOG")" == *"fetch origin refs/heads/main:refs/remotes/origin/main"* ]]
  [[ "$(<"$GIT_LOG")" == *"checkout origin/main -- ."* ]]

  run_setup --dry-run --system framework16 --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild --skip-neovim-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"fetch origin refs/heads/main:refs/remotes/origin/main"* ]]
  [[ "$output" == *"checkout origin/main -- ."* ]]
}

@test "generic setup rejects an existing origin mismatch before checkout mutation" {
  printf 'sentinel\n' > "$WORK_TREE/sentinel"
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" MOCK_ORIGIN_URL="git@github.com:unexpected/dotfiles.git" \
    "$SCRIPT" --system framework16 --repo-url https://github.com/max-farver/dotfiles --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"Existing Git origin must exactly match --repo-url"* ]]
  [ "$(<"$WORK_TREE/sentinel")" = sentinel ]
  [[ "$(<"$GIT_LOG")" != *"checkout "* ]]
}

@test "generic setup rejects homelab before NSS Git sudo or Nix work" {
  run_setup --system homelab --dry-run --git-dir "$GIT_DIR" --work-tree "$WORK_TREE"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Use scripts/setup-homelab.sh for the staged homelab bootstrap."* ]]
  [[ ! -s "$GIT_LOG" && ! -s "$NIX_LOG" && ! -s "$SUDO_LOG" && ! -s "$NSS_LOG" ]]
}

@test "generic setup never performs homelab operator discovery" {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" NSS_LOG="$NSS_LOG" FORBID_NSS=1 \
    "$SCRIPT" --dry-run --system framework16 --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ ! -s "$NSS_LOG" ]]
  [[ "$output" != *"homelab-bootstrap"* ]]
}

@test "generic setup validates its flake and performs switch rather than staged build" {
  run_setup --system framework16 --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$(<"$NIX_LOG")" == *"flake show --no-write-lock-file $WORK_TREE/nixos"* ]]
  [[ "$(<"$NIX_LOG")" == *"nixosConfigurations.framework16.config.networking.hostName"* ]]
  [[ "$(<"$SUDO_LOG")" == *"nixos-rebuild switch --flake $WORK_TREE/nixos#framework16"* ]]
  [[ "$(<"$SUDO_LOG")" != *"nixos-rebuild build"* ]]
}

@test "generic hardware sync stages the requested destination" {
  run_setup --system framework16 --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --sync-hardware --hardware-src "$HARDWARE_SRC" --hardware-dest "$HARDWARE_DEST" --skip-rebuild --skip-neovim-check

  [ "$status" -eq 0 ]
  [ "$(<"$HARDWARE_DEST")" = "generic hardware fixture" ]
}
