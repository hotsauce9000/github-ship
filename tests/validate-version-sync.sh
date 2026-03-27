#!/usr/bin/env bash
# Validate all version references match the canonical VERSION file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PASS=0
FAIL=0

check() {
    local label="$1" result="$2"
    if [ "$result" = "true" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        FAIL=$((FAIL + 1))
    fi
}

CANONICAL="$(cat "$REPO_ROOT/VERSION" | tr -d '[:space:]')"
echo "=== Version sync check (canonical: $CANONICAL) ==="
echo ""

# Each entry: file|jq_expr|pick
# jq_expr used when jq available; grep fallback for portability
FILES=(
    "package.json|.version|first"
    ".claude-plugin/plugin.json|.version|first"
    ".cursor-plugin/plugin.json|.version|first"
    "gemini-extension.json|.version|first"
    ".claude-plugin/marketplace.json|.plugins[0].version|last"
)

for entry in "${FILES[@]}"; do
    IFS='|' read -r file jq_expr pick <<< "$entry"
    full_path="$REPO_ROOT/$file"

    if [ ! -f "$full_path" ]; then
        check "$file exists" "false"
        continue
    fi

    actual=""
    if command -v jq &>/dev/null; then
        actual="$(jq -r "$jq_expr" "$full_path" 2>/dev/null || true)"
    else
        # Fallback: grep for "version" lines
        # Note: "last" pick for marketplace.json grabs nested plugins[0].version
        if [ "$pick" = "last" ]; then
            actual="$(grep -o '"version": *"[^"]*"' "$full_path" | tail -1 | grep -o '[0-9][0-9.]*')"
        else
            actual="$(grep -o '"version": *"[^"]*"' "$full_path" | head -1 | grep -o '[0-9][0-9.]*')"
        fi
    fi

    result="false"
    [ "$actual" = "$CANONICAL" ] && result="true"
    if [ "$result" = "false" ]; then
        echo "  ($file: found '$actual', expected '$CANONICAL')"
    fi
    check "$file version matches VERSION" "$result"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
