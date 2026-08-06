#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/setup-system.sh"

  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$TEST_DIR/bin"
  MOCK_LOG="$TEST_DIR/sudo.log"
  TAILSCALE_LOG="$TEST_DIR/tailscale.log"
  NIX_LOG="$TEST_DIR/nix.log"
  GIT_LOG="$TEST_DIR/git.log"
  IDENTITY_CAPTURE="$TEST_DIR/staged-identity.nix"
  GIT_DIR="$TEST_DIR/dotfiles.git"
  WORK_TREE="$TEST_DIR/work-tree"
  OPERATOR_NAME="bootstrap_operator"
  OPERATOR_UID="4242"
  OPERATOR_GROUP="bootstrap_group"
  OPERATOR_GID="4242"
  OPERATOR_HOME="$TEST_DIR/home"
  HARDWARE_SRC="$TEST_DIR/hardware-configuration.nix"
  HARDWARE_REPLACEMENT_SRC="$TEST_DIR/replacement-hardware-configuration.nix"
  ISOLATED_SCRIPT="$TEST_DIR/setup-system.sh"

  mkdir -p "$MOCK_BIN" "$GIT_DIR/objects" "$WORK_TREE/nixos/secrets" "$OPERATOR_HOME"
  : > "$GIT_DIR/config"
  : > "$WORK_TREE/nixos/flake.nix"
  printf '  homelab = "uninitialized-recipient";\n' > "$WORK_TREE/nixos/secrets/secrets.nix"
  chmod 0777 "$WORK_TREE/nixos/secrets"
  chmod 0666 "$WORK_TREE/nixos/secrets/secrets.nix"
  cat > "$HARDWARE_SRC" <<'EOF'
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/bootstrap-root";
    fsType = "ext4";
  };
}
EOF
  cat > "$HARDWARE_REPLACEMENT_SRC" <<'EOF'
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/replacement-root";
    fsType = "ext4";
  };
}
EOF
  : > "$MOCK_LOG"
  : > "$TAILSCALE_LOG"
  : > "$NIX_LOG"
  : > "$GIT_LOG"
  cp "$SCRIPT" "$ISOLATED_SCRIPT"
  chmod 0755 "$ISOLATED_SCRIPT"

  cat > "$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GIT_LOG-}" ]]; then
  printf '%s\n' "$*" >> "$GIT_LOG"
fi

if [[ "${1-}" == --git-dir=* && "${2-}" == "remote" && "${3-}" == "get-url" && "${4-}" == "--all" && "${5-}" == "origin" ]]; then
  printf '%s\n' "${MOCK_ORIGIN_URL:-https://github.com/max-farver/dotfiles}"
fi

if [[ "${GIT_CHECKOUT_REPLACE_SECRETS-0}" == "1" && "$*" == *"checkout origin/main -- ."* ]]; then
  printf '  homelab = "checkout-recipient";\n' > "${WORK_TREE:?}/nixos/secrets/secrets.nix"
  printf 'NEXTAUTH_SECRET=checkout-secret\n' > "${WORK_TREE:?}/nixos/secrets/linkwarden.env.age"
fi
EOF

  cat > "$MOCK_BIN/nix" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${NIX_LOG-}" ]]; then
  printf '%s\n' "$*" >> "$NIX_LOG"
fi

if [[ "${*: -1}" == *".config.users.mutableUsers" ]]; then
  printf '%s\n' "${HOMELAB_MUTABLE_USERS:-true}"
fi
EOF
  cat > "$MOCK_BIN/nix-instantiate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1-}" == "--parse" && -f "${2-}" ]] || exit 1
EOF

  cat > "$MOCK_BIN/age" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" == "--decrypt" ]]; then
  shift
  while (( $# > 0 )); do
    case "$1" in
      --identity)
        shift 2
        ;;
      --output)
        output_path="$2"
        shift 2
        ;;
      *)
        input_path="$1"
        shift
        ;;
    esac
  done
  cat "${input_path:?}" > "${output_path:?}"
  exit 0
fi

while (( $# > 0 )); do
  case "$1" in
    -r)
      shift 2
      ;;
    -o)
      output_path="$2"
      shift 2
      ;;
    *)
      printf 'unexpected age argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

