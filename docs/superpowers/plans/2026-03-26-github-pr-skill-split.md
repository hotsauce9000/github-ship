# github-ship v2.0 — PR/Ship Skill Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split github-ship into two independent skills (`/github-ship` + `/github-pr`) sharing one repo, with platform detection, test triage, and verification gates adopted from gstack.

**Architecture:** Two SKILL.md files under `skills/github-ship/` and `skills/github-pr/`. Shared gitignore/semver references stay in `skills/github-ship/references/`. New `pr-templates.md` reference in `skills/github-pr/references/`. Hooks, plugin metadata, and README updated to advertise both skills.

**Tech Stack:** Markdown skill files, bash hooks, JSON plugin configs

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/github-pr/SKILL.md` | New PR workflow (10 steps) |
| Create | `skills/github-pr/references/pr-templates.md` | PR body templates |
| Modify | `skills/github-ship/SKILL.md` | Add platform detection, base branch detection, test triage, verification gate, CHANGELOG cross-check, release notes from changelog, branch warning on push |
| Modify | `hooks/session-start` | Register both skills |
| Modify | `.claude-plugin/plugin.json` | Update description for both skills |
| Modify | `.claude-plugin/marketplace.json` | Add github-pr to marketplace plugins |
| Modify | `.cursor-plugin/plugin.json` | Update description |
| Modify | `.codex/INSTALL.md` | Add github-pr install instructions |
| Modify | `gemini-extension.json` | Update description |
| Modify | `hooks/hooks-cursor.json` | No change needed (reads skills/ dir) |
| Rewrite | `README.md` | Both workflows, decision table, side-by-side |
| Modify | `CHANGELOG.md` | v2.0.0 entry |
| Modify | `VERSION` | 1.2.0 -> 2.0.0 |
| Modify | `package.json` | version field |

---

### Task 1: Create PR Body Templates Reference

**Files:**
- Create: `skills/github-pr/references/pr-templates.md`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p skills/github-pr/references
```

- [ ] **Step 2: Write pr-templates.md**

```markdown
# PR Body Templates

## Non-Trivial PRs (features, refactors, multi-file changes)

Use this structure when the PR changes multiple files, adds a feature, refactors code, or fixes a non-trivial bug:

```
## Problem
What was broken, missing, or inadequate? Include user/team impact.

## Solution
What changed and how it works. Key decisions made.

## Why
Why this approach? What does it unblock?

## Test plan
- [ ] Verification step 1
- [ ] Verification step 2
```

**Guidelines:**
- Problem section: focus on impact, not implementation ("users couldn't log in" not "the auth middleware was missing")
- Solution section: explain the approach, not the diff ("added retry logic with exponential backoff" not "changed lines 42-58")
- Why section: explain tradeoffs ("chose retry over circuit breaker because the failure rate is < 1%")
- Test plan: specific verification steps a reviewer can follow

## Trivial PRs (typo, config tweak, single file)

1-2 sentence summary. Don't force the full structure when it adds no value.

Examples:
- "Fix typo in README installation section."
- "Update CI timeout from 10m to 15m after flaky test investigation."

## Detection Heuristic

A PR is **trivial** when ALL of these are true:
- Single file changed
- Change category is docs, chore, or typo
- No behavioral change

Everything else is **non-trivial** — use the full template.
```

- [ ] **Step 3: Commit**

```bash
git add skills/github-pr/references/pr-templates.md
git commit -m "feat: add PR body templates reference for github-pr skill"
```

---

### Task 2: Create `/github-pr` SKILL.md

**Files:**
- Create: `skills/github-pr/SKILL.md`

- [ ] **Step 1: Write the complete SKILL.md with frontmatter**

Write `skills/github-pr/SKILL.md` with this exact content:

```markdown
---
name: github-pr
description: Team PR workflow. Handles branch management, pre-flight checks, .gitignore audit, tests, diff review, committing, pushing, and creating pull requests with structured descriptions. Trigger phrases include "open a PR", "create a PR", "submit for review", "push for review", "github pr", or any request to create a pull request for team review.
---

# GitHub PR

Automated team workflow that handles everything between "I'm done coding" and "my PR is open for review." Designed for developers working on teams who want a reliable, repeatable process for opening pull requests.

## When to Use

After finishing implementation work on a feature branch and the user wants to commit, push, and open a pull request for review.

## Workflow

Execute these steps in order. Do not skip steps.

At checkpoints marked **[CONFIRM]**, use the **AskUserQuestion tool** to present options as an interactive picker menu. Always:
- Place the recommended option **first** in the list
- Add "(Recommended)" to the recommended option's label
- Keep option descriptions concise (one line)

**Auto-pilot mode:** If the user selected auto-pilot in Step 0a, skip all [CONFIRM] checkpoints and use the recommended option automatically. Only stop on critical safety gates (failing tests, detected secrets). At the end, include a summary of all auto-decisions made.

### Step 0a: Mode Selection

**[CONFIRM]** Use AskUserQuestion to ask: "How do you want to run this?"
- **Auto-pilot (Recommended)** — run all steps using recommended defaults, only stop on critical issues
- **Interactive** — confirm each step manually

Remember the user's choice — it controls whether [CONFIRM] checkpoints are shown or auto-resolved for the rest of the workflow.

### Step 0: Environment Check

Before anything else, verify the project is ready:

1. **Is this a git repo?** Run `git rev-parse --is-inside-work-tree`.
   - If NOT a git repo: use AskUserQuestion to ask: "This project isn't a git repository yet. Want me to set it up?"
     - **Yes, set it up (Recommended)** — initialize git and configure remote
     - **No, stop** — exit the workflow

     In auto-pilot mode: use recommended option.

     If yes:
     - Run `git init`
     - Ask: "What's the GitHub repo URL?" (e.g., `https://github.com/username/repo.git`)
     - Run `git remote add origin <url>`
   - If user says no: stop the workflow. Cannot create a PR without git.

