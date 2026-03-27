---
name: save
description: Quick save. Commits and pushes current changes with a descriptive message. No tests, no version bump, no changelog, no release, no confirmations. Use when the user says "save", "save my work", "quick save", "just commit", "commit and push", or wants to checkpoint progress without the full shipping ceremony.
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
- Continue to Step 1.

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

**If "Not now":** Write snooze with escalating backoff, then continue to Step 1.
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
Continue to Step 1.

If preamble output is empty or `MARKETPLACE=true`: no update available, continue to Step 1 silently.

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

If `_INSTALL_DIR` is empty: tell user "Could not determine install location. Run `git pull` manually in your github-ship directory." Skip upgrade, continue to Step 1.

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

# Save

Fast commit and push. No ceremony.

## Workflow

### Step 1: Check for changes

Run `git status`. If the working tree is clean (nothing to commit), say "Nothing to save — working tree is clean." and stop.

### Step 2: Secret scan

Check filenames of all changed and untracked files. **Exclude** files inside `.git/`, `node_modules/`, `vendor/`, `__pycache__/`.

- **Exact extension patterns** (block immediately): `.env`, `.env.*` (e.g., `.env.local`), `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.keystore`
- **Exact filename patterns** (block immediately): `id_rsa`, `id_ed25519`, `*.secret`, `*.credentials`
- **Suspicious keyword patterns** (warn and confirm): filenames where `credential`, `secret`, `token`, or `password` appears as a standalone word separated by dots, hyphens, or underscores at BOTH boundaries — e.g., `db-password.txt`, `api-token.json`, `secret.yaml`. Do NOT match when the keyword is embedded inside a compound word — e.g., `token_manager.py`, `credential_validator.go`, `password_hasher.rs` are fine.

**If exact pattern matches:** Block immediately. Warn: "Potential secret detected: <filename>. Add it to .gitignore before saving." Stop.

**If suspicious keyword matches:** Warn: "This filename looks like it might contain secrets: <filename>." Use AskUserQuestion:
- **Skip this file** — don't stage it
- **Include it** — I know it's safe, stage it

This is the ONE exception to /save's no-confirmations rule — potential secrets deserve a pause.

**Examples for clarity:**
- MATCHES (warn): `db-password.txt`, `api-token.json`, `secret.yaml`, `my_secret_config.yaml`
- DOES NOT MATCH (safe): `token_manager.py`, `credential_validator.go`, `password_hasher.rs`, `secrets_handler.rs`, `tokenize.js`

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

If the rebase encounters merge conflicts: stop and show conflicted files. Help the user resolve them, then `git add` each resolved file and `git rebase --continue`. If user wants to abort: `git rebase --abort`. Retry push after rebase completes.

### Step 6: Done

Construct the commit URL from the remote origin URL and the commit hash. Derive the base URL from `git remote get-url origin` (strip `.git` suffix if present, convert SSH to HTTPS), then append `/commit/<full hash>` where the full hash comes from `git rev-parse HEAD`.

Print:
```
███████╗ █████╗ ██╗   ██╗███████╗
██╔════╝██╔══██╗██║   ██║██╔════╝
███████╗███████║██║   ██║█████╗
╚════██║██╔══██║╚██╗ ██╔╝██╔══╝
███████║██║  ██║ ╚████╔╝ ███████╗
╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝

  ✓ Saved
  Branch:  <branch>
  Commit:  <short hash> — <message>
  Remote:  pushed to origin/<branch>
  URL:     <commit URL>
```

## Important Rules

- Never use `git add .` or `git add -A`.
- Never commit secrets. Step 2 catches the obvious ones.
- Never force-push.
- No confirmations, no prompts. This is a fast path.
