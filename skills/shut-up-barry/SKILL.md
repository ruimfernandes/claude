---
name: shut-up-berry
description: Fix failing GitHub Actions tests by fetching logs from a run URL, analyzing ExUnit failures, and applying fixes. Use when the user says "Shut up berry" followed by a GitHub Actions run URL, or asks to fix CI test failures from a specific run.
---

# Shut Up Berry - CI Test Failure Fixer

Fetch failing test logs from a GitHub Actions run, analyze ExUnit failures, fix the code, and open a PR.

## Trigger

User says "Shut up berry" followed by a GitHub Actions run URL:

```
Shut up berry https://github.com/sona-is/sona/actions/runs/22501785366
```

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- Repository checked out locally with access to the codebase
- Current branch is clean (no uncommitted changes that would conflict)

## Workflow

### Step 1: Parse the GitHub Actions Run URL

Extract owner, repo, and run ID from the URL:

```
https://github.com/{owner}/{repo}/actions/runs/{run_id}
```

Default repo: `sona-is/sona`

If the URL is missing or unparseable, ask for clarification.

### Step 2: Fetch Run Details and Identify Failing Jobs

```bash
gh run view {run_id} --repo {owner}/{repo}
```

Identify which jobs failed. Focus **only on test jobs** (job names matching `Tests (*)` pattern from the `run_tests` matrix). Skip non-test failures like:
- Build failures (compilation errors)
- Code Quality (credo, formatting)
- Dialyzer
- Docker Build

If no test jobs failed, inform the user:
> "No test failures found in this run. The failures are in non-test jobs ({list jobs}). This skill only handles test failures."

### Step 3: Fetch Failed Test Logs

```bash
gh run view {run_id} --repo {owner}/{repo} --log-failed
```

This downloads the full failed job logs. The output will contain ExUnit test failure blocks.

**If logs are too large**, try fetching logs for specific failed jobs:

```bash
gh run view {run_id} --repo {owner}/{repo} --log-failed --job {job_id}
```

### Step 4: Parse ExUnit Failures

Extract test failure information from the logs. ExUnit failures follow this pattern:

```
  1) test {test_description} ({TestModule})
     {test_file}:{line_number}

     Assertion with {operator} failed

     left:  {value}
     right: {value}

     code: {assertion_code}

     stacktrace:
       {test_file}:{line_number}: (test)
```

For each failure, extract:
- **Test file path** (relative to `backend/`, e.g., `test/backend/products/payroll_test.exs`)
- **Line number**
- **Test module name**
- **Test description**
- **Assertion error** (what failed: `==`, `=~`, `match`, `assert`, `refute`)
- **Left/right values** (expected vs actual)
- **Stacktrace** (to identify implementation files involved)

Also look for these failure patterns:
- `** (MatchError)` - Pattern match failures
- `** (FunctionClauseError)` - No matching function clause
- `** (KeyError)` - Missing map key
- `no process:` or `** (EXIT)` - Process crashes
- `expected` ... `to` ... - Custom assertion failures

Collect all failures into a structured list.

### Step 5: Fetch the Failing Commit Context

Get the commit SHA that triggered the run:

```bash
gh run view {run_id} --repo {owner}/{repo} --json headSha --jq '.headSha'
```

Then get the diff for that commit to understand recent changes:

```bash
gh api repos/{owner}/{repo}/commits/{sha} --jq '.files[].filename'
```

This helps identify which recently changed files likely introduced the failures.

### Step 6: Read Source Files

For each test failure:

1. **Read the test file** at the failing line (with surrounding context)
2. **Read the implementation file(s)** referenced in the stacktrace or implied by the test module name
3. **Read recently changed files** from the commit diff that are relevant to the failures

Convention mapping (test file to implementation):
- `test/backend/{path}_test.exs` → `lib/backend/{path}.ex`
- `test/backend_web/{path}_test.exs` → `lib/backend_web/{path}.ex`

### Step 7: Analyze and Fix

For each failure:

1. **Understand the root cause**: Was it a code change that broke existing behavior, or a test that needs updating?
2. **Determine the fix type**:
   - **Implementation bug**: Fix the implementation code
   - **Test needs updating**: Update the test expectations to match intended new behavior
   - **Missing setup**: Add test setup/fixtures for new requirements
   - **Race condition / async issue**: Add proper async handling

3. **Apply the fix** using edit tools
4. **Verify locally** when feasible:
   ```bash
   cd backend && mix test {test_file}:{line_number} --trace
   ```

### Step 8: Create Branch, Commit, and PR

1. **Fetch latest master and create a fix branch**:
   ```bash
   git fetch origin master
   git checkout -b fix/ci-test-{run_id} origin/master
   ```

   If the failure was on a feature branch, branch from that instead:
   ```bash
   gh run view {run_id} --repo {owner}/{repo} --json headBranch --jq '.headBranch'
   git fetch origin {branch}
   git checkout -b fix/ci-test-{run_id} origin/{branch}
   ```

2. **Stage and commit the fix**:
   ```bash
   git add -A
   git commit -m "$(cat <<'EOF'
fix: resolve failing CI tests from run #{run_id}

{brief description of what was fixed}
EOF
   )"
   ```

