# Dotfiles

## Layout

- `nixos/` — NixOS flake, Home Manager modules, machine-specific configs.
- `nvim/` — Neovim 0.12+ config using built-in `vim.pack`; plugin details live in `nvim/README.md`.
- `zsh/` — zsh base config, scripts, and extensions; the `config` command lives in `zsh/extensions/.zshrc.base`.
- `ghostty/`, `lazygit/`, `git/`, `starship.toml`, `claude/` — supporting application config.

## Git workflow

This repository uses a bare Git checkout:

- Work tree: `$HOME/.config`
- Git metadata: `$HOME/.cfg`

The active shell alias is:

```zsh
alias config="git --git-dir=$HOME/.cfg/ --work-tree=$HOME/.config";
```

Common commands:

```sh
config status
config add nixos/ nvim/ zsh/
config commit -m "Update config"
config push
```

Untracked files are hidden with `status.showUntrackedFiles no`, matching `~/.cfg/config` and keeping local application state out of routine `config status` output.

## NixOS systems

- `framework16` — default Framework laptop system; imports `nixos/system-specific/machines/framework16/configuration.nix` and `home.nix`.
- `nixos` — compatibility target for the legacy/default rebuild path, using the Framework system with the legacy hostname `nixos`.
- `homelab` — standalone x86_64 server/desktop target with Plasma, XRDP, OpenSSH, loopback-only Glance, Firefox, and system Neovim.
- `homeConfigurations.pixel-8-pro` — Home Manager-only profile, not a `nixos-rebuild` target.

Validate and build the default Framework output:

```sh
nix flake show ~/.config/nixos --no-write-lock-file
nix build ~/.config/nixos#nixosConfigurations.framework16.config.system.build.toplevel --no-link
```


### Fresh homelab installation

Boot the current x86_64 NixOS graphical installer in UEFI mode and run the graphical installer to completion. Select KDE Plasma, create the login name `mfarver` with administrator/sudo access and a password, set the hostname to `homelab`, and use the installer’s normal disk and boot choices. Leave encryption, partition sizing, and disk selection to the graphical installer UI.

Reboot into the installed system and sign into Plasma. The graphical installer is the source of truth for the initial account, password, disk layout, bootloader, and `/etc/nixos/hardware-configuration.nix`.

Confirm networking works and open Konsole. The following preserves the installer-created Plasma configuration as a timestamped sibling while installing the complete configured work tree at the established `$HOME/.config` location. Any failure stops the procedure before rebuilding.

```sh
test ! -e "$HOME/.cfg" || { echo "$HOME/.cfg already exists" >&2; exit 1; }
git clone --bare https://github.com/max-farver/dotfiles "$HOME/.cfg"

backup="$HOME/.config.installer-backup-$(date +%Y%m%d-%H%M%S)"
test ! -e "$backup" || { echo "$backup already exists" >&2; exit 1; }
mv "$HOME/.config" "$backup"
mkdir -p "$HOME/.config"

git --git-dir="$HOME/.cfg" --work-tree="$HOME/.config" checkout main
git --git-dir="$HOME/.cfg" config status.showUntrackedFiles no
test -f "$HOME/.config/nixos/flake.nix" || exit 1
```

`/etc/nixos/hardware-configuration.nix` from the completed GUI install is the sole source of truth. Copy it byte-for-byte over the repository placeholder because the flake imports the repository file. Do not regenerate, merge, normalize, or manually rewrite the generated module: the checked-in `REPLACE-ROOT-UUID`/`REPLACE-BOOT-UUID` template is deliberately non-activatable.

```sh
hardware="$HOME/.config/nixos/system-specific/machines/homelab/hardware-configuration.nix"
sudo install -Dm644 /etc/nixos/hardware-configuration.nix "$hardware"
sudo chown mfarver:users "$hardware"

cmp -s /etc/nixos/hardware-configuration.nix "$hardware" || {
  echo "repository hardware configuration differs from the GUI-generated file" >&2
  exit 1
}

if grep -Eq 'REPLACE-(ROOT|BOOT)-UUID' "$hardware"; then
  echo "hardware configuration still contains placeholder UUIDs" >&2
  exit 1
fi

sudo nixos-rebuild switch --flake "$HOME/.config/nixos#homelab"
reboot
```

If the first rebuild specifically reports that `nix-command` or `flakes` is disabled, replace only the rebuild line with `sudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild switch --flake "$HOME/.config/nixos#homelab"`; `nixos/system-specific/x86_64-linux/server.nix` enables both features in the activated system. Reboot only after a successful switch, then sign back into Plasma. Do not use the Framework-only rebuild aliases from `nixos/terminal/zsh.nix`, and do not run the Attic bootstrap as part of installation.

After rebooting and signing back in, run:

```sh
test "$(hostname)" = homelab
readlink -e /run/current-system >/dev/null
! grep -Eq 'REPLACE-(ROOT|BOOT)-UUID' \
  "$HOME/.config/nixos/system-specific/machines/homelab/hardware-configuration.nix"
test "$EDITOR" = nvim
test "$VISUAL" = nvim
command -v nvim
command -v firefox
nvim --headless '+lua assert(vim.fn.stdpath("config") == "/home/mfarver/.config/nvim")' +qa
systemctl is-active sshd glance xrdp xrdp-sesman display-manager
curl -fsS http://127.0.0.1:8080/ >/dev/null
```

Glance is loopback-only, XRDP is not firewall-exposed, and TCP 22 is the sole exposed port.


## Neovim

Neovim is installed by Home Manager through `nixos/terminal/neovim.nix`, which is imported by `nixos/terminal/default.nix` and therefore by the Framework home config.

Check setup with:

```sh
nvim --headless '+q'
```

See `nvim/README.md` for plugin management and `:PackUpdate`.

## Adding a new NixOS machine

1. Add `nixos/system-specific/machines/<name>/configuration.nix`.
2. For desktop or Home Manager-managed hosts, add `nixos/system-specific/machines/<name>/home.nix`.
3. For desktop or Home Manager-managed hosts, add an entry in `nixos/flake.nix` under `nixosConfigurations` using `mkNixosSystem` with `modules = [ ./system-specific/machines/<name>/configuration.nix ];` and `homeModule = ./system-specific/machines/<name>/home.nix;`.
4. Validate with `nix flake show ~/.config/nixos --no-write-lock-file`.
