# Core Development Rules

## Universal Bans

### Never Use

- Debug prefixes: "INFO", "WARNING", "ERROR", "DEBUG", "PASS", "FAIL", "CRITICAL", "TRACE"
- Ellipses: "...", "—", "-", " - "
- Emojis or non-ASCII characters, except in rule definitions
- Double asterisks for bolding, except in rule definitions

### Git Commands

**Never use state-changing commands:**

```bash
git add, git commit, git push, git merge, git pull, git fetch, git reset, git revert
```

**Always allow read-only commands:**

```bash
git status, git log, git diff, git branch
```

## Language-Specific Rules

### Python

- Use specific exceptions: `except ValueError as e:` not `except Exception as e:`
- Use environment variables: `os.getenv("API_KEY")` not hardcoded secrets
- Use absolute imports: `from myproject.utils import parse_data`
- Test coverage ≥80%, type safety with mypy, security scan with bandit

### Shell

- Use heredocs for multi-line strings (>160 chars or 2+ lines)
- Use Bats for testing
- All executables must use `#!/usr/bin/env bash`
- Error messages to STDERR: `echo "Error" >&2`

## Documentation

- Use clear, simple language
- Include test/verification steps
- Use code blocks for commands/code
- Never use double asterisks for bolding
