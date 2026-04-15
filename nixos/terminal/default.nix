{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./ai.nix
    ./git.nix
    ./litellm.nix
    ./neovim.nix
    ./tmux.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    csvlens
    freeze
    pandoc
    posting
    postgresql
    sqlite

    gnumake

    bat
    btop
    fd
    lsof
    jq
    ripgrep
    playwright-test
    inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs = {
    ghostty.enable = true;

    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "/home/mfarver/.config/nixos"; # sets NH_OS_FLAKE variable for you
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        keymap_mode = "auto";
        keymap_cursor = {
          emacs = "blink-block";
          vim_insert = "blink-block";
          vim_normal = "steady-block";
        };
      };
    };

    fzf = {
      enable = true;
      enableZshIntegration = false;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # zoxide = {
    #   enable = true;
    #   enableZshIntegration = true;
    # };

    bash.enable = true; # see note on other shells below
  };

}
