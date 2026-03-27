# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [2.1.2] - 2026-03-27

### Changed
- `/save` completion banner now shows block-char "SAVE" ASCII art above the summary, matching the style of `/github-ship` and `/github-pr`

## [2.1.1] - 2026-03-27

### Fixed
- Cross-skill path references — `/github-pr` now has its own `references/` directory instead of relying on `../github-ship/references/` (broke after manual `cp -r` install)
- Secret scan false positives in `/save` — keyword patterns (`token`, `credential`, etc.) now use word-boundary matching instead of substring matching; `token_manager.py` no longer blocked
- Missing `.gitignore` handling — `/github-pr` and `/github-ship` now create one with standard patterns if none exists
- Merge conflict handling — all three skills now guide users through `git rebase` conflict resolution instead of just saying "stop and report"
- Commit grouping threshold aligned to `4+ files` in both `/github-pr` and `/github-ship` (was `3+` in `/github-ship`)
- `sort -V` replaced with portable `_ver_gte` bash function in `bin/update-check` (BSD sort on older macOS lacks `-V`)
- LOCAL version validated with semver regex before comparison in `bin/update-check` (prevents crash on pre-release strings like `2.1.0-beta`)
- CRLF line ending handling in `hooks/session-start` — frontmatter parsing now strips `\r` before matching
- Stderr warnings added to `hooks/session-start` when SKILL.md descriptions can't be read (was silent fallback)
- LOCALAPPDATA Git path check added to `hooks/run-hook.cmd` for Windows winget installs
- `package.json` version synced to `2.1.0` (was still `2.0.0`)

### Added
- Test infrastructure: 5 bash test scripts with 114 assertions, runnable via `npm test`
- `tests/test-session-start.sh` — 6 tests covering happy path, env detection, missing SKILL.md, JSON escaping
- `tests/test-update-check.sh` — 9 tests covering version comparison, caching, snooze, disabled check, just-upgraded marker
- `tests/validate-skills.sh` — structural validation of all SKILL.md files (frontmatter, preamble, required sections)
- `tests/validate-references.sh` — path integrity, cross-skill reference detection, orphan files, drift sync between duplicated references
- `tests/validate-consistency.sh` — cross-skill consistency (thresholds, commit types, platform detection, language order)
- Explicit match/no-match examples in `/save` secret scan spec for LLM interpretation clarity

## [2.1.0] - 2026-03-27

### Added
- Auto-update notifications — checks for new versions when any skill is invoked (/save, /github-pr, /github-ship)
- 4-option upgrade menu: upgrade now, auto-upgrade, snooze (escalating 24h/48h/7d), disable
- `bin/update-check` script with caching (60min up-to-date, 720min upgrade-available)
- Semver comparison prevents presenting downgrades as upgrades
- Security: VERSION response validated with semver regex to block prompt injection
- Upgrade uses `git pull` (safe, preserves local changes) not `git reset --hard`
- Marketplace installs auto-detected and skipped (platform handles updates)
- `--force` flag for manual cache/snooze busting

## [2.0.0] - 2026-03-26

### Added
- `/save` skill — fast commit+push with no ceremony (6 steps: status, secret scan, stage, commit, push, done)
- `/github-pr` skill — team PR workflow with 10 steps: environment check, branch management, .gitignore audit, tests, diff review, commit, push, PR creation, reviewers/labels, summary
- PR body templates using Problem / Solution / Why / Test plan structure (non-trivial) or 1-2 sentence summary (trivial)
- Existing-PR detection — checks if a PR already exists before creating a new one
- Platform detection — auto-detect GitHub vs GitLab from remote URL, with CLI fallback
- Base branch detection — 4-step fallback chain (existing PR → repo default → git symbolic-ref → `main`)
- Test failure triage — classify failures as in-branch (must fix) vs pre-existing (can override)
- Commit grouping in `/github-ship` — opt-in split of multi-concern changes into logical commits
- Verification gate — re-run tests if code changed between test step and push/tag
- CHANGELOG cross-check — verify every commit maps to at least one changelog bullet
- Bisectable commits in `/github-pr` — offer to split multi-concern changes
- GitLab support — `glab` CLI for MR creation and releases alongside `gh` for GitHub
- Branch safety check in `/github-ship` — warns if shipping from a feature branch
- Draft PR support in `/github-pr`
- Reviewer suggestions from CODEOWNERS and recent PR history
- Label suggestions based on change category

### Changed
- `/github-ship` Step 11 (GitHub Release) now uses CHANGELOG entry as release body instead of `--generate-notes`
- `/github-ship` description no longer includes "save my work" (now handled by `/save`)
- SessionStart hook registers all three skills: `/save`, `/github-pr`, `/github-ship`
- Plugin metadata updated for all platforms (Claude Code, Cursor, Codex, Gemini CLI)
- README rewritten with decision table, side-by-side comparison, and all three workflows

## [1.2.0] - 2026-03-21

### Added
- Auto-pilot mode (Step 0a) — run entire workflow with recommended defaults, only stopping on critical issues
- AskUserQuestion interactive picker menus at all confirmation checkpoints with recommended option marked

### Changed
- All [CONFIRM] checkpoints now use AskUserQuestion tool for clickable interactive menus instead of plain numbered text lists
- Workflow preamble updated with AskUserQuestion and auto-pilot mode instructions

## [1.1.0] - 2026-03-21

### Added
- Block-style SHIPPED ASCII art banner in Step 12 summary output
- First-run-only interactive star prompt using `gh repo star` (gated by `~/.github-ship-star-prompted` marker file)
- Structured prompt options (numbered lists) at all 6 confirmation checkpoints
- SHIPPED ASCII art banner at top of README

### Changed
- Step 12 summary now uses checkmarks (✓/✗) and arrow (→) instead of plain text
- All confirmation points now present numbered options instead of open-ended questions

## [1.0.0] - 2026-03-20

### Added
- Initial release as Claude Code plugin
- 12-step shipping workflow: environment check, pre-flight, gitignore audit, tests, UBS scan, diff review, version bump, changelog, README check, commit, tag, push, release
- Multi-language gitignore references (Python, Node, Rust, Go, Ruby, PHP, Java, general)
- Multi-language test runner detection (pytest, npm, cargo, go test, rspec, phpunit, gradle/maven)
- Semantic versioning reference guide
- Step 0 environment check — sets up git, remote, and verifies auth for first-time users
- SessionStart hook for automatic skill discovery
- Cross-platform support (Windows + Unix) via polyglot hook wrapper
- Installation support for Claude Code, Cursor, Codex, and Gemini CLI
- Star prompt at workflow completion