cat > "${output_path:?}"
EOF

  cat > "$MOCK_BIN/prepare-homelab-secrets" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

work_tree="${1:?work tree is required}"
rm -f "$work_tree/nixos/secrets/secrets.nix" "$work_tree/nixos/secrets/linkwarden.env.age"
host_key="$(cat /etc/ssh/ssh_host_ed25519_key.pub)"
printf '  homelab = "%s";\n' "$host_key" > "$work_tree/nixos/secrets/secrets.nix"
printf 'NEXTAUTH_SECRET=verified-fixture\n' > "$work_tree/nixos/secrets/linkwarden.env.age"
EOF

  cat > "$MOCK_BIN/tailscale" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${TAILSCALE_LOG:?}"
exit 66
EOF

  cat > "$MOCK_BIN/id" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${FORBID_NSS-0}" != "1" ]] || exit 99
printf '%s\n' "${OPERATOR_UID:?}"
EOF

  cat > "$MOCK_BIN/getent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${FORBID_NSS-0}" != "1" ]] || exit 99

case "${1-}:${2-}" in
  passwd:"${OPERATOR_UID:?}")
    printf '%s:x:%s:%s::%s:/bin/bash\n' "${OPERATOR_NAME:?}" "${NSS_UID:-$OPERATOR_UID}" "${OPERATOR_GID:?}" "${OPERATOR_HOME:?}"
    ;;
  group:"${OPERATOR_GID:?}")
    printf '%s:x:%s:\n' "${OPERATOR_GROUP:?}" "${OPERATOR_GID:?}"
    ;;
  *)
    exit 2
    ;;
esac
EOF

  cat > "$MOCK_BIN/stat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "${HOME_OWNER_UID:-${OPERATOR_UID:?}}"
EOF

  cat > "$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${MOCK_LOG:?}"

case "${1-}" in
  -v)
    exit "${SUDO_VALIDATE_STATUS:-0}"
    ;;
  cat)
    command cat "${@:2}"
    ;;
  grep)
    command grep "${@:2}"
    ;;
  stat)
    printf '0\n'
    ;;
  test)
    test "${@:2}"
    ;;
  mktemp)
    if [[ "${2-}" == "-d" ]]; then
      mkdir -p "${TEST_DIR:?}/root-stage"
      printf '%s\n' "${TEST_DIR:?}/root-stage"
    else
      : > "${TEST_DIR:?}/root-identity-stage"
      printf '%s\n' "${TEST_DIR:?}/root-identity-stage"
    fi
    ;;
  install)
    if [[ "${2-}" == "-d" ]]; then
      exit 0
    fi
    cp "${@: -2:1}" "${@: -1}"
    for arg in "$@"; do
      if [[ "$arg" == */identity.nix && -f "$arg" ]]; then
        cp "$arg" "${IDENTITY_CAPTURE:?}"
      fi
    done
    ;;
  mv)
    command mv "${@:2}"
    ;;
  passwd)
    if [[ "${2-}" == "--status" ]]; then
      printf '%s %s 0 99999 7 -1\n' "${3:?}" "${PASSWORD_STATE:-P}"
      exit 0
    fi
    exit 1
    ;;
  sh)
    command sh "${@:2}"
    ;;
  ssh-keygen)
    case "${2-}" in
      -A|-t) ;;
      *) command ssh-keygen "${@:2}" ;;
    esac
    ;;
  nix-instantiate|age)
    command "$1" "${@:2}"
    ;;
  nixos-rebuild)
    if [[ -n "${NIXOS_REBUILD_LOCK_STATE-}" ]]; then
      if [[ -e /etc/nixos/homelab-bootstrap/flake.lock || -L /etc/nixos/homelab-bootstrap/flake.lock ]]; then
        printf 'present\n' > "$NIXOS_REBUILD_LOCK_STATE"
      else
        printf 'absent\n' > "$NIXOS_REBUILD_LOCK_STATE"
      fi
    fi
    ;;
  mkdir|chmod)
    ;;
  rm)
    command rm "${@:2}"
    ;;
  *)
    printf 'unexpected sudo command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "$MOCK_BIN/git" "$MOCK_BIN/nix" "$MOCK_BIN/nix-instantiate" "$MOCK_BIN/age" "$MOCK_BIN/tailscale" "$MOCK_BIN/id" "$MOCK_BIN/getent" "$MOCK_BIN/stat" "$MOCK_BIN/sudo"
  chmod +x "$MOCK_BIN/prepare-homelab-secrets"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "homelab bootstrap rejects direct root invocation" {
  run unshare --user --map-root-user env PATH="$MOCK_BIN:$PATH" "$SCRIPT" \
    --system homelab \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"Homelab bootstrap must be invoked directly by the intended non-root operator, not through sudo or as root"* ]]
}

