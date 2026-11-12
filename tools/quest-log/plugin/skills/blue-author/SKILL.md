---
name: blue-author
description: Creates accurate pr.md and issue.md delivery documents from current code changes. Use when the user explicitly invokes blue-author for PR or issue documentation.
disable-model-invocation: true
---

# PR and Issue Documentation

Create `pr.md` for reviewers and `issue.md` for the issue tracker. Both are current delivery artifacts. Create them only when the user explicitly invokes this skill. Read an existing file before replacing it, and keep a project-specific field that is still true.

## Source of truth

State only what the current code, the supplied request, or a test run in this session proves. When a fact is missing, say it is unknown. Do not invent issue links, requirements, test results, risks, or behavior.

1. Read any issue, specification, or acceptance criteria the user supplied.
2. Inspect the current branch, staged changes, unstaged changes, and untracked files with read-only Git commands.
3. Compare the branch with the base branch when the user names one.
4. Read the changed files needed to understand intent and behavior.
5. Claim a test pass only when this session ran that test and it passed.

## Voice

- Use simple words and the words already in the code and the request.
- One fact per sentence. Each highlight or criterion adds a new fact.
- Keep each document short.
- Skip stock wording such as robust, leverage, seamless, comprehensive, utilize, and "this change".
- Skip file banners, changelogs, migration or deprecation notes, timelines, release journals, compatibility plans, and records of prior work.
- Skip conversation, prompt, or iteration history in `pr.md`, `issue.md`, and other maintainer-facing prose.
- Skip secrets, credentials, personal data, and private URLs.

## pr.md

Write completed changes in past tense. Describe the current diff and why it matters.

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

## Risk

Two-way door. Reverting the merge restores the prior behavior.
````

Replace `Not provided` only when the user or repository supplies a real issue link. The testing command must run from the documented working directory. The expected result must follow from the diff or from a test this session already ran.

A change is a one-way door when it deletes data, publishes an artifact, or overwrites host files. For a one-way door, add one sentence on what a revert cannot undo.

## issue.md

Write requested work in future tense. Define the desired outcome.

```markdown
High-level description of the requested change and why it matters.

## Background

Current problem or constraint in one or two sentences.

## Acceptance Criteria

1. Specific observable outcome
2. Specific failure or edge-case behavior
3. Exact verification requirement
```

Each criterion is an observable outcome a reviewer can check, with the exact verification step. Include implementation detail only when the user required it.

## Final check

- `pr.md` matches the current diff.
- A two-sentence restatement of what `pr.md` claims matches the diff. Rewrite `pr.md` when it does not.
- `issue.md` states measurable criteria.
- Commands are complete and runnable.
- Test claims match observed results.
- The only placeholder left is `Issue Link: Not provided`.
