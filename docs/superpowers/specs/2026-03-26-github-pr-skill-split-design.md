# Design Spec: github-ship v2.0 — PR/Ship Skill Split

**Date:** 2026-03-26
**Status:** Draft
**Version:** 2.0.0 (breaking: structural split)

---

## Problem

github-ship v1.x conflates two distinct workflows into one 12-step skill:

1. **Team workflow** — commit to a feature branch, open a PR for review, get feedback, iterate
2. **Solo workflow** — commit, version bump, changelog, tag, push, cut a GitHub release

Users on teams are forced through version bump / changelog / tag / release steps they don't need. Solo developers have no way to create PRs when they want review. The skill name "github-ship" doesn't suggest PR creation, so trigger phrases like "open a PR" don't activate it.

## Solution

Split into two independent skills sharing one repo:

- **`/github-pr`** — team PR workflow (new)
- **`/github-ship`** — solo release workflow (refactored)

Both skills share the same reference files (gitignore guides, semver guide) and adopt proven patterns from gstack's `/ship` skill (platform detection, base branch detection, verification gate, test failure triage).

## Why

- The workflows diverge fundamentally after the commit step — trying to unify them creates branching logic that's harder for the AI to follow reliably
- Two focused SKILL.md files (~200-300 lines each) are more maintainable than one 500+ line file with conditionals
- Separate trigger phrases (`"open a PR"` vs `"ship it"`) map naturally to separate skills
- Users install one repo, get both commands — no extra setup

---

## Repo Structure

```
github-ship/
  skills/
    github-ship/
      SKILL.md              # solo release workflow (refactored)
      references/            # shared — both skills read from here
        gitignore-general.md
        gitignore-python.md
        gitignore-node.md
        gitignore-rust.md
        gitignore-go.md
        gitignore-ruby.md
        gitignore-php.md
        gitignore-java.md
        semver-guide.md
    github-pr/
      SKILL.md              # team PR workflow (new)
      references/
        pr-templates.md     # PR body templates (Problem/Solution/Why/Test plan)
  hooks/
    hooks.json              # SessionStart registers BOTH skills
    session-start           # bash script
    run-hook.cmd            # Windows wrapper
    hooks-cursor.json       # Cursor-specific
  .claude-plugin/           # Claude Code plugin (updated for both skills)
  .codex/                   # Codex support (updated)
  .cursor-plugin/           # Cursor support (updated)
  gemini-extension.json     # Gemini CLI (updated)
  README.md                 # rewritten for both workflows
  CHANGELOG.md
  VERSION                   # 2.0.0
  LICENSE
  package.json
```

**Key decisions:**
- References stay under `skills/github-ship/references/` — `github-pr/SKILL.md` references them via relative path `../github-ship/references/` (no file duplication)
- `pr-templates.md` is new — provides the PR body structure
- SessionStart hook advertises both `/github-ship` and `/github-pr`
- Plugin metadata updated to register both skills

---

## `/github-pr` Workflow (New)

### Trigger Phrases
`"open a PR"`, `"create a PR"`, `"submit for review"`, `"push this for review"`, `"github pr"`, or `/github-pr`

### SKILL.md Frontmatter
```yaml
name: github-pr
description: Team PR workflow. Handles branch management, pre-flight checks, .gitignore audit, tests, diff review, committing, pushing, and creating pull requests with structured descriptions. Trigger phrases include "open a PR", "create a PR", "submit for review", "push for review", "github pr", or any request to create a pull request for team review.
```

### Steps

#### Step 0a: Mode Selection
Same pattern as github-ship: auto-pilot (recommended) vs interactive.

#### Step 0: Environment Check
Same as github-ship: git repo check, remote check, auth check.

**New: Platform detection** (adopted from gstack)
- Check remote URL for `github.com` or `gitlab`
- Fall back to CLI detection: `gh auth status` or `glab auth status`
- Store platform for use in push and PR creation steps

#### Step 1: Pre-Flight
Same as github-ship: git status, branch check, remote check.

**New: Base branch detection** (adopted from gstack)
1. `gh pr view --json baseRefName -q .baseRefName` (existing PR)
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (repo default)
3. Git fallback: `git symbolic-ref refs/remotes/origin/HEAD`
4. Final fallback: `main`

