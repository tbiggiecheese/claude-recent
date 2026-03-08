#!/bin/bash
# claude-recent.sh — Track files Claude touches, maintain symlink folder, optionally auto-open in editor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
LOG_FILE="$SCRIPT_DIR/recent-files.log"

# Defaults
MAX_FILES=100
AUTO_OPEN=true
EDITOR_CMD="code"
EDITOR_ARGS="--reuse-window"
TRACK_READS=false

# Load config if it exists
if [[ -f "$CONFIG_FILE" ]]; then
  MAX_FILES=$(jq -r '.maxFiles // 100' "$CONFIG_FILE")
  AUTO_OPEN=$(jq -r '.autoOpen // true' "$CONFIG_FILE")
  EDITOR_CMD=$(jq -r '.editor // "code"' "$CONFIG_FILE")
  EDITOR_ARGS=$(jq -r '.editorArguments // "--reuse-window"' "$CONFIG_FILE")
  TRACK_READS=$(jq -r '.trackReads // false' "$CONFIG_FILE")
fi

# Read hook input from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

# Fall back to CLAUDE_PROJECT_DIR env var
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Skip reads unless configured
if [[ "$TOOL_NAME" == "Read" && "$TRACK_READS" != "true" ]]; then
  exit 0
fi

# Resolve to absolute path if relative
if [[ "$FILE_PATH" != /* ]]; then
  FILE_PATH="$PROJECT_DIR/$FILE_PATH"
fi

# Skip if file doesn't exist (e.g. failed write)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Compute relative path from project dir
REL_PATH="${FILE_PATH#"$PROJECT_DIR"/}"

# If the file is outside the project dir, use absolute path encoding
if [[ "$REL_PATH" == "$FILE_PATH" ]]; then
  REL_PATH="${FILE_PATH#/}"
fi

# --- Log to recent-files.log ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$TIMESTAMP $TOOL_NAME $FILE_PATH" >> "$LOG_FILE"

# Trim log to last 1000 lines
if [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
  tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# --- Manage symlink folder ---
RECENT_DIR="$PROJECT_DIR/claude-recent"
mkdir -p "$RECENT_DIR"

# Add to .gitignore if not already there
GITIGNORE="$PROJECT_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q '^claude-recent' "$GITIGNORE" 2>/dev/null; then
    echo 'claude-recent/' >> "$GITIGNORE"
  fi
fi

# Build symlink name: src/components/Button.tsx -> src__components__Button.tsx
SYMLINK_NAME=$(echo "$REL_PATH" | sed 's|/|__|g')

# Compute relative target from claude-recent/ to the actual file
SYMLINK_TARGET="../$REL_PATH"

# Remove existing symlink for this file (if re-edited, we want to refresh its timestamp)
if [[ -L "$RECENT_DIR/$SYMLINK_NAME" ]]; then
  rm "$RECENT_DIR/$SYMLINK_NAME"
fi

# Create symlink
ln -s "$SYMLINK_TARGET" "$RECENT_DIR/$SYMLINK_NAME"

# Prune: remove oldest symlinks if over max
SYMLINK_COUNT=$(find "$RECENT_DIR" -maxdepth 1 -type l | wc -l | tr -d ' ')
if [[ "$SYMLINK_COUNT" -gt "$MAX_FILES" ]]; then
  REMOVE_COUNT=$((SYMLINK_COUNT - MAX_FILES))
  # Sort by modification time (oldest first), remove extras
  find "$RECENT_DIR" -maxdepth 1 -type l -print0 | \
    xargs -0 ls -1t | \
    tail -n "$REMOVE_COUNT" | \
    xargs rm -f
fi

# --- Auto-open in editor ---
if [[ "$AUTO_OPEN" == "true" ]]; then
  # Run editor in background, don't let it block the hook
  $EDITOR_CMD $EDITOR_ARGS "$FILE_PATH" &>/dev/null &
fi

exit 0
