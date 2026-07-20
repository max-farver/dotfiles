let
  # Workflow:
  # 1) Add/replace host keys below.
  # 2) Create or edit a secret from `secrets/`: agenix -e <name>.age
  # 3) Rekey all secrets after key changes: agenix -r
  # 4) Apply config: sudo nixos-rebuild switch --flake .#homelab

  mfarver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhwd1Jc8J4Kf3EzV39VZzHeiSSP7iU87vwfec4ebV1f mfarver@nixos";
  framework16Attic = "age1tnjq3784t53gxjt8gtyjwa7duturq9850ewgz0hppwn90736tycqdthc2n";

  # Clean homelab bootstrap replaces this with `/etc/ssh/ssh_host_ed25519_key.pub`.
  # Homelab-only secrets are initialized fresh on the host, not rekeyed from mfarver.
  homelab = mfarver;
in
{
  "framework16.age".publicKeys = [
    mfarver
    framework16Attic
  ];

  "framework16-paseo.env.age".publicKeys = [
    mfarver
    framework16Attic
  ];

  "homelab-tailscale-auth.age".publicKeys = [
    homelab
  ];

  "linkwarden.env.age".publicKeys = [
    homelab
  ];
}
