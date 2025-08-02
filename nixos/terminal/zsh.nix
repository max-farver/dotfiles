{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    starship
  ];

   # Oh My ZSH
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initContent = lib.mkOrder 1200 ''
    source ~/.config/zsh-helpers/.zshrc
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
