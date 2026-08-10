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
- `homeConfigurations.pixel-8-pro` — Home Manager-only profile, not a `nixos-rebuild` target.

Validate and build the default Framework output:

```sh
nix flake show ~/.config/nixos --no-write-lock-file
nix build ~/.config/nixos#nixosConfigurations.framework16.config.system.build.toplevel --no-link
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
4. Validate with `nix flake show ~/.config/nixos --no-write-lock-file`.
