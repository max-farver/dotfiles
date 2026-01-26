{
  pkgs,
  ...
}:

let
  ghostty = pkgs.ghostty.overrideAttrs (_: {
    preBuild = ''
      shopt -s globstar
      sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
      shopt -u globstar
    '';
  });
in
{
  imports = [
    ./ai.nix
    ./git.nix
    ./neovim.nix
    ./tmux.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    csvlens
    nur.repos.charmbracelet.freeze
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
  ];

  programs = {
    ghostty = {
      enable = true;
      settings = {
        theme = "dark:dracula-local,light:alucard-local";
      };
      themes = {
        dracula-local = {
          background = "#282a36";
          foreground = "#f8f8f2";
          cursor-color = "#f8f8f2";
          cursor-text = "#282a36";
          selection-foreground = "#f8f8f2";
          selection-background = "#44475a";
          palette = [
            "0=#21222c"
            "1=#ff5555"
            "2=#50fa7b"
            "3=#f1fa8c"
            "4=#bd93f9"
            "5=#ff79c6"
            "6=#8be9fd"
            "7=#f8f8f2"
            "8=#6272a4"
            "9=#ff6e6e"
            "10=#69ff94"
            "11=#ffffa5"
            "12=#d6acff"
            "13=#ff92df"
            "14=#a4ffff"
            "15=#ffffff"
          ];
        };
        alucard-local = {
          background = "#fffbeb";
          foreground = "#1f1f1f";
          cursor-color = "#1f1f1f";
          cursor-text = "#fffbeb";
          selection-foreground = "#1f1f1f";
          selection-background = "#CFCFDE";
          palette = [
            "0=#fffbeb"
            "1=#cb3a2a"
            "2=#14710a"
            "3=#846e15"
            "4=#644ac9"
            "5=#a3144d"
            "6=#036a96"
            "7=#1f1f1f"
            "8=#6C664B"
            "9=#D74C3D"
            "10=#198D0C"
            "11=#9E841A"
            "12=#7862D0"
            "13=#BF185A"
            "14=#047FB4"
            "15=#2C2B31"
          ];
        };

      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

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

    bash.enable = true; # see note on other shells below
  };
}
