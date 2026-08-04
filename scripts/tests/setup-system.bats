#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/setup-system.sh"

  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$TEST_DIR/bin"
  MOCK_LOG="$TEST_DIR/sudo.log"
  TAILSCALE_LOG="$TEST_DIR/tailscale.log"
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
  cp "$SCRIPT" "$ISOLATED_SCRIPT"
  chmod 0755 "$ISOLATED_SCRIPT"
  ssh-keygen -q -t ed25519 -N '' -f "$TEST_DIR/beszel-agent-key"
  BESZEL_AGENT_KEY="$(<"$TEST_DIR/beszel-agent-key.pub")"
  BESZEL_AGENT_KEY="${BESZEL_AGENT_KEY% *} operator\$host \${config}"

  cat > "$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "$MOCK_BIN/nix" <<'EOF'
#!/usr/bin/env bash
exit 0
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
  mkdir|chmod|rm)
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
  [[ "$output" == *"[dry-run] sudo nixos-rebuild build --flake /etc/nixos/homelab-bootstrap#homelab"* ]]
  [[ ! -s "$MOCK_LOG" ]]
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
