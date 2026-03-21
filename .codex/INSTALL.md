# Installing github-ship for Codex

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/hotsauce9000/github-ship.git ~/.codex/github-ship
   ```

2. Create the skills symlink:
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/github-ship/skills/github-ship ~/.agents/skills/github-ship
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\github-ship" "$env:USERPROFILE\.codex\github-ship\skills\github-ship"
   ```

3. Restart Codex.

## Updating

```bash
cd ~/.codex/github-ship && git pull
```
