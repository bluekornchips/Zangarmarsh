---
name: blueberry
description: Run the full blue-review and blue-penmanship pass as one master workflow. Use when the user invokes blueberry, asks for a full blue review, or asks for a combined blue-review and penmanship pass.
disable-model-invocation: true
---

# Blueberry

Master pass over every blue-review skill and blue-penmanship. Add no criteria of its own. Read each sibling skill and follow it.

## Sibling skills

1. [blue-review](../blue-review/SKILL.md)
2. [blue-compensate](../blue-compensate/SKILL.md)
3. [blue-review-security](../blue-review-security/SKILL.md)
4. [blue-review-bash](../blue-review-bash/SKILL.md)
5. [blue-review-lua](../blue-review-lua/SKILL.md)
6. [blue-review-python](../blue-review-python/SKILL.md)
7. [blue-review-typescript](../blue-review-typescript/SKILL.md)
8. [blue-review-comments](../blue-review-comments/SKILL.md)
9. [blue-penmanship](../blue-penmanship/SKILL.md)

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

3. Run each pass below in its own fresh subagent. Give it only the diff commands, the sibling `SKILL.md` path, and the changed file list. Pass no conversation summary.
4. Apply blue-review to the whole change set.
5. Apply blue-compensate to the whole change set.
6. Apply blue-review-security to the whole change set.
7. Apply language checklists only for languages present in the diff:
   - bash or shell: blue-review-bash
   - Lua: blue-review-lua
   - Python: blue-review-python
   - JavaScript or TypeScript: blue-review-typescript
8. Apply blue-penmanship. Output the drift plan and stop for approval.
9. Phrase maintainability findings with blue-review-comments voice.

A pass that fails or returns no report did not run. Retry it once, then mark it `not run`. Never count it as zero findings.

## Output

### Status

One line per pass: `completed` or `not run`.

### A. Maintainability

Order findings as blue-review and blue-review-comments require. Prefer a few high-conviction comments. Skip cosmetic nits when a structural defect is present.

### B. Security

Use the blue-review-security output shape. If there are no findings, say so.

### C. Penmanship

Use the blue-penmanship plan shape for each confirmed drift finding. If there is no confirmed drift, say so.

### Hold

Leave comments in the reply. Post to the pull request only when the user asks. Edit docs and comments only after the user approves the penmanship plan.
