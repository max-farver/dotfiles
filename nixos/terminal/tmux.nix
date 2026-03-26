{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 0;
    keyMode = "vi";
    focusEvents = true;
    mouse = true;
    terminal = "tmux-256color";
    shell = "${pkgs.zsh}/bin/zsh";
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.vim-tmux-navigator;
        extraConfig = ''
          set -g @vim_navigator_mapping_left "C-Left C-h"  # use C-h and C-Left
          set -g @vim_navigator_mapping_right "C-Right C-l"
          set -g @vim_navigator_mapping_up "C-Up C-k"
          set -g @vim_navigator_mapping_down "C-Down C-j"
        '';
      }
      {
        plugin = pkgs.tmuxPlugins.dracula;
        extraConfig = ''
          set -g @dracula-plugins "time"
          set -g @dracula-show-powerline true
          set -g @dracula-show-flags true
          set -g @dracula-border-contrast true
          set -g @dracula-show-left-icon session
        '';
      }
    ];
    extraConfig = ''
      set -g status-position top
      set -g extended-keys on
      set -g extended-keys-format csi-u

      unbind r
      bind r source-file ${config.xdg.configHome}/tmux/tmux.conf \; display-message "tmux config reloaded"
    '';
  };

}
