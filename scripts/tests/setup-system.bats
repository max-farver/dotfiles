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
  ISOLATED_SCRIPT="$TEST_DIR/setup-system.sh"

  mkdir -p "$MOCK_BIN" "$GIT_DIR/objects" "$WORK_TREE/nixos" "$OPERATOR_HOME"
  : > "$GIT_DIR/config"
  : > "$WORK_TREE/nixos/flake.nix"
  : > "$HARDWARE_SRC"
  : > "$MOCK_LOG"
  : > "$TAILSCALE_LOG"
  : > "$NIX_LOG"
  : > "$GIT_LOG"
  cp "$SCRIPT" "$ISOLATED_SCRIPT"
  chmod 0755 "$ISOLATED_SCRIPT"
  ssh-keygen -q -t ed25519 -N '' -f "$TEST_DIR/beszel-agent-key"
  BESZEL_AGENT_KEY="$(<"$TEST_DIR/beszel-agent-key.pub")"
  BESZEL_AGENT_KEY="${BESZEL_AGENT_KEY% *} operator\$host \${config}"

  cat > "$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${GIT_LOG-}" ]]; then
  printf '%s\n' "$*" >> "$GIT_LOG"
fi
EOF

  cat > "$MOCK_BIN/nix" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${NIX_LOG-}" ]]; then
  printf '%s\n' "$*" >> "$NIX_LOG"
fi
EOF

  cat > "$MOCK_BIN/age" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

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
      printf '%s P 0 99999 7 -1\n' "${3:?}"
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

  chmod +x "$MOCK_BIN/git" "$MOCK_BIN/nix" "$MOCK_BIN/age" "$MOCK_BIN/tailscale" "$MOCK_BIN/id" "$MOCK_BIN/getent" "$MOCK_BIN/stat" "$MOCK_BIN/sudo"
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
    "--git-dir=$GIT_DIR config status.showUntrackedFiles no" \
    "--git-dir=$GIT_DIR fetch --all --prune" \
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
  [[ "$output" == *"[dry-run] git --git-dir=$GIT_DIR fetch --all --prune"*"[dry-run] git --git-dir=$GIT_DIR --work-tree=$WORK_TREE checkout origin/main -- ."* ]]
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

@test "first homelab setup accepts a missing Beszel agent key" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] atomically create root-owned wrapper flake at /etc/nixos/homelab-bootstrap with identity.nix and hardware-configuration.nix"* ]]
  [[ ! -s "$MOCK_LOG" ]]
}

@test "homelab bootstrap rejects an invalid Beszel agent key" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --beszel-agent-key 'ssh-ed25519 definitely-not-a-key' \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 1 ]
  [[ "$output" == *"--beszel-agent-key must be one nonempty SSH public-key line"* ]]
  [[ ! -s "$MOCK_LOG" ]]
}

@test "homelab bootstrap requires the exact discovered operator confirmation" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" bash -c '
    printf "%s\\n" "$1" | "$2" --system homelab --beszel-agent-key "$3" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild --skip-neovim-check
  ' _ 'different_operator' "$SCRIPT" "$BESZEL_AGENT_KEY"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Confirmation did not exactly match the detected homelab operator"* ]]
  [ "$(<"$MOCK_LOG")" = "-v" ]
  [[ ! -e "$IDENTITY_CAPTURE" ]]
}

@test "homelab dry run plans a root-owned wrapper and wrapper-only build without sudo" {
  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --beszel-agent-key "$BESZEL_AGENT_KEY" \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --hardware-src "$HARDWARE_SRC" \
    --skip-neovim-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] atomically create root-owned wrapper flake at /etc/nixos/homelab-bootstrap with identity.nix and hardware-configuration.nix"* ]]
  [[ "$output" == *"[dry-run] sudo nixos-rebuild build --no-write-lock-file --flake /etc/nixos/homelab-bootstrap#homelab"* ]]
  [[ ! -s "$MOCK_LOG" ]]
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
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(<"$NIX_LOG")" = $'--extra-experimental-features nix-command flakes flake show --no-write-lock-file /etc/nixos/homelab-bootstrap\n--extra-experimental-features nix-command flakes eval --no-write-lock-file --raw /etc/nixos/homelab-bootstrap#nixosConfigurations.homelab.config.networking.hostName' ]

  run env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" "$SCRIPT" \
    --dry-run \
    --system homelab \
    --git-dir "$GIT_DIR" \
    --work-tree "$WORK_TREE" \
    --skip-rebuild \
    --skip-neovim-check

  [ "$status" -eq 0 ]
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

