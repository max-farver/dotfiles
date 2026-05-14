# Homelab NixOS migration runbook

## Scope
This runbook provisions the `homelab` host defined by `.#homelab` and validates the migrated services (tailscale, glance, beszel, linkwarden) plus KDE + XRDP.

## Prereqs
- Repo is up to date and includes `nixosConfigurations.homelab`.
- Physical target machine has NixOS installed and can run `nixos-rebuild`.
- Tailscale auth key for this host is available.
- You can decrypt `secrets/*.age` locally (agenix set up).

## Scripted setup (recommended on homelab host)
Run the helper script to automate hardware sync, host-key output, optional switch, and checks:

```bash
./scripts/bootstrap-homelab.sh --switch --checks
```

Dry-run preview:

```bash
./scripts/bootstrap-homelab.sh --switch --checks --dry-run
```

What remains manual after script output:
- replace bootstrap `homelab = mfarver;` in `secrets/secrets.nix` with the real host key
- run `cd secrets && agenix -r`

## 1) Generate host hardware config on the target host
On `homelab`, regenerate and replace the placeholder hardware file:

```bash
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
```

Copy that content into:
- `system-specific/machines/homelab/hardware-configuration.nix`

## 2) Enroll homelab host SSH key in agenix recipients
Collect host key from `homelab`:

```bash
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

Update `secrets/secrets.nix`:
- replace bootstrap `homelab = mfarver;` with the real host public key

Rekey secrets:

```bash
cd secrets
agenix -r
```

## 3) Set homelab Tailscale auth secret
Edit `secrets/homelab-tailscale-auth.age` with a valid auth key (or reusable key) and ensure recipients include `mfarver` + `homelab`.

```bash
cd secrets
agenix -e homelab-tailscale-auth.age
```

## 4) Build and switch to homelab config
From repo root:

```bash
sudo nixos-rebuild switch --flake .#homelab
```

## 5) Service health checks

```bash
systemctl status sshd
systemctl status tailscaled
systemctl status tailscale-services
systemctl status xrdp
systemctl status xrdp-sesman
systemctl status glance
systemctl status beszel-hub
systemctl status beszel-agent
systemctl status linkwarden
```

## 6) Connectivity and exposure checks
From another tailnet node:

```bash
tailscale ping homelab
```

On homelab:

```bash
sudo ss -tulpn
sudo nft list ruleset
```

Expected:
- SSH hardening remains enabled (no password auth, root prohibit-password).
- Services bind loopback or are exposed through Tailscale Serve.
- No unintended WAN-facing service ports.

## 7) XRDP -> KDE validation
From another tailnet device:
- connect RDP client to `homelab` over tailnet address/name
- log in with a local user
- confirm KDE Plasma session starts

If session fails, inspect:

```bash
journalctl -u xrdp -u xrdp-sesman -b
```
