#!/usr/bin/env bash
# Structural validation of all 3 SKILL.md files
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

check_file_contains() {
    local label="$1" file="$2" pattern="$3"
    local result="false"
    grep -qE "$pattern" "$file" 2>/dev/null && result="true"
    check "$label" "$result"
}

check_file_not_contains() {
    local label="$1" file="$2" pattern="$3"
    local result="true"
    grep -qE "$pattern" "$file" 2>/dev/null && result="false"
    check "$label" "$result"
}

check_yaml_frontmatter() {
    local skill_name="$1" file="$2"
    echo "  [YAML frontmatter]"

    # Starts with ---
    local first_line
    first_line=$(head -1 "$file")
    local result="false"
    [ "$first_line" = "---" ] && result="true"
    check "$skill_name: starts with ---" "$result"

    # Has 2+ --- markers
    local marker_count
    marker_count=$(grep -c '^---$' "$file" 2>/dev/null || true)
    result="false"
    [ "$marker_count" -ge 2 ] && result="true"
    check "$skill_name: has 2+ --- markers" "$result"

    # name: field exists
    check_file_contains "$skill_name: has 'name:' field" "$file" '^name:'

    # description: field exists
    check_file_contains "$skill_name: has 'description:' field" "$file" '^description:'
}

check_sections() {
    local skill_name="$1" file="$2"
    echo "  [Required sections]"

    check_file_contains "$skill_name: has '## Preamble'" "$file" '^## Preamble'
    check_file_contains "$skill_name: has '### Upgrade Flow'" "$file" '^### Upgrade Flow'
    check_file_contains "$skill_name: has '## Workflow'" "$file" '^## Workflow'
    check_file_contains "$skill_name: has '## Important Rules'" "$file" '^## Important Rules'
}

check_commit_template() {
    local skill_name="$1" file="$2"
    echo "  [Commit template]"

    check_file_contains "$skill_name: Co-Authored-By in commit template" "$file" 'Co-Authored-By:'
}

check_safe_staging() {
    local skill_name="$1" file="$2"
    echo "  [Safe staging rule]"

    check_file_contains "$skill_name: has 'Never.*git add' safe staging rule" "$file" '[Nn]ever.*git add'
}

check_error_handling() {
    local skill_name="$1" file="$2"
    echo "  [Error Handling section]"

    check_file_contains "$skill_name: has '## Error Handling'" "$file" '^## Error Handling'
}

# ─── All 3 skills ────────────────────────────────────────────────────────────

SKILLS=(
    "skills/save/SKILL.md"
    "skills/github-pr/SKILL.md"
    "skills/github-ship/SKILL.md"
)

for skill in "${SKILLS[@]}"; do
    skill_file="${REPO_ROOT}/${skill}"
    skill_name="$(basename "$(dirname "$skill_file")")"

    echo ""
    echo "=== $skill_name ==="

    if [ ! -f "$skill_file" ]; then
        echo "  FAIL: $skill_name SKILL.md not found at $skill_file"
        FAIL=$((FAIL + 1))
        continue
    fi

    check_yaml_frontmatter "$skill_name" "$skill_file"
    check_sections "$skill_name" "$skill_file"
    check_commit_template "$skill_name" "$skill_file"
    check_safe_staging "$skill_name" "$skill_file"
done

# ─── github-pr and github-ship only: Error Handling ─────────────────────────

echo ""
echo "=== Error Handling (github-pr + github-ship only) ==="

for skill in "skills/github-pr/SKILL.md" "skills/github-ship/SKILL.md"; do
    skill_file="${REPO_ROOT}/${skill}"
    skill_name="$(basename "$(dirname "$skill_file")")"
    if [ -f "$skill_file" ]; then
        check_error_handling "$skill_name" "$skill_file"
    else
        echo "  FAIL: $skill_name SKILL.md not found"
        FAIL=$((FAIL + 1))
    fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
