---
name: kdb
description: Generates step-by-step manual testing instructions for the current branch compared with `master`, focused on reproducing the old behavior on the platform and verifying the new behavior while logged in as a manager. When a Jira ticket is provided, always fetch it via the Atlassian MCP first. Use when the user says `KdB`, asks how to test a branch manually, wants manager-facing repro steps, or asks for before/after verification against `master`.
---

# KdB

## Purpose

Use `KdB` to turn branch changes into a human test script for the platform.

The output must help the user manually validate behavior in the app, not by running unit tests or reading code only.

Default assumptions:

- Compare the current branch against `master`.
- The tester is logged in as a manager.
- Prefer platform actions and visible outcomes over implementation details.

## Hard Rules

- Do not return `run test`, `run unit test`, or similar test-suite instructions as the main result.
- Do not default to generic QA wording like `verify feature works`.
- Always produce concrete platform steps.
- Always explain how to reproduce the old behavior on `master` when that is possible from the diff and available context.
- Always explain how to verify the new behavior on the current branch.
- If the user provides a Jira ticket URL or key, always check it through the `user-Atlassian` MCP before using ticket details.
- If the Atlassian MCP is disabled, unavailable, or misconfigured, stop the flow immediately and tell the user to fix or enable it before continuing.
- Do not fall back to guessing Jira details from the URL, browser, or chat summary when a Jira ticket was provided.
- If required product context is missing, ask targeted follow-up questions before finalizing the steps.

## Inputs To Use

Before writing the testing guide, gather context from these sources in this order:

1. The current user request
2. Current chat history
3. Referenced Jira ticket, fetched through the Atlassian MCP when a ticket URL or key is provided
4. Current branch diff against `master`
5. Any implementation plan, PR notes, or review notes mentioned in the chat

If the user provides a Jira ticket, use the Atlassian MCP to fetch it before continuing.
First call `getAccessibleAtlassianResources` to obtain a `cloudId`, then call `getJiraIssue` with the Jira key or ID.
If no Jira ticket is provided, continue with the remaining context sources.
If the ticket is incomplete, infer the likely user-facing behavior from the branch diff and current conversation.

## Workflow

### 1. Resolve Jira context first when a ticket is provided

If the request includes a Jira URL or issue key:

- Confirm the `user-Atlassian` MCP is available.
- Use the Atlassian MCP, not a browser scrape or URL guess, to fetch the issue.
- Start with `getAccessibleAtlassianResources` to retrieve a `cloudId`.
- Then call `getJiraIssue` with `issueIdOrKey`.
- Use the Jira summary, description, acceptance criteria, and status as input for the manual test plan.

If the Atlassian MCP cannot be used, stop and reply with a short blocking message telling the user to fix or enable the Atlassian MCP before `KdB` can continue.

### 2. Understand the user-facing change

Inspect the current branch against `master` and identify:

- What behavior changed
- Who experiences the change
- Which screens, flows, or actions are involved
- What data/setup is needed
- What a manager must do to trigger the old and new behavior

Focus on user-observable behavior, not internal refactors unless they change visible outcomes.

### 3. Reconstruct the baseline on `master`

When possible, explain how the tester can see the old behavior on `master`.

This section should answer:

- Where should the manager navigate?
- What data or record state is required?
- What exact actions should they take?
- What wrong or buggy behavior should appear?

If the bug cannot be reproduced safely or deterministically on `master`, say that clearly and explain the closest observable baseline instead.

### 4. Verify the fix on the current branch

Translate the change into a clear validation path:

- Start from login as manager
- Navigate to the relevant area
- Perform the same or equivalent actions
- State the expected fixed behavior
- Mention any edge cases worth spot-checking manually

### 5. Include setup only when needed

Add prerequisites only if they materially help the tester:

- Required role or permissions
- Required record state
- Required employee/company/configuration setup
- Feature flags or environment conditions

Keep setup concise and actionable.

### 6. Make the instructions easy to follow

Prefer step-by-step instructions with explicit outcomes after important actions.

Good:

```markdown
1. Check out `master` and log in as a manager.
2. Open the employee profile for an employee with an approved leave request.
3. Navigate to `Time Off > Requests`.
4. Edit the request dates so they overlap with an existing request.
5. Save the form.
Expected on `master`: the platform accepts the change and creates the inconsistent state.
```

Bad:

```markdown
Verify leave request validation.
```

## Output Format

Always use this structure:

```markdown
## Manual Test Plan

### Goal
- Brief statement of what changed in user terms

### Preconditions
- Manager login
- Any specific setup needed

### Reproduce On `master`
1. ...
2. ...
Expected on `master`: ...

### Verify On Current Branch
1. ...
2. ...
Expected on current branch: ...

### Extra Checks
- Optional high-value edge case
- Optional regression check
```

## Writing Guidelines

- Use product language, not code jargon, when possible.
- Mention exact navigation paths when they can be inferred.
- Mention the type of record/data needed when exact identifiers are unknown.
- Prefer `open`, `click`, `select`, `save`, `refresh`, `approve`, `submit`, `edit`, `filter` verbs.
- Keep the goal short and concrete.
- Keep the number of steps tight; include enough detail to reproduce reliably.

## When To Ask Questions

Ask short follow-up questions if any of these are unclear:

- Which manager persona or organization to use
- Which area of the platform is affected
- What setup data is needed to trigger the bug
- Whether the user wants a pure repro flow, a fix-verification flow, or both

Do not ask follow-up questions that the Jira ticket should answer until after you have fetched the ticket through the Atlassian MCP.

If the user already asked for `KdB`, keep the questions minimal and only ask what blocks a useful manual test script.

## Examples

### Example Trigger

`KdB for this ticket: <url>`

### Example Blocking Response

`I can't continue the KdB flow yet because the Atlassian MCP is disabled or unavailable. Please fix or enable the \`user-Atlassian\` MCP, then ask me to continue.`

### Example Intent

Return a manual before/after guide such as:

- What to do on `master` to reproduce the bug
- What to do on the current branch to verify the fix
- What outcome the manager should observe in each case
