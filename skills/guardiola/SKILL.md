---
name: guardiola
description: End-to-end implementation orchestrator that asks clarifying questions, writes an implementation plan markdown file, executes it via Bob Builder, runs Mr. Milchick review, and delegates commit/PR writing or creation to Little in a strict synchronous flow. Use when the user invokes Guardiola, asks for the Guardiola flow, or continues a Guardiola workflow in the same chat with follow-up requests like continue, implement, review, create PR, or similar stage-advancing prompts.
---

# Guardiola

Synchronous delivery orchestrator. Guardiola converts rough intent into a validated implementation plan, executes it via Bob Builder, and then runs Mr. Milchick for post-implementation refinement.

## Trigger Phrases

Apply this skill when prompts include phrases like:

- "Guardiola"
- "Guardiola flow"
- "Plan then implement then review"
- "Create a plan and execute it"
- "Run Bob Builder and then Milchick"

Also apply this skill to follow-up turns in the same chat after Guardiola has already been invoked, even if the user does not repeat "Guardiola".

## Hard Rule: Chat-Scoped Activation

Once the user explicitly invokes `Guardiola` in a chat, treat the remainder of that chat as an active Guardiola workflow until one of these happens:

- The user explicitly exits or cancels the Guardiola flow.
- The user clearly switches to a different named workflow or unrelated task.
- The conversation ends.

While Guardiola is active:

- Interpret every follow-up message through the Guardiola pipeline and current stage state.
- Do not require the user to repeat `Guardiola` on later turns.
- Treat answers to clarifying questions as Guardiola inputs for the current plan.
- Treat short follow-ups like `continue`, `go ahead`, `implement it`, `run review`, `create a PR`, or `update the plan` as stage-specific Guardiola instructions.
- If the requested action maps to a later stage, use the existing Guardiola artifacts from the chat first instead of falling back to a generic workflow.
- If the request is ambiguous, ask which Guardiola stage the user wants to advance.

Persist this workflow state across turns:

- Ticket or problem statement
- Clarifications and user answers
- Current stage
- Plan file path
- Approval status for moving to implementation
- Implementation completion status
- Refinement report path
- PR description status

Example:

1. User: `Guardiola check this JIRA ticket - <url>`
2. Guardiola asks clarifying questions and receives answers over several turns.
3. User: `Create a PR`
4. Interpret that as a Guardiola Stage 4 request. Reuse the plan, implementation context, and Milchick output from this chat. If a prerequisite stage is incomplete, report the blocked stage and the next gate instead of switching to a generic PR flow.

## Hard Rule: Strict Sequence

Always run this pipeline in order, with no reordering:

1. Clarify and plan (Guardiola)
2. Implement (Bob Builder)
3. Refine/review (Mr. Milchick)
4. PR writing or PR creation (Little)

Do not start the next stage until the current stage is explicitly complete.

## Hard Rule: Commit After Every Step

Every completed implementation step MUST be followed by a commit using `Little create commit` before starting the next step. This applies to:

- Each implementation step defined in the plan's `Implementation Steps` section.
- Each slice defined in the `Commit/PR Slicing Plan`.
- Test-first steps (e.g., writing tests before implementation in TDD workflows).

Rationale: atomic commits make review, bisect, and rollback safer. Never batch multiple steps into one commit unless the steps are trivially coupled (e.g., a one-line fix and its test).

## Stage 1: Clarify and Plan

### 1.1 Gather Context

- Read the user request and any referenced files.
- Identify unknowns that can change architecture, scope, data model, API contract, UX behavior, testing strategy, or rollout risk.
- If uncertainty remains, clarify via the grill-me interview in 1.2.

### 1.2 Clarify via grill-me

Drive clarification through the `grill-me` skill instead of an ad-hoc question dump. Invoke `grill-me` to interview the user about the plan:

- Ask one question at a time, walking the decision tree and resolving dependencies between decisions in order (later questions must reflect earlier answers).
- For every question, provide a recommended answer the user can accept or override.
- Before asking, explore the codebase to answer anything that can be resolved there; only ask the user what the code cannot tell you.

Run the full grill-me interview to remove ambiguity across architecture, scope, data model, API contract, UX behavior, testing strategy, and rollout risk.

Termination:

- End the interview once enough is resolved to write a plan that passes the Plan Quality Gate (1.4) — do not keep grilling past that point.
- If the user is unavailable or asks to proceed on assumptions, stop the interview, list the assumptions explicitly, and continue to 1.3.

### 1.3 Produce the Plan File

Create a new markdown file in the project root:

- Preferred filename: `implementation-plan-YYYY-MM-DD.md`
- If a ticket exists, prefer: `implementation-plan-<ticket>-YYYY-MM-DD.md`

Minimum required sections:

1. Objective
2. Scope (in/out)
3. Assumptions
4. Implementation Steps (ordered, concrete)
5. Commit/PR Slicing Plan
6. Data/Schema changes (if any)
7. API/LiveView/UI changes (if any)
8. Risks and Mitigations
9. Test Plan
10. Rollback/Recovery notes (when relevant)

### 1.3.1 Commit/PR Slicing Plan Requirements

The `Commit/PR Slicing Plan` section is mandatory and must define:

- Planned commit sequence (small, logical, ordered).
- What each commit includes and explicitly excludes.
- Dependency order between commits.
- PR strategy (single concise PR with clean commit history, or stacked PRs if needed).
- Suggested commit checkpoints for safe review and rollback.
- PR size budget:
  - Hard maximum per PR: `<= 1000` added lines.
  - Preferred target per PR: `<= 800` added lines (buffer for review feedback changes).
- Proposed split strategy when size risk exists (for example by vertical slice, backend/frontend, risk isolation, or tests/docs follow-up PR).

