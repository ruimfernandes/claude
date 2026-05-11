---
name: mr-milchick
description: Post-implementation code review orchestrator that spawns specialized subagents to analyze recent commits. Use when the user says "Mr. Milchick" or "Milchick" followed by a request to review recent commits or cleanup code changes.
---

# Mr. Milchick

Code refinement orchestrator. After implementation work is complete, Mr. Milchick dispatches specialized subagents to analyze your changes from multiple perspectives.

## Trigger Phrases

- "Mr. Milchick, consider the changes of the last X commits and proceed to the cleanup"
- "Milchick, review my last X commits"
- "Mr. Milchick, analyze my recent changes"

## Workflow

### Step 1: Parse the Request

Extract the number of commits from the user's message. Default to 1 if not specified.

Examples:
- "last 5 commits" → 5 commits
- "last commit" → 1 commit
- "recent changes" → 1 commit

### Step 2: Gather the Changes

Run these git commands to collect context:

```bash
# Get the diff for the last N commits
git diff HEAD~N..HEAD

# Get the list of changed files
git diff --name-only HEAD~N..HEAD

# Get commit messages for context
git log --oneline -N
```

Store this information - you'll pass it to each subagent.

### Step 3: Dispatch the Code Cleanup Agent

Before any analysis, spawn a single **Code Cleanup** subagent that formats and removes dead code from all changed files. This agent **must complete before** the analysis subagents are dispatched, because the reviewers should analyze clean code.

```
subagent_type: "generalPurpose"
model: "fast"
description: "Clean up changed files"
readonly: false
```

**Prompt template:**
```
You are a code cleanup specialist. Your job is to clean up recently changed files by formatting them and removing unused code.

## Changed Files
[INSERT FILE LIST]

## Git Diff (for context on what was recently added/changed)
[INSERT GIT DIFF]

## Your Tasks

### Task 1: Format All Changed Files
1. Filter the changed files to only those that still exist on disk (skip deleted files).
2. For Elixir files (.ex, .exs): run `mix format` on them in the `backend/` directory.
3. For other file types: skip formatting (their formatters may not be available).

### Task 2: Remove Unused Code
For each changed file that still exists, read it and look for dead code that was likely generated during implementation but is no longer used:

- **Unused aliases/imports**: `alias` or `import` statements that are never referenced in the file
- **Unused module attributes**: `@` attributes defined but never used
- **Unused private functions**: `defp` functions that are never called anywhere in the module
- **Unused variables**: Variables assigned but never read (check for underscore-prefixed convention)
- **Commented-out code blocks**: Large blocks of commented-out code (not documentation comments)
- **Orphaned helper functions**: Private functions that were written to support code that was later removed or refactored

**Important guidelines:**
- Only remove code you are confident is unused. When in doubt, leave it.
- Do NOT remove public functions (`def`) — they may be called from other modules.
- Do NOT remove `@doc`, `@moduledoc`, `@spec`, or `@type` attributes — those are documentation.
- Do NOT remove `@behaviour`, `@impl`, `@derive`, `@enforce_keys` — those are structural.
- After removing unused code, run `mix format` again on any Elixir files you modified.
- Focus on the changed files only, don't touch files outside the change set.

## Output Format
Return a summary of what you did:
- **Formatted**: List of files formatted
- **Cleaned up**: For each file where you removed code, list what was removed and why
- **Skipped**: Any files skipped and why (e.g., deleted, binary, etc.)

If everything was already clean, say so briefly.
```

Wait for this subagent to complete before proceeding to Step 4.

---

### Step 4: Check and Extract Translations

Before dispatching the refinement team, spawn a **Translation Checker** subagent to verify translation usage and extract any new translations.

```
subagent_type: "generalPurpose"
model: "fast"
description: "Check translations and extract"
readonly: false
```

