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

## Bootstrap a NixOS machine

Fresh-machine bootstrap path:

```sh
curl -fsSL https://raw.githubusercontent.com/max-farver/dotfiles/main/scripts/setup-system.sh -o /tmp/setup-system.sh
chmod +x /tmp/setup-system.sh
/tmp/setup-system.sh --dry-run
/tmp/setup-system.sh
```

The script assumes NixOS is already installed or the command is running from an environment that provides `nix`. It does not partition disks, generate hardware configs, or run the NixOS installer.

The default NixOS system is `framework16`.

After the first checkout, rerun locally with:

```sh
~/.config/scripts/setup-system.sh --system framework16
```

For the physical homelab server, use the same setup script with the server-specific bootstrap actions:

```sh
~/.config/scripts/setup-system.sh --system homelab --sync-hardware --print-host-key --enroll-host-key --checks --skip-neovim-check
```

`--enroll-host-key` replaces `homelab = mfarver;` in `~/.config/nixos/secrets/secrets.nix` with the host `/etc/ssh/ssh_host_ed25519_key.pub`, switches the homelab agenix identity path to `/etc/ssh/ssh_host_ed25519_key`, and runs `agenix -r`. Rekeying still requires access to an existing private key that can decrypt the current secrets; if `agenix` is not installed, the setup script falls back to `nix run github:ryantm/agenix -- -r`.

The script is stored at repository root `scripts/setup-system.sh`, so it appears at `~/.config/scripts/setup-system.sh` after checkout because the work tree is `$HOME/.config`.

## NixOS systems

- `framework16` — default Framework laptop system; imports `nixos/system-specific/machines/framework16/configuration.nix` and `home.nix`.
- `nixos` — compatibility target for the legacy/default rebuild path, using the Framework system with the legacy hostname `nixos`.
- `homelab` — physical home server system from `nixos/system-specific/machines/homelab/configuration.nix`.
- `homeConfigurations.pixel-8-pro` — Home Manager-only profile, not a `nixos-rebuild` target.

Validate and build the default Framework output:

```sh
nix flake show ~/.config/nixos --no-write-lock-file
nix build ~/.config/nixos#nixosConfigurations.framework16.config.system.build.toplevel --no-link
```

Validate the homelab hostname output:

```sh
nix eval --raw ~/.config/nixos#nixosConfigurations.homelab.config.networking.hostName
# homelab
```

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
4. For server hosts without a Home Manager module, copy the existing `homelab` flake pattern: `nixpkgs.lib.nixosSystem` with `agenix.nixosModules.default`.
5. Validate with `nix flake show ~/.config/nixos --no-write-lock-file`.
6. Apply with `~/.config/scripts/setup-system.sh --system <name>`.
