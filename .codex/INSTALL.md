# Installing github-ship for Codex

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/hotsauce9000/github-ship.git ~/.codex/github-ship
   ```

2. Create the skills symlinks:
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/github-ship/skills/github-ship ~/.agents/skills/github-ship
   ln -s ~/.codex/github-ship/skills/github-pr ~/.agents/skills/github-pr
   ln -s ~/.codex/github-ship/skills/save ~/.agents/skills/save
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\github-ship" "$env:USERPROFILE\.codex\github-ship\skills\github-ship"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\github-pr" "$env:USERPROFILE\.codex\github-ship\skills\github-pr"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\save" "$env:USERPROFILE\.codex\github-ship\skills\save"
   ```

3. Restart Codex.

## Updating

```bash
cd ~/.codex/github-ship && git pull
```