### 1.4 Plan Quality Gate (Must Pass)

Before Stage 2, verify:

- The plan file exists.
- Steps are actionable and ordered.
- Commit/PR slicing is explicit, realistic, and concise.
- PR-size budget is defined and no planned PR exceeds `1000` added lines.
- Risks and test strategy are present.
- Open questions are either resolved or marked as assumptions.

If any gate fails, fix the plan first. Do not continue.

### 1.5 User Approval Gate (Mandatory)

After the plan quality gate passes, **always** ask the user for explicit approval before moving to Stage 2.

- Present a short summary of the plan: objective, number of implementation steps, planned commits/PRs, and any notable risks.
- Ask: "The plan is ready. Can I move to the implementation?"
- **Do not** proceed to Stage 2 until the user explicitly confirms (e.g., "yes", "go ahead", "proceed").
- If the user requests changes, update the plan, re-run the quality gate (1.4), and ask for approval again.

### 1.6 PR Splitting Heuristics (Reviewer First)

When proposing splits, prefer reviewer-friendly boundaries in this order:

1. Vertical slices by behavior (end-to-end increments).
2. Layer split (backend first, frontend follow-up) when coupling is low.
3. Risk split (safe prep/migration first, behavior switch later).
4. Non-functional follow-ups (cleanup/docs/extra tests) in separate PRs.

Each PR should remain independently understandable, testable, and reversible.

## Stage 2: Hand Off to Bob Builder

### 2.1 Invocation Contract

Tell Bob Builder to:

- Read the full plan file first.
- Restate the plan briefly.
- Call out assumptions that still matter.
- Implement exactly what the plan requires.
- Follow the plan's commit slicing and keep commits atomic.
- Avoid mixing unrelated refactors into feature commits.
- Follow project conventions (including i18n and SonaUI guidance when UI is touched).
- Add/update tests matching the plan.

### 2.2 Execution Gate (Must Pass)

Before Stage 3, verify implementation is complete:

- Planned code changes are applied.
- Commit history follows the planned slicing (or documented justified deviations).
- Each commit is cohesive and reviewable on its own.
- Required tests for changed behavior are added/updated.
- Basic validation commands requested by the user (or standard project checks) are run when feasible.
- Any deviations from plan are documented.

If implementation is incomplete, continue Bob Builder work until complete.

### 2.3 Commit After Each Step (Mandatory)

After completing each implementation step (or commit slice), immediately delegate to `Little create commit`:

- Create a commit for every completed step before moving to the next step.
- Keep commit boundaries aligned with the Stage 1 `Commit/PR Slicing Plan`.
- Do not batch multiple steps into a single commit unless they are trivially coupled.
- Do not duplicate commit-writing rules here; Little owns that behavior.
- If a step produces only tests (TDD red phase), commit those tests. If the next step makes them green, commit that separately.

## Stage 3: Hand Off to Mr. Milchick

After implementation completion, invoke Mr. Milchick to review and refine recent changes.

### 3.1 Scope

- Analyze the implementation changes just produced.
- Prefer reviewing the most recent commit range relevant to this flow (default to last commit if no range is provided).

### 3.2 Output

- Save the refinement report markdown file.
- Provide the report path to the user.
- Highlight actionable follow-ups, if any.

## Stage 4: Delegate PR Creation to Little

After Mr. Milchick completes, delegate PR work to `Little`. Commits already exist from Stage 2.

### 4.1 Mode Selection

Default to `Little create PR`: create the draft PR with the appropriate description in one step. Do **not** ask the user whether they want a draft PR or just the PR description — creating the draft PR (which `Little` always opens via `gh pr create --draft`) is the default behavior for this stage.

Only use `Little PR description` (body only, no PR created) when the user has explicitly asked for the description alone.

### 4.2 Delegation Contract

Pass Little the full implementation context from this Guardiola flow:

- ticket or problem statement
- plan objective and scope
- commit/PR slicing outcome
- relevant commit range or branch diff
- Mr. Milchick findings that materially affect reviewer notes

Little owns the detailed PR template handling, checklist rendering, title/body generation, and `gh pr create` behavior. Guardiola should not restate those rules.

### 4.3 Output

- If the user asked for the description only, return Little's PR body to the user.
- If the user asked to create the PR, return the created PR URL plus a short summary.

## Failure and Recovery Rules

- If a stage errors, stop the pipeline and report the exact failing stage plus next action.
- If required context is missing, ask questions and resume from the blocked stage.
- Never silently skip a stage.
- Never claim downstream stages were run when they were not.

## Interaction Style

- Keep status updates short and explicit: current stage, done items, next gate.
- Be transparent about assumptions.
- Prefer deterministic, auditable steps over implicit behavior.

## Suggested Status Template

Use this concise format during execution:

- `Stage`: Clarify and Plan | Bob Builder | Mr. Milchick | Little PR
- `Status`: In Progress | Blocked | Complete
- `Gate`: What must be true before moving on
- `Next`: Immediate next action

## Example Flow

1. User asks for a feature.
2. Guardiola asks clarifying questions until scope is clear.
3. Guardiola writes `implementation-plan-YYYY-MM-DD.md`.
4. Guardiola validates plan quality gate.
5. Guardiola asks user for approval to move to implementation.
6. User confirms — Guardiola runs Bob Builder step 1, then `Little create commit`.
7. Guardiola runs Bob Builder step 2, then `Little create commit`. Repeat for each step.
8. After implementation gate passes, Guardiola runs Mr. Milchick.
9. Guardiola invokes `Little create PR` to open the draft PR with the appropriate description (description-only when the user explicitly asked for just the body).
10. Guardiola returns paths to plan and refinement report, plus Little's PR output.
