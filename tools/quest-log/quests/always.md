# Core Development Rules

## Universal Bans

### Never Use

- Debug prefixes: "INFO", "WARNING", "ERROR", "DEBUG", "PASS", "FAIL", "CRITICAL", "TRACE"
- Ellipses: "...", "—", "-", " - "
- Emojis or non-ASCII characters, except in rule definitions
- Double asterisks for bolding, except in rule definitions

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

## Documentation

- Use clear, simple language
- Include test/verification steps
- Use code blocks for commands/code
- Never use double asterisks for bolding
