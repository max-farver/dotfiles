{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    n8n
    immich
    nextcloud32
  ];
}
