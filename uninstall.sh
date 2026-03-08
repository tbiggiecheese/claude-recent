#!/bin/bash
# uninstall.sh — Remove claude-recent hooks from ~/.claude/settings.json and clean up symlinks
set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Uninstalling claude-recent..."

if [[ -f "$SETTINGS_FILE" ]]; then
  # Remove any PostToolUse hook entries that reference claude-recent
  UPDATED=$(jq '
    if .hooks.PostToolUse then
      .hooks.PostToolUse |= map(select(.hooks | all(.command | test("claude-recent") | not)))
    else . end |
    if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
    if .hooks == {} then del(.hooks) else . end
  ' "$SETTINGS_FILE")

  echo "$UPDATED" > "$SETTINGS_FILE"
  echo "Hook removed from $SETTINGS_FILE"
else
  echo "No settings file found at $SETTINGS_FILE"
fi

# Remove claude-recent/ symlink folders from all projects
echo "Searching for claude-recent/ folders..."
FOUND=$(find "$HOME" -name "claude-recent" -type d -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | grep -v "$(cd "$(dirname "$0")" && pwd)" || true)

if [[ -n "$FOUND" ]]; then
  echo "Found:"
  echo "$FOUND"
  read -p "Remove all? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "$FOUND" | xargs rm -rf
    echo "Removed."
  fi
else
  echo "No claude-recent/ folders found."
fi

echo "Done!"
