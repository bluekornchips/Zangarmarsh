---
name: blueberry
description: Run blue-review and blue-penmanship as one workflow on Auto Cost. Use when the user invokes blueberry, asks for a full blue review, or asks for a combined blue-review and penmanship pass.
disable-model-invocation: true
---

# Blueberry

Master pass over blue-review and blue-penmanship. Add no criteria of its own. Read each sibling skill and follow it.

## Cost

Auto Cost is a hard requirement for every blueberry pass.

- Launch each pass only through the pinned blueberry agents: `blueberry-review` and `blueberry-penmanship`.
- Those agents pin `auto-smart[optimize_for=cost]`.
- Never inherit the parent model. Never pass a Task `model` argument; the agent frontmatter owns the pin.
- Never use Balance, Intelligence, Composer Fast, Grok Fast, Opus, or other frontier or high-effort slugs for a blueberry pass.
- Keep the parent to gathering diffs and assembling the reply. Do the review and penmanship work only in those agents.
- If a pinned agent is missing, stop and report that. Do not fall back to `generalPurpose`, `thermo-nuclear-code-quality-review`, or an unpinned Task call.

## Sibling skills

1. [blue-review](../blue-review/SKILL.md)
2. [blue-penmanship](../blue-penmanship/SKILL.md)

## Workflow

1. Read every sibling `SKILL.md` listed above.
2. Gather the current branch with read-only git:

```bash
git status --short
git diff
git diff --cached
git rev-parse --verify origin/main
git diff origin/main...HEAD
```

If the user names another base, use that. If `origin/main` is missing, use `main`. Stop and report when the base does not resolve or every diff is empty.

3. Run each pass in its own fresh blueberry agent. Give it only the diff commands, the sibling `SKILL.md` path, and the changed file list. Pass no conversation summary.
4. Launch `blueberry-review` for blue-review over the whole change set.
5. Launch `blueberry-penmanship` for blue-penmanship. Output the drift plan and stop for approval.

A pass that fails or returns no report did not run. Retry it once on the same pinned agent, then mark it `not run`. Never count it as zero findings. Never retry on a costlier model.

## Output

### Status

One line per pass: `completed` or `not run`.

### A. Maintainability

Order findings as blue-review requires. Prefer a few high-conviction comments. Skip cosmetic nits when a structural defect is present.

### B. Penmanship

Use the blue-penmanship plan shape for each confirmed drift finding. If there is no confirmed drift, say so.

### Hold

Leave comments in the reply. Post to the pull request only when the user asks. Edit docs and comments only after the user approves the penmanship plan.