3. **Push and create PR** following the repository's PR template (`.github/pull_request_template.md`):
   ```bash
   git push -u origin HEAD
   gh pr create --repo {owner}/{repo} --title "fix: resolve failing CI tests" --body "$(cat <<'EOF'
## Why

Fixes test failures from [GitHub Actions run #{run_id}](https://github.com/{owner}/{repo}/actions/runs/{run_id}).

### Failures Fixed
- {test_file}:{line} - {test_description}: {brief fix description}

### Root Cause
{what caused the failures}

## Screenshots & Demo

N/A — CI test fix, no UI changes.

## Localisation Review

1. Have you added all visible UI text in calls to Gettext?

- [ ] Yes
- [x] N/A

2. Have you handled time correctly across multiple timezones?

- [ ] Yes
- [x] N/A

3. Have you rendered dates and times correctly for other locales?

- [ ] Yes
- [x] N/A

## Design Review

1. Have you sought sign-off from a designer on the UI in this PR?

- [ ] Yes
- [x] N/A

## Security Review

### Tenanting

1. Have you confirmed and tested that tenant isolation is enforced?

- [ ] Yes
- [x] N/A

### Permissions and access control

1. Does this PR introduce any changes to the behaviour of permissions or access control?

- [ ] Yes
- [x] N/A

2. If so have these been tested in a sandbox environment?

- [ ] Yes
- [x] N/A

3. Is the new behaviour covered by unit tests?

- [ ] Yes
- [x] N/A

4. Will this impact what existing users of the platform can see or access?

- [ ] Yes
- [x] N/A

### APIs

1. Are there new public or private APIs being created?

- [ ] Yes
- [x] N/A

### Data Collection

1. Is any new data being collected?

- [ ] Yes
- [x] N/A

### Data Sharing

1. Is data to be shared with any new third parties or third party systems?

- [ ] Yes
- [x] N/A

2. Are there any changes to data exports to third parties?

- [ ] Yes
- [x] N/A

3. Are agreements in place covering the sharing and use of this data?

- [ ] Yes
- [x] N/A
EOF
   )"
   ```

   **Important**:
   - If the test fix touches implementation code (not just test files), re-evaluate the Security Review checkboxes — especially "Permissions and access control" and "Tenanting" — and check the relevant boxes as "Yes" instead of "N/A" when appropriate.
   - Do **not** append `Made with [Cursor](https://cursor.com)` or any tool attribution to the PR description.

### Step 9: Summary

Provide a final summary:

```
=== Shut Up Berry - Fix Summary ===

Run: https://github.com/{owner}/{repo}/actions/runs/{run_id}
Branch: fix/ci-test-{run_id}
PR: {pr_url}

Failures Fixed:
- {test_file}:{line} — {description} — {fix applied}

Failures Skipped (if any):
- {test_file}:{line} — {reason: flaky, non-test, too complex}

Next Steps:
- Review the PR
- CI should pass on the fix branch
```

## Important Rules

- **Only fix test failures**: Do not fix compilation errors, credo issues, or formatting problems (use Hunter for those)
- **Prefer minimal fixes**: Make the smallest change that resolves the failure
- **Never auto-merge**: Always create a PR for human review
- **Fix flaky tests**: If a test passes locally but fails on CI, report it as flaky and try to find a solution for it
- **Respect the codebase**: Follow existing patterns, naming conventions, and project structure
- **One commit per fix group**: Group related test fixes into a single commit

## Edge Cases

- **Compilation failures masking test failures**: If tests couldn't even run due to compilation errors, inform the user and suggest fixing compilation first
- **Too many failures (>10)**: Focus on the first 5 failures and inform the user about the rest
- **Log access denied**: Suggest checking `gh auth status` and repository permissions

## Example Session

```
User: Shut up berry https://github.com/sona-is/sona/actions/runs/22501785366

Agent:
Fetching run details for #22501785366...

Found 2 failing test jobs:
  - Tests (3) — 1 failure
  - Tests (7) — 2 failures

Fetching failed logs...

Parsed 3 test failures:
1. test/backend/products/payroll/payroll_management_test.exs:2560
   "updates record status when approved"
   Assertion (==) failed: left: :pending, right: :approved

2. test/backend/products/payroll/payroll_management_test.exs:2605
   "broadcasts status change"
   ** (MatchError) no match for {:error, :not_found}

3. test/backend_web/live/payroll/index_live_test.exs:145
   "renders updated status badge"
   Expected "Approved" in rendered HTML

Root cause: Recent commit changed the approval flow to require
an additional validation step, but tests expected immediate approval.

Reading implementation files...
Applying fixes...

Running tests locally to verify...
  ✓ All 3 tests pass

Creating branch fix/ci-test-22501785366...
Committing and pushing...
Creating PR (following repo PR template)...

=== Shut Up Berry - Fix Summary ===

Run: https://github.com/sona-is/sona/actions/runs/22501785366
Branch: fix/ci-test-22501785366
PR: https://github.com/sona-is/sona/pull/21234

Failures Fixed:
- payroll_management_test.exs:2560 — updated assertion for new validation step
- payroll_management_test.exs:2605 — added validation step before status check
- index_live_test.exs:145 — updated expected render after validation flow change

Next Steps:
- Review the PR for correctness
- CI should pass on the fix branch
```
