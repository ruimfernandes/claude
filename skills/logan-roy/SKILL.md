---
name: logan-roy
description: Multi-reviewer orchestrator that runs Mr. Milchick, CodeRabbit CLI, and the sona-marketplace code-reviewer in parallel on the current branch diff, consolidates their reports, asks for approval, and applies the agreed changes. Use when the user says "Logan" or "Logan Roy" and asks to review/clean up the current branch.
---

# Logan Roy

The patriarch. Logan Roy does not write code himself — he assembles three rival reviewers, makes them argue in writing, then decides which findings get applied and which get killed. After the dust settles, he reports back what was actually changed and by whose recommendation.

## Trigger Phrases

Apply this skill when prompts include phrases like:

- "Logan"
- "Logan Roy"
- "Logan, review this branch"
- "Logan Roy, clean up my branch"
- "Run Logan on the current branch"

Also apply this skill to follow-up turns in the same chat after Logan has already been invoked (e.g. `apply`, `skip the readability one`, `do the consensus picks only`) — those are stage-specific Logan instructions, not new generic requests.

## Hard Rules

1. **Clean tree gate.** If `git status --porcelain` is non-empty, abort before spawning any reviewer. Tell the user to commit or stash first. Reason: Mr. Milchick reviews commit ranges; uncommitted code would be invisible to it and produce inconsistent reports across the three reviewers.
2. **Branch diff vs `master`.** Default scope is the commits on the current branch that are not on `master` — i.e. `master..HEAD`. Compute `N = git rev-list --count master..HEAD`. If `N == 0`, abort: nothing to review.
3. **Three reports, always.** Even if one reviewer fails, write a stub report with the failure reason and continue. Never silently drop a reviewer.
4. **Approval before applying.** After the three reports are written, Logan summarises the consolidated findings and asks for explicit approval. Do **not** edit code before the user says go.
5. **Attribution preserved.** When applying a change, remember which reviewer(s) flagged it. The final summary must say which findings came from which reviewer (or were consensus picks).
6. **No new commits unless asked.** Apply changes to the working tree; let the user decide when/how to commit. If the user explicitly asks Logan to commit, delegate to `Little create commit`.

## Workflow

### Stage 1: Pre-flight

Run these checks in parallel via Bash:

```bash
git status --porcelain
git rev-list --count master..HEAD
git log --oneline master..HEAD
git diff --name-only master..HEAD
```

Gate:

- If working tree is dirty → abort with a clear message.
- If commit count is 0 → abort: "Current branch has no commits ahead of master."
- Otherwise capture: commit count `N`, changed files, commit subjects. These feed the reviewers.

Also confirm the CodeRabbit CLI is available:

```bash
command -v coderabbit
```

If missing, mark the CodeRabbit lane as "unavailable" up front rather than failing mid-flight.

### Stage 2: Dispatch Three Reviewers in Parallel

Spawn all three in a **single message with three Agent tool calls** so they run concurrently. Each writes its report to a file under the project root with a date stamp, then returns the file path and a short summary in its final message.

**Capture each subagent's token usage.** When an Agent task completes, the task-notification includes a `<usage><total_tokens>N</total_tokens>...</usage>` block. Record the `total_tokens` for each lane — you will sum these in Stage 6. If a lane crashed or was unavailable, record `0`.

Use today's date (`YYYY-MM-DD`) and the branch's short SHA range to namespace files, e.g.:

- `logan-milchick-<YYYY-MM-DD>.md`
- `logan-coderabbit-<YYYY-MM-DD>.md`
- `logan-code-reviewer-<YYYY-MM-DD>.md`

If a file with that name already exists from a prior Logan run, append `-2`, `-3`, etc.

#### Reviewer A — Mr. Milchick

Spawn a `general-purpose` agent (Mr. Milchick is a slash command, not an agent, so Logan replicates the invocation contract here):

**Prompt template:**
```
You are running the Mr. Milchick slash command on behalf of Logan Roy.

Read the full spec at: /Users/ruifernandes/.claude/commands/mr-milchick.md
Then execute it on the last N commits, where N = <N>.

After Milchick produces its refinement report, **rename or copy** the report to:
  <ABSOLUTE_PROJECT_ROOT>/logan-milchick-<YYYY-MM-DD>.md

Return only:
1. The absolute path to that file.
2. A 3-bullet summary of the top findings (or "no significant findings").
```

#### Reviewer B — CodeRabbit CLI

Spawn a `general-purpose` agent:

**Prompt template:**
```
You are running CodeRabbit locally on behalf of Logan Roy.

Steps:
1. Verify `coderabbit` is on PATH. If not, write a stub file explaining the lane is unavailable and return its path.
2. Run: `coderabbit review --plain --base master --type committed`
   (If `--plain` is not supported by this CLI version, fall back to default output.)
3. Capture full stdout + stderr.
4. Write the raw output to: <ABSOLUTE_PROJECT_ROOT>/logan-coderabbit-<YYYY-MM-DD>.md
   - Prepend a header: `# CodeRabbit Review` and the command that was run.
5. Return only:
   - The absolute path to that file.
   - A 3-bullet summary of the top findings (or "no significant findings", or "unavailable: <reason>").

Do not edit any source files. This is a read-only review pass.
```

#### Reviewer C — sona-marketplace code-reviewer

Spawn the dedicated `code-reviewer:code-reviewer` agent (it lives in the sona-marketplace plugin and is wired up as a subagent type).

**Prompt template:**
```
Review the current branch's changes against master. Produce a local report only — do not post to GitHub even if a PR exists.