2. **Is a remote configured?** Run `git remote -v`.
   - If no remote: ask "No remote configured. What's the GitHub repo URL?"
     - Run `git remote add origin <url>`
   - If remote exists: continue.

3. **Detect platform** from remote URL:
   - Run `git remote get-url origin 2>/dev/null`
   - If URL contains "github.com" → platform is **GitHub**
   - If URL contains "gitlab" → platform is **GitLab**
   - Otherwise check CLI: `gh auth status 2>/dev/null` succeeds → **GitHub**; `glab auth status 2>/dev/null` succeeds → **GitLab**
   - Neither → **unknown** (git-native commands only, PR creation will be manual)

4. **Is git authenticated?** Run `git ls-remote --exit-code origin HEAD 2>/dev/null`.
   - If auth fails: inform the user: "Can't reach the remote. You may need to authenticate. Try running `gh auth login` or check your SSH keys." Stop workflow.
   - If OK: continue to Step 1.

### Step 1: Pre-Flight Checks

Run these checks in parallel:

1. **Git status** — run `git status` to see all changed, staged, and untracked files
2. **Branch check** — confirm which branch is active via `git branch --show-current`
3. **Remote check** — confirm remote exists via `git remote -v`

**Detect base branch** using this fallback chain:
1. `gh pr view --json baseRefName -q .baseRefName 2>/dev/null` (existing PR for this branch)
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null` (repo default)
3. `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
4. Fall back to `main`

Report findings: branch name, base branch, number of files changed/added/deleted.

### Step 2: Branch Check

Check the current branch against the detected base branch.

**If on the base branch (main/master/default):**

**[CONFIRM]** Use AskUserQuestion: "You're on the base branch. PRs should come from feature branches."
- **Create a feature branch (Recommended)** — auto-generate name from recent commit messages (e.g., `feat/add-auth-middleware`)
- **Let me name it** — user provides branch name
- **Stay on this branch** — continue (warn: "Opening a PR from the base branch to itself is unusual")

In auto-pilot mode: use recommended option. Generate branch name from the most recent commit message: lowercase, hyphens, prefixed with commit type (e.g., `feat/`, `fix/`).

**If on a feature branch:** Continue.

### Step 3: .gitignore Audit

Read the project's `.gitignore` file. Detect the project's primary language using this priority order (check in order, use first match):

1. Python: `requirements.txt`, `setup.py`, `pyproject.toml`, or `*.py` files → use `../github-ship/references/gitignore-python.md`
2. Node/JS/TS: `package.json`, `*.js`, or `*.ts` files → use `../github-ship/references/gitignore-node.md`
3. Rust: `Cargo.toml` or `*.rs` files → use `../github-ship/references/gitignore-rust.md`
4. Go: `go.mod` or `*.go` files → use `../github-ship/references/gitignore-go.md`
5. Ruby: `Gemfile` or `*.rb` files → use `../github-ship/references/gitignore-ruby.md`
6. PHP: `composer.json` or `*.php` files → use `../github-ship/references/gitignore-php.md`
7. Java: `pom.xml`, `build.gradle`, or `*.java` files → use `../github-ship/references/gitignore-java.md`
8. Fallback: use `../github-ship/references/gitignore-general.md`

**Always** also check the entries in `../github-ship/references/gitignore-general.md` (secrets, IDE files, OS files) regardless of which language-specific reference matched.

Check for:
- Files that SHOULD be ignored but are not
- Untracked files that look like they should be ignored (e.g., `.env`, `__pycache__/`)
- Any files containing potential secrets (filenames with "key", "secret", "token", "credential", "password")

If issues found: fix `.gitignore` and report what was added. If clean: move on silently.

### Step 4: Run Tests

Detect and run the project's test suite. Check in this order, use first match:

