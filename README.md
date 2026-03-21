# github-ship

> Done coding? Say "ship it" and let Claude handle the rest.

## Why

You just finished building a feature. Now you need to: check for secrets, run tests, write a commit message, bump the version, update the changelog, tag, push, maybe create a release. That's 12 steps you have to remember every time — or you skip half of them.

**github-ship does all 12 steps automatically.** Just say "ship it."

## When to Use

- After finishing a feature or bug fix
- After executing an implementation plan
- Any time you'd normally run `git add`, `git commit`, `git push`
- When you want a proper release with version bump, changelog, and GitHub release
- First time shipping a project (github-ship will set up git and remotes for you)

## Before / After

**Before github-ship:**

```
git add... git commit... forgot to update changelog... forgot VERSION...
git push... oh wait, .env is in there... git reset... fix .gitignore...
git add again... git commit --amend... git push...
```

**After github-ship:**

```
"Ship it."
Done.
```

## What It Does

github-ship runs a 12-step workflow:

| Step | What | Details |
|------|------|---------|
| 0 | Environment Check | Verifies git repo exists, remote configured, auth works. Sets up if missing. |
| 1 | Pre-Flight | Branch, remote, changed files summary |
| 2 | .gitignore Audit | Detects language, checks against best practices |
| 3 | Run Tests | Auto-detects test runner for your language |
| 3b | Bug Scan | Runs UBS if installed (optional) |
| 4 | Diff Review | Summarizes changes, asks for confirmation |
| 5 | Version Bump | Semantic versioning (patch/minor/major) |
| 6 | Changelog | Auto-generates from diff |
| 7 | README Check | Flags outdated docs |
| 8 | Commit | Specific file staging, conventional commits |
| 9 | Tag | Git tag with version |
| 10 | Push | Push with tags (asks first) |
| 11 | GitHub Release | Creates release via `gh` CLI (optional) |
| 12 | Summary | Final report |

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
# Copy or symlink the skill:
cp -r github-ship/skills/github-ship ~/.claude/skills/github-ship
```

## Usage

After installation, just use any of these trigger phrases:

- "ship it"
- "commit this"
- "push to GitHub"
- "save my work"
- "release this"

Or invoke directly: `/github-ship`

## Optional Tools

For enhanced bug scanning, install [Ultimate Bug Scanner](https://github.com/Dicklesworthstone/ultimate_bug_scanner). If installed, github-ship automatically runs a bug scan before committing. If not installed, the step is silently skipped.

## Updating

```bash
/plugin update github-ship
```

## Troubleshooting

- **Skill doesn't auto-trigger:** Invoke manually with `/github-ship`. The auto-trigger hook requires bash. On Windows, install [Git for Windows](https://gitforwindows.org/).
- **"Not a git repository" error:** github-ship will offer to set up git for you (Step 0).
- **Push fails with auth error:** Run `gh auth login` or check your SSH keys.
- **No test runner detected:** This is expected for docs-only or unsupported-language projects. github-ship warns and continues.

## Acknowledgments

This project was inspired by the "Full GitHub Flow" prompt in [Agent Flywheel](https://agent-flywheel.com/workflow) by [Jeffrey Emanuel](https://x.com/doodlestein) ([@Dicklesworthstone](https://github.com/Dicklesworthstone)). Check out his work on agentic workflows — it's excellent.

Built by [Anthony Buitran](https://x.com/anthonybuitran) ([@hotsauce9000](https://github.com/hotsauce9000)).

## License

MIT — see [LICENSE](LICENSE) for details.
