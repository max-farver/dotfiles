#!/bin/bash
# Registers the personal-workflow plugin with Claude Code

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR"
PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
SETTINGS_FILE="$HOME/.claude/settings.json"
PLUGIN_KEY="personal-workflow@local"

# Remove old symlink if it exists
[ -L "$HOME/.claude/skills" ] && rm "$HOME/.claude/skills"

# Register plugin in installed_plugins.json
if [ -f "$PLUGINS_FILE" ]; then
  python3 -c "
import json, sys
with open('$PLUGINS_FILE') as f:
    data = json.load(f)
key = '$PLUGIN_KEY'
if key not in data['plugins']:
    data['plugins'][key] = [{
        'scope': 'user',
        'installPath': '$PLUGIN_DIR',
        'version': '0.1.0'
    }]
    with open('$PLUGINS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('Registered plugin in installed_plugins.json')
else:
    # Update install path in case dotfiles moved
    data['plugins'][key][0]['installPath'] = '$PLUGIN_DIR'
    with open('$PLUGINS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('Updated plugin path in installed_plugins.json')
"
else
  echo "Error: $PLUGINS_FILE not found. Is Claude Code installed?"
  exit 1
fi

# Enable plugin in settings.json
if [ -f "$SETTINGS_FILE" ]; then
  python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
if 'enabledPlugins' not in data:
    data['enabledPlugins'] = {}
if '$PLUGIN_KEY' not in data['enabledPlugins'] or not data['enabledPlugins']['$PLUGIN_KEY']:
    data['enabledPlugins']['$PLUGIN_KEY'] = True
    with open('$SETTINGS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('Enabled plugin in settings.json')
else:
    print('Plugin already enabled in settings.json')
"
fi

echo "Done. Restart Claude Code to load the plugin."