- Python: `python -m pytest tests/ -v`
- Node: `npm test`
- Rust: `cargo test`
- Go: `go test ./...`
- Ruby: `bundle exec rspec`
- PHP: `vendor/bin/phpunit`
- Java: `./gradlew test` or `mvn test`

**If no recognizable test setup found:** Warn ("No test runner detected — skipping tests") and continue to Step 4b.

**If tests pass:** Continue to Step 4b.

**If tests fail — triage each failure:**

1. Get files changed on this branch: `git diff origin/<base>...HEAD --name-only`
2. For each failing test, classify:
   - **In-branch** if: the failing test file was modified on this branch, OR the code it tests was modified on this branch, OR you can trace the failure to a branch change.
   - **Pre-existing** if: neither the test file nor the code it tests was modified on this branch, AND the failure is unrelated to any branch change.
   - **When ambiguous, default to in-branch** — safer to stop than to let a broken test through.

3. **In-branch failures:** STOP. Report failures. Help the user fix them before continuing.
4. **Pre-existing failures:** Warn the user. Use AskUserQuestion:
   - **Continue anyway (Recommended)** — these failures existed before your changes
   - **Fix now** — investigate and fix before continuing
   - **Abort** — stop the workflow

In auto-pilot mode: continue for pre-existing, stop for in-branch.

### Step 4b: Bug Scan (UBS)

Check if `ubs` is available by running `which ubs` or `where ubs`.

**If ubs is available:** Run `ubs --diff .`

- Critical bugs: stop and report.
- Warnings only: **[CONFIRM]** — continue (recommended) or fix now.
- Clean or no code to scan: continue.

**If ubs is not available:** Skip silently.

### Step 5: Diff Review

Run `git diff` (staged + unstaged) and `git diff --stat`.

Analyze the changes and prepare:
1. A one-line summary of what changed
2. A categorization: **bug fix**, **new feature**, **refactor**, **docs update**, or **mixed**
3. Count files changed and lines added/removed

**[CONFIRM]** Present the summary to the user:
- **Yes, commit (Recommended)** — proceed with staging and commit
- **Edit first** — let me make changes before committing
- **No, abort** — stop the workflow

### Step 6: Commit

**Check if the change should be split** (bisectable commits):
- If diff touches 4+ files across 2+ logical concerns (e.g., infra + feature + tests for different things):
  - **[CONFIRM]**: "This changes multiple concerns. Split into logical commits?"
    - **Yes (Recommended)** — split by concern (infra first, then models/services, then views/controllers)
    - **No, single commit** — commit everything together
  - In auto-pilot mode: use recommended option.
- If diff is small (< 4 files or single concern): single commit, no prompt.

**For each commit:**

Stage specific files (never `git add -A` or `git add .`):
```bash
git add <specific files>
```

Write a commit message following this format:
```
<type>: <short description>

<optional body with details>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Where `<type>` is one of: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

Use a HEREDOC for the commit message to preserve formatting.

### Step 6b: Verification Gate

**If any code changed after Step 4's test run** (e.g., .gitignore fixes in Step 3, commit splitting in Step 6):
- Re-run the test suite using the same command from Step 4
- If tests fail: STOP. Do not push. Fix the issue.
- If tests pass: continue.

**If no code changed since Step 4:** Skip — the earlier test run is still valid.

### Step 7: Push

Push to the feature branch with upstream tracking:

```bash
git push -u origin <branch>
```

No tags. No [CONFIRM] needed in auto-pilot — it's just a branch push.

**If push is rejected:** Run `git pull --rebase origin <branch>` and retry once. If still rejected, stop and report.

### Step 8: Create PR

Generate the PR title and body.

**Title:** From branch name or commit summary. Conventional commit style, < 70 characters.

**Body:** Read `references/pr-templates.md` for the template structure.

Detect whether the change is trivial or non-trivial:
- **Trivial** = single file changed AND category is docs/chore/typo → 1-2 sentence summary
- **Non-trivial** = everything else → full Problem / Solution / Why / Test plan structure

Generate the body by reading the actual diff, not generic descriptions.

**[CONFIRM]** Use AskUserQuestion:
- **Open PR (Recommended)** — create the pull request now
- **Open as Draft** — create a draft PR for early feedback
- **Skip PR creation** — code is pushed, I'll create the PR manually

In auto-pilot mode: use recommended option.

**If GitHub:**
```bash
gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
<generated PR body>
EOF
)"
```

For draft: add `--draft` flag.

**If GitLab:**
```bash
glab mr create -b <base> -t "<title>" -d "$(cat <<'EOF'
<generated MR body>
EOF
)"
```

For draft: add `--draft` flag.

**If neither CLI available:** Print the branch name and remote URL. Instruct the user to create the PR via the web UI. Do not stop — the code is pushed and ready.

Output the PR/MR URL.

### Step 9: Reviewers & Labels (Optional)

**Skip silently** if no PR was created (user chose "Skip" in Step 8) or if the platform is unknown.

**Reviewers:**
1. Check for `CODEOWNERS` file → extract owners for changed file paths
2. If no CODEOWNERS: check recent PR reviewers: `gh pr list --json reviews --limit 10`
3. If reviewers found: **[CONFIRM]** with suggested names and option to skip

**Labels:**
1. Check available labels: `gh label list --limit 20 2>/dev/null`
2. Suggest labels based on change category (bug → "bug", feature → "enhancement", docs → "documentation")
3. If labels found: **[CONFIRM]** with suggestions and option to skip

In auto-pilot mode: apply suggested reviewers and labels if found, skip if none.

**If GitHub:**
```bash
gh pr edit <PR_NUMBER> --add-reviewer <reviewer1>,<reviewer2>
gh pr edit <PR_NUMBER> --add-label <label1>,<label2>
```

**If GitLab:**
```bash
glab mr update <MR_NUMBER> --reviewer <reviewer1>,<reviewer2>
glab mr update <MR_NUMBER> --label <label1>,<label2>
```

### Step 10: Summary

Print this output:

```
██████╗ ██████╗
██╔══██╗██╔══██╗
██████╔╝██████╔╝
██╔═══╝ ██╔══██╗
██║     ██║  ██║
╚═╝     ╚═╝  ╚═╝

  Branch:     <branch>
  PR:         #<number> — <title>
  Status:     <✓ Open / ✓ Draft / ✗ Skipped>
  URL:        <PR URL or "created manually">
  Reviewers:  <names or "none assigned">
  Labels:     <labels or "none">
