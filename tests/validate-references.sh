#!/usr/bin/env bash
# Path integrity + drift sync check for SKILL.md reference files
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

# ─── Section 1: Referenced files exist ───────────────────────────────────────

echo "=== Section 1: Referenced files exist ==="

SKILLS_WITH_REFS=(
    "skills/github-pr/SKILL.md"
    "skills/github-ship/SKILL.md"
)

for skill in "${SKILLS_WITH_REFS[@]}"; do
    skill_file="${REPO_ROOT}/${skill}"
    skill_dir="$(dirname "$skill_file")"
    skill_name="$(basename "$skill_dir")"

    echo ""
    echo "  [$skill_name]"

    if [ ! -f "$skill_file" ]; then
        echo "  FAIL: $skill_name SKILL.md not found"
        FAIL=$((FAIL + 1))
        continue
    fi

    while read -r ref; do
        ref_path="${skill_dir}/${ref}"
        result="false"
        [ -f "$ref_path" ] && result="true"
        check "$skill_name/$ref exists" "$result"
    done < <(grep -oE 'references/[a-z0-9_-]+\.md' "${skill_file}" | sort -u)
done

# ─── Section 2: No cross-skill refs ──────────────────────────────────────────

echo ""
echo "=== Section 2: No cross-skill refs ==="

cross_refs=$(grep -r '\.\./github-ship/references' "${REPO_ROOT}/skills/" 2>/dev/null || true)
result="true"
[ -n "$cross_refs" ] && result="false"
check "no cross-skill references (../github-ship/references)" "$result"

cross_refs2=$(grep -r '\.\./github-pr/references' "${REPO_ROOT}/skills/" 2>/dev/null || true)
result="true"
[ -n "$cross_refs2" ] && result="false"
check "no cross-skill references (../github-pr/references)" "$result"

# ─── Section 3: No orphan files ──────────────────────────────────────────────

echo ""
echo "=== Section 3: No orphan files ==="

SKILLS_WITH_REF_DIRS=(
    "skills/github-pr/SKILL.md"
    "skills/github-ship/SKILL.md"
)

for skill in "${SKILLS_WITH_REF_DIRS[@]}"; do
    skill_file="${REPO_ROOT}/${skill}"
    skill_dir="$(dirname "$skill_file")"
    skill_name="$(basename "$skill_dir")"
    ref_dir="${skill_dir}/references"

    echo ""
    echo "  [$skill_name]"

    if [ ! -d "$ref_dir" ]; then
        echo "  PASS: $skill_name has no references/ dir (nothing to orphan)"
        PASS=$((PASS + 1))
        continue
    fi

    while read -r ref_file; do
        bn="$(basename "$ref_file")"
        rel_ref="references/${bn}"
        result="false"
        grep -qF "$rel_ref" "$skill_file" 2>/dev/null && result="true"
        check "$skill_name/$rel_ref is referenced by SKILL.md" "$result"
    done < <(find "$ref_dir" -maxdepth 1 -name "*.md" | sort)
done

# ─── Section 4: Duplicated refs in sync ──────────────────────────────────────

echo ""
echo "=== Section 4: Duplicated refs in sync (github-ship == github-pr) ==="

ship_refs_dir="${REPO_ROOT}/skills/github-ship/references"

if [ ! -d "$ship_refs_dir" ]; then
    echo "  SKIP: github-ship/references/ not found"
else
    found_any="false"
    for f in "${ship_refs_dir}"/gitignore-*.md; do
        [ -f "$f" ] || continue
        found_any="true"
        bn="$(basename "$f")"
        pr_copy="${REPO_ROOT}/skills/github-pr/references/$bn"
        if [ -f "$pr_copy" ]; then
            synced="false"
            diff -q "$f" "$pr_copy" &>/dev/null && synced="true"
            check "github-ship/$bn == github-pr/$bn" "$synced"
        else
            echo "  FAIL: github-pr/references/$bn does not exist (no copy to compare)"
            FAIL=$((FAIL + 1))
        fi
    done
    if [ "$found_any" = "false" ]; then
        echo "  SKIP: no gitignore-*.md files found in github-ship/references/"
    fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
