{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    starship
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = "${config.xdg.configHome}/zsh";
    initContent = lib.mkOrder 550 ''
      export NH_FLAKE="${config.xdg.configHome}/nixos"
      source ${config.xdg.configHome}/zsh/extensions/.zshrc.base
    '';

    shellAliases = {
      rebuild_switch = "sudo nixos-rebuild switch --flake ~/.config/nixos";
      rebuild_boot = "sudo nixos-rebuild boot --flake ~/.config/nixos";
      update_pi = "nix flake update pi-mono --flake ~/.config/nixos/pkgs/pi";
      update_pi_rebuild = "nix flake update pi-mono --flake ~/.config/nixos/pkgs/pi && rebuild_switch";
    };
    autosuggestion = {
      enable = true;
    };
    # historySubstringSearch = {
    #   enable = true;
    #   searchUpKey = [
    #     "$terminfo[kcuu1]"
    #     "^[[A"
    #   ];
    #   searchDownKey = [
    #     "$terminfo[kcud1]"
    #     "^[[B"
    #   ];
    # };
    syntaxHighlighting = {
      enable = true;
    };
    plugins = [
      {
        name = pkgs.zsh-fzf-tab.pname;
        src = pkgs.zsh-fzf-tab.src;
      }
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];
  };
}
