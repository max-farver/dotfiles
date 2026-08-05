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

### Copy-and-run homelab bootstrap

Run this **as the existing local administrator**, never with `sudo`. It downloads the bootstrap script to `/tmp`, stages the homelab wrapper, builds it without activating it, then requires an explicit `INSTALL` acknowledgement before registering the result for the next boot. It does not replace the current generation.

```sh
set -euo pipefail

bootstrap=/tmp/setup-system.sh
curl -fsSL https://raw.githubusercontent.com/max-farver/dotfiles/main/scripts/setup-system.sh -o "$bootstrap"
chmod 0755 "$bootstrap"

"$bootstrap" \
  --system homelab \
  --sync-hardware \
  --initialize-homelab-secrets \
  --skip-neovim-check

sudo cat /etc/nixos/homelab-bootstrap/identity.nix
sudo cat /etc/nixos/homelab-bootstrap/hardware-configuration.nix

read -r -p 'Type INSTALL to register the reviewed homelab generation for the next boot: ' install
if [ "$install" = INSTALL ]; then
  sudo nixos-rebuild boot --no-write-lock-file --flake /etc/nixos/homelab-bootstrap#homelab --option experimental-features "nix-command flakes"
fi
```

The script derives a candidate from the invoking account's numeric UID, validates its NSS record, home directory ownership, and `sudo` access, then requires you to type the detected username. It writes the confirmed identity and generated hardware configuration to root-owned `/etc/nixos/homelab-bootstrap/`; neither is stored in or overwritten by the Git work tree. `--initialize-homelab-secrets` encrypts the initial Linkwarden secret to the generated host key before first boot. The first boot starts the Beszel Hub but deliberately leaves the agent disabled. Subsequent runs verify the persisted identity and refuse to adopt a different account automatically. After `INSTALL`, reboot from the physical console and retain the prior systemd-boot generation as the rollback path.

Before staging, the script rejects an origin mismatch, a non-concrete generated root filesystem, an unusable local unlock password, or unverified Linkwarden secret provisioning. It also preserves the verified host-recipient secret artifacts across later repository checkouts, so Beszel enrollment cannot revert them.

After that first boot, enroll Tailscale from the physical console and restart the endpoint-provisioning unit:

```sh
sudo tailscale up --advertise-tags=tag:server
sudo systemctl restart tailscale-services
```

### Enroll the Beszel agent after first boot

After the Hub is reachable, open its **Add System** flow and copy the public key it displays. Run this as the same local administrator; it changes only the agent key in the root-owned identity file, stages a build, and does not activate it:

```sh
~/.config/scripts/setup-system.sh \
  --system homelab \
  --beszel-agent-key "$(cat /path/to/key-copied-from-beszel-hub.pub)"

sudo nixos-rebuild boot --no-write-lock-file --flake /etc/nixos/homelab-bootstrap#homelab --option experimental-features "nix-command flakes"
```

Reboot from the physical console to start the agent. Do not pass `--sync-hardware` while enrolling the agent.

### Homelab recovery

If a staged generation cannot authenticate the original local user or loses network access, boot the previous systemd-boot generation from the physical console. Do not run the homelab target from a root recovery shell or manually create a replacement user. Return to the known-good local account, inspect the generated wrapper, correct its inputs, and stage a new boot generation instead. The setup script intentionally rejects root invocation and cannot replace the confirmed machine-local identity on later runs.

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
