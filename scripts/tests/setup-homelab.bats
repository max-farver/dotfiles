#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SOURCE_SCRIPT="$REPO_ROOT/scripts/setup-homelab.sh"
  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$TEST_DIR/bin"
  GIT_DIR="$TEST_DIR/dotfiles.git"
  WORK_TREE="$TEST_DIR/work-tree"
  HARDWARE_SRC="$TEST_DIR/hardware-configuration.nix"
  ENV_FILE="$TEST_DIR/linkwarden.env"
  GIT_LOG="$TEST_DIR/git.log"
  NIX_LOG="$TEST_DIR/nix.log"
  SUDO_LOG="$TEST_DIR/sudo.log"
  REBUILD_LOG="$TEST_DIR/rebuild.log"
  OPERATOR_NAME="bootstrap_operator"
  OPERATOR_UID=4242
  OPERATOR_GROUP="bootstrap_group"
  OPERATOR_GID=4242
  OPERATOR_HOME="$TEST_DIR/home"
  SCRIPT="$TEST_DIR/setup-homelab.sh"

  mkdir -p "$MOCK_BIN" "$GIT_DIR/objects" "$WORK_TREE/nixos" "$OPERATOR_HOME"
  : > "$MOCK_BIN/valid-login-shell"
  chmod 0755 "$MOCK_BIN/valid-login-shell"
  export OPERATOR_SHELL="$MOCK_BIN/valid-login-shell"
  export OPERATOR_MANAGED_MARKER="$TEST_DIR/operator-managed"
  : > "$GIT_DIR/config"
  cp "$SOURCE_SCRIPT" "$SCRIPT"
  chmod 0755 "$SCRIPT"
  : > "$WORK_TREE/nixos/flake.nix"
  : > "$GIT_LOG"
  : > "$NIX_LOG"
  : > "$SUDO_LOG"
  : > "$REBUILD_LOG"
  write_valid_hardware
  write_mock_commands
  chmod 0777 "$TEST_DIR" "$MOCK_BIN" "$WORK_TREE" "$WORK_TREE/nixos" "$OPERATOR_HOME"
  chmod 0666 "$GIT_LOG" "$NIX_LOG" "$SUDO_LOG" "$REBUILD_LOG"
}

teardown() { chmod -R a+rwx "$TEST_DIR" 2>/dev/null || true; rm -rf "$TEST_DIR" 2>/dev/null || true; }

write_valid_hardware() {
  cat > "$HARDWARE_SRC" <<'EOF'
{
  fileSystems."/" = { device = "/dev/disk/by-uuid/bootstrap-root"; fsType = "ext4"; };
}
EOF
}

write_mock_commands() {
  cat > "$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${GIT_LOG:?}"
if [[ "${1-}" == --git-dir=* && "${2-}" == remote && "${3-}" == get-url ]]; then
  printf '%s\n' "${MOCK_ORIGIN_URL:-https://github.com/max-farver/dotfiles}"
fi
if [[ "${GIT_CHECKOUT_REPLACE-0}" == 1 && "$*" == *"checkout origin/main -- ."* ]]; then
  mkdir -p "${WORK_TREE:?}/nixos/secrets"
  printf 'checkout replacement\n' > "${WORK_TREE:?}/nixos/secrets/linkwarden.env.age"
fi
EOF
  cat > "$MOCK_BIN/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${NIX_LOG:?}"
case "$*" in
  *config.users.mutableUsers) printf '%s\n' "${HOMELAB_MUTABLE_USERS:-true}" ;;
  *config.users.users*) [[ -e "${OPERATOR_MANAGED_MARKER:?}" ]] && printf 'true\n' || printf 'false\n' ;;
  *config.networking.hostName) printf 'homelab\n' ;;
esac
EOF
  cat > "$MOCK_BIN/nix-instantiate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1-}" == --parse && -f "${2-}" ]]
EOF
  cat > "$MOCK_BIN/age" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${AGE_FAIL-0}" != 1 ]] || exit 1
if [[ "${1-}" == --decrypt ]]; then
  shift
  while (( $# )); do
    case "$1" in
      --identity) shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) input="$1"; shift ;;
    esac
  done
  cat "${input:?}" > "${output:?}"
  exit 0
fi
while (( $# )); do
  case "$1" in
    -r) shift 2 ;;
    -o) output="$2"; shift 2 ;;
    *) exit 2 ;;
  esac
done
cat > "${output:?}"
EOF
  cat > "$MOCK_BIN/id" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${FORBID_NSS-0}" != 1 ]] || exit 99
