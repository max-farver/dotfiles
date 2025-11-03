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
    docker
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
        theme = "dracula-local";
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
