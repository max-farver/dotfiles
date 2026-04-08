#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-all}"

check() {
  local desc="$1"
  shift
  echo "[CHECK] $desc"
  "$@"
  echo "[PASS]  $desc"
  echo
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

pre_switch_checks() {
  require_cmd nix

  check "Default session is hyprland-uwsm" \
    bash -lc '[ "$(nix eval --raw .#nixosConfigurations.nixos.config.services.displayManager.defaultSession)" = "hyprland-uwsm" ]'

  check "Plasma fallback remains enabled" \
    bash -lc '[ "$(nix eval .#nixosConfigurations.nixos.config.services.desktopManager.plasma6.enable)" = "true" ]'

  check "Upstream ilyamiro input is removed" \
    bash -lc 'nix flake metadata --json | jq -e "(.locks.nodes | has(\"ilyamiro-config\")) | not" >/dev/null'

  check "NixOS config still builds" \
    nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
}

post_login_checks() {
  require_cmd hyprctl
  require_cmd pgrep
  require_cmd gdbus

  check "Running under Hyprland" \
    bash -lc '[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]'

  check "Quickshell Main is running" \
    pgrep -f "quickshell.*Main\\.qml"

  check "Quickshell TopBar is running" \
    pgrep -f "quickshell.*TopBar\\.qml"

  check "swaync is running" \
    pgrep -f "swaync"

  check "swayosd-server is running" \
    pgrep -f "swayosd-server"

  check "hypridle is running" \
    pgrep -x hypridle

  check "swww-daemon is running" \
    pgrep -x swww-daemon

  check "hyprpolkitagent is running" \
    pgrep -f "hyprpolkitagent"

  check "Clipboard watcher is running" \
    pgrep -f "wl-paste --type text --watch cliphist store"

  check "Portal service is available" \
    bash -lc 'gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop >/dev/null'

  check "Core executables exist" \
    bash -lc 'command -v quickshell >/dev/null && command -v rofi >/dev/null && command -v swaync-client >/dev/null && command -v swayosd-client >/dev/null'

  cat <<'EOF'
Manual interactive checks to run now:
  1) SUPER+Return -> Ghostty opens
  2) SUPER+D      -> Rofi app launcher appears
  3) ALT+TAB       -> Rofi window switcher appears
  4) SUPER+A      -> SwayNC control center toggles
  5) Print        -> Screenshot script runs and notifies
  6) SHIFT+Print  -> Screenshot opens editor mode
  7) SUPER+L      -> Quickshell lock screen opens
  8) Volume/Brightness keys show SwayOSD overlays
  9) SUPER+Q / SUPER+W / SUPER+N toggle Quickshell widgets
EOF
}

case "$MODE" in
  pre)
    pre_switch_checks
    ;;
  post)
    post_login_checks
    ;;
  all)
    pre_switch_checks
    echo "---"
    echo "Run 'verify-hyprland-iteration1.sh post' from inside a Hyprland session after switch/reboot."
    ;;
  *)
    fail "Usage: $0 [pre|post|all]"
    ;;
esac