@test "setup checks out fetched origin/main in normal and dry-run paths" {
  expected_git_log="$(printf '%s\n' \
    "--git-dir=$GIT_DIR remote get-url --all origin" \
    "--git-dir=$GIT_DIR remote get-url --all origin" \
    "--git-dir=$GIT_DIR config status.showUntrackedFiles no" \
    "--git-dir=$GIT_DIR fetch --all --prune" \
    "--git-dir=$GIT_DIR fetch origin refs/heads/main:refs/remotes/origin/main" \
    "--git-dir=$GIT_DIR --work-tree=$WORK_TREE checkout origin/main -- .")"

  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" "$SCRIPT" \
    --system framework16 \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [ "$(<"$GIT_LOG")" = "$expected_git_log" ]

  run env PATH="$MOCK_BIN:$PATH" "$SCRIPT" \
    --dry-run \
    --system framework16 \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] git --git-dir=$GIT_DIR fetch --all --prune"*"[dry-run] git --git-dir=$GIT_DIR fetch origin refs/heads/main:refs/remotes/origin/main"*"[dry-run] git --git-dir=$GIT_DIR --work-tree=$WORK_TREE checkout origin/main -- ."* ]]
}
@test "existing Git origin mismatch aborts before checkout mutation" {
  printf 'work-tree sentinel\n' > "$WORK_TREE/sentinel"

  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" MOCK_ORIGIN_URL="git@github.com:unexpected/dotfiles.git" "$SCRIPT" \
    --system framework16 \
    --repo-url "https://github.com/max-farver/dotfiles" \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"Existing Git origin must exactly match --repo-url; expected https://github.com/max-farver/dotfiles"* ]]
  [ "$(<"$GIT_LOG")" = "--git-dir=$GIT_DIR remote get-url --all origin" ]
  [ "$(<"$WORK_TREE/sentinel")" = "work-tree sentinel" ]
}

@test "staged homelab build rejects --checks before operator or Git work" {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" MOCK_LOG="$MOCK_LOG" FORBID_NSS=1 "$SCRIPT" \
    --system homelab \
    --checks \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"--checks is not supported for staged homelab builds; boot the staged generation and check its services there"* ]]
  [[ ! -s "$GIT_LOG" ]]
  [[ ! -s "$MOCK_LOG" ]]
}

