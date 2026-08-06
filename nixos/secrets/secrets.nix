let
  # Workflow for workstation secrets only:
  # 1) Add or replace workstation keys below.
  # 2) Create or edit a workstation secret from `secrets/`: agenix -e <name>.age
  # 3) Rekey workstation secrets after key changes: agenix -r
  # 4) Apply the relevant workstation configuration with nixos-rebuild.

  mfarver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhwd1Jc8J4Kf3EzV39VZzHeiSSP7iU87vwfec4ebV1f mfarver@nixos";
  framework16Attic = "age1tnjq3784t53gxjt8gtyjwa7duturq9850ewgz0hppwn90736tycqdthc2n";

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

}
