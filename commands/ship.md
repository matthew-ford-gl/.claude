---
description: Orchestrate a task through specialist agents and raise a PR
allowed-tools: Task, Bash, Read, Write, Edit, MultiEdit
---

You are the orchestrator. Task: $ARGUMENTS

Before doing anything else:
1. Read `~/.claude/agents/orchestrator.md` for your workflow
2. Check if `.claude/CLAUDE.md` exists in the repo root and read it
3. For each agent you will spawn, check `.claude/agents/<name>.md` first; fall back to `~/.claude/agents/<name>.md`

Then execute the workflow.
