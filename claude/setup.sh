#!/bin/bash
# Sets up Claude Code skill imports in ~/.claude/CLAUDE.md

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

mkdir -p "$HOME/.claude"

# Build the skills import block
IMPORT_BLOCK="# Skills
# Managed by dotfiles — do not edit this section manually"
for skill in "$SKILLS_DIR"/*.md; do
  IMPORT_BLOCK="$IMPORT_BLOCK
@import $skill"
done
IMPORT_BLOCK="$IMPORT_BLOCK
# End skills"

# If CLAUDE.md exists, replace existing skills block or append
if [ -f "$CLAUDE_MD" ]; then
  if grep -q "# Skills" "$CLAUDE_MD" && grep -q "# End skills" "$CLAUDE_MD"; then
    # Replace existing block
    tmp=$(mktemp)
    awk '/^# Skills/{skip=1} /^# End skills/{skip=0; next} !skip' "$CLAUDE_MD" > "$tmp"
    echo "$IMPORT_BLOCK" | cat - "$tmp" > "$CLAUDE_MD"
    rm "$tmp"
  else
    # Append to existing file
    printf "\n%s\n" "$IMPORT_BLOCK" >> "$CLAUDE_MD"
  fi
else
  echo "$IMPORT_BLOCK" > "$CLAUDE_MD"
fi

echo "Claude skills linked from $SKILLS_DIR"
echo "Imports written to $CLAUDE_MD"
