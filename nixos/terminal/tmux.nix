{
  config,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    gum
  ];

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
      # Use Ctrl-b so physical Super+b works with the Voyager keyd swap.
      set -g prefix C-b
      bind C-b send-prefix

      set -g status-position top
      set -g extended-keys on
      set -g extended-keys-format csi-u

      # Open lazygit in a popup rooted at the active pane's working directory.
      bind g display-popup -E -w 90% -h 90% -d '#{pane_current_path}' lazygit


      # Session switcher popup (Prefix+s).
      bind s display-popup -E -w 90% -h 90% -d '#{pane_current_path}' "sh -c 'selected=\$(tmux list-sessions -F \"#{session_name}\" | gum filter --fuzzy --limit 1 --header \"Switch to session\"); [ -n \"\$selected\" ] && tmux switch-client -t \"\$selected\"'"
      # Bulk session delete popup (Prefix+S); never deletes current session.
      bind S display-popup -E -w 90% -h 90% -d '#{pane_current_path}' "sh -c 'client=\"#{client_tty}\"; current=\"#{session_name}\"; selected=\$(tmux list-sessions -F \"#{session_name}\" | gum filter --fuzzy --no-limit --header \"Delete sessions\"); [ -z \"\$selected\" ] && exit 0; skipped_current=0; if printf \"%s\\n\" \"\$selected\" | grep -Fxq \"\$current\"; then skipped_current=1; fi; printf \"%s\\n\" \"\$selected\" | while IFS= read -r session; do [ -z \"\$session\" ] && continue; [ \"\$session\" = \"\$current\" ] && continue; tmux kill-session -t \"\$session\"; done; if [ \"\$skipped_current\" -eq 1 ]; then tmux display-message -c \"\$client\" \"Deleted selected sessions; skipped current session: \$current\"; else tmux display-message -c \"\$client\" \"Deleted selected sessions\"; fi'"
      # Create a new session via existing tmuxsess workflow (Prefix+n).
      bind n display-popup -E -w 90% -h 90% -d '#{pane_current_path}' "${pkgs.zsh}/bin/zsh -ic 'tmuxsess'"
      unbind r
      bind r source-file ${config.xdg.configHome}/tmux/tmux.conf \; display-message "tmux config reloaded"
    '';
  };

}
