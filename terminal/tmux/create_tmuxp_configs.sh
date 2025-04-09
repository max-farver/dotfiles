#!/bin/bash

for DIR in $1; do
	reponame=$(basename "$DIR")
	if [ -f "$HOME/.tmux/tmuxp/$reponame" ]; then
		continue
	fi
	cat >"$HOME/.tmux/tmuxp/$reponame.yaml" <<EOF
session_name: $reponame
start_directory: ~/Documents/repos/$reponame
windows:
  - window_name: nvim
    panes:
      - shell_command:
          - nvim
  - window_name: git
    panes:
      - lg
  - window_name: terminal
    panes:
      - terminal
EOF
done