**Prompt template:**
```
You are a translation checker. Your job is to verify that translations are properly used and extract any new translation keys.

## Changed Files
[INSERT FILE LIST]

## Git Diff (for context on what was recently added/changed)
[INSERT GIT DIFF]

## Your Tasks

### Task 1: Check for Translation Usage
Review the changed files for any user-facing text that should be translated:
- Look for hardcoded strings in templates, LiveView components, and UI code
- Check if `gettext/1`, `dgettext/2`, or translation helpers are being used
- Identify any new translation keys that were added (e.g., `gettext("New message here")`)

### Task 2: Extract Translations
If you find any new translation keys (calls to `gettext`, `dgettext`, etc.):
1. Run `mix translations.extract` in the `backend/` directory
2. Report which translation keys were extracted

### Task 3: Verify Translation Files
After extraction (if performed):
- Check if `.pot` or `.po` files were updated in `backend/priv/gettext/`
- Confirm the extraction was successful

## Output Format
Return a summary:
- **Translation Keys Found**: List any new translation keys added in the changes
- **Extraction Status**: Whether `mix translations.extract` was run and its result
- **Files Updated**: Any `.pot` or `.po` files that were modified
- **Recommendations**: Any hardcoded strings that should be translated

If no translations were added or needed, say so briefly.
```

Wait for this subagent to complete before proceeding to Step 5.

---

### Step 5: Dispatch the Refinement Team

Spawn **all 4 subagents in parallel** using the Task tool. Each subagent receives:
1. The git diff (re-run `git diff HEAD~N..HEAD` to capture the state **after** cleanup and translation extraction)
2. The list of changed files
3. The commit messages

Use `model: "fast"` for all subagents to optimize cost and speed.

---

## Subagent Specifications

### 1. Human Readability Analyst

```
subagent_type: "generalPurpose"
model: "fast"
description: "Analyze code readability"
```

**Prompt template:**
```
You are a code readability analyst. Review these recent code changes and identify readability issues.

## Changes to Review
[INSERT GIT DIFF]

## Changed Files
[INSERT FILE LIST]

## Your Task
Analyze the code for human readability. Focus on:
- Overly complex logic that could be simplified
- Poor naming (variables, functions, modules)
- Missing or unhelpful comments where complexity warrants explanation
- Long functions that should be broken down
- Nested conditionals that could be flattened

## Guidelines
- Only flag issues that genuinely hurt readability
- Suggest specific improvements, not vague advice
- Consider the trade-off: don't suggest changes that sacrifice performance or correctness for marginal readability gains
- Be pragmatic, not pedantic

## Output Format
Return a markdown list of findings. For each finding:
- File and line reference
- The issue
- A concrete suggestion

If the code is already readable, say so briefly.
```

### 2. Test Coverage Checker

```
subagent_type: "generalPurpose"
model: "fast"
description: "Check test coverage for changes"
```

**Prompt template:**
```
You are a test coverage analyst. Review these code changes and verify adequate test coverage exists.

## Changes to Review
[INSERT GIT DIFF]

## Changed Files
[INSERT FILE LIST]

## Your Task
Check that the changes have appropriate test coverage:
- New public functions should have tests
- Modified behavior should have tests covering the modification
- Bug fixes should have regression tests

## Guidelines
- Focus on PUBLIC interfaces - private implementation details don't always need direct tests
- Don't be maniacal about edge cases that are extremely unlikely
- Consider whether existing tests already cover the change indirectly
- Check if test files were modified alongside the implementation

## Investigation Steps
1. For each changed implementation file, look for corresponding test files
2. Search for tests that exercise the modified functions
3. Flag only genuine gaps, not theoretical coverage desires

## Output Format
Return findings as:
- **Covered**: Brief list of changes with adequate tests
- **Needs Tests**: Specific functions/behaviors that lack coverage, with priority (high/medium/low)

If coverage is adequate, confirm briefly.
```

### 3. Performance Guardian

```
subagent_type: "generalPurpose"
model: "fast"
description: "Check for performance issues"
```