printf '%s\n' "${OPERATOR_UID:?}"
EOF
  cat > "$MOCK_BIN/getent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${FORBID_NSS-0}" != 1 ]] || exit 99
case "${1-}:${2-}" in
  passwd:"${OPERATOR_UID:?}") printf '%s:x:%s:%s::%s:%s\n' "${OPERATOR_NAME:?}" "${NSS_UID:-$OPERATOR_UID}" "${OPERATOR_GID:?}" "${OPERATOR_HOME:?}" "${OPERATOR_SHELL:-/bin/bash}" ;;
  group:"${OPERATOR_GID:?}") printf '%s:x:%s:\n' "${OPERATOR_GROUP:?}" "${OPERATOR_GID:?}" ;;
  *) exit 2 ;;
esac
EOF
  cat > "$MOCK_BIN/stat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
format="${2-}"; path="${*: -1}"
if [[ "$path" == "${OPERATOR_HOME:?}" ]]; then
  printf '%s\n' "${HOME_OWNER_UID:-${OPERATOR_UID:?}}"
elif [[ "$format" == '%u' ]]; then
  printf '0\n'
elif [[ "$format" == '%a' ]]; then
  printf '644\n'
else
  printf '0\n'
fi
EOF
  cat > "$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SUDO_LOG:?}"
[[ "${1-}" != -v ]] || exit "${SUDO_VALIDATE_STATUS:-0}"
if [[ "${1-}" == passwd && "${2-}" == --status ]]; then
  printf '%s %s 0 99999 7 -1\n' "${3:?}" "${PASSWORD_STATE:-P}"
  exit 0
fi
if [[ "${1-}" == sh ]]; then
  exit 0
