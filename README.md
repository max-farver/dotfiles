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

Boot a current NixOS installer in UEFI mode. Complete this flow from its terminal as `nixos`; do not complete the graphical installer. The disk-selection and format commands below are destructive.

#### Select and partition the installation disk

First, list physical disks and identify the target by its model, serial number, and size. Do not select the installer USB or any disk with data to retain. Prefer a stable `/dev/disk/by-id/` path over `/dev/sdX` or `/dev/nvmeXnY` names.

```sh
lsblk --paths -d -o NAME,SIZE,MODEL,SERIAL,TRAN,TYPE

# Set this only after visually matching the intended physical disk.
export DISK=/dev/disk/by-id/<unique-physical-disk-id>
test -b "$DISK"
lsblk --paths -o NAME,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS "$DISK"
wipefs -n "$DISK"
```

Confirm that `$DISK` is the intended whole physical disk and that none of its partitions are mounted. Create a GPT with a 1 GiB EFI System Partition and an ext4 root partition:

```sh
parted --script "$DISK" -- \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart root ext4 1025MiB 100%
partprobe "$DISK"

export BOOT_PART="${DISK}-part1"
export ROOT_PART="${DISK}-part2"
export OPERATOR_PUBLIC_KEY=/path/to/mfarver.pub
test -b "$BOOT_PART"
test -b "$ROOT_PART"


mkfs.fat -F 32 "$BOOT_PART"
mkfs.ext4 -L nixos "$ROOT_PART"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

nixos-generate-config --root /mnt

mkdir -p /mnt/home/mfarver
git clone --bare https://github.com/max-farver/dotfiles /mnt/home/mfarver/.cfg
git --git-dir=/mnt/home/mfarver/.cfg --work-tree=/mnt/home/mfarver/.config checkout main

# The generated file contains this machine's real filesystem UUIDs. It must
# replace the repository's non-activatable bootstrap template before install.
install -Dm644 /mnt/etc/nixos/hardware-configuration.nix \
  /mnt/home/mfarver/.config/nixos/system-specific/machines/homelab/hardware-configuration.nix
install -Dm644 "$OPERATOR_PUBLIC_KEY" /mnt/root/mfarver.pub

nixos-install --root /mnt \
  --flake /mnt/home/mfarver/.config/nixos#homelab
```

Create the operator account before rebooting. Homelab disables SSH password and keyboard-interactive authentication, so install the public key now instead of weakening SSH policy:

```sh
nixos-enter --root /mnt
useradd --create-home --groups wheel mfarver
passwd mfarver
install -d -m 700 -o mfarver -g users /home/mfarver/.ssh
install -m 600 -o mfarver -g users /root/mfarver.pub /home/mfarver/.ssh/authorized_keys
rm /root/mfarver.pub
chown -R mfarver:users /home/mfarver/.cfg /home/mfarver/.config
exit
reboot
```

After signing in as `mfarver`, validate the installed host and its Neovim configuration:

```sh
test "$EDITOR" = nvim
test "$VISUAL" = nvim
command -v nvim
command -v firefox
nvim --headless '+lua assert(vim.fn.stdpath("config") == "/home/mfarver/.config/nvim")' +qa
systemctl is-active sshd glance xrdp xrdp-sesman display-manager
curl -fsS http://127.0.0.1:8080/ >/dev/null
```

Glance listens only on `127.0.0.1:8080`, and XRDP is intentionally not firewall-exposed. Use the local Plasma session to open Glance in Firefox; TCP 22 is the only exposed port.


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
