# Orchestrator Workflow

## Agents

Plan-stage reviewers — permanent (always run):
- senior-engineer
- qa-gatekeeper
- security-analyst
- guardian
- historian
- pragmatist
- performance-reviewer
- observability-reviewer
- architect
- user-advocate

Plan-stage reviewers — conditional (run when detected):
- accessibility-reviewer  → when the plan touches UI, components, pages, or user-facing markup
- dependency-reviewer     → when the plan introduces, upgrades, or removes packages or libraries
- migration-reviewer      → when the plan modifies database schema, runs data migrations, or changes how persistent data is written

Diff-stage reviewers (always run against the actual diff after tests pass):
- qa-gatekeeper (implementation-review mode)
- code-reviewer
- guardian
- performance-reviewer
- observability-reviewer

## Pre-approved mode

If invoked with a `PRE-APPROVED PLAN` header (passed by `/plan-task`), the strategic
decision has already been debated and accepted by the human. In this case:

- **Skip step 3** — do not produce a new plan or stop for human approval
- Use the provided implementation plan and DECISION.md as the mandate
- Note to the human: "Implementing accepted plan from /plan-task — beginning technical review"
- Begin at **step 4** (fan out plan-stage reviewers), passing the provided plan and analyses
  as the plan content
- The DECISION.md's test strategy, rollout plan, and rollback conditions carry forward into
  step 9 (PR description)

All other steps (4 onwards) run as normal.

## Path resolution
For each agent, check Test-Path ".claude/agents/<name>.md". If true use that file, else use "~/.claude/agents/<name>.md".

## Steps

0. Before anything else, run: `pwsh -Command "Sync-AgentContext -TargetRepo (Get-Location)"`.
   This pulls the latest standards and playbooks from the central clone.
   If it fails, warn the human but continue -- the existing .context/ files are still usable.

1. Read relevant source files. Understand scope. While reading, note:
   - Does the plan touch any UI files (.tsx, .jsx, .vue, .svelte, .html, .css, templates)?
     → set flag: RUN_ACCESSIBILITY
   - Does the plan add, remove, or upgrade packages (package.json, pom.xml, build.gradle,
     requirements.txt, go.mod, Cargo.toml, *.csproj, etc.)?
     → set flag: RUN_DEPENDENCY
   - Does the plan include database migrations, schema changes, or changes to how persistent
     data is written (migration files, ORM model changes, SQL files, repository layer changes)?
     → set flag: RUN_MIGRATION

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

   **Permanent reviewers** (always run — 8 tasks):

   senior-engineer, qa-gatekeeper, security-analyst: no special instruction needed beyond
   the plan and standards content.

   guardian: append — "Review this plan for production safety, user impact, data integrity,
   and rollback feasibility. Check: what breaks if this fails in production? Is there a
   rollback path? What is the blast radius? Does anything risk data loss or a security breach?
   Conclude with APPROVED or BLOCKED. BLOCKED is required if risk is HIGH or you are
   exercising the Safety Veto (data loss, security breach, payment corruption)."

   historian: append — "Search the git log and any documented known-bugs or incident files
   in this codebase for patterns relevant to this plan. Classify each concern as DIRECT HIT /
   PATTERN MATCH / REPO RISK / CLEAR. Conclude with APPROVED or BLOCKED. BLOCKED is required
   if a DIRECT HIT pattern is present that the plan does not explicitly address."

   pragmatist: append — "Review this plan for over-engineering, unnecessary complexity, and
   scope creep. Ask: what is the minimum shippable version of this? What can be deferred
   without losing core value? Assign a probability (%) to each significant risk. Conclude
   with APPROVED or BLOCKED. BLOCKED is required only if the plan proposes unjustifiable
   complexity where a simpler approach would achieve the same outcome."

   performance-reviewer: no special instruction needed beyond the plan and file contents.

   observability-reviewer: no special instruction needed beyond the plan and file contents.

   architect: append — "Review this plan for system-level design quality. Ask: is
   responsibility placed in the right component or service? What does this couple together
   that was previously independent? Will this abstraction hold under foreseeable future
   requirements? Is data ownership clear? Conclude with APPROVED or BLOCKED. BLOCKED is
   required if the plan creates a circular dependency, a dual-write pattern for critical
   data, or places responsibility in a component that will need to be split as a result."

   user-advocate: append — "Review this plan from the perspective of the end user. Ignore
   implementation internals — focus only on what the user experiences. Trace the happy path
   end-to-end, then identify the 3–5 most likely edge case journeys (partial completion,
   error recovery, re-entry, empty state). Flag anywhere the technical model leaks into the
   user experience or where an error leaves the user stuck with no recovery path. Only raise
   concerns that are visible to or felt by the user — do not comment on code structure,
   test coverage, or system internals. Conclude with APPROVED or BLOCKED. BLOCKED is
   required if a common error scenario has no user-recoverable path."

   **Conditional reviewers** (run only if the corresponding flag is set):

   accessibility-reviewer [if RUN_ACCESSIBILITY]: pass the plan and all UI file contents.

   dependency-reviewer [if RUN_DEPENDENCY]: pass the plan and the relevant manifest files
   (package.json, pom.xml, etc.) with their full contents.

   migration-reviewer [if RUN_MIGRATION]: pass the plan and all migration files, schema
   definitions, and repository layer files relevant to the change.

5. Consolidate feedback. If any agent returns BLOCKED, present the reason and STOP for
   human input. Incorporate all non-blocking feedback from all reviewers into the
   implementation approach before proceeding.

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

8. Run diff-stage reviewers as parallel Tasks, passing:
   - The approved plan
   - The diff
   - Any standards/playbooks loaded in step 2

   code-reviewer: no special instruction needed.

   guardian: append — "Review the diff for production safety. Verify: the rollback path
   described in the plan is actually implemented; monitoring or logging for the changed
   behaviour is present; no new data-loss or security-breach vectors are introduced.
   Conclude with APPROVED or BLOCKED."

   performance-reviewer: append — "Review the diff for introduced performance regressions.
   Focus on query patterns, algorithmic complexity, and resource allocation in the changed
   code. Conclude with APPROVED or BLOCKED."

   observability-reviewer: append — "Review the diff for observability completeness. Verify
   that new code paths have sufficient logging, metrics, and error signals. Conclude with
   APPROVED or BLOCKED."

   If any reviewer returns BLOCKED or lists MUST-FIX items, address them and loop back to
   step 7a. Should-fix and nit items are reported to the human but do not block.

9. Create a PR for the changes.
   - Detect remote type.
   - Create branch, commit, push, raise PR.
   - The PR must have a descriptive title and description of changes within:
     - Summary of changes in a short paragraph
     - List of main files changed and why
     - Review & Testing Checklist for a Human to perform
     - Notes (test execution status, known issues, things not included or done...etc.)
   - Report the PR URL.