@test "homelab hardware guard rejects empty and non-concrete root sources before checkout" {
  local fixture_name
  local hardware_content
  local expected_error

  while IFS='|' read -r fixture_name hardware_content expected_error; do
    printf '%b' "$hardware_content" > "$HARDWARE_SRC"
    : > "$GIT_LOG"
    : > "$MOCK_LOG"

    run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
      --dry-run \
      --system homelab \
      --initialize-homelab-secrets \
      --git-dir "$GIT_DIR" \
      --work-tree "$WORK_TREE" \
      --hardware-src "$HARDWARE_SRC" \
      --skip-rebuild \
      --skip-neovim-check

    [ "$status" -eq 1 ]
    [[ "$output" == *"$expected_error"* ]]
    [[ ! -s "$GIT_LOG" ]]
    [[ "$(<"$MOCK_LOG")" != *"install "* ]]
    [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
  done <<'EOF'
empty||Homelab hardware source must be a nonempty regular file
missing-root|{\n  boot.initrd.availableKernelModules = [ "nvme" ];\n}\n|Homelab hardware source must declare fileSystems."/" as a concrete root filesystem mount
incomplete-root|{\n  fileSystems."/" = { device = "/dev/disk/by-uuid/root"; };\n}\n|Homelab hardware source root filesystem mount must have nonempty device and fsType values
placeholder-root|{\n  fileSystems."/" = { device = "/dev/root"; fsType = "ext4"; };\n}\n|Homelab hardware source root filesystem mount must not use the /dev/root placeholder
EOF
}

@test "homelab password refusal happens before wrapper, secret, build, or checkout mutation" {
  mkdir -p "$WORK_TREE/nixos/secrets"
  printf 'recipient sentinel\n' > "$WORK_TREE/nixos/secrets/secrets.nix"

  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" MOCK_LOG="$MOCK_LOG" PASSWORD_STATE="L" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --initialize-homelab-secrets \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --hardware-src "$HARDWARE_SRC" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"$OPERATOR_NAME has no usable local password (state: L)"* ]]
  [ "$(<"$WORK_TREE/nixos/secrets/secrets.nix")" = "recipient sentinel" ]
  [[ ! -e "$WORK_TREE/nixos/secrets/linkwarden.env.age" ]]
  [[ ! -s "$GIT_LOG" ]]
  [[ "$(<"$MOCK_LOG")" == *"passwd --status $OPERATOR_NAME"* ]]
  [[ "$(<"$MOCK_LOG")" != *"install "* ]]
  [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
}

@test "homelab bootstrap rejects an NSS account whose UID differs from the invoking identity" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" NSS_UID="9999" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"NSS passwd entry UID does not match invoking UID $OPERATOR_UID"* ]]
  [[ ! -s "$MOCK_LOG" ]]
}

@test "first homelab setup plans a root-owned wrapper without a legacy key option" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --initialize-homelab-secrets \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] atomically create root-owned wrapper flake at /etc/nixos/homelab-bootstrap with identity.nix and hardware-configuration.nix"* ]]
  [[ "$(<"$MOCK_LOG")" != *"install "* ]]
  [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
}

@test "removed Beszel option fails before Git, Nix, or sudo mutation" {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" MOCK_LOG="$MOCK_LOG" "$SCRIPT" \
    --beszel-agent-key value \
    --system homelab \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --beszel-agent-key"* ]]
  [[ ! -s "$GIT_LOG" ]]
  [[ ! -s "$NIX_LOG" ]]
  [[ ! -s "$MOCK_LOG" ]]
}

@test "homelab bootstrap requires the exact discovered operator confirmation" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" bash -c '
    printf "%s\\n" "$1" | "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild --skip-neovim-check
  ' _ 'different_operator' "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Confirmation did not exactly match the detected homelab operator"* ]]
  [ "$(<"$MOCK_LOG")" = "-v" ]
  [[ ! -e "$IDENTITY_CAPTURE" ]]
}

@test "homelab dry run plans a root-owned wrapper and wrapper-only build without sudo" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --initialize-homelab-secrets \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --hardware-src "$HARDWARE_SRC" \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] atomically create root-owned wrapper flake at /etc/nixos/homelab-bootstrap with identity.nix and hardware-configuration.nix"* ]]
  [[ "$output" == *"[dry-run] sudo nixos-rebuild build --no-write-lock-file --flake /etc/nixos/homelab-bootstrap#homelab"* ]]
  [[ "$(<"$MOCK_LOG")" != *"install "* ]]
  [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
}

@test "homelab wrapper validation prevents lock writes in normal and dry-run paths" {
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG" "$NIX_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" NIX_LOG="$NIX_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --initialize-homelab-secrets --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    first_status=$?
    (( first_status == 0 )) || exit "$first_status"
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --dry-run --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(<"$NIX_LOG")" = $'--extra-experimental-features nix-command flakes flake show --no-write-lock-file /etc/nixos/homelab-bootstrap\n--extra-experimental-features nix-command flakes eval --no-write-lock-file --raw /etc/nixos/homelab-bootstrap#nixosConfigurations.homelab.config.networking.hostName\n--extra-experimental-features nix-command flakes eval --no-write-lock-file --raw /etc/nixos/homelab-bootstrap#nixosConfigurations.homelab.config.users.mutableUsers\n--extra-experimental-features nix-command flakes eval --no-write-lock-file --raw /etc/nixos/homelab-bootstrap#nixosConfigurations.homelab.config.users.mutableUsers' ]

  [[ "$output" == *"[dry-run] nix --extra-experimental-features nix-command\\ flakes flake show --no-write-lock-file /etc/nixos/homelab-bootstrap"* ]]
  [[ "$output" == *"[dry-run] nix --extra-experimental-features nix-command\\ flakes eval --no-write-lock-file --raw /etc/nixos/homelab-bootstrap#nixosConfigurations.homelab.config.networking.hostName"* ]]
}

