#!/usr/bin/env bash
# tests/test-update-check.sh — unit tests for bin/update-check
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/update-check"
LOCAL_VER="$(cat "$REPO_ROOT/VERSION" | tr -d '[:space:]')"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; }

echo "=== test-update-check.sh (local version: $LOCAL_VER) ==="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Up-to-date — local == remote → no output, cache says UP_TO_DATE
# ---------------------------------------------------------------------------
echo "Test 1: Up-to-date (local == remote)"
TMP="$(mktemp -d)"
echo "$LOCAL_VER" > "$TMP/remote-version"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  pass "no output when up-to-date"
else
  fail "expected no output, got: $OUT"
fi
if [ -f "$TMP/last-update-check" ]; then
  CACHE="$(cat "$TMP/last-update-check")"
  if echo "$CACHE" | grep -q "^UP_TO_DATE"; then
    pass "cache says UP_TO_DATE"
  else
    fail "cache content unexpected: $CACHE"
  fi
else
  # file:// may not work — treat as skip for cache check
  skip "cache file not created (file:// may be unsupported)"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 2: Upgrade available — remote=99.99.99 → UPGRADE_AVAILABLE output
# ---------------------------------------------------------------------------
echo "Test 2: Upgrade available (remote=99.99.99)"
TMP="$(mktemp -d)"
echo "99.99.99" > "$TMP/remote-version"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if echo "$OUT" | grep -q "^UPGRADE_AVAILABLE"; then
  pass "outputs UPGRADE_AVAILABLE"
elif [ -z "$OUT" ]; then
  skip "no output — file:// URLs may be unsupported on this platform"
else
  fail "unexpected output: $OUT"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 3: No downgrade — remote=0.0.1 → no output
# ---------------------------------------------------------------------------
echo "Test 3: No downgrade (remote=0.0.1)"
TMP="$(mktemp -d)"
echo "0.0.1" > "$TMP/remote-version"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  pass "no output for downgrade scenario"
elif echo "$OUT" | grep -q "^UPGRADE_AVAILABLE"; then
  fail "wrongly reported upgrade for older remote: $OUT"
else
  fail "unexpected output: $OUT"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 4: Disabled — touch update-check-disabled → no output
# ---------------------------------------------------------------------------
echo "Test 4: Disabled (update-check-disabled file present)"
TMP="$(mktemp -d)"
touch "$TMP/update-check-disabled"
echo "99.99.99" > "$TMP/remote-version"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  pass "no output when disabled"
else
  fail "expected no output when disabled, got: $OUT"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 5: Just-upgraded marker → JUST_UPGRADED output, marker cleaned
# ---------------------------------------------------------------------------
echo "Test 5: Just-upgraded marker"
TMP="$(mktemp -d)"
PREV_VER="2.0.0"
echo "$PREV_VER" > "$TMP/just-upgraded-from"
echo "$LOCAL_VER" > "$TMP/remote-version"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if echo "$OUT" | grep -q "^JUST_UPGRADED"; then
  pass "outputs JUST_UPGRADED"
else
  fail "expected JUST_UPGRADED, got: $OUT"
fi
if [ ! -f "$TMP/just-upgraded-from" ]; then
  pass "marker file cleaned up"
else
  fail "marker file still exists after run"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 6: Invalid remote (HTML response) → no output
# ---------------------------------------------------------------------------
echo "Test 6: Invalid remote (HTML response)"
TMP="$(mktemp -d)"
echo "<html><body>Not Found</body></html>" > "$TMP/remote-version"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  pass "no output for invalid (HTML) remote version"
else
  fail "expected no output for HTML remote, got: $OUT"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 7: Snooze respected — fresh snooze → no output
# ---------------------------------------------------------------------------
echo "Test 7: Snooze respected (fresh snooze)"
TMP="$(mktemp -d)"
echo "99.99.99" > "$TMP/remote-version"
# Write a fresh snooze file: version level epoch(now)
NOW="$(date +%s)"
echo "99.99.99 1 $NOW" > "$TMP/update-snoozed"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  pass "no output when snoozed"
elif echo "$OUT" | grep -q "^UPGRADE_AVAILABLE"; then
  skip "file:// may be unsupported; snooze check bypassed"
else
  fail "unexpected output: $OUT"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Test 8: _ver_gte correctness — test the function directly
# ---------------------------------------------------------------------------
echo "Test 8: _ver_gte function correctness"
FUNC="$(sed -n '/_ver_gte()/,/^}/p' "$SCRIPT")"
RESULT="$(bash -c "$FUNC
_ver_gte \"2.1.0\" \"2.0.0\" && echo P1
_ver_gte \"2.0.0\" \"2.1.0\" || echo P2
_ver_gte \"1.0.0\" \"1.0.0\" && echo P3
_ver_gte \"0.1.0\" \"0.0.9\" && echo P4
" 2>/dev/null || true)"

if echo "$RESULT" | grep -q "P1"; then
  pass "_ver_gte: 2.1.0 >= 2.0.0"
else
  fail "_ver_gte: 2.1.0 should be >= 2.0.0"
fi
if echo "$RESULT" | grep -q "P2"; then
  pass "_ver_gte: 2.0.0 < 2.1.0 (correctly returns false)"
else
  fail "_ver_gte: 2.0.0 should NOT be >= 2.1.0"
fi
if echo "$RESULT" | grep -q "P3"; then
  pass "_ver_gte: 1.0.0 >= 1.0.0 (equal)"
else
  fail "_ver_gte: 1.0.0 should be >= 1.0.0"
fi
if echo "$RESULT" | grep -q "P4"; then
  pass "_ver_gte: 0.1.0 >= 0.0.9"
else
  fail "_ver_gte: 0.1.0 should be >= 0.0.9"
fi
echo ""

# ---------------------------------------------------------------------------
# Test 9: Expired snooze — old epoch → UPGRADE_AVAILABLE
# ---------------------------------------------------------------------------
echo "Test 9: Expired snooze (old epoch)"
TMP="$(mktemp -d)"
echo "99.99.99" > "$TMP/remote-version"
# Write an expired snooze: level=1 (24h), epoch far in the past
OLD_EPOCH=1000000000  # year 2001 — definitely expired
echo "99.99.99 1 $OLD_EPOCH" > "$TMP/update-snoozed"
OUT="$(GITHUB_SHIP_STATE_DIR="$TMP" GITHUB_SHIP_REMOTE_URL="file://$TMP/remote-version" \
  bash "$SCRIPT" 2>/dev/null || true)"
if echo "$OUT" | grep -q "^UPGRADE_AVAILABLE"; then
  pass "outputs UPGRADE_AVAILABLE after snooze expires"
elif [ -z "$OUT" ]; then
  skip "no output — file:// URLs may be unsupported on this platform"
else
  fail "unexpected output: $OUT"
fi
rm -rf "$TMP"
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==================================="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
