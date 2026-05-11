---
name: mr-milchick
description: Post-implementation code review orchestrator that spawns specialized subagents to analyze recent commits or the current branch, including checks for flaky new or modified tests. Use when the user says "Mr. Milchick" or "Milchick" followed by a request to review recent commits, review the current branch, check tests for flakiness, or cleanup code changes.
---

# Mr. Milchick

Code refinement orchestrator. After implementation work is complete, Mr. Milchick dispatches specialized subagents to analyze your changes from multiple perspectives.

## Trigger Phrases

- "Mr. Milchick, consider the changes of the last X commits and proceed to the cleanup"
- "Milchick, review my last X commits"
- "Mr. Milchick, analyze my recent changes"
- "Mr. Milchick, review my current branch"
- "Milchick, check the tests on this branch for flakiness"

## Workflow

### Step 1: Parse the Request

Determine the review scope from the user's message.

- If the user says `current branch`, `this branch`, or equivalent, review everything on the current branch since it diverged from the mainline branch.
- Otherwise, extract the number of commits from the user's message. Default to 1 if not specified.

Examples:
- "last 5 commits" → 5 commits
- "last commit" → 1 commit
- "recent changes" → 1 commit
- "current branch" → branch diff from merge-base to `HEAD`

For current-branch reviews, resolve the base branch in this order:
1. `origin/main`
2. `main`
3. `origin/master`
4. `master`

If none exists, stop and ask the user which base branch to compare against.

### Step 2: Gather the Changes

Run git commands to collect context for the chosen scope.

```bash
# If reviewing the last N commits
git diff HEAD~N..HEAD
git diff --name-only HEAD~N..HEAD
git log --oneline -N

# If reviewing the current branch
BASE_REF=<resolved mainline branch>
MERGE_BASE=$(git merge-base HEAD "$BASE_REF")
git diff "$MERGE_BASE"..HEAD
git diff --name-only "$MERGE_BASE"..HEAD
git log --oneline "$MERGE_BASE"..HEAD
```

Also derive a list of changed test files from the changed file list by filtering for test directories and test naming conventions used in the repo.

Store this information - you'll pass it to each subagent:
- scope description
- git diff
- changed files
- changed test files
- commit messages

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

### Step 5: Dispatch Refinement Agents in Parallel

Spawn **4 subagents in parallel** (Readability, Test Coverage, Test Flakiness, Performance) using the Task tool. Each subagent receives:
1. The git diff for the analyzed scope (re-run the appropriate `git diff` command to capture the state **after** cleanup and translation extraction)
2. The list of changed files
3. The list of changed test files
4. The commit messages

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
Analyze the code for human readability, but only for code that changed in the analyzed scope.

Scope rules:
- ONLY review added/modified lines and hunks shown in the provided git diff
- You may read nearby lines for context, but do NOT create findings about unchanged code
- Do NOT suggest refactors outside the changed hunks
- If a readability issue exists only in untouched legacy code, ignore it for this report

Focus on:
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
- Every finding must point to code changed in the analyzed scope

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

## Changed Test Files
[INSERT CHANGED TEST FILE LIST]

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
4. If test files were created or modified, use that as evidence when deciding whether coverage is already adequate

## Output Format
Return findings as:
- **Covered**: Brief list of changes with adequate tests
- **Needs Tests**: Specific functions/behaviors that lack coverage, with priority (high/medium/low)

If coverage is adequate, confirm briefly.
```

### 3. Flaky Test Analyst

```
subagent_type: "generalPurpose"
model: "fast"
description: "Check changed tests for flakiness"
```

**Prompt template:**
```
You are a flaky test analyst. Review newly created or modified tests in the analyzed scope and identify tests that are likely to become flaky.

## Changes to Review
[INSERT GIT DIFF]

## Changed Files
[INSERT FILE LIST]

## Changed Test Files
[INSERT CHANGED TEST FILE LIST]

## Your Task
Inspect only the changed test files and only the newly added or modified tests in those files. Look for patterns that can cause flaky, nondeterministic, or timing-sensitive test behavior.

Focus on:
- Time-sensitive assertions (`Process.sleep`, aggressive timeouts, exact timing assumptions)
- Reliance on wall clock, current date, timezone, locale, or month-boundary behavior without controlling time
- Randomized inputs or ordering assumptions without deterministic setup
- Shared mutable global state (`Application.put_env`, ETS, process registry, filesystem paths, environment variables) without cleanup/isolation
- Concurrency races (`async: true` with shared fixtures, message ordering assumptions, background jobs not synchronized)
- External dependencies or side effects not properly stubbed or isolated
- Assertions that depend on unordered collections, non-deterministic IDs, or eventual background completion

## Guidelines
- Flag only credible flakiness risks, not merely style preferences
- Prioritize newly added or modified tests over untouched tests in the same file
- Read surrounding helper code if needed, but do not create findings about unchanged production code unless it directly makes the changed test flaky
- If a pattern is acceptable because the test controls the source of nondeterminism, do not flag it
- If no changed test files exist, say so briefly

## Output Format
Return findings as:
- **Looks Stable**: Brief list of changed tests that appear deterministic
- **Flaky Risk**: For each risky test, include file/test name, why it may be flaky, severity (high/medium/low), and a concrete stabilization suggestion

If no flaky patterns are found, confirm briefly.
```

### 4. Performance Guardian

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

## Step 6: Output the Report

After all refinement tasks return:

### 6a. Write Subagent Findings to a Markdown File

Create a **new .md file** in the workspace with the refinement report. Use the Write tool.

- **Path**: Use a descriptive name, e.g. `mr-milchick-refinement-report.md` in the **project root**, or `docs/mr-milchick-refinement-report.md` if the project has a `docs/` folder. Optionally include the date for uniqueness, e.g. `mr-milchick-refinement-report-2025-02-06.md`.
- **Contents**: The markdown report containing:
  - Title: `# Mr. Milchick's Refinement Report`
  - **Commits Analyzed** (list of commits reviewed)
  - **Translation Check** (Translation Checker's findings)
  - **Readability Assessment** (Human Readability Analyst's findings)
  - **Test Coverage** (Test Coverage Checker's findings)
  - **Test Flakiness Review** (Flaky Test Analyst's findings)
  - **Performance Review** (Performance Guardian's findings)
  - Closing line: *"Please try to enjoy each task equally."*
- In your **chat message** to the user, briefly state that the full refinement report was saved to `[path to the .md file]`.

## Error Handling

- If a subagent fails, report the failure but continue with the others
- If git commands fail (not a git repo, invalid review scope), inform the user clearly
- If there are no changes in the analyzed scope, inform the user

## Notes

- The **Code Cleanup** subagent runs first and must complete before analysis begins
- The **Translation Checker** subagent runs second and must complete before the refinement team
- Readability, coverage, flaky-test review, and performance then run **in parallel** for speed
- Use `model: "fast"` for all subagents to minimize cost and latency
- **Chat**: report file path confirmation
- **File**: Translation Check, Readability, Test Coverage, Test Flakiness, and Performance findings in a new `.md` file
- Findings are prioritized - focus on actionable items
