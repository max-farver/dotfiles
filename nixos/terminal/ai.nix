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
    claude-code
    opencode
  ];
}