@test "confirmed homelab operator stages the discovered identity in the wrapper" {
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
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --beszel-agent-key "$3" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    bootstrap_status=$?
    chmod 0644 "$IDENTITY_CAPTURE"
    exit "$bootstrap_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$BESZEL_AGENT_KEY"
  [ "$status" -eq 0 ]

  NIX_SERIALIZED_BESZEL_AGENT_KEY="${BESZEL_AGENT_KEY//\$\{/\\\${}"
  [[ "$(<"$IDENTITY_CAPTURE")" == *"name = \"$OPERATOR_NAME\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"uid = $OPERATOR_UID;"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"primaryGroup = \"$OPERATOR_GROUP\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"primaryGid = $OPERATOR_GID;"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"home = \"$OPERATOR_HOME\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"flakePath = \"/etc/nixos/homelab-bootstrap#homelab\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"ageIdentityPath = \"/etc/ssh/ssh_host_ed25519_key\";"* ]]
  [[ "$(<"$IDENTITY_CAPTURE")" == *"beszelAgentKey = \"$NIX_SERIALIZED_BESZEL_AGENT_KEY\";"* ]]
  run nix-instantiate --parse "$IDENTITY_CAPTURE"
  [ "$status" -eq 0 ]
}

@test "keyless homelab bootstrap stages a null Beszel agent key" {
  KEYLESS_IDENTITY_CAPTURE="$TEST_DIR/keyless-identity.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"
  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    bootstrap_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$3"
    chmod 0644 "$3"
    exit "$bootstrap_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$KEYLESS_IDENTITY_CAPTURE"

  [ "$status" -eq 0 ]
  [[ "$(<"$KEYLESS_IDENTITY_CAPTURE")" == *"beszelAgentKey = null;"* ]]
}

@test "later Beszel enrollment atomically replaces only the serialized key" {
  INITIAL_IDENTITY_CAPTURE="$TEST_DIR/initial-identity.nix"
  ENROLLED_IDENTITY_CAPTURE="$TEST_DIR/enrolled-identity.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"
  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    first_status=$?
    (( first_status == 0 )) || exit "$first_status"
    cp /etc/nixos/homelab-bootstrap/identity.nix "$4"
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --beszel-agent-key "$3" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    enrollment_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$5"
    chmod 0644 "$4" "$5"
    exit "$enrollment_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$BESZEL_AGENT_KEY" "$INITIAL_IDENTITY_CAPTURE" "$ENROLLED_IDENTITY_CAPTURE"

  [ "$status" -eq 0 ]
  initial_identity="$(<"$INITIAL_IDENTITY_CAPTURE")"
  enrolled_identity="$(<"$ENROLLED_IDENTITY_CAPTURE")"
  NIX_SERIALIZED_BESZEL_AGENT_KEY="${BESZEL_AGENT_KEY//\$\{/\\\${}"
  [[ "$initial_identity" == *"beszelAgentKey = null;"* ]]
  [[ "$enrolled_identity" == *"beszelAgentKey = \"$NIX_SERIALIZED_BESZEL_AGENT_KEY\";"* ]]
  initial_immutable="$(printf '%s\\n' "$initial_identity" | grep -v '^[[:space:]]*beszelAgentKey[[:space:]]*=')"
  enrolled_immutable="$(printf '%s\\n' "$enrolled_identity" | grep -v '^[[:space:]]*beszelAgentKey[[:space:]]*=')"
  [ "$initial_immutable" = "$enrolled_immutable" ]
}

@test "later invalid Beszel enrollment is rejected without replacing the key" {
  IDENTITY_AFTER_REJECTION="$TEST_DIR/identity-after-rejection.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"
  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    first_status=$?
    (( first_status == 0 )) || exit "$first_status"
    setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --beszel-agent-key "ssh-ed25519 definitely-not-a-key" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    enrollment_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$3"
    chmod 0644 "$3"
    exit "$enrollment_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$IDENTITY_AFTER_REJECTION"

  [ "$status" -eq 1 ]
  [[ "$output" == *"--beszel-agent-key must be one nonempty SSH public-key line"* ]]
  [[ "$(<"$IDENTITY_AFTER_REJECTION")" == *"beszelAgentKey = null;"* ]]
}

