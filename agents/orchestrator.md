# Orchestrator Workflow

## Agents

Plan-stage reviewers (run in parallel against the proposed plan):
- senior-engineer
- qa-gatekeeper
- security-analyst

Diff-stage reviewer (runs against the actual diff after tests pass):
- code-reviewer

## Path resolution
For each agent, check Test-Path ".claude/agents/<name>.md". If true use that file, else use "~/.claude/agents/<name>.md".

## Steps

0. Before anything else, run: `pwsh -Command "Sync-AgentContext -TargetRepo (Get-Location)"`.
   This pulls the latest standards and playbooks from the central clone.
   If it fails, warn the human but continue -- the existing .context/ files are still usable.

1. Read relevant source files. Understand scope.

2. If `.context/index.md` exists, scan it for keywords matching the task domain.
   Load every matched standard and playbook file into your context now.
   Pass this loaded context to all sub-agents in steps 3 and 7.

3. Produce a plan: files to change, why, risks, test strategy.
   STOP and wait for human approval before continuing.

4. Fan out the three plan-stage reviewers as parallel Tasks, passing:
   - The approved plan
   - Relevant file contents (not paths)
   - Any standards/playbooks loaded in step 2
   Do not pass file paths -- pass actual content.

5. Consolidate feedback. If any agent returns BLOCKED, present the reason and STOP for human input.

6. Implement the changes, addressing all agent feedback.

7a. Run build, then lint, then tests using commands from CLAUDE.md.
    If not defined, ask the human. Fix any failures before continuing.

7b. Generate the diff (`git diff` against the base branch). Collect all test files touched or created.
    Run `qa-gatekeeper` as a Task in implementation-review mode, passing:
    - The approved plan
    - The diff
    - All test file contents (not paths)
    - Any standards/playbooks loaded in step 2
    If it returns BLOCKED, address the gaps and loop back to step 7a.

8. Run `code-reviewer` as a Task, passing:
   - The approved plan
   - The diff
   - Any standards/playbooks loaded in step 2
   If it returns BLOCKED or lists MUST-FIX items, address them and loop back to step 7a.
   Should-fix and nit items are reported to the human but do not block.

9. Create a PR for the changes.
   - Detect remote type. 
   - Create branch, commit, push, raise PR. 
   - The PR must have a descriptive title and description of changes within.
     - Summary of changes in a short paragraph
     - List of main files changed and why
     - Review & Testing Checklist for a Human to perform
     - Notes (test execution status, known issues, things not included or done...etc.)
   - Report the PR URL.