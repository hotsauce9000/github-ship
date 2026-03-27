#!/usr/bin/env bash
# Cross-skill consistency validation between github-pr and github-ship
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PASS=0
FAIL=0

PR_SKILL="${REPO_ROOT}/skills/github-pr/SKILL.md"
SHIP_SKILL="${REPO_ROOT}/skills/github-ship/SKILL.md"

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

# ─── Section 1: Grouping threshold ───────────────────────────────────────────

echo "=== Section 1: Grouping threshold ==="

pr_threshold=$(grep -oE '[0-9]+\+ files across' "$PR_SKILL" | head -1)
ship_threshold=$(grep -oE '[0-9]+\+ files across' "$SHIP_SKILL" | head -1)

result="false"
[ -n "$pr_threshold" ] && [ "$pr_threshold" = "$ship_threshold" ] && result="true"
echo "  github-pr:   '$pr_threshold'"
echo "  github-ship: '$ship_threshold'"
check "grouping thresholds match" "$result"

# ─── Section 2: Commit types ─────────────────────────────────────────────────

echo ""
echo "=== Section 2: Commit types ==="

pr_types=$(grep -oE '`(feat|fix|refactor|docs|test|chore)`' "$PR_SKILL" | sort -u | tr '\n' ' ' | sed 's/ $//')
ship_types=$(grep -oE '`(feat|fix|refactor|docs|test|chore)`' "$SHIP_SKILL" | sort -u | tr '\n' ' ' | sed 's/ $//')

result="false"
[ -n "$pr_types" ] && [ "$pr_types" = "$ship_types" ] && result="true"
echo "  github-pr:   '$pr_types'"
echo "  github-ship: '$ship_types'"
check "commit types match" "$result"

# ─── Section 3: Platform detection ───────────────────────────────────────────

echo ""
echo "=== Section 3: Platform detection ==="

for term in "github.com" "gitlab" "gh auth status" "glab auth status"; do
    pr_has="false"
    ship_has="false"
    grep -qF "$term" "$PR_SKILL" 2>/dev/null && pr_has="true"
    grep -qF "$term" "$SHIP_SKILL" 2>/dev/null && ship_has="true"
    result="false"
    [ "$pr_has" = "true" ] && [ "$ship_has" = "true" ] && result="true"
    check "both skills reference '$term'" "$result"
done

# ─── Section 4: Language order ───────────────────────────────────────────────

echo ""
echo "=== Section 4: Language order (first 8 entries) ==="

pr_langs=$(grep -E '^[0-9]+\. (Python|Node|Rust|Go|Ruby|PHP|Java)' "$PR_SKILL" | head -8 | sed 's/:.*//' | tr '\n' '|')
ship_langs=$(grep -E '^[0-9]+\. (Python|Node|Rust|Go|Ruby|PHP|Java)' "$SHIP_SKILL" | head -8 | sed 's/:.*//' | tr '\n' '|')

result="false"
[ -n "$pr_langs" ] && [ "$pr_langs" = "$ship_langs" ] && result="true"
echo "  github-pr:   '$pr_langs'"
echo "  github-ship: '$ship_langs'"
check "language detection order matches (first 8)" "$result"

# ─── Section 5: Preamble — Upgrade Flow ──────────────────────────────────────

echo ""
echo "=== Section 5: Preamble Upgrade Flow ==="

pr_has_uf="false"
ship_has_uf="false"
grep -q "Upgrade Flow" "$PR_SKILL" 2>/dev/null && pr_has_uf="true"
grep -q "Upgrade Flow" "$SHIP_SKILL" 2>/dev/null && ship_has_uf="true"

check "github-pr has 'Upgrade Flow'" "$pr_has_uf"
check "github-ship has 'Upgrade Flow'" "$ship_has_uf"

result="false"
[ "$pr_has_uf" = "true" ] && [ "$ship_has_uf" = "true" ] && result="true"
check "both skills have 'Upgrade Flow'" "$result"

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