fi
if [[ "${1-}" == install ]]; then
  shift
  [[ "${1-}" != -d ]] || exit 0
  args=()
  while (( $# )); do
    case "$1" in
      -o|-g) shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  exec install "${args[@]}"
fi
exec "$@"
EOF
  cat > "$MOCK_BIN/nixos-rebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${REBUILD_LOG:?}"
EOF
  chmod +x "$MOCK_BIN"/*
}

run_plain() {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" REBUILD_LOG="$REBUILD_LOG" \
    OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_UID="$OPERATOR_UID" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" \
    "$SCRIPT" "$@"
}

# $1 provisions state before the invocation; $2 copies observable state after it.
run_homelab_namespace() {
  local namespace_setup="$1" namespace_capture="$2"
  shift 2
  run unshare --user --map-auto --setuid 0 --setgid 0 --mount --propagation private \
    env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" REBUILD_LOG="$REBUILD_LOG" \
    TEST_DIR="$TEST_DIR" SCRIPT="$SCRIPT" GIT_DIR="$GIT_DIR" WORK_TREE="$WORK_TREE" HARDWARE_SRC="$HARDWARE_SRC" ENV_FILE="$ENV_FILE" \
    OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_UID="$OPERATOR_UID" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" \
    ATTESTATION="${ATTESTATION-}" FAILURE_MODE="${FAILURE_MODE-}" AGE_FAIL="${AGE_FAIL-0}" OPERATOR_MANAGED_MARKER="$OPERATOR_MANAGED_MARKER" \
    NAMESPACE_SETUP="$namespace_setup" NAMESPACE_CAPTURE="$namespace_capture" \
    bash -ceu '
      mount -t tmpfs tmpfs /etc/nixos
      mount -t tmpfs tmpfs /etc/ssh
      chmod 0777 /etc/nixos /etc/ssh
      ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
      chmod 0644 /etc/ssh/ssh_host_ed25519_key
      eval "$NAMESPACE_SETUP"
      set +e
      setpriv --reuid 65534 --regid 65534 --clear-groups "$SCRIPT" "$@" <<< "$OPERATOR_NAME"
      bootstrap_status=$?
      set -e
      eval "$NAMESPACE_CAPTURE"
      exit "$bootstrap_status"
    ' _ "$@"
}

@test "dedicated parser rejects removed generic options before NSS Git sudo or Nix" {
  local option
  for option in --system --checks --skip-neovim-check; do
    : > "$GIT_LOG"; : > "$NIX_LOG"; : > "$SUDO_LOG"
    if [[ "$option" == --system ]]; then
      run_plain "$option" homelab --git-dir "$GIT_DIR" --work-tree "$WORK_TREE"
    else
      run_plain "$option" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE"
    fi
    [ "$status" -eq 1 ]
    [[ ! -s "$GIT_LOG" && ! -s "$NIX_LOG" && ! -s "$SUDO_LOG" ]]
  done
}

@test "linkwarden input requires explicit initialization before mutation" {
  run_plain --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE"
  [ "$status" -eq 1 ]
  [[ ! -s "$GIT_LOG" && ! -s "$NIX_LOG" && ! -s "$SUDO_LOG" ]]
}

@test "homelab bootstrap refuses direct root invocation" {
  run unshare --user --map-root-user env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" \
    "$SCRIPT" --dry-run --git-dir "$GIT_DIR" --work-tree "$WORK_TREE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be invoked directly"* ]]
}

@test "NSS UID mismatch and locked password fail before checkout" {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" \
    OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_UID="$OPERATOR_UID" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" NSS_UID=9999 \
    "$SCRIPT" --dry-run --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild
  [ "$status" -eq 1 ]
  [[ "$output" == *"NSS passwd entry UID does not match"* ]]
  [[ ! -s "$GIT_LOG" ]]

  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" \
    OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_UID="$OPERATOR_UID" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" PASSWORD_STATE=L \
    "$SCRIPT" --dry-run --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --skip-rebuild
  [ "$status" -eq 1 ]
  [[ "$output" == *"no usable local password"* ]]
  [[ ! -s "$GIT_LOG" ]]
}

@test "service and non-executable operator shells fail before checkout" {
  local operator_shell non_executable_shell
  non_executable_shell="$TEST_DIR/non-executable-shell"
  printf '#!/usr/bin/env bash\n' > "$non_executable_shell"
  chmod 0644 "$non_executable_shell"

  for operator_shell in /sbin/nologin /bin/false "$non_executable_shell"; do
    : > "$GIT_LOG"; : > "$NIX_LOG"; : > "$REBUILD_LOG"
    OPERATOR_SHELL="$operator_shell" run_plain --dry-run --initialize-homelab-secrets --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"$operator_shell"* && "$output" == *"login shell"* ]]
    [[ ! -s "$GIT_LOG" && ! -s "$NIX_LOG" && ! -s "$REBUILD_LOG" ]]
  done
}

@test "first-run confirmation must exactly match the discovered operator" {
  run env PATH="$MOCK_BIN:$PATH" GIT_LOG="$GIT_LOG" NIX_LOG="$NIX_LOG" SUDO_LOG="$SUDO_LOG" \
    OPERATOR_NAME="$OPERATOR_NAME" OPERATOR_UID="$OPERATOR_UID" OPERATOR_GROUP="$OPERATOR_GROUP" OPERATOR_GID="$OPERATOR_GID" OPERATOR_HOME="$OPERATOR_HOME" \
    bash -c 'printf "other-user\\n" | "$1" --initialize-homelab-secrets --git-dir "$2" --work-tree "$3" --hardware-src "$4" --skip-rebuild' _ "$SCRIPT" "$GIT_DIR" "$WORK_TREE" "$HARDWARE_SRC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Confirmation did not exactly match"* ]]
  [[ ! -s "$GIT_LOG" ]]
}

@test "invalid hardware root variants fail before checkout" {
  local content
  for content in '' '{ fileSystems."/" = { device = "/dev/root"; fsType = "ext4"; }; }' '{ fileSystems."/" = { device = "/dev/disk/by-uuid/root"; }; }'; do
    printf '%s\n' "$content" > "$HARDWARE_SRC"
    : > "$GIT_LOG"
    run_plain --dry-run --initialize-homelab-secrets --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    [ "$status" -eq 1 ]
    [[ ! -s "$GIT_LOG" ]]
  done
}

@test "dry run plans the wrapper build and never switch or boot" {
  run_plain --dry-run --initialize-homelab-secrets --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nixos-rebuild build --no-write-lock-file --flake /etc/nixos/homelab-bootstrap#homelab"* ]]
  [[ "$output" != *"nixos-rebuild switch"* && "$output" != *"nixos-rebuild boot"* ]]
}

@test "declaratively managed operator fails after Nix evaluation and before rebuild" {
  run_homelab_namespace '
    rm -f "$OPERATOR_MANAGED_MARKER"
    printf "NEXTAUTH_SECRET=test-secret\\n" > "$ENV_FILE"
    printf "$OPERATOR_NAME\\n" | setpriv --reuid 65534 --regid 65534 --clear-groups "$SCRIPT" --initialize-homelab-secrets --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    : > "$GIT_LOG"; : > "$NIX_LOG"; : > "$REBUILD_LOG"
    : > "$OPERATOR_MANAGED_MARKER"
  ' '
    cp "$NIX_LOG" "$TEST_DIR/operator-managed-nix.log"
    cp "$REBUILD_LOG" "$TEST_DIR/operator-managed-rebuild.log"
    chmod 0644 "$TEST_DIR"/operator-managed-*.log
  ' --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"declaratively manages existing local operator $OPERATOR_NAME"* ]]
  [[ "$(<"$TEST_DIR/operator-managed-nix.log")" == *"config.users.users"* ]]
  [[ "$(<"$TEST_DIR/operator-managed-nix.log")" == *"--apply users: builtins.hasAttr \"$OPERATOR_NAME\" users"* ]]
  [[ ! -s "$TEST_DIR/operator-managed-rebuild.log" ]]
}

@test "fresh initialization creates root-owned local ciphertext and attested identity" {
  run_homelab_namespace 'printf "NEXTAUTH_SECRET=test-secret\\n" > "$ENV_FILE"' '
    chown root:root /etc/nixos/homelab-bootstrap/linkwarden.env.age /etc/nixos/homelab-bootstrap/identity.nix
    cp /etc/nixos/homelab-bootstrap/linkwarden.env.age "$TEST_DIR/ciphertext"
    cp /etc/nixos/homelab-bootstrap/identity.nix "$TEST_DIR/identity.nix"
    ls -ln /etc/nixos/homelab-bootstrap/linkwarden.env.age > "$TEST_DIR/ciphertext-stat"
    test ! -e "$WORK_TREE/nixos/secrets/linkwarden.env.age"
    test ! -e "$WORK_TREE/nixos/secrets/secrets.nix"
    chmod 0644 "$TEST_DIR"/ciphertext "$TEST_DIR"/identity.nix "$TEST_DIR"/ciphertext-stat
  ' --initialize-homelab-secrets --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
  [ "$status" -eq 0 ]
  [ "$(<"$TEST_DIR/ciphertext")" = "NEXTAUTH_SECRET=test-secret" ]
  [[ "$(<"$TEST_DIR/ciphertext-stat")" == -rw-r--r--\ *\ 0\ 0\ * ]]
  [[ "$(<"$TEST_DIR/identity.nix")" == *"linkwardenSecretFile = ./linkwarden.env.age;"* ]]
  [[ "$(<"$TEST_DIR/identity.nix")" == *"secretsValidated = true;"* ]]
  run env PATH="$MOCK_BIN:$PATH" nix-instantiate --parse "$TEST_DIR/identity.nix"
  [ "$status" -eq 0 ]
}

@test "explicit initialization repairs true false and absent secret attestations" {
  local attestation
  for attestation in true false absent; do
    ATTESTATION="$attestation" run_homelab_namespace '
      printf "NEXTAUTH_SECRET=old\\n" > "$ENV_FILE"
      printf "$OPERATOR_NAME\\n" | setpriv --reuid 65534 --regid 65534 --clear-groups "$SCRIPT" --initialize-homelab-secrets --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
      case "$ATTESTATION" in
        true) : ;;
        false) sed -i "s/secretsValidated = true;/secretsValidated = false;/" /etc/nixos/homelab-bootstrap/identity.nix ;;
        absent) sed -i "/secretsValidated = true;/d" /etc/nixos/homelab-bootstrap/identity.nix ;;
      esac
      printf "NEXTAUTH_SECRET=recovered\\n" > "$ENV_FILE"
    ' '
      cp /etc/nixos/homelab-bootstrap/linkwarden.env.age "$TEST_DIR/recovered-$ATTESTATION"
      cp /etc/nixos/homelab-bootstrap/identity.nix "$TEST_DIR/recovered-identity-$ATTESTATION.nix"
      chmod 0644 "$TEST_DIR"/recovered-*
    ' --initialize-homelab-secrets --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    [ "$status" -eq 0 ]
    [ "$(<"$TEST_DIR/recovered-$attestation")" = "NEXTAUTH_SECRET=recovered" ]
    [[ "$(<"$TEST_DIR/recovered-identity-$attestation.nix")" == *"linkwardenSecretFile = ./linkwarden.env.age;"* ]]
    [[ "$(<"$TEST_DIR/recovered-identity-$attestation.nix")" == *"secretsValidated = true;"* ]]
  done
}

@test "subsequent checkout leaves the local ciphertext byte-identical" {
  run_homelab_namespace '
    printf "NEXTAUTH_SECRET=test-secret\\n" > "$ENV_FILE"
    printf "$OPERATOR_NAME\\n" | setpriv --reuid 65534 --regid 65534 --clear-groups "$SCRIPT" --initialize-homelab-secrets --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    sha256sum /etc/nixos/homelab-bootstrap/linkwarden.env.age > "$TEST_DIR/before"
    export GIT_CHECKOUT_REPLACE=1
  ' '
    sha256sum /etc/nixos/homelab-bootstrap/linkwarden.env.age > "$TEST_DIR/after"
    cp /etc/nixos/homelab-bootstrap/linkwarden.env.age "$TEST_DIR/final-ciphertext"
    chmod 0644 "$TEST_DIR"/before "$TEST_DIR"/after "$TEST_DIR"/final-ciphertext
  ' --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
  [ "$status" -eq 0 ]
  [ "$(<"$TEST_DIR/before")" = "$(<"$TEST_DIR/after")" ]
  [ "$(<"$TEST_DIR/final-ciphertext")" = "NEXTAUTH_SECRET=test-secret" ]
  [ "$(<"$WORK_TREE/nixos/secrets/linkwarden.env.age")" = "checkout replacement" ]
}

@test "current wrapper migrates host-decryptable Git ciphertext before checkout" {
  run_homelab_namespace '
    printf "NEXTAUTH_SECRET=old\\n" > "$ENV_FILE"
    printf "$OPERATOR_NAME\\n" | setpriv --reuid 65534 --regid 65534 --clear-groups "$SCRIPT" --initialize-homelab-secrets --linkwarden-env-file "$ENV_FILE" --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    rm /etc/nixos/homelab-bootstrap/linkwarden.env.age
    sed -i "/linkwardenSecretFile =/d; /secretsValidated =/d" /etc/nixos/homelab-bootstrap/identity.nix
    mkdir -p "$WORK_TREE/nixos/secrets"
    chmod 0777 "$WORK_TREE/nixos/secrets"
    printf "  homelab = \\\"$(cat /etc/ssh/ssh_host_ed25519_key.pub)\\\";\\n" > "$WORK_TREE/nixos/secrets/secrets.nix"
    printf "NEXTAUTH_SECRET=migrated\\n" > "$WORK_TREE/nixos/secrets/linkwarden.env.age"
    chmod 0666 "$WORK_TREE/nixos/secrets/secrets.nix" "$WORK_TREE/nixos/secrets/linkwarden.env.age"
    export GIT_CHECKOUT_REPLACE=1
  ' '
    cp /etc/nixos/homelab-bootstrap/linkwarden.env.age "$TEST_DIR/migrated-ciphertext"
    cp /etc/nixos/homelab-bootstrap/identity.nix "$TEST_DIR/migrated-identity.nix"
    chmod 0644 "$TEST_DIR"/migrated-ciphertext "$TEST_DIR"/migrated-identity.nix
  ' --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
  [ "$status" -eq 0 ]
  [ "$(<"$TEST_DIR/migrated-ciphertext")" = "NEXTAUTH_SECRET=migrated" ]
  [[ "$(<"$TEST_DIR/migrated-identity.nix")" == *"linkwardenSecretFile = ./linkwarden.env.age;"* ]]
}

@test "missing or undecryptable old ciphertext refuses checkout without initialization" {
  local failure_mode
  for failure_mode in missing undecryptable; do
    : > "$GIT_LOG"
    FAILURE_MODE="$failure_mode" AGE_FAIL=1 run_homelab_namespace '
      mkdir -p /etc/nixos/homelab-bootstrap "$WORK_TREE/nixos/secrets"
      printf "foreign wrapper\\n" > /etc/nixos/homelab-bootstrap/flake.nix
      printf "{ }\\n" > /etc/nixos/homelab-bootstrap/identity.nix
      printf "persisted\\n" > /etc/nixos/homelab-bootstrap/hardware-configuration.nix
      if [[ "$FAILURE_MODE" == undecryptable ]]; then
        printf "bad\\n" > "$WORK_TREE/nixos/secrets/linkwarden.env.age"
      fi
    ' ':' --git-dir "$GIT_DIR" --work-tree "$WORK_TREE" --hardware-src "$HARDWARE_SRC" --skip-rebuild
    [ "$status" -eq 1 ]
    [[ ! -s "$GIT_LOG" ]]
  done
}
