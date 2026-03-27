---
name: github-ship
description: This skill should be used when the user is done coding and wants to save, commit, and ship their work to GitHub. It handles the full post-coding workflow including pre-flight checks, .gitignore audit, test execution, version bumping, changelog updates, committing, pushing, and creating GitHub releases. Trigger phrases include "ship it", "commit this", "push to GitHub", "release this", "github ship", or any request to finalize and push code changes. For quick saves without the full ceremony, use /save instead.
---

# GitHub Ship

Automated post-coding workflow that handles everything between "I'm done coding" and "my work is saved on GitHub." Designed for developers who want a reliable, repeatable process without memorizing git commands.

## When to Use

After finishing implementation work (e.g., after executing a plan, fixing a bug, adding a feature) and the user wants to commit, push, and optionally release.

## Workflow

Execute these steps in order. Do not skip steps.

At checkpoints marked **[CONFIRM]**, use the **AskUserQuestion tool** to present options as an interactive picker menu. Always:
- Place the recommended option **first** in the list
- Add "(Recommended)" to the recommended option's label
- Keep option descriptions concise (one line)

**Auto-pilot mode:** If the user selected auto-pilot in Step 0a, skip all [CONFIRM] checkpoints and use the recommended option automatically. Only stop on critical safety gates (failing tests, detected secrets, UBS critical bugs). At the end, include a summary of all auto-decisions made.

### Step 0a: Mode Selection

**[CONFIRM]** Use AskUserQuestion to ask: "How do you want to run this?"
- **Auto-pilot (Recommended)** — run all steps using recommended defaults, only stop on critical issues
- **Interactive** — confirm each step manually

Remember the user's choice — it controls whether [CONFIRM] checkpoints are shown or auto-resolved for the rest of the workflow.

### Step 0: Environment Check

Before anything else, verify the project is ready for shipping:

1. **Is this a git repo?** Run `git rev-parse --is-inside-work-tree`.
   - If NOT a git repo: use AskUserQuestion to ask: "This project isn't a git repository yet. Want me to set it up?"
     - **Yes, set it up (Recommended)** — initialize git and configure remote
     - **No, stop** — exit the workflow

     In auto-pilot mode: use recommended option.

     If yes:
     - Run `git init`
     - Ask: "What's the GitHub repo URL?" (e.g., `https://github.com/username/repo.git`)
     - Run `git remote add origin <url>`
     - Run `git add .` for the initial commit (exception to the "no git add ." rule — first commit only)
     - Run `git commit -m "Initial commit"`
   - If user says no: stop the workflow. Cannot ship without git.

2. **Is a remote configured?** Run `git remote -v`.
   - If no remote: ask "No remote configured. What's the GitHub repo URL?"
     - Run `git remote add origin <url>`
   - If remote exists: continue.

3. **Is git authenticated?** Run `git ls-remote --exit-code origin HEAD 2>/dev/null`.
   - If auth fails: inform the user: "Can't reach the remote. You may need to authenticate. Try running `gh auth login` or check your SSH keys." Stop workflow — pushing will fail without auth.
   - If OK: continue to Step 1.

4. **Detect platform** from remote URL:
   - Run `git remote get-url origin 2>/dev/null`
   - If URL contains "github.com" → platform is **GitHub**
   - If URL contains "gitlab" → platform is **GitLab**
   - Otherwise check CLI: `gh auth status 2>/dev/null` succeeds → **GitHub**; `glab auth status 2>/dev/null` succeeds → **GitLab**
   - Neither → **unknown** (use git-native commands only)

### Step 1: Pre-Flight Checks

Run these checks in parallel:

1. **Git status** -- run `git status` to see all changed, staged, and untracked files
2. **Branch check** -- confirm which branch is active via `git branch --show-current`
3. **Remote check** -- confirm remote exists via `git remote -v`

**Detect base branch** using this fallback chain:
1. `gh pr view --json baseRefName -q .baseRefName 2>/dev/null` (existing PR)
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null` (repo default)
3. `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
4. Fall back to `main`

Report findings to user as a brief summary: branch name, number of files changed/added/deleted.

### Step 2: .gitignore Audit

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
- Files that SHOULD be ignored but are not (secrets, caches, IDE config, OS files)
- Untracked files that look like they should be ignored (e.g., `.env`, `__pycache__/`, `*.pyc`, `.vscode/`)
- Any files containing potential secrets (filenames with "key", "secret", "token", "credential", "password")

If issues found: fix `.gitignore` and report what was added. If clean: move on silently.

### Step 3: Run Tests

Detect and run the project's test suite. Check in this order, use first match:

- Python (`requirements.txt`, `pyproject.toml`, `pytest.ini`, or `tests/` with `.py` files): `python -m pytest tests/ -v`
- Node (`package.json` with "test" script): `npm test`
- Rust (`Cargo.toml`): `cargo test`
- Go (`go.mod`): `go test ./...`
- Ruby (`Gemfile` with rspec, or `spec/` directory): `bundle exec rspec`
- PHP (`composer.json` with phpunit, or `phpunit.xml`): `vendor/bin/phpunit`
- Java (`build.gradle`): `./gradlew test` — or (`pom.xml`): `mvn test`

