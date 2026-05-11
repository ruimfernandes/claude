---
name: little
description: Generates or creates concise commit messages, commits, PR descriptions, and pull requests from repository changes. Use when the user starts a prompt with "Little", especially for "Little commit message", "Little create commit", "Little PR description", or "Little create PR".
---

# Little

Own concise git writing and creation tasks.

## Trigger Handling

When the prompt starts with `Little`:

1. Detect the intent:
   - `commit message`
   - `create commit`
   - `PR description`
   - `create PR`
2. Inspect the relevant git state before writing anything.
3. Return only the requested artifact unless the user explicitly asked you to execute the git or GitHub action.

If the request is ambiguous, ask one short clarifying question.

## Shared Rules

- Keep output concise, reviewer-friendly, and focused on why.
- Follow recent repository commit style when drafting commit titles.
- Never commit likely secret files such as `.env` or credentials exports without warning the user.
- Never push or create a PR unless the user explicitly asks for it.
- If tests were not run, say so explicitly.
- When a repository contains `.github/pull_request_template.md`, use that template's structure and ordering exactly for PR description work.
- Use HEREDOCs for multiline commit messages and `gh pr create` bodies.

## Mode: Little commit message

Draft a ready-to-use commit message from the relevant diff.

### Workflow

1. Inspect staged and unstaged changes unless the user asked for staged-only.
2. Infer the actual intent of the change.
3. Draft a concise message that matches the repo's recent style.

### Rules

- Prefer conventional-style prefixes when they fit naturally:
  - `feat`
  - `fix`
  - `refactor`
  - `chore`
  - `test`
  - `docs`
- Use imperative mood.
- Omit scope if it is unclear.
- Optional body: 1-2 short sentences focused on motivation or impact, not a mini changelog.

### Output Format

````markdown
## Commit Message
```text
<type>(<scope>): <short summary>

<optional body>
```
````

## Mode: Little create commit

Create a git commit when the user explicitly asks for it.

### Workflow

1. Inspect:
   - all untracked and modified files with `git status`
   - staged and unstaged changes with `git diff`
   - recent commit messages with `git log`
2. Decide which files belong in the commit and stage only those.
3. Draft the message using the `Little commit message` rules.
4. Create the commit with a HEREDOC message.
5. Run `git status` after the commit to verify success.

### Rules

- Do not create an empty commit.
- Do not amend unless the user explicitly asked for it.
- Do not bypass hooks.
- If a hook fails, fix the issue and create a new commit instead of amending a failed attempt.
- Keep the message concise and biased toward why the change exists.

## Mode: Little PR description

Draft the PR body in repository-ready Markdown.

### Workflow

1. Read `.github/pull_request_template.md` from the repository root first.
2. Inspect the branch diff and included commits.
3. Fill the template exactly, preserving section order and checklist structure.

### Required Template Behavior

- `Why`: include the ticket link when available plus a concise summary of what changed and why.
- `Screenshots & Demo`: leave a placeholder reminder for screenshots or a loom when needed.
- Checklist sections: answer every question based on the implementation.
- Free-text security questions: provide short accurate answers, or `N/A` when not applicable.

### Checklist Rule

When a question offers both `Yes` and `N/A`, always render both options and mark exactly one:

```markdown
- [x] Yes
- [ ] N/A
```

or

```markdown
- [ ] Yes
- [x] N/A
```

Never remove one of the options.

## Mode: Little create PR

Create the PR when the user explicitly asks for it.

### Workflow

1. Inspect:
   - `git status`
   - staged and unstaged `git diff`
   - whether the current branch tracks a remote branch and is up to date
   - recent `git log`
   - `git diff <base-branch>...HEAD`
2. Ask for the base branch if it is unclear.
3. Push with `git push -u origin HEAD` if the branch is not yet on the remote.
4. Generate the PR title and body from the included commits and diff.
5. Create the PR with `gh pr create`, using a HEREDOC for the body.
6. Return the PR URL.

### Rules

- The PR body must follow `.github/pull_request_template.md` exactly when that file exists.
- The PR summary should reflect the full branch delta, not just the last commit.
- If the user asked only for the description, do not create the PR.

## Examples

### Example: Little commit message

Input: `Little commit message`

Output: a concise Markdown block containing the proposed commit message.

### Example: Little create commit

Input: `Little create commit`

Output: the created commit hash plus a short confirmation summary.

### Example: Little PR description

Input: `Little PR description`

Output: the repository template filled with concise, ready-to-use content.

### Example: Little create PR

Input: `Little create PR`

Output: the created PR URL plus a one-line summary.