@test "initialized fresh homelab bootstrap defers Tailscale enrollment until boot" {
  LINKWARDEN_ENV_FILE="$TEST_DIR/linkwarden.env"
  mkdir -p "$WORK_TREE/nixos/secrets"
  printf '  homelab = "old-recipient";\n' > "$WORK_TREE/nixos/secrets/secrets.nix"
  printf 'NEXTAUTH_SECRET=deterministic-test-secret\n' > "$LINKWARDEN_ENV_FILE"
  chmod 0777 "$TEST_DIR" "$WORK_TREE/nixos/secrets"
  chmod 0666 "$MOCK_LOG" "$TAILSCALE_LOG" "$WORK_TREE/nixos/secrets/secrets.nix"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TAILSCALE_LOG="$TAILSCALE_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" LINKWARDEN_ENV_FILE="$LINKWARDEN_ENV_FILE" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --initialize-homelab-secrets --linkwarden-env-file "$3" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    chmod 0644 "$WORK_TREE/nixos/secrets/linkwarden.env.age"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$LINKWARDEN_ENV_FILE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Tailscale enrollment is deferred until the staged homelab generation boots"* ]]
  [ "$(<"$WORK_TREE/nixos/secrets/linkwarden.env.age")" = "NEXTAUTH_SECRET=deterministic-test-secret" ]
  [[ ! -s "$TAILSCALE_LOG" ]]
  ! grep -q -- 'tailscale' "$MOCK_LOG"
}
@test "initialized homelab rerun restores host-verified secret artifacts after checkout" {
  LINKWARDEN_ENV_FILE="$TEST_DIR/linkwarden.env"
  INITIAL_RECIPIENTS="$TEST_DIR/initial-secrets.nix"
  INITIAL_CIPHERTEXT="$TEST_DIR/initial-linkwarden.env.age"
  FINAL_IDENTITY="$TEST_DIR/final-identity.nix"
  mkdir -p "$WORK_TREE/nixos/secrets"
  printf '  homelab = "old-recipient";\n' > "$WORK_TREE/nixos/secrets/secrets.nix"
  printf 'NEXTAUTH_SECRET=host-secret\n' > "$LINKWARDEN_ENV_FILE"
  chmod 0777 "$TEST_DIR" "$WORK_TREE/nixos/secrets"
  chmod 0666 "$MOCK_LOG" "$WORK_TREE/nixos/secrets/secrets.nix"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" LINKWARDEN_ENV_FILE="$LINKWARDEN_ENV_FILE" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --initialize-homelab-secrets --linkwarden-env-file "$3" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    first_status=$?
    (( first_status == 0 )) || exit "$first_status"
    cp "$WORK_TREE/nixos/secrets/secrets.nix" "$4"
    cp "$WORK_TREE/nixos/secrets/linkwarden.env.age" "$5"
    GIT_CHECKOUT_REPLACE_SECRETS=1 setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    rerun_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$6"
    chmod 0644 "$WORK_TREE/nixos/secrets/secrets.nix" "$WORK_TREE/nixos/secrets/linkwarden.env.age"
    chmod 0644 "$4" "$5" "$6"
    exit "$rerun_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$LINKWARDEN_ENV_FILE" "$INITIAL_RECIPIENTS" "$INITIAL_CIPHERTEXT" "$FINAL_IDENTITY"

  [ "$status" -eq 0 ]
  [ "$(<"$WORK_TREE/nixos/secrets/secrets.nix")" = "$(<"$INITIAL_RECIPIENTS")" ]
  [ "$(<"$WORK_TREE/nixos/secrets/linkwarden.env.age")" = "$(<"$INITIAL_CIPHERTEXT")" ]
  [[ "$(<"$FINAL_IDENTITY")" == *"secretsValidated = true;"* ]]
}

