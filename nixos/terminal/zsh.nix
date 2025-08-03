{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    starship
  ];

   # Oh My ZSH
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = ".config/zsh"; 
    initContent = ''
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
      searchUpKey = "$terminfo[kcuu1]";
      searchDownKey = "$terminfo[kcud1]";
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
          name = pkgs.zsh-vi-mode.pname;
          src = pkgs.zsh-vi-mode.src;
        }
    ];
  };
}
