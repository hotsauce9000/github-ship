---
name: save
description: Quick save. Commits and pushes current changes with a descriptive message. No tests, no version bump, no changelog, no release, no confirmations. Use when the user says "save", "save my work", "quick save", "just commit", "commit and push", or wants to checkpoint progress without the full shipping ceremony.
---

# Save

Fast commit and push. No ceremony.

## Workflow

### Step 1: Check for changes

Run `git status`. If the working tree is clean (nothing to commit), say "Nothing to save — working tree is clean." and stop.

### Step 2: Secret scan

Check filenames of all changed and untracked files:
- **Exact patterns** (block immediately): `.env`, `.env.*` (e.g., `.env.local`), `*.pem`, `*.key` (file extension)
- **Substring patterns** (block immediately): `credential`, `secret`, `token`, `password` — but only when they appear in the filename stem, NOT in directory names like `node_modules/`
- **Exclude:** files inside `.git/`, `node_modules/`, `vendor/`, `__pycache__/`

If any match, warn the user: "Potential secret detected: <filename>. Add it to .gitignore before saving." Stop — do not commit secrets.

### Step 3: Stage files

Stage all changed and untracked files individually. Never use `git add .` or `git add -A` — always stage specific files by name.

### Step 4: Commit

Generate a commit message from the diff. Use conventional commit format:

```
<type>: <short description>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Where `<type>` is: `feat`, `fix`, `refactor`, `docs`, `test`, or `chore`.

Use a HEREDOC for the message to preserve formatting. If the diff spans multiple concerns, pick the dominant one for the type.

### Step 5: Push

```bash
git push origin <current branch>
```

If push is rejected, run `git pull --rebase origin <branch>` and retry once. If still rejected, stop and report.

### Step 6: Done

Print:
```
  ✓ Saved
  Branch:  <branch>
  Commit:  <short hash> — <message>
  Remote:  pushed to origin/<branch>
```

## Important Rules

- Never use `git add .` or `git add -A`.
- Never commit secrets. Step 2 catches the obvious ones.
- Never force-push.
- No confirmations, no prompts. This is a fast path.
