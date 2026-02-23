{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    gh
    lazygit
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "max.farver";
        email = "maxwell.farver@gmail.com";
      };
      core = {
        excludesFile = "~/.config/git/ignore";
      };
    };
    # defaultBranch = "main";
    # lfs.enable = true;
  };
}