@test "later Beszel enrollment rejects hardware synchronization without changing hardware" {
  HARDWARE_AFTER_REJECTION="$TEST_DIR/hardware-after-rejection.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$HARDWARE_SRC"
  chmod 0666 "$MOCK_LOG"
  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" IDENTITY_CAPTURE="$IDENTITY_CAPTURE" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
    printf "initial hardware\\n" > "$HARDWARE_SRC"
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    first_status=$?
    (( first_status == 0 )) || exit "$first_status"
    printf "replacement hardware\\n" > "$HARDWARE_SRC"
    printf "%s\\n" "$1" | setpriv --reuid 65534 --regid 65534 --clear-groups "$2" --system homelab --beszel-agent-key "$3" --sync-hardware --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    enrollment_status=$?
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$4"
    chmod 0644 "$4"
    exit "$enrollment_status"
  ' _ "$OPERATOR_NAME" "$ISOLATED_SCRIPT" "$BESZEL_AGENT_KEY" "$HARDWARE_AFTER_REJECTION"

  [ "$status" -eq 1 ]
  [[ "$output" == *"--sync-hardware cannot be combined with --beszel-agent-key enrollment"* ]]
  [ "$(<"$HARDWARE_AFTER_REJECTION")" = "initial hardware" ]
}

@test "exact legacy homelab wrapper migrates its operator module without changing identity or hardware" {
  LEGACY_IDENTITY="$TEST_DIR/legacy-identity.nix"
  LEGACY_HARDWARE="$TEST_DIR/legacy-hardware.nix"
  MIGRATED_IDENTITY="$TEST_DIR/migrated-identity.nix"
  MIGRATED_HARDWARE="$TEST_DIR/migrated-hardware.nix"
  MIGRATED_FLAKE="$TEST_DIR/migrated-flake.nix"
  chmod 0777 "$TEST_DIR"
  chmod 0666 "$MOCK_LOG"

  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private env PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" TEST_DIR="$TEST_DIR" OPERATOR_UID="$OPERATOR_UID" OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" bash -c '
    mount -t tmpfs tmpfs /etc/nixos
    mount -t tmpfs tmpfs /etc/ssh
    chmod 0777 /etc/ssh /etc/nixos
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    chmod 0666 /etc/ssh/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/ssh_host_ed25519_key
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
    printf "legacy hardware\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
    cp /etc/nixos/homelab-bootstrap/identity.nix "$1"
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$2"
    printf "%s\\n" "$OPERATOR_NAME" | setpriv --reuid 65534 --regid 65534 --clear-groups "$3" --system homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild --skip-neovim-check
    bootstrap_status=$?
    cp /etc/nixos/homelab-bootstrap/identity.nix "$4"
    cp /etc/nixos/homelab-bootstrap/hardware-configuration.nix "$5"
    cp /etc/nixos/homelab-bootstrap/flake.nix "$6"
    chmod 0644 "$1" "$2" "$4" "$5" "$6"
    exit "$bootstrap_status"
  ' _ "$LEGACY_IDENTITY" "$LEGACY_HARDWARE" "$ISOLATED_SCRIPT" "$MIGRATED_IDENTITY" "$MIGRATED_HARDWARE" "$MIGRATED_FLAKE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrated machine-local homelab wrapper flake to import homelabOperator"* ]]
  [ "$(<"$LEGACY_IDENTITY")" = "$(<"$MIGRATED_IDENTITY")" ]
  [ "$(<"$LEGACY_HARDWARE")" = "$(<"$MIGRATED_HARDWARE")" ]
  [ "$(<"$MIGRATED_FLAKE")" = "$(cat <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ dotfiles.nixosModules.homelabOperator ./identity.nix ./hardware-configuration.nix ];
    };
  };
}
EOF
)" ]
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
    beszelAgentKey = null;
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
    beszelAgentKey = null;
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
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ dotfiles.nixosModules.homelabOperator ./identity.nix ./hardware-configuration.nix ];
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
    beszelAgentKey = null;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ dotfiles.nixosModules.homelabOperator ./identity.nix ./hardware-configuration.nix ];
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
    beszelAgentKey = null;
  };
}
EOF
    cat > /etc/nixos/homelab-bootstrap/flake.nix <<EOF
{
  description = "Machine-local homelab bootstrap";

  inputs.dotfiles.url = "path:$WORK_TREE/nixos";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.homelab = dotfiles.nixosConfigurations.homelab.extendModules {
      modules = [ dotfiles.nixosModules.homelabOperator ./identity.nix ./hardware-configuration.nix ];
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

@test "non-homelab bootstrap does not require homelab identity or Beszel key discovery" {
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
