#!/usr/bin/env bash
# Tests for hooks/session-start
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK="${REPO_ROOT}/hooks/session-start"
PASS=0
FAIL=0

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label — expected to find: $needle"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  FAIL: $label — did not expect to find: $needle"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    fi
}

assert_valid_json() {
    local label="$1" json="$2"
    if command -v jq &>/dev/null; then
        if echo "$json" | jq . &>/dev/null; then
            echo "  PASS: $label (jq)"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: $label — invalid JSON"
            FAIL=$((FAIL + 1))
        fi
    else
        if echo "$json" | grep -q '^{' && echo "$json" | grep -q '}$'; then
            echo "  PASS: $label (basic)"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: $label — not JSON"
            FAIL=$((FAIL + 1))
        fi
    fi
}

echo "=== hooks/session-start tests ==="
echo ""

# Test 1: Happy path
echo "Test 1: Happy path"
OUTPUT=$(bash "$HOOK" 2>/dev/null)
STDERR=$(bash "$HOOK" 2>&1 >/dev/null || true)
assert_valid_json "valid JSON" "$OUTPUT"
assert_contains "mentions /save" "$OUTPUT" "/save"
assert_contains "mentions /github-pr" "$OUTPUT" "github-pr"
assert_contains "mentions /github-ship" "$OUTPUT" "github-ship"
assert_not_contains "no warnings" "$STDERR" "WARNING"

# Test 2: CLAUDE_PLUGIN_ROOT → hookSpecificOutput
echo "Test 2: CLAUDE_PLUGIN_ROOT"
OUTPUT=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null)
assert_contains "hookSpecificOutput key" "$OUTPUT" "hookSpecificOutput"
assert_contains "SessionStart event" "$OUTPUT" "SessionStart"

# Test 3: CURSOR_PLUGIN_ROOT → additional_context
echo "Test 3: CURSOR_PLUGIN_ROOT"
OUTPUT=$(CURSOR_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null)
assert_contains "additional_context key" "$OUTPUT" "additional_context"
assert_not_contains "no hookSpecificOutput" "$OUTPUT" "hookSpecificOutput"

# Test 4: Neither env → fallback
echo "Test 4: No env vars"
OUTPUT=$(unset CLAUDE_PLUGIN_ROOT CURSOR_PLUGIN_ROOT; bash "$HOOK" 2>/dev/null)
assert_contains "fallback additional_context" "$OUTPUT" "additional_context"

# Test 5: Missing SKILL.md → fallback + warning
echo "Test 5: Missing SKILL.md"
TMP=$(mktemp -d)
mkdir -p "$TMP/skills/github-ship" "$TMP/skills/github-pr"
cp "$REPO_ROOT/skills/github-ship/SKILL.md" "$TMP/skills/github-ship/"
cp "$REPO_ROOT/skills/github-pr/SKILL.md" "$TMP/skills/github-pr/"
PATCHED="$TMP/session-start"
sed "s|PLUGIN_ROOT=.*|PLUGIN_ROOT=\"$TMP\"|" "$HOOK" > "$PATCHED"
chmod +x "$PATCHED"
OUTPUT=$(bash "$PATCHED" 2>/dev/null)
STDERR=$(bash "$PATCHED" 2>&1 >/dev/null || true)
assert_valid_json "valid JSON with missing skill" "$OUTPUT"
assert_contains "fallback /save text" "$OUTPUT" "quick commit and push"
assert_contains "stderr warning" "$STDERR" "WARNING"
rm -rf "$TMP"

# Test 6: JSON escaping (description with quotes)
echo "Test 6: JSON escaping"
TMP=$(mktemp -d)
mkdir -p "$TMP/skills/github-ship" "$TMP/skills/github-pr" "$TMP/skills/save"
cat > "$TMP/skills/save/SKILL.md" << 'SKILL_EOF'
---
name: save
description: Quick "save" with back\slash and tab	here
---
SKILL_EOF
cp "$REPO_ROOT/skills/github-ship/SKILL.md" "$TMP/skills/github-ship/"
cp "$REPO_ROOT/skills/github-pr/SKILL.md" "$TMP/skills/github-pr/"
PATCHED="$TMP/session-start"
sed "s|PLUGIN_ROOT=.*|PLUGIN_ROOT=\"$TMP\"|" "$HOOK" > "$PATCHED"
chmod +x "$PATCHED"
OUTPUT=$(bash "$PATCHED" 2>/dev/null)
assert_valid_json "valid JSON with special chars" "$OUTPUT"
rm -rf "$TMP"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
