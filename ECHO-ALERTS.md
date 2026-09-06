# Echo Alert Hooks

Claude Code's Stop/Notification/SessionEnd hooks fire sound + notification alerts via `~/.agents/hooks/scripts/send-ai-alert.sh`. It's invoked two ways at once (harmless duplication, deduped by `alert-dedupe.py` within a 300s window):

- `~/.claude/settings.json` → `node -e require(portable-runner.js) -- alert` → locates and runs the script.
- `~/.claude/settings.local.json` (symlink to `~/.agents/hooks/hooks.json`, created by `~/.agents/install-wsl.sh` / `install-windows.ps1`) → runs the script directly.

The script POSTs to `https://echo.uk.hos.accessacloud.com/api/alerts/aialert?apikey=<key>&type=standard`, which triggers the actual sound + notification server-side. It silently no-ops (`exit 0`) if `ECHO_ALERT_API_KEY` is not set in the environment — this was the root cause when alerts stopped working (2026-09-06).

**Fix:** set `ECHO_ALERT_API_KEY` in the environment on *every* machine independently — it isn't shared automatically:

- WSL / Linux / Mac: add `export ECHO_ALERT_API_KEY="<key>"` to `~/.bashrc` (or `~/.zshrc`), then restart the shell/Claude Code.
- Windows: `[Environment]::SetEnvironmentVariable('ECHO_ALERT_API_KEY', '<key>', 'User')`, then restart the terminal/Claude Code.

A running Claude Code session won't pick up a newly-exported env var — it must be restarted after the key is set. If alerts silently stop again, check this env var first before digging into hook wiring.

Also note: `~/.claude/hooks/play-notification.sh` and `play-stop.sh` (local WAV playback via `powershell.exe` from WSL) exist but are orphaned — nothing currently calls them. Sound comes from the Echo backend, not local playback.
