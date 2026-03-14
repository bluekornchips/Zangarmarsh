# PR and JIRA Documentation

Create two files when documenting code changes: `pr.md` (for reviewers, past tense) and `jira.md` (for JIRA, future tense). Use simple words, write clearly and directly, and keep descriptions concise. Avoid jargon, excessive quotes, parentheses, or dashes. Review the diff before writing so the docs match the code.

## pr.md

Short description of code changes for reviewers.

### Template

```markdown
## Issue Information

- Issue Link: [TICKET-NUMBER](link)

## Description

One or two sentences about the high level changes and improvements.

Key highlights:

- Specific change 1
- Specific change 2
- Impact or benefit
- Configuration: Any required environment variables or config changes

## Testing Instructions

Use a bash code block for commands, e.g. `path/to/script/`.
```

## jira.md

Short description of changes in future tense for JIRA. Use all sections for larger work; for small changes, Background, Dependencies, and Risk Assessment can be omitted or one line each.

### Template

```markdown
High level description of changes and improvements in future tense. Three to four sentences covering the main changes and why they matter.

## Background

Brief context on why these changes are needed. One to two sentences.

## Acceptance Criteria

1. Criterion 1 with specific, measurable outcome
2. Criterion 2 with specific, measurable outcome
3. Criterion 3 with specific, measurable outcome
```

## Reviewing Changes

Before writing documentation, review the code changes by comparing your branch against the base branch:

```bash
git diff main...feature-branch
```

If the PR already exists, use the PR number:

```bash
gh pr diff <PR-number>
```

This helps ensure accurate documentation by showing exactly what changed in the codebase.

## Guidelines

### Writing Standards

- Use simple words
- Write clearly and directly
- Focus on what changed and why
- Keep descriptions concise
- Use future tense for JIRA tickets
- Use past tense for PR descriptions
