{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    doctl
  ];
}