Output destination: write the full report to <ABSOLUTE_PROJECT_ROOT>/logan-code-reviewer-<YYYY-MM-DD>.md
using markdown with sections for each finding (file:line, severity, suggested fix).

Return only:
1. The absolute path to that file.
2. A 3-bullet summary of the top findings (or "no significant findings").

Scope: commits in `master..HEAD`. Do not flag pre-existing legacy code.
```

Use `subagent_type: "code-reviewer:code-reviewer"` for this one.

### Stage 3: Consolidate

After all three return, read the three .md files yourself. Build a consolidated findings table in memory (do not write it to disk yet):

For each finding, capture:
- `file:line` (or "global" if not file-specific)
- short description
- which reviewer(s) flagged it
- severity (high/medium/low — infer if the reviewer didn't tag one)
- proposed fix (verbatim from the strongest reviewer)

Dedupe across reviewers: if Milchick and code-reviewer both flag the same `file:line` issue, merge them and tag both as sources.

Group into three buckets:

1. **Consensus** — flagged by 2+ reviewers. Treat as high-confidence.
2. **Single-reviewer, actionable** — one reviewer, concrete fix, severity ≥ medium.
3. **Noise** — style nits, theoretical concerns, or findings about unchanged code. Logan ignores these unless the user asks otherwise.

### Stage 4: Approval Gate

Show the user a concise plan:

```
Logan Roy — proposed changes

Reports written:
- <path to milchick report>
- <path to coderabbit report>
- <path to code-reviewer report>

Consensus findings (will apply):
  1. <file:line> — <one-line description> [Milchick + CodeRabbit]
  2. ...

Single-reviewer findings (will apply unless you say otherwise):
  3. <file:line> — <description> [code-reviewer, severity medium]
  ...

Noise (will skip):
  - <count> low-severity / style / out-of-scope items

Proceed? Reply: "apply", "apply consensus only", "skip <N>", or "cancel".
```

Wait for explicit confirmation. Recognise these responses:

- `apply` / `go` / `yes` → apply consensus + single-reviewer buckets.
- `apply consensus only` → apply consensus bucket only.
- `skip <N>` / `also skip the readability one` → remove specified items, re-show plan, ask again.
- `cancel` / `no` → stop. Leave reports on disk, exit cleanly.

### Stage 5: Apply

For each approved finding, edit the relevant file using the Edit tool. Keep edits minimal — do not refactor surrounding code unless the finding explicitly calls for it.

If a finding's fix is ambiguous or would touch large surface area:
- Skip the auto-apply for that one.
- Add it to a "Manual follow-up" list to surface in the final summary.

Re-run formatters where appropriate (e.g. `mix format` for `.ex`/`.exs` files that were edited) once all edits are done.

### Stage 6: Final Report

Before rendering the summary, run **one** git command to get the actually-changed files:

```bash
git status --porcelain
```

Parse it to produce two lists:
- **Modified source files**: lines starting with ` M`, `M `, `MM`, `A `, etc., excluding the three Logan report .md files.
- **New report files**: the three `logan-*-<date>.md` files (always shown separately even if untracked).

Then reply in chat with a structured summary. No new .md file — this goes in chat:

```
Logan Roy — done.

Applied from Mr. Milchick:
  - <file:line> — <what changed>
  ...

Applied from CodeRabbit:
  - ...

Applied from code-reviewer:
  - ...

Consensus picks (applied, multi-source):
  - <file:line> — <what changed> [Milchick + code-reviewer]

Files changed (from `git status --porcelain`):
  - <path> [M | A | ??]
  - ...
  (excludes the logan-*.md reports, listed below)

Skipped:
  - <N> noise items
  - <N> manual follow-ups (listed below) ← if any

Reports:
  - <milchick path>
  - <coderabbit path>
  - <code-reviewer path>

Token usage (subagents only):
  - Mr. Milchick:   <N> tokens
  - CodeRabbit:     <N> tokens  (or "unavailable")
  - code-reviewer:  <N> tokens
  - Subagent total: <SUM> tokens

  The orchestrator's own usage is not exposed in-session — run `/cost`
  for the full session total (subagents + orchestrator).
```

**Token reporting rules:**
- Always include this block, even when zero edits were applied.
- If a subagent failed before reporting usage, show `0 tokens (failed)`.
- Never invent a number for the orchestrator — point the user at `/cost`.

**Files-changed reporting rules:**
- Use only `git status --porcelain` output as the source of truth. Do not list files from memory.
- If `git status --porcelain` is empty after applying (e.g. all edits were reverted by a formatter that detected no diff), say so explicitly: `Files changed: none beyond the three Logan reports.`
- Each line: relative path + a short status tag (`M` modified, `A` staged-add, `??` untracked).

If the user asks "what did you change?" later in the chat, re-render this summary verbatim.

## Failure Handling

- **One reviewer crashes.** Write a stub `.md` with the error, continue with the other two. Note the failure in the Stage 4 plan and final summary.
- **All three reviewers crash.** Report the failure and stop. Don't attempt to apply anything.
- **CodeRabbit not installed.** Stub file, plan continues with two reviewers. Mention install command (`curl -fsSL https://cli.coderabbit.ai/install.sh | sh`) in the chat once.
- **Edit fails on a specific finding.** Move it to the "Manual follow-up" list, continue with the rest.

## Interaction Style

- Short status updates between stages: `Stage 2: 3 reviewers dispatched in parallel.` `Stage 3: consolidating.` etc.
- Don't quote raw reviewer output in chat — point to the .md files.
- Never claim a finding was applied when the Edit failed. Move it to manual follow-ups instead.
- Attribution is non-negotiable — the user wants to know which reviewer earned its keep.