@test "confirmed homelab operator stages the discovered identity in the wrapper" {
  GENERATED_FLAKE_CAPTURE="$TEST_DIR/generated-flake.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"
  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh
    chmod 0777 /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --initialize-homelab-secrets --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    bootstrap_status=$?
    cp /etc/nixos/homelab-bootstrap/flake.nix "$3"
    chmod 0644 "$IDENTITY_CAPTURE" "$3"
    exit "$bootstrap_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$GENERATED_FLAKE_CAPTURE"
  [ "$status" -eq 0 ]

  [[ "$(<"$IDENTITY_CAPTURE")" == *"name = \"$OPERATOR_NAME\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"uid = $OPERATOR_UID;"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"primaryGroup = \"$OPERATOR_GROUP\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"primaryGid = $OPERATOR_GID;"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"home = \"$OPERATOR_HOME\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"flakePath = \"/etc/nixos/homelab-bootstrap#homelab\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"ageIdentityPath = \"/etc/ssh/ssh_host_ed25519_key\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" != *"beszelAgentKey"* ]]
  [ "$(<"$GENERATED_FLAKE_CAPTURE")" = "$(cat <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
)" ]
  run nix-instantiate --parse "$IDENTITY_CAPTURE"
  [ "$status" -eq 0 ]
}


@test "root-owned legacy Beszel identity dry run plans removal, normal run removes one line, and rerun is idempotent" {
  LEGACY_IDENTITY="$TEST_DIR/legacy-identity.nix"
  DRY_RUN_IDENTITY="$TEST_DIR/dry-run-identity.nix"
  MIGRATED_IDENTITY="$TEST_DIR/migrated-identity.nix"
  RERUN_IDENTITY="$TEST_DIR/rerun-identity.nix"
  INITIAL_HARDWARE="$TEST_DIR/initial-hardware.nix"
  FINAL_HARDWARE="$TEST_DIR/final-hardware.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    chmod 0777 /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    beszelAgentKey = null;
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
    printf "persisted hardware\\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    [[ -O /etc/nixos/homelab-bootstrap && -O /etc/nixos/homelab-bootstrap/identity.nix && -O /etc/nixos/homelab-bootstrap/flake.nix && -O /etc/nixos/homelab-bootstrap/hardware-configuration.nix ]] || exit 1
    cp /etc/nixos/homelab-bootstrap/identity.nix "$1"
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$5"
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --dry-run --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    dry_run_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$3"
    (( dry_run_status == 0 )) || exit "$dry_run_status"
    printf "%s\\n" "$OPERATOR_NAME" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    migration_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$4"
    (( migration_status == 0 )) || exit "$migration_status"
    printf "%s\\n" "$OPERATOR_NAME" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    rerun_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$6"
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$7"
    chmod 0644 "$1" "$3" "$4" "$5" "$6" "$7"
    exit "$rerun_status"
  ' _ "$LEGACY_IDENTITY" "$ISOLATED_SCRIPT" "$DRY_RUN_IDENTITY" "$MIGRATED_IDENTITY" "$INITIAL_HARDWARE" "$RERUN_IDENTITY" "$FINAL_HARDWARE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] atomically remove the legacy Beszel agent key from /etc/nixos/homelab-bootstrap/identity.nix"* ]]
  [ "$(<"$DRY_RUN_IDENTITY")" = "$(<"$LEGACY_IDENTITY")" ]
  [ "$(grep -c '^[[:space:]]*beszelAgentKey[[:space:]]*=' "$LEGACY_IDENTITY")" -eq 1 ]
  expected_identity="$(grep -v '^[[:space:]]*beszelAgentKey[[:space:]]*=' "$LEGACY_IDENTITY")"
  [ "$(<"$MIGRATED_IDENTITY")" = "$expected_identity" ]
  [ "$(<"$RERUN_IDENTITY")" = "$(<"$MIGRATED_IDENTITY")" ]
  [[ "$(<"$MIGRATED_IDENTITY")" == *"name = \"$OPERATOR_NAME\";"* ]]
  [[ "$(<"$MIGRATED_IDENTITY")" == *"uid = $OPERATOR_UID;"* ]]
  [[ "$(<"$MIGRATED_IDENTITY")" == *"primaryGroup = \"$OPERATOR_GROUP\";"* ]]
  [[ "$(<"$MIGRATED_IDENTITY")" == *"primaryGid = $OPERATOR_GID;"* ]]
  [[ "$(<"$MIGRATED_IDENTITY")" == *"home = \"$OPERATOR_HOME\";"* ]]
  [[ "$(<"$MIGRATED_IDENTITY")" == *"ageIdentityPath = \"/etc/ssh/ssh_host_ed25519_key\";"* ]]
  [ "$(grep -c '^[[:space:]]*beszelAgentKey[[:space:]]*=' "$MIGRATED_IDENTITY")" -eq 0 ]
  [[ "$(<"$MIGRATED_IDENTITY")" != *"beszelAgentKey"* ]]
  [ "$(<"$FINAL_HARDWARE")" = "$(<"$INITIAL_HARDWARE")" ]
}

