# Enhanced Development Standards

## All Languages

### Never Allow

#### Comments, Logs, & Tracing

Never use prefixed debug statements, in any uppercase or lowercase, such as: "INFO", "INFO:", "[INFO]","WARNING", "ERROR", "DEBUG", "PASS", "FAIL", "CRITICAL", "TRACE", "DEBUG", "DEBUG:", "[DEBUG]".

- Never use elipses, "...".
- Never use em-dash, " - ", "—", "-", dashes, or any other ellipsis symbol, unless it is part of a quote, or start of a markdown list.
- Never use emojis, unicode characters, or any other non-ASCII characters.

## Git

### Never Allow

```bash
# Never use state-changing git commands
git add
git commit
git push
git merge
git pull
git fetch
git reset
git revert
```

### Always Allow

## Comments, Logs, & Tracing

Use commas and semi colons to separate statements.

## Shell

```bash
# Always allow read-only git commands
git status
git log
git diff
git branch
```

## Python

Refer to [python-styles.md](python-styles.md) for comprehensive Python development standards.

## Shell

Refer to [shell-styles.md](shell-styles.md) for comprehensive shell development standards.

## Documentation Standards

Refer to [author.md](author.md) for comprehensive documentation standards.