```

If auto-pilot was used, append:
```
  Auto-decisions:
    → Mode: auto-pilot
    → <list each auto-decided checkpoint and what was chosen>
```

### Star Prompt (first run only)

Check if `~/.github-ship-star-prompted` exists.

**If marker file exists:** Skip silently.

**If marker file does NOT exist:**
1. Create the marker file: `touch ~/.github-ship-star-prompted`
2. Ask the user: "Would you like to star github-ship on GitHub to support the project?"
3. Only if they explicitly agree and `gh` CLI is available, run:
   ```bash
   gh repo star hotsauce9000/github-ship
   ```
4. If `gh` is not available or user declines, skip silently.

## Error Handling

- **Merge conflicts:** Stop and help the user resolve them.
- **No remote configured:** Help the user add one with `git remote add origin <url>`.
- **Push rejected:** Suggest `git pull --rebase`, retry once.
- **Not a git repo:** Step 0 handles setup.
- **Not authenticated:** Step 0 detects this early.
- **PR creation fails:** Print the error. Code is already pushed — user can create PR via web UI.

## Important Rules

- Never force-push (`--force`) unless the user explicitly requests it.
- Never open a PR past failing in-branch tests. Pre-existing failures can be overridden.
- Never commit secrets. Flag and add to `.gitignore`.
- Always use specific file staging, never `git add .` or `git add -A`.
- The user may be new to git — provide brief explanations when something unexpected happens.
```

- [ ] **Step 2: Verify the file reads correctly**

Open and skim `skills/github-pr/SKILL.md`. Confirm frontmatter parses (has `---` delimiters, `name:` and `description:` fields). Confirm all steps are numbered sequentially (0a, 0, 1, 2, 3, 4, 4b, 5, 6, 6b, 7, 8, 9, 10, Star Prompt). Confirm reference paths use `../github-ship/references/`.

- [ ] **Step 3: Commit**

```bash
git add skills/github-pr/SKILL.md
git commit -m "feat: add /github-pr skill — team PR workflow (10 steps)"
```

---

### Task 3: Refactor `/github-ship` SKILL.md

**Files:**
- Modify: `skills/github-ship/SKILL.md`

This task adds 6 enhancements to the existing SKILL.md. Apply each edit incrementally.

- [ ] **Step 1: Add platform detection to Step 0 (after auth check)**

In `skills/github-ship/SKILL.md`, after the existing Step 0 auth check (line ~59, `If OK: continue to Step 1.`), add platform detection. Find the line:

```
   - If OK: continue to Step 1.
```

Insert after it:

```markdown

4. **Detect platform** from remote URL:
   - Run `git remote get-url origin 2>/dev/null`
   - If URL contains "github.com" → platform is **GitHub**
   - If URL contains "gitlab" → platform is **GitLab**
   - Otherwise check CLI: `gh auth status 2>/dev/null` succeeds → **GitHub**; `glab auth status 2>/dev/null` succeeds → **GitLab**
   - Neither → **unknown** (use git-native commands only)
```

- [ ] **Step 2: Add base branch detection to Step 1**

Find the line `Report findings to user as a brief summary: branch name, number of files changed/added/deleted.`

Insert before it:

```markdown
**Detect base branch** using this fallback chain:
1. `gh pr view --json baseRefName -q .baseRefName 2>/dev/null` (existing PR)
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null` (repo default)
3. `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
4. Fall back to `main`

```

- [ ] **Step 3: Add test failure triage to Step 3**

Find the line `- If tests **fail**: stop and report failures. Do NOT continue shipping with failing tests. Help the user fix the failures first.`

Replace it with:

```markdown
- If tests **fail** — triage each failure:
  1. Get files changed since base: `git diff origin/<base>...HEAD --name-only`
  2. For each failing test, classify:
     - **In-branch** if: the test file or code-under-test was modified on this branch
     - **Pre-existing** if: neither was modified and failure is unrelated to branch changes
     - **When ambiguous, default to in-branch** (safer)
  3. **In-branch failures:** STOP. Report and help fix. Do NOT continue.
  4. **Pre-existing failures:** Warn user. Use AskUserQuestion:
     - **Continue anyway (Recommended)** — these existed before your changes
     - **Fix now** — investigate before continuing
     - **Abort** — stop the workflow
  In auto-pilot mode: continue for pre-existing, stop for in-branch.
```

- [ ] **Step 4: Add CHANGELOG cross-check to Step 6**

Find the line `Write entries by reading the actual diff, not generic descriptions. Each entry should be one concise line describing what was done and why.`

Insert after it:

```markdown

**Cross-check:** After writing the entry:
1. Enumerate all commits: `git log <base>..HEAD --oneline`
2. Verify every commit maps to at least one CHANGELOG bullet
3. If any commit is unrepresented, add it
```

- [ ] **Step 5: Add verification gate as Step 8b**

Find `### Step 9: Tag`. Insert before it:

```markdown
### Step 8b: Verification Gate

**If any code changed after Step 3's test run** (e.g., .gitignore fixes, CHANGELOG edits that touched code):
- Re-run the test suite using the same command from Step 3
- If tests fail: STOP. Do not tag or push. Fix the issue.
- If tests pass: continue.

**If no code changed since Step 3:** Skip — the earlier test run is still valid.

```

- [ ] **Step 6: Add branch safety check to Step 10 (Push)**

Find the existing Step 10 `### Step 10: Push` section. Find the line `If confirmed:`.

Insert before `If confirmed:`:

```markdown
**Branch safety check:**
- If NOT on main/master or the detected base branch: warn "You're on `<branch>`, not the base branch. Ship typically pushes to main. Continue anyway, or switch first?"
  In auto-pilot mode: warn but continue.

```

- [ ] **Step 7: Replace release notes generation in Step 11**

Find the line:

```
gh release create v<VERSION> --generate-notes --title "v<VERSION>"
```

Replace the entire Step 11 GitHub release section (from `**If gh is available:**` through the install link paragraph) with:

```markdown
**If gh is available or glab is available:** Use AskUserQuestion to ask:
- **Yes, create release (Recommended)** — create a GitHub/GitLab Release for this version
- **No, skip release** — no release this time

In auto-pilot mode: use recommended option.

If yes:
1. Extract the CHANGELOG entry for this version (the text between the `## [VERSION]` header and the next `## [` or `---`)
2. Write it to a temp file as the release body
3. Derive a title suffix from the first `### Added` heading or first bullet point

**If GitHub:**
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

**If neither CLI is available:** Inform user they can install GitHub CLI (`gh`) or GitLab CLI (`glab`) to create releases. Links: https://cli.github.com/ or https://gitlab.com/gitlab-org/cli
```

- [ ] **Step 8: Verify the file**

Read the full `skills/github-ship/SKILL.md` and confirm:
- Step 0 has 4 checks (git repo, remote, platform, auth)
- Step 1 has base branch detection
- Step 3 has test failure triage
- Step 6 has CHANGELOG cross-check
- Step 8b exists (verification gate)
- Step 10 has branch safety check
- Step 11 uses CHANGELOG for release notes and supports GitLab

- [ ] **Step 9: Commit**

```bash
git add skills/github-ship/SKILL.md
git commit -m "feat: add platform detection, test triage, verification gate, and CHANGELOG improvements to /github-ship"
```

---

### Task 4: Update SessionStart Hook

**Files:**
- Modify: `hooks/session-start:6,18-38`

- [ ] **Step 1: Update the hook to read both skill descriptions**

In `hooks/session-start`, replace line 6:

```bash
SKILL_MD="${PLUGIN_ROOT}/skills/github-ship/SKILL.md"
```

With:

```bash
SHIP_SKILL_MD="${PLUGIN_ROOT}/skills/github-ship/SKILL.md"
PR_SKILL_MD="${PLUGIN_ROOT}/skills/github-pr/SKILL.md"
```

- [ ] **Step 2: Update the description reading to handle both skills**

Replace lines 18-38 (the description reading and session_context building) with:

```bash
# Read description from SKILL.md YAML frontmatter
read_description() {
    local skill_md="$1"
    local desc=""
    if [ -f "$skill_md" ]; then
        local in_frontmatter=false
        while IFS= read -r line; do
            if [[ "$line" == "---" ]]; then
                if $in_frontmatter; then break; fi
                in_frontmatter=true
                continue
            fi
            if $in_frontmatter && [[ "$line" == description:* ]]; then
                desc="${line#description: }"
            fi
        done < "$skill_md"
    fi
    printf '%s' "$desc"
}