@test "modified homelab wrapper is refused without mutating machine-local files" {
  WRAPPER_BEFORE="$TEST_DIR/modified-wrapper-before.nix"
  WRAPPER_AFTER="$TEST_DIR/modified-wrapper-after.nix"
  IDENTITY_BEFORE="$TEST_DIR/modified-identity-before.nix"
  IDENTITY_AFTER="$TEST_DIR/modified-identity-after.nix"
  HARDWARE_BEFORE="$TEST_DIR/modified-hardware-before.nix"
  HARDWARE_AFTER="$TEST_DIR/modified-hardware-after.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
# machine-specific modification
EOF
    printf "modified-wrapper hardware\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    cp /etc/nixos/homelab-bootstrap/flake.nix "$1"
    cp /etc/nixos/homelab-bootstrap/identity.nix "$2"
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$3"
    setpriv --reuid 65534 --regid 65534 --clear-groups "$4" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    bootstrap_status=$?
    cp /etc/nixos/homelab-bootstrap/flake.nix "$5"
    cp /etc/nixos/homelab-bootstrap/identity.nix "$6"
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$7"
    chmod 0644 "$1" "$2" "$3" "$5" "$6" "$7"
    exit "$bootstrap_status"
  ' _ "$WRAPPER_BEFORE" "$IDENTITY_BEFORE" "$HARDWARE_BEFORE" "$ISOLATED_SCRIPT" "$WRAPPER_AFTER" "$IDENTITY_AFTER" "$HARDWARE_AFTER"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Machine-local homelab wrapper does not match this checkout; refusing to replace it"* ]]
  [ "$(<"$WRAPPER_BEFORE")" = "$(<"$WRAPPER_AFTER")" ]
  [ "$(<"$IDENTITY_BEFORE")" = "$(<"$IDENTITY_AFTER")" ]
  [ "$(<"$HARDWARE_BEFORE")" = "$(<"$HARDWARE_AFTER")" ]
}

@test "legacy homelab wrapper is not migrated before persisted hardware validates" {
  WRAPPER_BEFORE="$TEST_DIR/unvalidated-wrapper-before.nix"
  WRAPPER_AFTER="$TEST_DIR/unvalidated-wrapper-after.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
    printf "REPLACE invalid hardware\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    cp /etc/nixos/homelab-bootstrap/flake.nix "$1"
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    bootstrap_status=$?
    cp /etc/nixos/homelab-bootstrap/flake.nix "$3"
    chmod 0644 "$1" "$3"
    exit "$bootstrap_status"
  ' _ "$WRAPPER_BEFORE" "$ISOLATED_SCRIPT" "$WRAPPER_AFTER"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Machine-local homelab hardware configuration still contains a REPLACE placeholder"* ]]
  [ "$(<"$WRAPPER_BEFORE")" = "$(<"$WRAPPER_AFTER")" ]
}

