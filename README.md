# Claude Code Global Config

Personal Claude Code configuration: global instructions, agents, commands, and hooks.

> **Note:** `settings.json` contains an `apiKeyHelper` with a credential — review before pushing to a public remote.

## Structure

```
~/.claude/
├── CLAUDE.md           # Global instructions loaded into every session
├── settings.json       # Permissions, hooks wiring, env vars, model
├── keybindings.json    # Custom key bindings
├── agents/             # Sub-agent definitions
└── commands/           # Slash commands (skills)
    hooks/              # Shell scripts called by hook events
```

## Commands

### `/ship <task>`

Orchestrates a task end-to-end through specialist agents and raises a PR.

**Workflow** (defined in [agents/orchestrator.md](agents/orchestrator.md)):

1. Sync standards from central clone (`Sync-AgentContext`)
2. Read source files and load relevant standards from `.context/index.md`
3. **Produce a plan — pause for human approval**
4. Fan out three plan-stage reviewers in parallel
5. Consolidate feedback; stop if any agent is BLOCKED
6. Implement changes
7. Build → lint → test; fix failures
8. Run diff-stage code reviewer; fix MUST-FIX items
9. Create branch, commit, push, raise PR

## Agents

| Agent | Stage | Purpose |
|---|---|---|
| `senior-engineer` | Plan | Design concerns, edge cases, maintainability |
| `qa-gatekeeper` | Plan | Test coverage, testability, regression risks |
| `security-analyst` | Plan | Auth gaps, injection risks, data exposure |
| `code-reviewer` | Diff | Plan-drift, bugs visible in the diff, code quality |

All agents respond with **APPROVED** or **BLOCKED** (reason required if blocked). Plan-stage reviewers run in parallel; the diff-stage reviewer runs after tests pass.

## Hooks

| Hook | Trigger | Script |
|---|---|---|
| Notification sound | Any Claude notification | `play-notification.sh` — plays `Speech Slap.wav` |
| Stop sound | Claude session ends | `play-stop.sh` — plays `tada.wav` |
| Git co-author | After any `Bash(git commit)` | `git-coauthor.sh` — amends the commit to add `Co-authored-by: Claude` trailer |

## Setup on a new machine

```powershell
# Clone directly to the expected path
git clone <remote-url> "$env:USERPROFILE\.claude"
```

Claude Code loads from `~/.claude/` automatically — no additional configuration needed.

### Per-repo overrides

Drop agent or command overrides in `.claude/agents/<name>.md` at the repo root. The orchestrator and `CLAUDE.md` both prefer repo-local files over these global ones.
