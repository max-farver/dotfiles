{ lib, ... }:
{
  # The machine-local wrapper overrides these defaults with generated hardware data.
  # This fallback exists only so the identity assertion is the direct configuration's
  # activation gate; it must not encode host disk identifiers in the Git worktree.
  fileSystems."/" = {
    device = lib.mkDefault "/dev/root";
    fsType = lib.mkDefault "auto";
  };
}
