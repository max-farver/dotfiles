#!/bin/bash
# Registers the personal-workflow plugin with Claude Code

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Remove old symlink if it exists
[ -L "$HOME/.claude/skills" ] && rm "$HOME/.claude/skills"

# Add as marketplace and install
CLAUDECODE= claude plugin marketplace add "$SCRIPT_DIR" --scope user 2>/dev/null
CLAUDECODE= claude plugin install personal-workflow 2>/dev/null

echo "Done. Restart Claude Code to load the plugin."
