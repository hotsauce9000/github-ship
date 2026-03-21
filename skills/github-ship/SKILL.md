---
name: github-ship
description: This skill should be used when the user is done coding and wants to save, commit, and ship their work to GitHub. It handles the full post-coding workflow including pre-flight checks, .gitignore audit, test execution, version bumping, changelog updates, committing, pushing, and creating GitHub releases. Trigger phrases include "ship it", "commit this", "push to GitHub", "save my work", "release this", "github ship", or any request to finalize and push code changes.
---

# GitHub Ship

Automated post-coding workflow that handles everything between "I'm done coding" and "my work is saved on GitHub." Designed for developers who want a reliable, repeatable process without memorizing git commands.

## When to Use

After finishing implementation work (e.g., after executing a plan, fixing a bug, adding a feature) and the user wants to commit, push, and optionally release.

## Workflow

Execute these steps in order. Do not skip steps. Ask the user for confirmation only at the checkpoints marked **[CONFIRM]**.

### Step 1: Pre-Flight Checks

Run these checks in parallel:

1. **Git status** -- run `git status` to see all changed, staged, and untracked files
2. **Branch check** -- confirm which branch is active via `git branch --show-current`
3. **Remote check** -- confirm remote exists via `git remote -v`

Report findings to user as a brief summary: branch name, number of files changed/added/deleted.

### Step 2: .gitignore Audit

Read the project's `.gitignore` file. Compare against the reference checklist in `references/gitignore-python.md`.

Check for:
- Files that SHOULD be ignored but are not (secrets, caches, IDE config, OS files)
- Untracked files that look like they should be ignored (e.g., `.env`, `__pycache__/`, `*.pyc`, `.vscode/`)
- Any files containing potential secrets (filenames with "key", "secret", "token", "credential", "password")

If issues found: fix `.gitignore` and report what was added. If clean: move on silently.

### Step 3: Run Tests

Run the project's test suite:

```bash
python -m pytest tests/ -v
```

- If tests **pass**: move to Step 3b
- If tests **fail**: stop and report failures. Do NOT continue shipping with failing tests. Help the user fix the failures first.

### Step 3b: Bug Scan (UBS)

Check if `ubs` is available by running `which ubs` or `where ubs`.

**If ubs is available:** Run a scan on staged/changed files:

```bash
ubs --diff .
```

If no code files exist (docs-only changes), UBS will report "no recognizable languages" -- this is fine, move on silently.

- If scan finds **critical** bugs: stop and report them. Help the user fix before continuing.
- If scan finds **warnings** only: report them to the user but continue. Ask if they want to fix now or ship anyway.
- If scan is **clean** or **no code to scan**: move to Step 4.

**If ubs is not available:** Skip silently and move to Step 4. Do not prompt the user to install it.

### Step 4: Diff Review

Run `git diff` (staged + unstaged) and `git diff --stat` to get a summary.

Analyze the changes and prepare:
1. A one-line summary of what changed (for commit message)
2. A categorization: is this a **bug fix**, **new feature**, **refactor**, **docs update**, or **mixed**?

**[CONFIRM]** Present the summary and category to the user. Ask: "Ready to commit these changes?"

### Step 5: Version Bump

Check if a `VERSION` file exists at project root.

**If VERSION does not exist:** Create it with `0.1.0` as initial version. Inform the user this is the starting version.

**If VERSION exists:** Read current version. Based on the change category from Step 4, determine the bump:

- Bug fix / docs / refactor -> PATCH bump (0.1.0 -> 0.1.1)
- New feature -> MINOR bump (0.2.0 -> 0.3.0)
- Breaking change -> MAJOR bump (0.3.0 -> 1.0.0)

Reference `references/semver-guide.md` for the decision tree if unsure.

For MAJOR bumps, **[CONFIRM]** with user before proceeding (breaking changes are significant).

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

### Step 7: Check README

Check if `README.md` exists at project root.

**If README does not exist:** Skip. Do not create one unless the user asks. (Creating a good README requires user input about project goals, usage, etc.)

**If README exists:** Scan it briefly. Flag if anything is obviously outdated based on the current changes (e.g., removed a script that's still documented, changed CLI flags). Do not rewrite the README -- just flag issues for the user.

### Step 8: Commit

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

### Step 9: Tag

Create a git tag for the new version:

```bash
git tag -a v<VERSION> -m "Release v<VERSION>"
```

### Step 10: Push

**[CONFIRM]** Ask user: "Push to origin/<branch> with tags?"

If confirmed:

```bash
git push origin <branch> --follow-tags
```

### Step 11: GitHub Release (Optional)

Check if `gh` CLI is available by running `gh --version`.

**If gh is available:** Ask user if they want a GitHub Release created.

If yes:

```bash
gh release create v<VERSION> --generate-notes --title "v<VERSION>"
```

**If gh is not available:** Inform user they can install GitHub CLI (`gh`) to create releases from the command line in the future. Provide the install link: https://cli.github.com/

### Step 12: Summary

Print a final summary:

```
Ship complete!
  Branch:    <branch>
  Version:   <old> -> <new>
  Commit:    <short hash> <message>
  Tag:       v<VERSION>
  Remote:    pushed to origin/<branch>
  Release:   <created / skipped>
```

## Error Handling

- **Merge conflicts:** Stop and help the user resolve them before continuing.
- **No remote configured:** Help the user add one with `git remote add origin <url>`.
- **Dirty worktree after commit:** Something went wrong. Run `git status` and investigate.
- **Push rejected:** Likely needs `git pull --rebase` first. Run it and retry push.

## Important Rules

- Never force-push (`--force`) unless the user explicitly requests it and understands the consequences.
- Never skip tests. Failing tests = stop shipping.
- Never commit secrets. If a file looks like it contains API keys or passwords, flag it and add to `.gitignore`.
- Always use specific file staging, never `git add .` or `git add -A`.
- The user is new to git -- provide brief explanations when something unexpected happens (merge conflict, detached HEAD, etc.) rather than just running commands silently.