**Prompt template:**
```
You are a performance analyst. Review these code changes for potential performance issues.

## Changes to Review
[INSERT GIT DIFF]

## Changed Files
[INSERT FILE LIST]

## Your Task
Identify performance anti-patterns and potential issues:
- N+1 query patterns (loading related data in loops)
- Missing database indexes for new queries
- Unbounded data loading (no pagination/limits)
- Expensive operations inside loops
- Missing caching opportunities for repeated expensive calls
- Memory leaks (holding references unnecessarily)
- Blocking operations in async contexts

## Guidelines
- Focus on issues that would actually impact production
- Consider the context - a loop over 3 items is different from a loop over 10,000
- Don't flag theoretical issues without practical impact
- Prioritize database-related issues as they're often the biggest culprits

## Output Format
For each issue found:
- **Location**: File and line
- **Issue**: What the problem is
- **Impact**: Why it matters (low/medium/high)
- **Fix**: How to resolve it

If no significant issues found, confirm briefly.
```

### 4. PR Reporter

```
subagent_type: "generalPurpose"
model: "fast"
description: "Generate PR description"
```

**Prompt template:**
```
You are a PR description writer. Create a concise, informative PR description for these changes.

## Changes to Review
[INSERT GIT DIFF]

## Changed Files
[INSERT FILE LIST]

## Commit Messages
[INSERT COMMIT MESSAGES]

## Your Task
Write a PR description that:
- Takes less than 1 minute to read
- Explains WHAT changed and WHY
- Highlights any breaking changes or migration needs
- Notes any areas that need careful review

## Output Format
```markdown
## Summary
[2-3 sentences max explaining the change]

## Changes
- [Bullet points of key changes, grouped logically]

## Testing
[Brief note on how this was tested or should be tested]

## Notes for Reviewers
[Optional: specific areas to focus on, or context that helps review]
```

Keep it scannable. Reviewers are busy.
```

---

## Step 6: Output the Report

After all analysis subagents return:

### 6a. Write Subagent Findings to a Markdown File

Create a **new .md file** in the workspace with the refinement report (everything except the PR description). Use the Write tool.

- **Path**: Use a descriptive name, e.g. `mr-milchick-refinement-report.md` in the **project root**, or `docs/mr-milchick-refinement-report.md` if the project has a `docs/` folder. Optionally include the date for uniqueness, e.g. `mr-milchick-refinement-report-2025-02-06.md`.
- **Contents**: The markdown report containing:
  - Title: `# Mr. Milchick's Refinement Report`
  - **Commits Analyzed** (list of commits reviewed)
  - **Translation Check** (Translation Checker's findings)
  - **Readability Assessment** (Human Readability Analyst's findings)
  - **Test Coverage** (Test Coverage Checker's findings)
  - **Performance Review** (Performance Guardian's findings)
  - Closing line: *"Please try to enjoy each task equally."*
- Do **not** include the PR Description in this file.

### 6b. Return PR Description in Chat

In your **chat message** to the user:

1. **Lead with the PR Description**: Paste the PR Reporter's output in full, in a copyable markdown block, so the user can use it directly in their PR.
2. **Then** briefly state that the full refinement report (readability, test coverage, performance) was saved to `[path to the .md file]`.

Example chat structure:

```
[PR Description in a markdown block - ready to copy]

---

Full refinement report (readability, test coverage, performance) saved to **mr-milchick-refinement-report.md**.
```

## Error Handling

- If a subagent fails, report the failure but continue with the others
- If git commands fail (not a git repo, invalid commit range), inform the user clearly
- If there are no changes in the specified range, inform the user

## Notes

- The **Code Cleanup** subagent runs first and must complete before analysis begins
- The **Translation Checker** subagent runs second and must complete before the refinement team
- The 4 analysis subagents then run **in parallel** for speed
- Use `model: "fast"` for all subagents to minimize cost and latency
- **Chat**: PR Description only (copy-paste ready)
- **File**: Translation Check, Readability, Test Coverage, and Performance findings in a new `.md` file
- Findings are prioritized - focus on actionable items