**If no recognizable test setup found:** Warn the user ("No test runner detected — skipping tests") and continue to Step 3b. Do NOT block the workflow.

- If tests **pass**: move to Step 3b
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

### Step 3b: Bug Scan (UBS)

Check if `ubs` is available by running `which ubs` or `where ubs`.

**If ubs is available:** Run a scan on staged/changed files:

```bash
ubs --diff .
```

If no code files exist (docs-only changes), UBS will report "no recognizable languages" -- this is fine, move on silently.

- If scan finds **critical** bugs: stop and report them. Help the user fix before continuing.
- If scan finds **warnings** only: report them to the user. Use AskUserQuestion to ask:
- **Ship anyway (Recommended)** — continue with warnings noted
- **Fix now** — stop and fix the warnings before shipping

In auto-pilot mode: use recommended option.
- If scan is **clean** or **no code to scan**: move to Step 4.

**If ubs is not available:** Skip silently and move to Step 4. Do not prompt the user to install it.

### Step 4: Diff Review

Run `git diff` (staged + unstaged) and `git diff --stat` to get a summary.

Analyze the changes and prepare:
1. A one-line summary of what changed (for commit message)
2. A categorization: is this a **bug fix**, **new feature**, **refactor**, **docs update**, or **mixed**?

**[CONFIRM]** Present the summary and category to the user. Use AskUserQuestion to ask:
- **Yes, commit (Recommended)** — proceed with staging and commit
- **Edit first** — let me make changes before committing
- **No, abort** — stop the workflow

In auto-pilot mode: use recommended option.

### Step 4b: Commit Grouping (opt-in)

If the diff touches **3+ files across 2+ logical concerns** (e.g., feature code + bug fix + docs), offer to split into grouped commits.

1. **Classify each changed file** by its primary concern:
   - `feat` — new feature code or feature tests
   - `fix` — bug fix code or bug fix tests
   - `refactor` — restructuring without behavior change
   - `docs` — documentation, README, comments
   - `test` — test-only changes (not tied to a specific feat/fix)
   - `chore` — config, CI, tooling, dependencies

2. **Present a grouping table:**

```
Proposed commit groups:
  Group 1 (feat):     src/auth.ts, src/auth.test.ts
  Group 2 (fix):      src/billing.ts
  Group 3 (docs):     README.md
  Meta (final group): VERSION, CHANGELOG.md
```

3. **[CONFIRM]** — **always shown, even in auto-pilot mode** (this is a safety gate):
   - **Use these groups (Recommended)** — commit each group separately with a group-specific message
   - **Adjust groups** — let me reorganize before committing
   - **Single commit** — commit everything together as usual

**Rules:**
- Meta files (VERSION, CHANGELOG.md, .gitignore) always go in the **last** group.
- If the concern classification is ambiguous for a file (could be feat or refactor), collapse to **single commit** automatically. Don't guess.
- If only 1-2 concerns detected, or fewer than 3 files changed, skip this step entirely — no prompt.
- If user selects "Adjust groups," ask them to describe the grouping. Re-present and confirm again.

Store the grouping decision for use in Step 8.

### Step 5: Version Bump

Check if a `VERSION` file exists at project root.

**If VERSION does not exist:** Create it with `0.1.0` as initial version. Inform the user this is the starting version.

**If VERSION exists:** Read current version. Based on the change category from Step 4, determine the bump:

- Bug fix / docs / refactor -> PATCH bump (0.1.0 -> 0.1.1)
- New feature -> MINOR bump (0.2.0 -> 0.3.0)
- Breaking change -> MAJOR bump (0.3.0 -> 1.0.0)

Reference `references/semver-guide.md` for the decision tree if unsure.

For MAJOR bumps, **[CONFIRM]** using AskUserQuestion:
- **Yes, major bump (Recommended)** — this is a breaking change, bump major version
- **Make it minor** — bump minor version instead
- **Make it patch** — bump patch version instead

In auto-pilot mode: use recommended option.

Write the new version to the `VERSION` file.

### Step 6: Update CHANGELOG

Check if `CHANGELOG.md` exists at project root.

**If CHANGELOG does not exist:** Create it using this template:

```markdown
# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [VERSION] - YYYY-MM-DD

### Added/Changed/Fixed
- Description of changes
```

**If CHANGELOG exists:** Add a new entry at the top (below the header), using the version from Step 5 and today's date.

Categorize changes under these headers (only include headers that apply):
- **Added** -- new features or files
- **Changed** -- changes to existing functionality
- **Fixed** -- bug fixes
- **Removed** -- removed features or files

Write entries by reading the actual diff, not generic descriptions. Each entry should be one concise line describing what was done and why.

**Cross-check:** After writing the entry:
1. Enumerate all commits: `git log <base>..HEAD --oneline`
2. Verify every commit maps to at least one CHANGELOG bullet
3. If any commit is unrepresented, add it

### Step 7: Check README

Check if `README.md` exists at project root.

