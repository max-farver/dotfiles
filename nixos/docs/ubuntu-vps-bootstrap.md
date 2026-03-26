# Ubuntu VPS bootstrap (DigitalOcean)

Use this when your VPS runs Ubuntu and you want to apply the shared Home Manager config from this repo.

## 1) Update username in HM config (important)

File:

- `system-specific/machines/ubuntu-vps/home.nix`

Set `username` to your VPS login user (`ubuntu` on most DO images).

## 2) Choose repo access method

### Option A: SSH (recommended for private repos)

- Ensure VPS has an SSH key: `ls ~/.ssh/id_ed25519.pub`
- If missing: `ssh-keygen -t ed25519 -C "vps-bootstrap"`
- Add the public key to GitHub/GitLab account deploy keys

Repo URL format:

```bash
git@github.com:<you>/<repo>.git
```

### Option B: HTTPS

Repo URL format:

```bash
https://github.com/<you>/<repo>.git
```

For private repos, you’ll need PAT/credential auth when cloning.

## 3) Bootstrap on VPS

Run as your normal sudo user (not root).

### Optional: dry run first (recommended)

This validates install + clone + flake evaluation without applying Home Manager:

```bash
/tmp/bootstrap-ubuntu-vps.sh --dry-run git@github.com:<you>/<repo>.git ~/.config/nixos ubuntu-vps
```

Then do the real apply.

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/<branch>/scripts/bootstrap-ubuntu-vps.sh -o /tmp/bootstrap-ubuntu-vps.sh
chmod +x /tmp/bootstrap-ubuntu-vps.sh
/tmp/bootstrap-ubuntu-vps.sh git@github.com:<you>/<repo>.git ~/.config/nixos ubuntu-vps
```

HTTPS variant:

```bash
/tmp/bootstrap-ubuntu-vps.sh https://github.com/<you>/<repo>.git ~/.config/nixos ubuntu-vps
```

If repo already exists on the VPS:

```bash
~/.config/nixos/scripts/bootstrap-ubuntu-vps.sh "" ~/.config/nixos ubuntu-vps
```

## 4) What this script does

- Installs Nix (if missing)
- Enables flakes (`nix-command flakes`)
- Installs git (if missing)
- Clones/updates your config repo
- Validates flake outputs
- Applies Home Manager profile:

```bash
nix run github:nix-community/home-manager -- switch --flake ~/.config/nixos#ubuntu-vps
```

## 5) Post-checks

```bash
nix --version
home-manager generations
which tailscale || true
which caddy || true
```

## 6) Re-apply after changes

```bash
cd ~/.config/nixos
git pull
nix run github:nix-community/home-manager -- switch --flake .#ubuntu-vps
```
