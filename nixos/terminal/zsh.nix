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
      export NH_FLAKE="${config.xdg.configHome}/nixos#framework16"
      local_zsh_base="${config.xdg.configHome}/zsh/extensions/.zshrc.base"
      [[ -r "$local_zsh_base" ]] && source "$local_zsh_base"
    '';

    shellAliases = {
      rebuild_switch = "sudo nixos-rebuild switch --flake ~/.config/nixos#framework16";
      rebuild_boot = "sudo nixos-rebuild boot --flake ~/.config/nixos#framework16";
      update_oh_my_pi = "~/.config/nixos/scripts/update-oh-my-pi.sh";
      update_oh_my_pi_rebuild = "~/.config/nixos/scripts/update-oh-my-pi.sh && rebuild_switch";
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
