---
name: blue-author
description: Creates accurate pr.md and issue.md delivery documents from current code changes. Use when the user explicitly invokes blue-author for PR or issue documentation.
disable-model-invocation: true
---

# PR and Issue Documentation

Create `pr.md` for reviewers and `issue.md` for the issue tracker. These are current delivery artifacts.

Use simple words. Write the way a person would say the fact. Keep each document short. Shorter delivery docs are required.

State only what the current code, the supplied request, or a test run in this session proves. When a fact is missing, say it is unknown. Do not invent issue links, requirements, test results, risks, or behavior.

## Source of truth

Before writing:

1. Read any issue, specification, or acceptance criteria the user supplied.
2. Inspect the current branch, staged changes, unstaged changes, and untracked files with read-only Git commands.
3. Compare the branch with the base branch when the user names one.
4. Read the changed files needed to understand intent and behavior.
5. Use test output from the current session. Claim a pass only when this session ran that test and it passed.

## Voice

- One fact per sentence.
- Use the words already in the code and the request.
- Each highlight or criterion adds a new fact.
- Skip stock wording such as robust, leverage, seamless, comprehensive, utilize, and "this change".
- Skip file banners, timelines, and records of prior work.

## pr.md

Write completed changes in past tense. Describe the current diff and why it matters.

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

Replace `Not provided` only when the user or repository supplies a real issue link. The testing command must run from the documented working directory. The expected result must follow from the diff or from a test this session already ran.

## issue.md

Write requested work in future tense. Define the desired outcome.

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

Each acceptance criterion is an observable outcome a reviewer can check. Include the exact verification step. Include implementation detail only when the user required that implementation.

## Boundaries

- Create both files only when the user explicitly invokes this skill.
- When either file already exists, read it before replacing it.
- Keep a current project-specific field when it is still true.
- Skip changelogs, migration histories, deprecation histories, timelines, release journals, and records of prior work.
- Skip obsolete behavior and compatibility plans.
- Skip secrets, credentials, personal data, and private URLs.

## Final check

- `pr.md` uses past tense and matches the current diff.
- `issue.md` uses future tense and states measurable acceptance criteria.
- Commands are complete and runnable.
- Test claims match observed results.
- The only placeholder left is `Issue Link: Not provided`.
- Both documents state facts in plain sentences and stay short.