@test "stale regular homelab wrapper lock is removed before a no-write rebuild" {
  LOCK_REMOVAL_STATE="$TEST_DIR/lock-removal-state"
  REBUILD_LOCK_STATE="$TEST_DIR/rebuild-lock-state"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" NIXOS_REBUILD_LOCK_STATE="$REBUILD_LOCK_STATE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    chmod 0777 /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
    printf "persisted hardware\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    cat > /etc/nixos/homelab-bootstrap/flake.lock <<EOF
{
  "nodes": {
    "root": {
      "inputs": {}
    }
  },
  "root": "root",
  "version": 7
}
EOF
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-neovim-check
    bootstrap_status=$?
    if [[ -e /etc/nixos/homelab-bootstrap/flake.lock || -L /etc/nixos/homelab-bootstrap/flake.lock ]]; then
      printf "present\n" > "$1"
    else
      printf "removed\n" > "$1"
    fi
    chmod 0644 "$1" "$NIXOS_REBUILD_LOCK_STATE"
    exit "$bootstrap_status"
  ' _ "$LOCK_REMOVAL_STATE" "$ISOLATED_SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Removing stale root-owned homelab wrapper lock"* ]]
  [ "$(<"$LOCK_REMOVAL_STATE")" = "removed" ]
  [ "$(<"$REBUILD_LOCK_STATE")" = "absent" ]
  [[ "$(<"$MOCK_LOG")" == *"nixos-rebuild build --no-write-lock-file --flake /etc/nixos/homelab-bootstrap#homelab --option experimental-features nix-command flakes"* ]]
}

@test "homelab bootstrap refuses immutable-user configuration before rebuild" {
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" HOMELAB_MUTABLE_USERS=false TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    chmod 0777 /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
    printf "persisted hardware\\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    setpriv --reuid 65534 --regid 65534 --clear-groups "$1" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-neovim-check
  ' _ "$ISOLATED_SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"users.mutableUsers=false"* ]]
  [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
}

@test "symlink homelab wrapper lock is rejected without deletion or rebuild" {
  LOCK_STATE="$TEST_DIR/symlink-lock-state"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
    printf "persisted hardware\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    printf "protected lock target\n" > /etc/nixos/homelab-bootstrap/lock-target
    ln -s lock-target /etc/nixos/homelab-bootstrap/flake.lock
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-neovim-check
    bootstrap_status=$?
    if [[ -L /etc/nixos/homelab-bootstrap/flake.lock ]]; then
      printf "symlink-survived\n" > "$1"
    else
      printf "symlink-removed\n" > "$1"
    fi
    chmod 0644 "$1"
    exit "$bootstrap_status"
  ' _ "$LOCK_STATE" "$ISOLATED_SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Expected a regular file at /etc/nixos/homelab-bootstrap/flake.lock"* ]]
  [ "$(<"$LOCK_STATE")" = "symlink-survived" ]
  [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
}

@test "nonregular homelab wrapper lock is rejected without deletion or rebuild" {
  LOCK_STATE="$TEST_DIR/directory-lock-state"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    setpriv --reuid 65534 --regid 65534 --clear-groups prepare-homelab-secrets "$WORK_TREE"
    mkdir /etc/nixos/homelab-bootstrap
    cat > /etc/nixos/homelab-bootstrap/identity.nix <<EOF
{
  homelab.operator = {
    validated = true;
    name = "$OPERATOR_NAME";
    uid = $OPERATOR_UID;
    primaryGroup = "$OPERATOR_GROUP";
    primaryGid = $OPERATOR_GID;
    home = "$OPERATOR_HOME";
    flakePath = "/etc/nixos/homelab-bootstrap#homelab";
    ageIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
    secretsValidated = true;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
    printf "persisted hardware\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    mkdir /etc/nixos/homelab-bootstrap/flake.lock
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-neovim-check
    bootstrap_status=$?
    if [[ -d /etc/nixos/homelab-bootstrap/flake.lock ]]; then
      printf "directory-survived\n" > "$1"
    else
      printf "directory-removed\n" > "$1"
    fi
    chmod 0644 "$1"
    exit "$bootstrap_status"
  ' _ "$LOCK_STATE" "$ISOLATED_SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Expected a regular file at /etc/nixos/homelab-bootstrap/flake.lock"* ]]
  [ "$(<"$LOCK_STATE")" = "directory-survived" ]
  [[ "$(<"$MOCK_LOG")" != *"nixos-rebuild "* ]]
}

@test "non-homelab bootstrap does not require homelab identity discovery" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" FORBID_NSS=1 "$SCRIPT" \
    --dry-run \
    --system framework16 \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$output" != *"Homelab operator"* ]]
  [[ "$output" != *"homelab-bootstrap"* ]]
  [[ ! -s "$MOCK_LOG" ]]
}
