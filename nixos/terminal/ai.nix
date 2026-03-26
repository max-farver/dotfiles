{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    nur.repos.charmbracelet.crush
    codex
    dos2unix
    claude-code
    opencode
    inputs.pi-local.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
