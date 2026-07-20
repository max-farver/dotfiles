let
  # Workflow:
  # 1) Add/replace host keys below.
  # 2) Create or edit a secret from `secrets/`: agenix -e <name>.age
  # 3) Rekey all secrets after key changes: agenix -r
  # 4) Apply config: sudo nixos-rebuild switch --flake .#homelab

  mfarver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhwd1Jc8J4Kf3EzV39VZzHeiSSP7iU87vwfec4ebV1f mfarver@nixos";
  framework16Attic = "age1tnjq3784t53gxjt8gtyjwa7duturq9850ewgz0hppwn90736tycqdthc2n";
  doServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOL4ugtjT3hEg/UJ2N2EAL45XI9aoSoNv9c+Duvb237W root@do-server";

  # TODO: replace with homelab host `/etc/ssh/ssh_host_ed25519_key.pub` and run `agenix -r`.
  # Bootstrap keeps the secret reachable via the operator key until host key is enrolled.
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

  "do-server-tailscale-auth.age".publicKeys = [
    mfarver
    doServer
  ];

  "homelab-tailscale-auth.age".publicKeys = [
    mfarver
    homelab
  ];

  "linkwarden.env.age".publicKeys = [
    mfarver
    doServer
    homelab
  ];
}
