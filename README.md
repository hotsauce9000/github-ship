```
███████╗██╗  ██╗██╗██████╗ ██████╗ ███████╗██████╗
██╔════╝██║  ██║██║██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████╗███████║██║██████╔╝██████╔╝█████╗  ██║  ██║
╚════██║██╔══██║██║██╔═══╝ ██╔═══╝ ██╔══╝  ██║  ██║
███████║██║  ██║██║██║     ██║     ███████╗██████╔╝
╚══════╝╚═╝  ╚═╝╚═╝╚═╝     ╚═╝     ╚══════╝╚═════╝
```

# github-ship

> Done coding? Three commands:
> - `/save` — quick checkpoint. Commit and push, nothing else.
> - `/github-pr` — working with a team? Open a PR.
> - `/github-ship` — working solo? Tag and release.

## When to Use What

| Situation | Command |
|-----------|---------|
| Quick checkpoint mid-session | `/save` |
| Feature branch → PR for review | `/github-pr` |
| Bug fix → PR for review | `/github-pr` |
| Solo project → release | `/github-ship` |
| Merged PR → cut a release | `/github-ship` |
| First time shipping anything | Any — all handle git setup |

## What Each Command Does

| | `/save` | `/github-pr` | `/github-ship` |
|---|---|---|---|
| Environment check | | ✓ | ✓ |
| Platform detection (GitHub/GitLab) | | ✓ | ✓ |
| Branch management | | ✓ Creates feature branch if needed | Warns if not on main |
| .gitignore audit | | ✓ | ✓ |
| Secret filename scan | ✓ | ✓ | ✓ |
| Run tests | | ✓ With failure triage | ✓ With failure triage |
| Bug scan (UBS) | | ✓ | ✓ |
| Diff review + commit | ✓ Auto | ✓ With bisectable commits | ✓ With opt-in grouping |
| Verification gate | | ✓ Re-runs tests if code changed | ✓ Re-runs tests if code changed |
| Version bump | | | ✓ |
| Changelog | | | ✓ With cross-check |
| README check | | | ✓ |
| Tag | | | ✓ |
| Push | To current branch | To feature branch | To main with tags |
| Create PR | | ✓ With Problem/Solution/Why format | |
| Reviewers & labels | | ✓ Suggests from CODEOWNERS | |
| GitHub/GitLab Release | | | ✓ From changelog |
| Speed | ~5 seconds | ~1 minute | ~2 minutes |

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
# Copy or symlink all three skills:
cp -r github-ship/skills/save ~/.claude/skills/save
cp -r github-ship/skills/github-ship ~/.claude/skills/github-ship
cp -r github-ship/skills/github-pr ~/.claude/skills/github-pr
```

## Usage

**`/save`** (slash command or natural language):
- "save"
- "save my work"
- "quick save"
- "just commit"
- "commit and push"

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

All three commands support **auto-pilot mode** — run the workflow with recommended defaults, only stopping on critical issues (except `/save`, which has no confirmations by design).

## Optional Tools

For enhanced bug scanning, install [Ultimate Bug Scanner](https://github.com/Dicklesworthstone/ultimate_bug_scanner). If installed, `/github-pr` and `/github-ship` automatically run a bug scan before committing. If not installed, the step is silently skipped.

## Updating

```bash
/plugin update github-ship
```

## Troubleshooting

- **Skill doesn't auto-trigger:** Invoke manually with `/save`, `/github-ship`, or `/github-pr`. The auto-trigger hook requires bash. On Windows, install [Git for Windows](https://gitforwindows.org/).
- **"Not a git repository" error:** `/github-pr` and `/github-ship` offer to set up git for you (Step 0). `/save` requires git to already be set up.
- **Push fails with auth error:** Run `gh auth login` (GitHub) or `glab auth login` (GitLab), or check your SSH keys.
- **No test runner detected:** Expected for docs-only or unsupported-language projects. `/github-pr` and `/github-ship` warn and continue. `/save` doesn't run tests.
- **PR creation fails:** Code is already pushed. Create the PR manually via the web UI.
- **GitLab not detected:** Ensure `glab` CLI is installed and authenticated (`glab auth status`).
- **Secret false positive:** `/save` blocks files matching exact secret patterns (`.env`, `*.pem`, `*.key`) and warns on keyword patterns (`credential`, `secret`, `token`, `password` as standalone words in filename). Keyword warnings let you choose to include the file. Compound names like `token_manager.py` are not flagged.

## Acknowledgments

This project was inspired by the "Full GitHub Flow" prompt in [Agent Flywheel](https://agent-flywheel.com/workflow) by [Jeffrey Emanuel](https://x.com/doodlestein) ([@Dicklesworthstone](https://github.com/Dicklesworthstone)). Check out his work on agentic workflows.

Built by [Anthony Buitran](https://x.com/anthonybuitran) ([@hotsauce9000](https://github.com/hotsauce9000)).

## License

MIT — see [LICENSE](LICENSE) for details.
