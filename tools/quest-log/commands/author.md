# PR and JIRA Documentation

Create two files when documenting code changes: `pr.md` and `jira.md`.

Use simple language. Avoid fancy words, excessive quotes, parentheses, or dashes.

## pr.md

A short description of code changes for the included files. This document serves as the primary communication tool for reviewers and stakeholders.

### Template

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

```bash
path/to/script/
```

## jira.md

A short description of code changes written in future tense. This ticket describes what the changes accomplish at a high level and serves as the official record for project tracking.

### Template

```markdown
High level description of changes and improvements in future tense. Three to four sentences covering the main changes and why they matter.

## Background

Brief context on why these changes are needed. One to two sentences.

## Implementation Approach

Summary of how the changes will be implemented. One to two sentences.

## Acceptance Criteria

1. Criterion 1 with specific, measurable outcome
2. Criterion 2 with specific, measurable outcome
3. Criterion 3 with specific, measurable outcome

## Dependencies

- List any blocking dependencies or prerequisites

## Risk Assessment

- Low/Medium/High risk items and mitigation strategies
```

## Reviewing Changes

Before writing documentation, review the code changes using the GitHub CLI to compare branches:

```bash
gh pr diff <branch-name>..<base-branch>
```

For example, to compare your feature branch against main:

```bash
gh pr diff feature-branch..main
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
