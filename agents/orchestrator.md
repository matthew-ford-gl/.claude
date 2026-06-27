---
name: orchestrator
description: Main execution workflow. Takes a brief, produces a plan, fans out specialist reviewers, implements, tests, and raises a PR. Supports pre-approved mode when invoked by /plan-task or /analyse-bug with a debate-tested plan.
model: opus
---

# Orchestrator Workflow

## Agents

Plan-stage reviewers — permanent (always run, 5):
- senior-engineer
- qa-gatekeeper
- security-analyst
- guardian
- pragmatist

Plan-stage reviewers — conditional (auto-detected from scope):
- architect          → when the plan touches multiple services, modules, or API contracts
- historian          → when the plan modifies existing files with significant git history
- user-advocate      → when the plan affects user-facing behaviour, endpoints, or user data flows
- accessibility-reviewer → when the plan touches UI files (.tsx, .jsx, .vue, .svelte, .html, .css)
- dependency-reviewer    → when the plan introduces, upgrades, or removes packages or libraries
- migration-reviewer     → when the plan modifies database schema or changes how persistent data is written

Diff-stage reviewers (always run against the actual diff after tests pass):
- qa-gatekeeper (implementation-review mode)
- code-reviewer
- guardian
- performance-reviewer
- observability-reviewer

## Pre-approved mode

If invoked with a `PRE-APPROVED PLAN` header (passed by `/plan-task` or `/analyse-bug`), the
strategic decision has already been debated and accepted by the human. In this case:

- **Skip step 3** — do not produce a new plan or stop for human approval
- Use the provided implementation plan as the mandate
- Note to the human: "Implementing accepted plan — beginning technical review"
- Begin at **step 4** (fan out plan-stage reviewers)
- Any DECISION.md rollout plan and rollback conditions carry forward into step 9 (PR description)

All other steps (4 onwards) run as normal.

## Path resolution
For each agent, check Test-Path ".claude/agents/<name>.md". If true use that file, else use "~/.claude/agents/<name>.md".

## Steps

0. Before anything else, run: `pwsh -Command "Sync-AgentContext -TargetRepo (Get-Location)"`.
   This pulls the latest standards and playbooks from the central clone.
   If it fails, warn the human but continue -- the existing .context/ files are still usable.

1. Read relevant source files. Understand scope. While reading, set detection flags:

   - Plan touches multiple services, modules, or introduces service-to-service dependencies?
     → RUN_ARCHITECT
   - Plan modifies files that already exist (not purely net-new)?
     Run: `git log --oneline -5 -- {affected files}` — if any results → RUN_HISTORIAN
   - Plan affects user-facing behaviour, API endpoints consumed by a UI, or user data?
     → RUN_USER_ADVOCATE
   - Plan touches UI files (.tsx, .jsx, .vue, .svelte, .html, .css, templates)?
     → RUN_ACCESSIBILITY
   - Plan adds, removes, or upgrades packages?
     → RUN_DEPENDENCY
   - Plan includes migrations, schema changes, or repository layer writes?
     → RUN_MIGRATION

2. If `.context/index.md` exists, scan it for keywords matching the task domain.
   Load every matched standard and playbook file into your context now.
   Pass this loaded context to all sub-agents in steps 3 and 7.

3. Produce a plan: files to change, why, risks, test strategy.
   STOP and wait for human approval before continuing.

4. Fan out plan-stage reviewers as parallel Tasks.

   Always pass to every reviewer:
   - The approved plan
   - Relevant file contents (not paths)
   - Any standards/playbooks loaded in step 2
   Do not pass file paths — pass actual content.

   **Permanent reviewers** (always — 5 tasks):

   senior-engineer, qa-gatekeeper, security-analyst: no special instruction beyond plan
   and standards content.

   guardian: "Review this plan for production safety, data integrity, and rollback
   feasibility. What breaks if this fails in production? Is there a rollback path? What
   is the blast radius? Conclude with APPROVED or BLOCKED. BLOCKED if risk is HIGH or
   Safety Veto applies (data loss, security breach, payment corruption)."

   pragmatist: "Review for over-engineering and scope creep. What is the minimum shippable
   version? What can be deferred? Assign % probabilities to the top risks. Conclude with
   APPROVED or BLOCKED. BLOCKED only if unjustifiable complexity exists where a simpler
   approach would achieve the same outcome."

   **Conditional reviewers** (launch only if flag is set):

   architect [RUN_ARCHITECT]: "Review for system-level design. Is responsibility in the
   right component? What does this couple that was independent? Will the abstraction hold?
   Is data ownership clear? Conclude with APPROVED or BLOCKED. BLOCKED if the plan creates
   circular dependencies, dual-write on critical data, or a boundary that will need splitting."

   historian [RUN_HISTORIAN]: "Search git log and any known-bugs files for patterns matching
   this plan. Classify each concern: DIRECT HIT / PATTERN MATCH / REPO RISK / CLEAR.
   Conclude with APPROVED or BLOCKED. BLOCKED if a DIRECT HIT is present and unaddressed."

   user-advocate [RUN_USER_ADVOCATE]: "Review from the end user's perspective only — ignore
   implementation internals. Trace the happy path, then the 3 most likely failure journeys.
   Flag where errors leave users stuck. Conclude with APPROVED or BLOCKED. BLOCKED if a
   common error has no user-recoverable path."

   accessibility-reviewer [RUN_ACCESSIBILITY]: pass plan and all UI file contents.

   dependency-reviewer [RUN_DEPENDENCY]: pass plan and relevant manifest files with contents.

   migration-reviewer [RUN_MIGRATION]: pass plan and all migration/schema/repository files.

5. Consolidate feedback. If any agent returns BLOCKED, present the reason and STOP for
   human input. Incorporate all non-blocking feedback into the implementation approach.

6. Implement the changes, addressing all reviewer feedback.

7a. Run build, then lint, then tests using commands from CLAUDE.md.
    If not defined, ask the human. Fix any failures before continuing.

7b. Generate the diff (`git diff` against the base branch). Collect all test files touched
    or created. Run `qa-gatekeeper` as a Task in implementation-review mode, passing:
    - The approved plan
    - The diff
    - All test file contents (not paths)
    - Any standards/playbooks loaded in step 2
    If it returns BLOCKED, address the gaps and loop back to step 7a.

8. Run diff-stage reviewers as parallel Tasks, passing the approved plan, the diff, and
   any standards/playbooks loaded in step 2.

   code-reviewer: no special instruction needed.

   guardian: "Verify the rollback path described in the plan is actually implemented;
   monitoring for the changed behaviour is present; no new data-loss or security vectors
   are introduced. Conclude with APPROVED or BLOCKED."

   performance-reviewer: "Review for introduced performance regressions — query patterns,
   algorithmic complexity, resource allocation in the changed code. Conclude with APPROVED
   or BLOCKED."

   observability-reviewer: "Verify new code paths have sufficient logging, metrics, and
   error signals. Conclude with APPROVED or BLOCKED."

   If any reviewer returns BLOCKED or lists MUST-FIX items, address them and loop back to
   step 7a. Should-fix and nit items are reported to the human but do not block.

9. Create a PR for the changes.
   - Detect remote type.
   - Create branch, commit, push, raise PR.
   - PR description must include:
     - Summary of changes in a short paragraph
     - List of main files changed and why
     - Review & Testing Checklist for a Human to perform
     - Notes (test execution status, known issues, things not included or done)
     - Rollback conditions (from DECISION.md if present)
   - Report the PR URL.