#### Step 2: Branch Check (NEW)
- If on main/master/default branch: **[CONFIRM]** — create a feature branch?
  - Yes (Recommended) — auto-generate branch name from recent commits (`feat/add-auth-middleware`)
  - Let me name it — user provides branch name
  - No, stay on main — continue (warn that this is unusual for a PR)
- If on a feature branch: continue
- Set upstream tracking if not set: `git push -u origin <branch>`

#### Step 3: .gitignore Audit
Same as github-ship: language detection, reference check, secrets scan.

#### Step 4: Run Tests
Same as github-ship: auto-detect test runner, run suite.

**New: Test failure triage** (adopted from gstack)
- If tests fail, classify each failure:
  - **In-branch**: test file or code-under-test was modified on this branch → STOP, must fix
  - **Pre-existing**: neither test file nor tested code was modified → warn, offer to continue
- When ambiguous, default to in-branch (safer)

#### Step 4b: Bug Scan (UBS)
Same as github-ship: run UBS if available, skip silently if not.

#### Step 5: Diff Review
Same as github-ship: `git diff`, summarize changes, categorize.

**[CONFIRM]**: proceed with commit, edit first, or abort.

#### Step 6: Commit
Same as github-ship: specific file staging (never `git add .`), conventional commit message.

**New: Bisectable commits option** (adopted from gstack, simplified)
- If diff touches 4+ files across 2+ logical concerns:
  - **[CONFIRM]**: "This is a multi-concern change. Split into logical commits?"
    - Yes (Recommended) — split by concern (infra first, then models, then views)
    - No, single commit — one commit with everything
- If diff is small (< 4 files or single concern): single commit, no prompt

#### Step 6b: Verification Gate (NEW — adopted from gstack)
- If any code changed after Step 4's test run (fixes from review, etc.), re-run tests
- Build verification if project has a build step
- Do NOT proceed if re-run fails

