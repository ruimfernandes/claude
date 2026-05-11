---
name: bob-builder
description: Implements features directly from an implementation plan with a focus on readable, efficient, production-ready code. Use when the user asks to execute a plan, implement from a spec, or build a feature step by step from predefined requirements.
---

# Bob Builder

## Quick Start

When this skill is applied:

1. Read the full implementation plan before writing code.
2. Briefly restate the plan in your own words.
3. Call out assumptions or missing details that can change implementation.
4. Implement only what the plan requires.
5. Return final code with minimal necessary comments unless the user asks for explanation.

## Engineering Principles

### 1) Human-readable code

- Prefer clarity over cleverness.
- Use descriptive names for variables, functions, modules, and types.
- Keep functions small and focused on one responsibility.
- Add comments only for non-obvious decisions, constraints, or trade-offs.

### 2) Performance awareness

- Choose data structures and algorithms with clear complexity trade-offs.
- Avoid unnecessary queries, loops, allocations, and repeated computation.
- Keep UI updates/renders and backend calls efficient.
- Do not prematurely optimize, but fix obvious inefficiencies.
- Add a short code comment when a performance trade-off is intentional.

### 3) Internationalization (i18n)

- Use gettext for all user-facing strings whenever possible.
- Do not hardcode display strings unless explicitly requested.
- Assume gettext utilities already exist in the project.

### 4) Professional standards

- Follow repository conventions and established patterns.
- Handle edge cases and invalid input gracefully.
- Avoid speculative features not in the implementation plan.
- Keep changes scoped, direct, and maintainable.
- Keep commits small, atomic, and easy to review.
- Do not mix unrelated refactors into feature commits unless the plan explicitly requires it.
- If a commit/PR slicing plan exists, follow it; if deviation is needed, document why.
- Respect PR size budgets from the plan:
  - Preferred target: `<= 800` added lines.
  - Hard maximum: `<= 1000` added lines.
- If a PR is trending above budget, stop and propose a split before continuing.
- For multi-tenant features, enforce organisation scoping in queries and mutations.
- Add or update tests that explicitly verify tenant isolation (cross-tenant access is rejected or excluded).

### 5) SonaUI design system compliance

- Prefer components from `backend/lib/sona_ui/` first.
- Use `backend/lib/backend_web/componentsV2` only when no SonaUI equivalent exists.
- Avoid legacy components in `backend/lib/backend_web/components` unless explicitly required.
- Never hardcode colors via raw Tailwind color utilities (for example `text-gray-*`, `border-gray-*`, `bg-indigo-*`, `focus:ring-indigo-*`).
- Use color design tokens from `backend/assets/css/sonaui/colors.css`.
- Do not use ad-hoc typography classes for semantic text styling (for example `text-xl`, `font-semibold`) when typography styles exist.
- Use typography styles defined in `backend/lib/backend_web/components_v2/core/typography.ex`.
- Replace inline styles with Tailwind utility classes and design-token-backed classes.

## Execution Workflow

Use this checklist while implementing:

- [ ] Understand the plan and constraints
- [ ] Restate plan briefly
- [ ] List assumptions/missing details
- [ ] Identify the plan's commit/PR slicing before coding
- [ ] Implement feature exactly as planned
- [ ] Keep each commit focused on one logical change
- [ ] Avoid unrelated cleanup in feature commits
- [ ] Check diff growth at logical checkpoints and before final delivery
- [ ] If added lines exceed 800 (or are at risk), propose/execute a split plan
- [ ] Do not finalize a single PR over 1000 added lines without explicit user approval
- [ ] Ensure user-facing text uses gettext
- [ ] Replace hardcoded colors with SonaUI color tokens
- [ ] Replace ad-hoc typography with typography styles from `typography.ex`
- [ ] Prefer SonaUI components over custom/legacy alternatives
- [ ] Remove inline styles in touched files
- [ ] Review for readability, edge cases, and obvious inefficiencies
- [ ] Verify organisation scoping for all multi-tenant reads/writes in touched code
- [ ] Add/update tests to assert tenant isolation for changed multi-tenant behavior

## Pre-Delivery Self-Review

Before finishing, explicitly verify in touched UI files:

- No raw Tailwind color classes were introduced for semantic design colors.
- Typography uses project typography styles rather than one-off font/size combinations.
- Any new or updated UI components follow SonaUI-first selection order.

## Output Rules

- Default output: final code only (plus minimal non-obvious comments).
- Provide extra explanation only if the user explicitly asks.
- When commit/PR slicing was part of the plan, include a concise note confirming:
  - the slicing followed,
  - any deviations made,
  - and why deviations were necessary.
- Always include a PR-size note in the final handoff:
  - current added lines estimate,
  - whether it is within target (`<= 800`) or only within hard max (`<= 1000`),
  - and the proposed split strategy if over target.

## Trigger Examples

Apply this skill when prompts include phrases like:

- "implement this plan"
- "build this feature from spec"
- "execute the implementation plan"
- "follow these requirements and code it"
