# claude-recent


https://github.com/user-attachments/assets/70f16526-59e3-443b-9d4c-f2a5983e2f70

Track every file Claude Code touches. Auto-open edited files in your editor and browse recent files via symlinks in your IDE's file tree.

Works with any file editor: VS Code, Cursor, Android Studio, IntelliJ, Sublime, etc.

## Setup

### Requirements

**macOS:**
```bash
brew install jq
```

### Install

```bash
git clone <this-repo>
cd claude-recent
./install.sh
```

This adds a `PostToolUse` hook to `~/.claude/settings.json` that fires on every `Edit`, `Write`, and `Read`.

### Configuration

Edit `config.json` in the claude-recent directory:

```json
{
  ## Max symlinks to keep in claude-recent/
  "maxFiles": 100,
  ## Open edited files in your editor automatically
  "autoOpen": true,
  ## Editor CLI command (code, cursor, idea, subl, etc.)
  "editor": "code",
  ## Arguments passed between the editor command and the file path
  "editorArguments": "--reuse-window",
  ## Also track files Claude reads, not just writes/edits
  "trackReads": false
}
```

### Uninstall

```bash
./uninstall.sh
```

This removes the hook from `~/.claude/settings.json` and offers to clean up `claude-recent/` folders from your projects.

## Gitignore

The hook automatically adds `claude-recent/` to your project's `.gitignore` on first run. If you don't have a `.gitignore`, add one or create it manually.