**If README does not exist:** Skip. Do not create one unless the user asks. (Creating a good README requires user input about project goals, usage, etc.)

**If README exists:** Scan it briefly. Flag if anything is obviously outdated based on the current changes (e.g., removed a script that's still documented, changed CLI flags). Do not rewrite the README -- just flag issues for the user.

### Step 8: Commit

**If commit grouping was accepted in Step 4b**, loop through each group. **Otherwise**, make a single commit as before.

#### Single commit (default):

Stage all relevant files. Be deliberate about what gets staged:

```bash
git add <specific files from the diff>
git add VERSION
git add CHANGELOG.md
git add .gitignore  # if modified in Step 2
```

Never use `git add -A` or `git add .` -- always stage specific files to avoid accidents.

Write a commit message following this format:

```
<type>: <short description>

<optional body with details>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Where `<type>` is one of: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

Use a HEREDOC for the commit message to preserve formatting.

#### Grouped commits (from Step 4b):

For each group in order (non-meta groups first, meta group last):

1. **Stage only the files in this group:**
   ```bash
   git add <file1> <file2> ...
   ```

2. **Write a group-specific commit message:**
   ```
   <group type>: <description of this group's changes>

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

3. **Commit** using a HEREDOC for the message.

4. **If any commit fails:** Stop immediately. Report which group failed and why. Do not continue to the next group.

**Final group (meta):** Stage and commit VERSION, CHANGELOG.md, and any other meta files (.gitignore if modified) together:
```
chore: bump version to <VERSION> and update changelog

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 8b: Verification Gate

**If any code changed after Step 3's test run** (e.g., .gitignore fixes, CHANGELOG edits that touched code):
- Re-run the test suite using the same command from Step 3
- If tests fail: STOP. Do not tag or push. Fix the issue.
- If tests pass: continue.

**If no code changed since Step 3:** Skip — the earlier test run is still valid.

### Step 9: Tag

Create a git tag for the new version:

```bash
git tag -a v<VERSION> -m "Release v<VERSION>"
```

### Step 10: Push

**[CONFIRM]** Use AskUserQuestion to ask:
- **Yes, push (Recommended)** — push to origin/<branch> with tags
- **No, don't push** — keep changes local (committed but not pushed)

In auto-pilot mode: use recommended option.

**Branch safety check:**
- If NOT on main/master or the detected base branch: warn "You're on `<branch>`, not the base branch. Ship typically pushes to main. Continue anyway, or switch first?"
  In auto-pilot mode: warn but continue.

If confirmed:

```bash
git push origin <branch> --follow-tags
```

### Step 11: GitHub Release (Optional)

Check if `gh` CLI is available by running `gh --version`.

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

### Step 12: Summary

Print this output:

```
███████╗██╗  ██╗██╗██████╗ ██████╗ ███████╗██████╗
██╔════╝██║  ██║██║██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████╗███████║██║██████╔╝██████╔╝█████╗  ██║  ██║
╚════██║██╔══██║██║██╔═══╝ ██╔═══╝ ██╔══╝  ██║  ██║
███████║██║  ██║██║██║     ██║     ███████╗██████╔╝
╚══════╝╚═╝  ╚═╝╚═╝╚═╝     ╚═╝     ╚══════╝╚═════╝

  Branch:    <branch>
  Version:   <old> → <new>
  Commit:    <short hash> <message>
  Tag:       v<VERSION>
  Remote:    ✓ pushed to origin/<branch>
  Release:   <✓ created / ✗ skipped>
```

### Star Prompt (first run only)

Check if `~/.github-ship-star-prompted` exists.

**If marker file exists:** Skip silently.

**If marker file does NOT exist:**
1. Create the marker file: `touch ~/.github-ship-star-prompted`
2. Ask the user: "Would you like to ⭐ star github-ship on GitHub to support the project?"
3. Only if they explicitly agree and `gh` CLI is available, run:
   ```bash
   gh repo star hotsauce9000/github-ship
   ```
4. If `gh` is not available or user declines, skip silently. Never run this automatically without user consent.

## Error Handling

- **Merge conflicts:** Stop and help the user resolve them before continuing.
- **No remote configured:** Help the user add one with `git remote add origin <url>`.
- **Dirty worktree after commit:** Something went wrong. Run `git status` and investigate.
- **Push rejected:** Likely needs `git pull --rebase` first. Run it and retry push.
- **Not a git repo:** Step 0 handles this — offers to initialize git and set up remote.
- **Not authenticated:** Step 0 detects this early — suggests `gh auth login` or SSH key check before wasting time on the rest of the workflow.

## Important Rules

- Never force-push (`--force`) unless the user explicitly requests it and understands the consequences.
- Never ship past failing tests. Failing tests = stop shipping. If no test runner is detected, warn and continue — "never skip tests" means never ignore failures, not refuse to ship when no tests exist.
- Never commit secrets. If a file looks like it contains API keys or passwords, flag it and add to `.gitignore`.
- Always use specific file staging, never `git add .` or `git add -A`.
- The user is new to git -- provide brief explanations when something unexpected happens (merge conflict, detached HEAD, etc.) rather than just running commands silently.
