{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    lazygit
  ];

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "max-farver";
        email = "maxwell.farver@gmail.com";
      };
      core = {
        excludesFile = "~/.config/git/ignore";
      };
      init = {
        defaultBranch = "main";
      };
    };
    # lfs.enable = true;
  };
}
