#!/bin/bash
# test.sh — Unit tests for claude-recent.sh symlink logic
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

# --- Test helpers ---
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_symlink_target() {
  local label="$1" symlink="$2" expected_target="$3"
  if [[ ! -L "$symlink" ]]; then
    echo "  FAIL: $label — symlink does not exist: $symlink"
    ((FAIL++))
    return
  fi
  local actual_target
  actual_target=$(readlink "$symlink")
  assert_eq "$label" "$expected_target" "$actual_target"
}

assert_symlink_resolves() {
  local label="$1" symlink="$2"
  if [[ ! -e "$symlink" ]]; then
    echo "  FAIL: $label — symlink is broken: $symlink"
    ((FAIL++))
    return
  fi
  echo "  PASS: $label"
  ((PASS++))
}

# --- Setup temp environment ---
TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PROJECT_DIR="$TMPDIR_ROOT/myproject"
EXTERNAL_REPO="$TMPDIR_ROOT/other-repo"
EXTERNAL_NO_GIT="$TMPDIR_ROOT/no-git-dir"

mkdir -p "$PROJECT_DIR/src/components"
mkdir -p "$EXTERNAL_REPO/.git"
mkdir -p "$EXTERNAL_REPO/lib/utils"
mkdir -p "$EXTERNAL_NO_GIT/some/deep/path"

echo "hello" > "$PROJECT_DIR/src/components/Button.tsx"
echo "world" > "$EXTERNAL_REPO/lib/utils/helper.kt"
echo "test" > "$EXTERNAL_NO_GIT/some/deep/path/file.txt"

# Temporarily disable auto-open in real config
ORIG_CONFIG=$(cat "$SCRIPT_DIR/config.json")
cat > "$SCRIPT_DIR/config.json" <<CONF
{
  "maxFiles": 100,
  "autoOpen": false,
  "editor": "echo",
  "editorArguments": "",
  "trackReads": false
}
CONF
restore_config() { echo "$ORIG_CONFIG" > "$SCRIPT_DIR/config.json"; }
trap 'rm -rf "$TMPDIR_ROOT"; restore_config' EXIT

# --- Helper to invoke the hook ---
invoke_hook() {
  local tool="$1" file_path="$2" cwd="$3"
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s"},"cwd":"%s"}' \
    "$tool" "$file_path" "$cwd" \
    | bash "$SCRIPT_DIR/claude-recent.sh"
}

# =============================================================================
echo "=== Test 1: In-project file creates relative symlink ==="
invoke_hook "Edit" "$PROJECT_DIR/src/components/Button.tsx" "$PROJECT_DIR"

RECENTS="$PROJECT_DIR/recents"
EXPECTED_NAME="Button.tsx__components__src"
assert_eq "symlink exists" "true" "$([ -L "$RECENTS/$EXPECTED_NAME" ] && echo true || echo false)"
assert_symlink_target "relative target" "$RECENTS/$EXPECTED_NAME" "../src/components/Button.tsx"
assert_symlink_resolves "symlink resolves" "$RECENTS/$EXPECTED_NAME"

# =============================================================================
echo ""
echo "=== Test 2: External file in git repo uses absolute symlink ==="
invoke_hook "Write" "$EXTERNAL_REPO/lib/utils/helper.kt" "$PROJECT_DIR"

EXPECTED_NAME="helper.kt__utils__lib@@other-repo"
assert_eq "external symlink exists" "true" "$([ -L "$RECENTS/$EXPECTED_NAME" ] && echo true || echo false)"
assert_symlink_target "absolute target" "$RECENTS/$EXPECTED_NAME" "$EXTERNAL_REPO/lib/utils/helper.kt"
assert_symlink_resolves "symlink resolves" "$RECENTS/$EXPECTED_NAME"

# =============================================================================
echo ""
echo "=== Test 3: External file with no git repo uses short name ==="
invoke_hook "Edit" "$EXTERNAL_NO_GIT/some/deep/path/file.txt" "$PROJECT_DIR"

EXPECTED_NAME="file.txt__path__deep"
assert_eq "no-git symlink exists" "true" "$([ -L "$RECENTS/$EXPECTED_NAME" ] && echo true || echo false)"
assert_symlink_target "absolute target" "$RECENTS/$EXPECTED_NAME" "$EXTERNAL_NO_GIT/some/deep/path/file.txt"
assert_symlink_resolves "symlink resolves" "$RECENTS/$EXPECTED_NAME"

# =============================================================================
echo ""
echo "=== Test 4: Re-editing refreshes symlink (no duplicates) ==="
invoke_hook "Edit" "$PROJECT_DIR/src/components/Button.tsx" "$PROJECT_DIR"
COUNT=$(find "$RECENTS" -name "Button.tsx*" -type l | wc -l | tr -d ' ')
assert_eq "no duplicate symlinks" "1" "$COUNT"

# =============================================================================
echo ""
echo "=== Test 5: Read events are skipped (trackReads=false) ==="
BEFORE=$(find "$RECENTS" -type l | wc -l | tr -d ' ')
invoke_hook "Read" "$PROJECT_DIR/src/components/Button.tsx" "$PROJECT_DIR"
AFTER=$(find "$RECENTS" -type l | wc -l | tr -d ' ')
assert_eq "read did not add symlink" "$BEFORE" "$AFTER"

# =============================================================================
echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
