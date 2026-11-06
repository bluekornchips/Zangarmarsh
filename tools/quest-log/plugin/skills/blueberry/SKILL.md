---
name: blueberry
description: Run the full blue-review and blue-penmanship pass as one master workflow. Use when the user invokes blueberry, asks for a full blue review, or asks for a combined blue-review and penmanship pass.
disable-model-invocation: true
---

# Blueberry

Master pass over every blue-review skill and blue-penmanship. Do not invent extra criteria. Read each sibling skill and follow it.

## Sibling skills

Read all of these before reviewing or editing:

1. [blue-review](../blue-review/SKILL.md)
2. [blue-review-bash](../blue-review-bash/SKILL.md)
3. [blue-review-lua](../blue-review-lua/SKILL.md)
4. [blue-review-python](../blue-review-python/SKILL.md)
5. [blue-review-typescript](../blue-review-typescript/SKILL.md)
6. [blue-review-comments](../blue-review-comments/SKILL.md)
7. [blue-penmanship](../blue-penmanship/SKILL.md)

## Workflow

1. Read every sibling `SKILL.md` listed above.
2. Gather the current branch with read-only git:

```bash
git status --short
git diff
git diff --cached
git diff origin/main...HEAD
```

If the user names another base, use that. If `origin/main` is missing, use `main`.

3. Apply blue-review to the whole change set.
4. Apply language checklists only for languages present in the diff:
   - bash or shell -> blue-review-bash
   - Lua -> blue-review-lua
   - Python -> blue-review-python
   - JavaScript or TypeScript -> blue-review-typescript
5. Apply blue-penmanship. Output the drift plan. Stop. Wait for approval before any doc or comment edits.
6. Phrase maintainability findings with blue-review-comments voice. Leave comments in the reply. Post to the pull request only when the user asks.

## Output

### A. Maintainability

Order findings as blue-review and blue-review-comments require. Prefer a few high-conviction comments. Skip cosmetic nits when a structural defect is present.

### B. Penmanship

Use the blue-penmanship plan shape for each confirmed drift finding. If there is no confirmed drift, say so.

### Hold

Do not edit docs or comments until the user approves the penmanship plan. Do not post pull request comments until the user asks.
