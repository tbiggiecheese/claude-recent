#!/bin/bash
# install.sh — Install claude-recent hooks into ~/.claude/settings.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/claude-recent.sh"
CONFIG_FILE="$SCRIPT_DIR/config.json"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Installing claude-recent..."

# Make the hook script executable
chmod +x "$SCRIPT_PATH"

# Create ~/.claude if it doesn't exist
mkdir -p "$HOME/.claude"

# Create settings.json if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if hooks are already installed
if jq -e '.hooks.PostToolUse[]? | select(.hooks[]?.command | test("claude-recent"))' "$SETTINGS_FILE" &>/dev/null; then
  echo "Hook already installed in $SETTINGS_FILE"
  echo "Done!"
  exit 0
fi

# Add the PostToolUse hook using jq
UPDATED=$(jq --arg cmd "$SCRIPT_PATH" '
  .hooks //= {} |
  .hooks.PostToolUse //= [] |
  .hooks.PostToolUse += [
    {
      "matcher": "Edit|Write|Read",
      "hooks": [
        {
          "type": "command",
          "command": $cmd
        }
      ]
    }
  ]
' "$SETTINGS_FILE")

echo "$UPDATED" > "$SETTINGS_FILE"

echo "Hook installed in $SETTINGS_FILE"
echo ""
echo "Configuration: $CONFIG_FILE"
echo "  - autoOpen: true (opens files in your editor)"
echo "  - editor: code (change to 'cursor', 'idea', etc.)"
echo "  - editorArguments: --reuse-window (prevents new windows/focus stealing)"
echo "  - maxFiles: 100 symlinks in recents/"
echo "  - trackReads: false (set to true to also track file reads)"
echo ""
echo "Edit $CONFIG_FILE to customize."
echo ""
echo "Done! Start a Claude Code session and edited files will appear in recents/"