#### Step 7: Push
Push to feature branch with upstream tracking:
```bash
git push -u origin <branch>
```
No tags. No [CONFIRM] needed in auto-pilot (it's just a branch push).

#### Step 8: Create PR (NEW — core of this skill)
Auto-detect base branch (from Step 1).

**PR body generation** — detect change size to pick format:

**Non-trivial** (features, refactors, multi-file changes):
```markdown
## Problem
<What was broken, missing, or inadequate? User/team impact.>

## Solution
<What changed and how it works. Key decisions made.>

## Why
<Why this approach? What does it unblock?>

## Test plan
- [ ] <verification step>
- [ ] <verification step>
```

**Trivial** (typo, config tweak, single file):
1-2 sentence summary. Don't force the full structure.

**Detection heuristic:** trivial = single file changed AND category is docs/chore/typo. Everything else = non-trivial.

Generate title from branch name or commit summary (conventional commit style, < 70 chars).

**[CONFIRM]** with options:
- Open PR (Recommended)
- Open as Draft — for early feedback before the work is complete
- Skip PR creation — code is pushed, create PR manually later

**If GitHub:**
```bash
gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
<PR body>
EOF
)"
```

**If GitLab:**
```bash
glab mr create -b <base> -t "<title>" -d "$(cat <<'EOF'
<MR body>
EOF
)"
```

**If neither CLI available:** print branch name and remote URL, instruct user to create PR via web UI.

#### Step 9: Reviewers & Labels (NEW — optional)
- Check for `CODEOWNERS` file → suggest reviewers from matching paths
- Check for frequent reviewers: `gh pr list --json reviews --limit 10` → suggest most active
- If repo uses labels: suggest based on change category (bug, feature, docs, chore)
- **[CONFIRM]** with suggested reviewers/labels, option to skip
- If no reviewers or labels to suggest: skip silently

#### Step 10: Summary
```
██████╗ ██████╗
██╔══██╗██╔══██╗
██████╔╝██████╔╝
██╔═══╝ ██╔══██╗
██║     ██║  ██║
╚═╝     ╚═╝  ╚═╝

  Branch:     feat/add-auth-middleware
  PR:         #42 — feat: add auth middleware
  Status:     ✓ Open (or ✓ Draft)
  URL:        https://github.com/user/repo/pull/42
  Reviewers:  @alice, @bob (or "none assigned")
  Labels:     enhancement (or "none")
```

#### Star Prompt (first run only)
Same as github-ship: check marker file, prompt once.

---

## `/github-ship` Changes (Refactored)

### What stays the same
Steps 0a, 0, 1, 2, 3, 3b, 4, 5, 6, 7, 8, 9, 12 — identical to v1.2.0.

### New: Platform detection (Step 0)
Same as github-pr: detect GitHub vs GitLab from remote URL.

### New: Base branch detection (Step 1)
Same fallback chain as github-pr.

### New: Test failure triage (Step 3)
Same classification logic as github-pr.

### New: Step 8b — Verification Gate
Insert between commit (Step 8) and tag (Step 9). Re-run tests if any code changed between Step 3's test run and now.

### Changed: Step 10 — Push
Add branch safety check:
- If NOT on main/master/default: warn "You're on `feat/xyz`, not main. Ship typically pushes to main. Continue anyway, or switch to main first?"
- If on main/master: proceed normally

### Changed: Step 11 — GitHub Release
Instead of `gh release create --generate-notes`:
1. Read the CHANGELOG entry written in Step 6
2. Use it as the release body
3. Derive title suffix from the first `### Added` heading or first bullet

```bash
gh release create v<VERSION> \
  --title "v<VERSION> — <title suffix>" \
  --notes-file /tmp/release-notes.md
```

**If GitLab:**
```bash
glab release create v<VERSION> \
  --name "v<VERSION> — <title suffix>" \
  --notes-file /tmp/release-notes.md
```

### New: CHANGELOG cross-check (Step 6)
After writing the CHANGELOG entry:
1. Enumerate all commits: `git log <base>..HEAD --oneline`
2. Verify every commit maps to at least one CHANGELOG bullet
3. If any commit is unrepresented, add it

---

## Shared Behavior (Both Skills)

### Error Handling
- Merge conflicts: stop, help resolve
- No remote: help add one
- Push rejected: suggest `git pull --rebase`, retry
- Not a git repo: Step 0 handles setup
- Not authenticated: suggest `gh auth login` or SSH key check

### Important Rules
- Never force-push unless user explicitly requests and understands consequences
- Never ship past failing tests (in-branch failures = hard stop)
- Never commit secrets — flag and add to `.gitignore`
- Always use specific file staging, never `git add .` or `git add -A`
- User may be new to git — provide brief explanations for unexpected situations

---

## README Structure

```
# github-ship

> SHIPPED ASCII banner

## One-liner
Done coding? Two commands:
- /github-pr — team? Open a PR.
- /github-ship — solo? Tag and release.

## When to Use What
| Situation                          | Command       |
|------------------------------------|---------------|
| Feature branch -> PR for review    | /github-pr    |
| Bug fix -> PR for review           | /github-pr    |
| Solo project -> release            | /github-ship  |
| Merged PR -> cut a release         | /github-ship  |
| First time shipping anything       | Either        |

## What Each Command Does
Side-by-side comparison table showing both workflows.

## Supported Languages
(existing table — 7 languages + general fallback)

## Installation
(existing — works for both skills automatically)

## Usage
- /github-pr: triggers + natural language
- /github-ship: triggers + natural language

## Optional Tools
(UBS — existing)

## Troubleshooting
(expanded for both skills)

## Acknowledgments + License
(existing)
```

---

## Version & Release

- Bump VERSION to `2.0.0` — this is a breaking structural change (skill directory split)
- CHANGELOG entry documents the split, new skill, and adopted features
- Tag `v2.0.0`
- GitHub Release with full notes

## Migration

Existing users who have `github-ship` installed get both skills automatically on update — the repo structure change is transparent. No breaking changes to `/github-ship` behavior; `/github-pr` is purely additive.

---

## Out of Scope (explicitly deferred)

- Telemetry / analytics
- Eval suites
- Adversarial review
- Review readiness dashboard
- Test framework bootstrap
- TODOS.md management
- Distribution pipeline check
- Contributor mode / field reports
- Document-release auto-sync (better as separate skill)
