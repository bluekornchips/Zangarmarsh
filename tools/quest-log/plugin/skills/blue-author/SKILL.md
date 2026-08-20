---
name: blue-author
description: Creates accurate pr.md and issue.md delivery documents from current code changes. Use when the user explicitly invokes blue-author for PR or issue documentation.
disable-model-invocation: true
---

# PR and Issue Documentation

Create `pr.md` for reviewers and `issue.md` for the issue tracker. These are
current delivery artifacts, not historical records.

Use simple words. Write clearly and directly. Keep each document concise.
Do not invent issue links, requirements, test results, risks, or behavior.

## Source of truth

Before writing:

1. Read any issue, specification, or acceptance criteria the user supplied.
2. Inspect the current branch, staged changes, unstaged changes, and untracked
   files with read-only Git commands.
3. Compare the branch with the user-provided base branch when one is given.
4. Read the changed files needed to understand intent and behavior.
5. Use test output from the current session. Never claim a test passed when it
   was not run.

If intent cannot be proven from those sources, state the uncertainty or ask the
user. Do not fill gaps with guesses.

## pr.md

Write completed changes in past tense. Describe the current diff and why it
matters. Do not narrate development history.

### pr.md template

````markdown
## Issue Information

- Issue Link: Not provided

## Description

One or two sentences that state the change and its purpose.

Key highlights:

- Specific behavior or implementation change
- User or maintainer impact
- Required configuration change, when present

## Testing Instructions

```bash
exact command a reviewer can run
```

Expected result in one sentence.
````

Replace `Not provided` only when the user or repository supplies a real issue
link. Testing instructions must be runnable from the documented working
directory.

## issue.md

Write requested work in future tense. Define the desired outcome, not the
implementation history.

### issue.md template

```markdown
High-level description of the requested change and why it matters.

## Background

Current problem or constraint in one or two sentences.

## Acceptance Criteria

1. Specific observable outcome
2. Specific failure or edge-case behavior
3. Exact verification requirement
```

Use measurable acceptance criteria. Avoid internal implementation detail unless
the implementation itself is required.

## Boundaries

- Create both files only when the user explicitly invokes this skill.
- If either file already exists, read it before replacing it.
- Keep current project-specific fields that remain valid.
- Do not create changelogs, migration histories, deprecation histories,
  timelines, release journals, or records of prior work.
- Do not preserve obsolete behavior or document compatibility plans.
- Do not include secrets, credentials, personal data, or private URLs.
- Do not use vague claims such as "improved performance" without evidence.

## Final check

- `pr.md` uses past tense and matches the current diff.
- `issue.md` uses future tense and has measurable acceptance criteria.
- Commands are complete and runnable.
- Test claims match observed results.
- No placeholder remains except `Issue Link: Not provided`.
