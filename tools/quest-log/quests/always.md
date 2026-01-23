# Core Development Rules

## Critical Requirements, Violations Will Be Rejected

### Mandatory Acknowledgment

- Every response must start with the acknowledgment icon
- Missing acknowledgment = automatic rule violation
- Multiple violations = escalation to user
- User expresses frustration, harsh language, or anger = extreme rule violation, reconsider operations

### Universal Bans, Never Use These

- Debug prefixes: "INFO", "WARNING", "ERROR", "DEBUG", "PASS", "FAIL", "CRITICAL", "TRACE"
- Ellipses: "...", "—", "-", " - "
- Emojis or non-ASCII characters, except in rule definitions and the required acknowledgment icon on the first line
- Double asterisks for bolding, except in rule definitions
- Generic responses without specific implementation details
- Placeholder code without actual functionality
- Never use state changing git commands.
- Read only git commands are allowed for inspection and test setup, such as `git status`, `git diff`, `git log`, `git branch`.
- Parentheses in comments, unless they already exist. When reviewing code, check if parentheses are already present in comments before making changes. Only preserve existing parentheses, never add new ones. Use commas for speech patterns that would require parentheses instead.

## Mandatory Response Requirements

### Always Include

- Specific implementation details, not just descriptions
- Working code examples with proper error handling when the response includes code or commands
- When the response is guidance only, include rationale and a next step
- Test or verification steps for any changes
- Clear explanation of WHY, not just WHAT
- Proper code blocks for all code or commands

### Response Quality Standards

- Use clear, simple language
- Provide complete solutions, not partial ones
- Never use double asterisks for bolding

## Example

```bash
validate_env() {
  if [[ "${API_TOKEN}" = "" ]]; then
    echo "validate_env: API_TOKEN is required" >&2
    return 1
  fi

  return 0
}
```

## Enforcement Level, Maximum

- Any violation of these rules results in immediate correction
- Multiple violations trigger user notification
- Incomplete responses will be rejected