ship_desc=$(read_description "$SHIP_SKILL_MD")
pr_desc=$(read_description "$PR_SKILL_MD")

if [ -z "$ship_desc" ]; then
    ship_desc="Invoke /github-ship when the user wants to ship, commit, tag, and release code."
fi
if [ -z "$pr_desc" ]; then
    pr_desc="Invoke /github-pr when the user wants to open a pull request for team review."
fi

session_context="You have two shipping skills available: /github-ship (solo releases) and /github-pr (team PRs). ${ship_desc} ${pr_desc}"
escaped=$(escape_for_json "$session_context")
```

- [ ] **Step 3: Verify the hook runs without errors**

```bash
bash hooks/session-start
```

Expected: JSON output with `hookSpecificOutput` or `additional_context` containing both skill descriptions.

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start
git commit -m "feat: register both /github-ship and /github-pr in SessionStart hook"
```

---

### Task 5: Update Plugin Metadata

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.cursor-plugin/plugin.json`
- Modify: `.codex/INSTALL.md`
- Modify: `gemini-extension.json`

- [ ] **Step 1: Update `.claude-plugin/plugin.json`**

Replace the entire file with:

```json
{
  "name": "github-ship",
  "description": "Two commands for shipping code: /github-pr opens a PR for team review, /github-ship tags and releases for solo projects. Both handle pre-flight checks, gitignore audit, tests, diff review, and committing. Supports Python, Node, Rust, Go, Ruby, PHP, Java, GitHub, and GitLab.",
  "version": "2.0.0",
  "author": {
    "name": "hotsauce9000",
    "url": "https://github.com/hotsauce9000"
  },
  "homepage": "https://github.com/hotsauce9000/github-ship",
  "repository": "https://github.com/hotsauce9000/github-ship",
  "license": "MIT",
  "keywords": ["shipping", "git", "release", "versioning", "changelog", "workflow", "automation", "pull-request", "pr", "gitlab"]
}
```

- [ ] **Step 2: Update `.claude-plugin/marketplace.json`**

Replace the entire file with:

```json
{
  "name": "github-ship-marketplace",
  "description": "Marketplace for github-ship plugin",
  "owner": {
    "name": "hotsauce9000",
    "url": "https://github.com/hotsauce9000"
  },
  "plugins": [
    {
      "name": "github-ship",
      "description": "Two commands: /github-pr (team PRs) and /github-ship (solo releases). Pre-flight checks, tests, versioning, changelog, and GitHub/GitLab support.",
      "version": "2.0.0",
      "source": "./"
    }
  ]
}
```

- [ ] **Step 3: Update `.cursor-plugin/plugin.json`**

Replace the entire file with:

```json
{
  "name": "github-ship",
  "displayName": "GitHub Ship",
  "description": "Two shipping workflows: /github-pr for team pull requests, /github-ship for solo releases. Handles pre-flight checks, tests, versioning, changelog, and GitHub/GitLab support.",
  "version": "2.0.0",
  "author": {
    "name": "hotsauce9000",
    "url": "https://github.com/hotsauce9000"
  },
  "homepage": "https://github.com/hotsauce9000/github-ship",
  "repository": "https://github.com/hotsauce9000/github-ship",
  "license": "MIT",
  "keywords": ["shipping", "git", "release", "pull-request", "workflow"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks-cursor.json"
}
```

- [ ] **Step 4: Update `.codex/INSTALL.md`**

Replace the entire file with:

```markdown
# Installing github-ship for Codex

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/hotsauce9000/github-ship.git ~/.codex/github-ship
   ```

2. Create the skills symlinks (both skills):
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/github-ship/skills/github-ship ~/.agents/skills/github-ship
   ln -s ~/.codex/github-ship/skills/github-pr ~/.agents/skills/github-pr
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\github-ship" "$env:USERPROFILE\.codex\github-ship\skills\github-ship"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\github-pr" "$env:USERPROFILE\.codex\github-ship\skills\github-pr"
   ```

3. Restart Codex.

## Updating

```bash
cd ~/.codex/github-ship && git pull
```
```

- [ ] **Step 5: Update `gemini-extension.json`**

Replace the entire file with:

```json
{
  "name": "github-ship",
  "description": "Two shipping workflows: /github-pr for team pull requests, /github-ship for solo releases. Pre-flight checks, tests, versioning, and GitHub/GitLab support.",
  "version": "2.0.0",
  "contextFileName": "GEMINI.md"
}
```

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json .cursor-plugin/plugin.json .codex/INSTALL.md gemini-extension.json
git commit -m "chore: update plugin metadata for v2.0.0 (both skills, GitLab support)"
```

---

### Task 6: Rewrite README.md

**Files:**
- Rewrite: `README.md`

- [ ] **Step 1: Write the new README**

Replace the entire `README.md` with:

````markdown
```
███████╗██╗  ██╗██╗██████╗ ██████╗ ███████╗██████╗
██╔════╝██║  ██║██║██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████╗███████║██║██████╔╝██████╔╝█████╗  ██║  ██║
╚════██║██╔══██║██║██╔═══╝ ██╔═══╝ ██╔══╝  ██║  ██║
███████║██║  ██║██║██║     ██║     ███████╗██████╔╝
╚══════╝╚═╝  ╚═╝╚═╝╚═╝     ╚═╝     ╚══════╝╚═════╝
```

# github-ship

> Done coding? Two commands:
> - `/github-pr` — working with a team? Open a PR.
> - `/github-ship` — working solo? Tag and release.

## When to Use What

| Situation | Command |
|-----------|---------|
| Feature branch → PR for review | `/github-pr` |
| Bug fix → PR for review | `/github-pr` |
| Solo project → release | `/github-ship` |
| Merged PR → cut a release | `/github-ship` |
| First time shipping anything | Either — both handle git setup |

## What Each Command Does

| | `/github-pr` | `/github-ship` |
|---|---|---|
| Environment check | ✓ | ✓ |
| Platform detection (GitHub/GitLab) | ✓ | ✓ |
| Branch management | ✓ Creates feature branch if needed | Warns if not on main |
| .gitignore audit | ✓ | ✓ |
| Run tests | ✓ With failure triage | ✓ With failure triage |
| Bug scan (UBS) | ✓ | ✓ |
| Diff review + commit | ✓ With bisectable commits | ✓ |
| Verification gate | ✓ Re-runs tests if code changed | ✓ Re-runs tests if code changed |
| Version bump | | ✓ |
| Changelog | | ✓ With cross-check |
| README check | | ✓ |
| Tag | | ✓ |
| Push | To feature branch | To main with tags |
| Create PR | ✓ With Problem/Solution/Why format | |
| Reviewers & labels | ✓ Suggests from CODEOWNERS | |
| GitHub/GitLab Release | | ✓ From changelog |

## Supported Languages

| Language | Gitignore Reference | Test Runner |
|----------|-------------------|-------------|
| Python | gitignore-python.md | `python -m pytest tests/ -v` |
| Node/JS/TS | gitignore-node.md | `npm test` |
| Rust | gitignore-rust.md | `cargo test` |
| Go | gitignore-go.md | `go test ./...` |
| Ruby | gitignore-ruby.md | `bundle exec rspec` |
| PHP | gitignore-php.md | `vendor/bin/phpunit` |
| Java | gitignore-java.md | `./gradlew test` or `mvn test` |
| Other | gitignore-general.md | Warns and continues |

## Supported Platforms

| Platform | PR/MR Creation | Release Creation | Detection |
|----------|---------------|-----------------|-----------|
| GitHub | `gh pr create` | `gh release create` | Remote URL or `gh auth status` |
| GitLab | `glab mr create` | `glab release create` | Remote URL or `glab auth status` |
| Other | Manual (prints instructions) | Manual | Fallback |

## Installation

### Claude Code (Recommended)

```bash
/plugin marketplace add hotsauce9000/github-ship
/plugin install github-ship@github-ship-marketplace
```

### Cursor

```
/add-plugin github-ship
```

Or search for "github-ship" in the plugin marketplace.

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/hotsauce9000/github-ship/refs/heads/main/.codex/INSTALL.md
```

### Gemini CLI

```bash
gemini extensions install https://github.com/hotsauce9000/github-ship
```

### Manual Installation

```bash
git clone https://github.com/hotsauce9000/github-ship.git
# Copy or symlink both skills:
cp -r github-ship/skills/github-ship ~/.claude/skills/github-ship
cp -r github-ship/skills/github-pr ~/.claude/skills/github-pr
```

## Usage

**`/github-pr`** (slash command or natural language):
- "open a PR"
- "create a PR"
- "submit for review"
- "push for review"

**`/github-ship`** (slash command or natural language):
- "ship it"
- "commit this"
- "push to GitHub"
- "release this"
- "save my work"

Both commands support **auto-pilot mode** — run the entire workflow with recommended defaults, only stopping on critical issues.

## Optional Tools

For enhanced bug scanning, install [Ultimate Bug Scanner](https://github.com/Dicklesworthstone/ultimate_bug_scanner). If installed, both skills automatically run a bug scan before committing. If not installed, the step is silently skipped.

## Updating

```bash
/plugin update github-ship
```

## Troubleshooting

- **Skill doesn't auto-trigger:** Invoke manually with `/github-ship` or `/github-pr`. The auto-trigger hook requires bash. On Windows, install [Git for Windows](https://gitforwindows.org/).
- **"Not a git repository" error:** Both skills offer to set up git for you (Step 0).
- **Push fails with auth error:** Run `gh auth login` (GitHub) or `glab auth login` (GitLab), or check your SSH keys.
- **No test runner detected:** Expected for docs-only or unsupported-language projects. Both skills warn and continue.
- **PR creation fails:** Code is already pushed. Create the PR manually via the web UI.
- **GitLab not detected:** Ensure `glab` CLI is installed and authenticated (`glab auth status`).

## Acknowledgments

This project was inspired by the "Full GitHub Flow" prompt in [Agent Flywheel](https://agent-flywheel.com/workflow) by [Jeffrey Emanuel](https://x.com/doodlestein) ([@Dicklesworthstone](https://github.com/Dicklesworthstone)). Check out his work on agentic workflows.

Built by [Anthony Buitran](https://x.com/anthonybuitran) ([@hotsauce9000](https://github.com/hotsauce9000)).

## License

MIT — see [LICENSE](LICENSE) for details.
````

- [ ] **Step 2: Verify README renders correctly**

Read through the markdown and confirm:
- SHIPPED banner is present
- Decision table has 5 rows
- Side-by-side comparison table has all features
- Both skills shown in Installation manual section
- Both skills have Usage trigger phrases
- Troubleshooting covers both skills + GitLab

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for v2.0 — both workflows, decision table, GitLab support"
```

---

### Task 7: Version Bump, Changelog, and Release Prep

**Files:**
- Modify: `VERSION`
- Modify: `CHANGELOG.md`
- Modify: `package.json`

- [ ] **Step 1: Bump VERSION**

Write `2.0.0` to the `VERSION` file (replacing `1.2.0`).

- [ ] **Step 2: Update package.json version**

In `package.json`, change the `"version"` field from `"1.0.0"` to `"2.0.0"`.

- [ ] **Step 3: Update CHANGELOG.md**

Add a new entry at the top of the changelog (after the header), before the `## [1.2.0]` entry:

```markdown
## [2.0.0] - 2026-03-26

### Added
- `/github-pr` skill — team PR workflow with 10 steps: environment check, branch management, .gitignore audit, tests, diff review, commit, push, PR creation, reviewers/labels, summary
- PR body templates using Problem / Solution / Why / Test plan structure (non-trivial) or 1-2 sentence summary (trivial)
- Platform detection — auto-detect GitHub vs GitLab from remote URL, with CLI fallback
- Base branch detection — 4-step fallback chain (existing PR → repo default → git symbolic-ref → `main`)
- Test failure triage — classify failures as in-branch (must fix) vs pre-existing (can override)
- Verification gate — re-run tests if code changed between test step and push/tag
- CHANGELOG cross-check — verify every commit maps to at least one changelog bullet
- Bisectable commits option — offer to split multi-concern changes into logical commits
- GitLab support — `glab` CLI for MR creation and releases alongside `gh` for GitHub
- Branch safety check in `/github-ship` — warns if shipping from a feature branch instead of main
- Draft PR support in `/github-pr`
- Reviewer suggestions from CODEOWNERS and recent PR history
- Label suggestions based on change category

### Changed
- `/github-ship` Step 11 (GitHub Release) now uses CHANGELOG entry as release body instead of `--generate-notes`
- SessionStart hook registers both `/github-ship` and `/github-pr`
- Plugin metadata updated for all platforms (Claude Code, Cursor, Codex, Gemini CLI)
- README rewritten with decision table, side-by-side comparison, and both workflows

```

- [ ] **Step 4: Commit**

```bash
git add VERSION CHANGELOG.md package.json
git commit -m "chore: bump version to 2.0.0 and update changelog"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Every section of the spec maps to a task (PR templates → T1, github-pr SKILL.md → T2, github-ship refactor → T3, hooks → T4, plugin metadata → T5, README → T6, version/changelog → T7)
- [x] **Placeholder scan:** No TBDs, TODOs, or "implement later" — every step has exact content
- [x] **Type consistency:** Frontmatter field names (`name:`, `description:`) match across SKILL.md files. Reference paths (`../github-ship/references/`) are consistent. Version `2.0.0` is consistent across VERSION, package.json, plugin.json files, marketplace.json, cursor plugin.json, gemini-extension.json, and CHANGELOG
- [x] **Out of scope items from spec:** Telemetry, eval suites, adversarial review, test bootstrap, TODOS.md, distribution pipeline, contributor mode, document-release — none appear in any task
