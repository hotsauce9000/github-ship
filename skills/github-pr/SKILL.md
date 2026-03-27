---
name: github-pr
description: Team PR workflow. Handles branch management, pre-flight checks, .gitignore audit, tests, diff review, committing, pushing, and creating pull requests with structured descriptions. Trigger phrases include "open a PR", "create a PR", "submit for review", "push for review", "github pr", or any request to create a pull request for team review.
---

## Preamble (run first, before any workflow step)

```bash
# Skip update check for marketplace-managed installs (platform handles updates)
_IS_MARKETPLACE=""
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/marketplace.json" ] && _IS_MARKETPLACE="true"
_SHIP_ROOT=""
for _D in "${CLAUDE_PLUGIN_ROOT:-}" "$HOME/.claude/skills/github-ship" ".claude/skills/github-ship"; do
  [ -n "$_D" ] && [ -f "$_D/bin/update-check" ] && _SHIP_ROOT="$_D" && break
done
_UPD=""
if [ -n "$_SHIP_ROOT" ] && [ -z "$_IS_MARKETPLACE" ]; then
  _UPD=$("$_SHIP_ROOT/bin/update-check" 2>/dev/null || true)
fi
[ -n "$_UPD" ] && echo "$_UPD" || true
_AUTO_UPG=""
[ -f "$HOME/.github-ship/auto-upgrade" ] && _AUTO_UPG="true"
echo "AUTO_UPGRADE=${_AUTO_UPG:-false}"
echo "MARKETPLACE=${_IS_MARKETPLACE:-false}"
```

**Handle preamble output before proceeding to the workflow:**

If output shows `JUST_UPGRADED <old> <new>`:
- Tell user: "Running github-ship v{new} (just updated from v{old})!"
- Read CHANGELOG.md from the skill's repo root. Find entries between old and new version. Summarize as 3-5 bullets.
- Continue to Step 0a.

If output shows `UPGRADE_AVAILABLE <old> <new>`:
- If `AUTO_UPGRADE=true`: Log "Auto-upgrading github-ship v{old} → v{new}..." and proceed to **Upgrade Flow** below.
- Otherwise, use **AskUserQuestion**:
  - Question: "github-ship **v{new}** is available (you're on v{old}). Upgrade now?"
  - Options:
    1. "Yes, upgrade now"
    2. "Always keep me up to date"
    3. "Not now"
    4. "Never ask again"

**If "Yes, upgrade now":** Run Upgrade Flow below.

**If "Always keep me up to date":**
```bash
mkdir -p ~/.github-ship && touch ~/.github-ship/auto-upgrade
```
Tell user: "Auto-upgrade enabled. Future updates install automatically."
Run Upgrade Flow below.

**If "Not now":** Write snooze with escalating backoff, then continue to Step 0a.
```bash
_SNOOZE_FILE=~/.github-ship/update-snoozed
_REMOTE_VER="{new}"
_CUR_LEVEL=0
if [ -f "$_SNOOZE_FILE" ]; then
  _SNOOZED_VER=$(awk '{print $1}' "$_SNOOZE_FILE")
  if [ "$_SNOOZED_VER" = "$_REMOTE_VER" ]; then
    _CUR_LEVEL=$(awk '{print $2}' "$_SNOOZE_FILE")
    case "$_CUR_LEVEL" in *[!0-9]*) _CUR_LEVEL=0 ;; esac
  fi
fi
_NEW_LEVEL=$((_CUR_LEVEL + 1))
[ "$_NEW_LEVEL" -gt 3 ] && _NEW_LEVEL=3
echo "$_REMOTE_VER $_NEW_LEVEL $(date +%s)" > "$_SNOOZE_FILE"
```
Tell user snooze duration: "Next reminder in 24h" (level 1), "48h" (level 2), or "1 week" (level 3).

**If "Never ask again":**
```bash
mkdir -p ~/.github-ship && touch ~/.github-ship/update-check-disabled
```
Tell user: "Update checks disabled. Delete `~/.github-ship/update-check-disabled` to re-enable."
Continue to Step 0a.

If preamble output is empty or `MARKETPLACE=true`: no update available, continue to Step 0a silently.

### Upgrade Flow

Detect install type and upgrade. **Guard: never proceed with empty install dir.**

