#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SYSTEM="framework16"
DEFAULT_REPO_URL="https://github.com/max-farver/dotfiles"
DEFAULT_GIT_DIR='${HOME}/.cfg'
DEFAULT_WORK_TREE='${HOME}/.config'

SYSTEM="${DOTFILES_SYSTEM:-$DEFAULT_SYSTEM}"
REPO_URL="${DOTFILES_REPO_URL:-$DEFAULT_REPO_URL}"
GIT_DIR="${DOTFILES_GIT_DIR:-$HOME/.cfg}"
WORK_TREE="${DOTFILES_WORK_TREE:-$HOME/.config}"
DRY_RUN=0
SKIP_REBUILD=0
SKIP_NEOVIM_CHECK=0

usage() {
  cat <<EOF
Usage: scripts/setup-system.sh [--dry-run] [--system NAME] [--repo-url URL] [--git-dir PATH] [--work-tree PATH] [--skip-rebuild] [--skip-neovim-check] [-h|--help]

Post-install bootstrap for this dotfiles repository.

Options:
  --dry-run              Print commands without mutating files or rebuilding.
  --system NAME          NixOS configuration output to apply. Default: $DEFAULT_SYSTEM.
  --repo-url URL         Bare repository clone URL. Default: $DEFAULT_REPO_URL.
  --git-dir PATH         Git metadata directory. Default: $DEFAULT_GIT_DIR.
  --work-tree PATH       Dotfiles work tree. Default: $DEFAULT_WORK_TREE.
  --skip-rebuild         Skip sudo nixos-rebuild switch.
  --skip-neovim-check    Skip the post-rebuild nvim startup check.
  -h, --help             Show this help.

Environment overrides:
  DOTFILES_SYSTEM        Default value for --system. Default: $DEFAULT_SYSTEM.
  DOTFILES_REPO_URL      Default value for --repo-url. Default: $DEFAULT_REPO_URL.
  DOTFILES_GIT_DIR       Default value for --git-dir. Default: $DEFAULT_GIT_DIR.
  DOTFILES_WORK_TREE     Default value for --work-tree. Default: $DEFAULT_WORK_TREE.
EOF
}

die() {
  printf '[!] %s\n' "$*" >&2
  exit 1
}

quote_cmd() {
  local quoted=()
  local arg
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    quoted+=("$arg")
  done
  printf '%s' "${quoted[*]}"
}

run() {
  if (( DRY_RUN )); then
    printf '[dry-run] %s\n' "$(quote_cmd "$@")"
    return 0
  fi

  printf '[+] %s\n' "$(quote_cmd "$@")"
  "$@"
}

need_cmd() {
  local cmd="$1"
  local hint="$2"
  command -v "$cmd" >/dev/null 2>&1 || die "$hint"
}

is_git_dir() {
  local path="$1"
  [[ -f "$path/config" && -d "$path/objects" ]]
}

config_git() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

require_value() {
  local option="$1"
  local value="${2-}"
  [[ -n "$value" ]] || die "$option requires a non-empty value"
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --system)
      require_value "$1" "${2-}"
      SYSTEM="$2"
      shift 2
      ;;
    --repo-url)
      require_value "$1" "${2-}"
      REPO_URL="$2"
      shift 2
      ;;
    --git-dir)
      require_value "$1" "${2-}"
      GIT_DIR="$2"
      shift 2
      ;;
    --work-tree)
      require_value "$1" "${2-}"
      WORK_TREE="$2"
      shift 2
      ;;
    --skip-rebuild)
      SKIP_REBUILD=1
      shift
      ;;
    --skip-neovim-check)
      SKIP_NEOVIM_CHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

NIXOS_FLAKE="$WORK_TREE/nixos"

printf '[i] System: %s\n' "$SYSTEM"
printf '[i] Repository URL: %s\n' "$REPO_URL"
printf '[i] Git dir: %s\n' "$GIT_DIR"
printf '[i] Work tree: %s\n' "$WORK_TREE"

if ! command -v git >/dev/null 2>&1; then
  if command -v nix >/dev/null 2>&1; then
    run nix profile install nixpkgs#git
  else
    die "Install git first or run from a NixOS environment with nix available."
  fi
fi

if ! is_git_dir "$GIT_DIR"; then
  if (( DRY_RUN )); then
    run git clone --bare "$REPO_URL" "$GIT_DIR"
  else
    if [[ -e "$GIT_DIR" ]]; then
      if [[ -d "$GIT_DIR" ]] && [[ -z "$(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        :
      else
        die "Git dir exists but is not recognized as bare Git metadata: $GIT_DIR"
      fi
    fi
    run git clone --bare "$REPO_URL" "$GIT_DIR"
  fi
fi

run git --git-dir="$GIT_DIR" config status.showUntrackedFiles no
run mkdir -p "$WORK_TREE"
run git --git-dir="$GIT_DIR" fetch --all --prune

if (( DRY_RUN )); then
  run git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" checkout main -- .
elif ! config_git checkout main -- .; then
  printf '[!] Move or back up the conflicting file, then rerun the script.\n' >&2
  exit 1
fi

need_cmd nix "nix is required; run this from NixOS or install Nix before using this bootstrap script."

if [[ -f "$NIXOS_FLAKE/flake.nix" ]]; then
  run nix flake show --no-write-lock-file "$NIXOS_FLAKE"
  run nix eval --raw "$NIXOS_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
elif (( DRY_RUN )); then
  run nix flake show --no-write-lock-file "$NIXOS_FLAKE"
  run nix eval --raw "$NIXOS_FLAKE#nixosConfigurations.$SYSTEM.config.networking.hostName"
  printf '[i] Skipping flake validation because dry-run did not check out %s\n' "$NIXOS_FLAKE"
else
  die "Missing NixOS flake at $NIXOS_FLAKE/flake.nix after checkout"
fi

if (( SKIP_REBUILD )); then
  printf '[i] Skipping nixos-rebuild\n'
elif (( DRY_RUN )); then
  run sudo nixos-rebuild switch --flake "$NIXOS_FLAKE#$SYSTEM"
else
  run sudo nixos-rebuild switch --flake "$NIXOS_FLAKE#$SYSTEM"
fi

if (( ! SKIP_NEOVIM_CHECK )); then
  if (( DRY_RUN )); then
    run nvim --headless '+q'
  else
    command -v nvim >/dev/null 2>&1 || die "nvim not found after rebuild; confirm nixos/terminal/neovim.nix is imported by the selected home.nix"
    run nvim --headless '+q'
  fi
fi

printf '[+] Done\n'
