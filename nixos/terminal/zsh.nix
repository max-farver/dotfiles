{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    starship
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = ".config/zsh"; 
    initExtra = lib.mkOrder 550 ''
    source ~/.config/zsh/extensions/.zshrc.base
    '';
    
    shellAliases = {
      rebuild_switch = "sudo nixos-rebuild switch --flake ~/.config/nixos";
      rebuild_boot = "sudo nixos-rebuild boot --flake ~/.config/nixos";
    };
    autosuggestion = {
      enable = true;
    };
    historySubstringSearch = {
      enable = true;
      searchUpKey = [
        "$terminfo[kcuu1]"
        "^[[A"
      ];
      searchDownKey = [
        "$terminfo[kcud1]"
        "^[[B"
      ];
    };
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
