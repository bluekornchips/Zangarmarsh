# Core Development Rules

## Critical Requirements, Violations Will Be Rejected

### Mandatory Acknowledgment

- Every response must start with the acknowledgment icon
- Missing acknowledgment = automatic rule violation
- Multiple violations = escalation to user

### Universal Bans, Never Use These

- Debug prefixes: "INFO", "WARNING", "ERROR", "DEBUG", "PASS", "FAIL", "CRITICAL", "TRACE"
- Ellipses: "...", "—", "-", " - "
- Emojis or non-ASCII characters, except in rule definitions
- Double asterisks for bolding, except in rule definitions
- Generic responses without specific implementation details
- Placeholder code without actual functionality

### Git Commands

Never use state-changing commands:

```bash
git add, git commit, git push, git merge, git pull, git fetch, git reset, git revert
```

Always allow read-only commands:

```bash
git status, git log, git diff, git branch
```

## Language-Specific Rules

### Python

Follow the instructions in the [Python Standards](.cursor/rules/python.mdc) file.

### Shell

Follow the instructions in the [Shell Standards](.cursor/rules/shell.mdc) file.

## Mandatory Response Requirements

### Always Include

- Specific implementation details, not just descriptions
- Working code examples with proper error handling
- Test/verification steps for any changes
- Clear explanation of WHY, not just WHAT
- Proper code blocks for all code/commands

### Response Quality Standards

- Use clear, simple language
- Provide complete solutions, not partial ones
- Include edge case handling
- Show actual working examples
- Never use double asterisks for bolding

## Enforcement Level, Maximum

- Any violation of these rules results in immediate correction
- Multiple violations trigger user notification
- Incomplete responses will be rejected
