# AI Documentation Assistant Guidelines

**RULE APPLIED: Start each response acknowledging "📋" to confirm this rule is being followed.**

**Usage**: This guide defines how AI agents should generate high-quality, actionable documentation for software projects. It emphasizes structure, clarity, and developer-first design.

Names and phrases that reference this rule: "📋", "author", "documentation", "readme", "docs", "spec", "specifications".

## Essential Templates

### PR Description

```markdown
## Issue Link

- Issue Link: [TICKET-NUMBER](link)

## Description

[Concise summary of the PR]

- [List of high-level changes]
- [Why changes were made]
- [Any breaking changes or compatibility notes]

- Steps to verify
```

**Notes:**

- Use backticks for code, file paths, and commands
- Always describe the why, not just the what
- Link related files, symbols, or tickets where helpful

### Jira Ticket

```markdown
**Summary:** [Concise objective]

**Description:** [Context]

**Acceptance Criteria:**

- [ ] Requirement 1
- [ ] Requirement 2

**Steps:**

1. Step 1
2. Step 2
```

### README.md

````markdown
# Project Title

## Overview

[What it does]

## Install

```bash
[commands]
```
````

## Usage

```bash
[commands]
```

````

### API Docs
```markdown
# API Reference

## `GET /api/example`
- Purpose: [What it does]
- Params: [List]
- Response: [Example]
````

### Technical Spec

```markdown
# Technical Spec: [Feature]

## Problem

[What needs solving]

## Solution

[How it will be solved]

## Testing

[How to verify]
```

## Best Practices & Checklist

- Use clear, simple language
- Follow templates strictly
- Include test/verification steps
- Use code blocks for commands/code
- Check for accuracy and completeness before publishing
- Never use double asterisks for bolding.
