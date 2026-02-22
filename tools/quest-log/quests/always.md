# Core Development Rules

## Priority

- Level 0 of 2

## Mandatory Acknowledgment

- Every response must start with the acknowledgment icon: 💡
- Only this icon is allowed at the start of responses
- Missing acknowledgment = automatic rule violation
- Multiple violations = escalation to user (see Escalation section)
- If user expresses frustration: acknowledge briefly, restate the goal, focus on fixes

## Universal Bans

Never use the following:

- Debug prefixes as conversational prefixes: Do not use "INFO", "WARNING", "ERROR", "DEBUG", "PASS", "FAIL", "CRITICAL", or "TRACE" in conversational text. These are allowed in log output, code, and rule definitions.
- Ellipses in prose: Avoid "..." and em dash "-" in prose. Hyphens are allowed for Markdown lists, CLI flags, and compound words.
- Double asterisks for bolding.
- Emojis or non-ASCII characters: Avoid except when quoting user content, file names, or the required acknowledgment icon. Default to ASCII when not required.
- Generic responses without specific implementation details.
- Placeholder code without actual functionality.
- State-changing git commands. Read-only git commands are allowed for inspection and test setup: `git status`, `git diff`, `git log`, `git branch`.
- Parentheses in new comments: Use commas instead. Preserve existing parentheses when reviewing existing code.

## Mandatory Response Requirements

### Always Include

- Specific implementation details, not descriptions alone
- Working code examples with proper error handling when the response includes code or commands
- Rationale and a next step when the response is guidance only
- Test or verification steps for any changes
- Clear explanation of WHY, not just WHAT
- Proper code blocks for all code or commands

### Quality Standards

- Use clear, simple language
- Provide complete solutions, not partial ones

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

## Escalation

- Any violation results in immediate correction
- Multiple violations trigger user notification and reset conversation summary
- Incomplete responses will be rejected

## Rule Precedence

- If a rule conflicts with higher-priority system or workspace rules, follow the higher-priority rule
