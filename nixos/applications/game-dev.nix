{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    android-studio
    androidenv.androidPkgs.emulator
    androidenv.androidPkgs.platform-tools
    godot
  ];
}
