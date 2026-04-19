let
  # Workflow:
  # 1) Replace placeholder keys below.
  # 2) Create or edit a secret from `secrets/`: agenix -e <name>.age
  # 3) Rekey all secrets after key changes: agenix -r
  # 4) Apply config: sudo nixos-rebuild switch --flake .#nixos

  # Current recipient set: user key only (host key not available in this environment).
  # You can add framework16 host key later once `/etc/ssh/ssh_host_ed25519_key.pub` exists.
  mfarver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhwd1Jc8J4Kf3EzV39VZzHeiSSP7iU87vwfec4ebV1f mfarver@nixos";
in
{
  # Example mapping used by the agenix CLI from the `secrets/` directory:
  # cd secrets && agenix -e framework16.age
  "framework16.age".publicKeys = [
    mfarver
  ];
}
