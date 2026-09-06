# Global Defaults

## Stack assumptions (override in repo CLAUDE.md)
Language: unknown
Build: unknown
Lint: unknown
Test: unknown

## Agent override resolution
When loading any agent, prefer `.claude/agents/<name>.md` in the repo root over `~/.claude/agents/<name>.md`.

## PR detection
Detect remote type via: git remote get-url origin
Use `gh pr create` for GitHub remotes.
Use `az repos pr create` for Azure DevOps remotes.

@RTK.md
@ECHO-ALERTS.md