```bash
_INSTALL_DIR=""
_INSTALL_TYPE=""
if [ -d "${CLAUDE_PLUGIN_ROOT:-}/.git" ]; then
  _INSTALL_TYPE="plugin-git"
  _INSTALL_DIR="$CLAUDE_PLUGIN_ROOT"
elif [ -d "$HOME/.claude/skills/github-ship/.git" ]; then
  _INSTALL_TYPE="global-git"
  _INSTALL_DIR="$HOME/.claude/skills/github-ship"
elif [ -d ".claude/skills/github-ship/.git" ]; then
  _INSTALL_TYPE="local-git"
  _INSTALL_DIR=".claude/skills/github-ship"
elif [ -d "$HOME/.claude/skills/github-ship" ]; then
  _INSTALL_TYPE="vendored-global"
  _INSTALL_DIR="$HOME/.claude/skills/github-ship"
elif [ -d ".claude/skills/github-ship" ]; then
  _INSTALL_TYPE="vendored"
  _INSTALL_DIR=".claude/skills/github-ship"
fi
echo "INSTALL: $_INSTALL_TYPE at $_INSTALL_DIR"
```

If `_INSTALL_DIR` is empty: tell user "Could not determine install location. Run `git pull` manually in your github-ship directory." Skip upgrade, continue to Step 0a.

**For git installs** (plugin-git, global-git, local-git):
```bash
OLD_VERSION=$(cat "$_INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")
cd "$_INSTALL_DIR" && git pull origin main
```
If `git pull` fails (conflicts, network): tell user "Upgrade failed — you can manually update with `cd $_INSTALL_DIR && git pull`." Continue with current version.

**For vendored installs** (vendored, vendored-global):
```bash
OLD_VERSION=$(cat "$_INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")
TMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/hotsauce9000/github-ship.git "$TMP_DIR/github-ship"
mv "$_INSTALL_DIR" "$_INSTALL_DIR.bak"
cp -Rf "$TMP_DIR/github-ship" "$_INSTALL_DIR"
rm -rf "$_INSTALL_DIR/.git" "$TMP_DIR"
```
If clone/copy fails: restore backup and warn user.
```bash
rm -rf "${_INSTALL_DIR:?}"
mv "$_INSTALL_DIR.bak" "$_INSTALL_DIR"
```

**Post-upgrade (all install types):**
```bash
mkdir -p ~/.github-ship
echo "$OLD_VERSION" > ~/.github-ship/just-upgraded-from
rm -f ~/.github-ship/last-update-check
rm -f ~/.github-ship/update-snoozed
```

Show "What's New": Read CHANGELOG.md, summarize entries between old and new version as 3-5 bullets. Then tell user: "Upgrade complete. **Start a new session** to use github-ship v{new}." Do NOT continue the workflow in the current session — the SKILL.md Claude is executing may have changed.

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

**If no `.gitignore` exists:** Create one. Use the detected language reference to populate it with standard patterns. Always include entries from `references/gitignore-general.md` (secrets, IDE, OS files). Inform user: "No .gitignore found — created one with standard [language] patterns."

Read the project's `.gitignore` file. Detect the project's primary language using this priority order (check in order, use first match):

1. Python: `requirements.txt`, `setup.py`, `pyproject.toml`, or `*.py` files → use `references/gitignore-python.md`
2. Node/JS/TS: `package.json`, `*.js`, or `*.ts` files → use `references/gitignore-node.md`
3. Rust: `Cargo.toml` or `*.rs` files → use `references/gitignore-rust.md`
4. Go: `go.mod` or `*.go` files → use `references/gitignore-go.md`
5. Ruby: `Gemfile` or `*.rb` files → use `references/gitignore-ruby.md`
6. PHP: `composer.json` or `*.php` files → use `references/gitignore-php.md`
7. Java: `pom.xml`, `build.gradle`, or `*.java` files → use `references/gitignore-java.md`
8. Fallback: use `references/gitignore-general.md`

**Always** also check the entries in `references/gitignore-general.md` (secrets, IDE files, OS files) regardless of which language-specific reference matched.

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

**Check for existing PR:**
1. Run `gh pr view --json number,url,state 2>/dev/null` (GitHub) or `glab mr view -F json 2>/dev/null` (GitLab)
2. If a PR/MR already exists for this branch:
   - **[CONFIRM]** Use AskUserQuestion:
     - **Push updates to existing PR (Recommended)** — your commits are already pushed, the PR updates automatically
     - **Open existing PR in browser** — view the current PR
     - **Create a new PR anyway** — create a second PR (unusual)
   - In auto-pilot mode: use recommended option (push updates).
3. If no PR exists: continue with PR creation.

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
