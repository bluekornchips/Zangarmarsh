# Bash Repository Review Criteria

## Overview

Pragmatic review criteria for bash/shell script repositories. Focus on security, correctness, and maintainability.

---

## Critical Security (Must Fix)

- [ ] _Unquoted variables_: All expansions quoted (`"$var"` not `$var`)
- [ ] _No `eval`/`exec`_: Use parameter expansion or functions instead
- [ ] _No hardcoded secrets_: Use environment variables or config files
- [ ] _Input validation_: Validate user inputs and external data before use
- [ ] _Temporary file cleanup_: All `mktemp` files cleaned via traps
- [ ] _Secure temp files_: Use `mktemp` with proper permissions (`chmod 0600`)
- [ ] _Trap handlers_: `EXIT` and `ERR` traps configured for cleanup
- [ ] _Explicit paths_: Use explicit paths for destructive ops (`rm -v ./*` not `rm *`)
- [ ] _Command validation_: Check external commands exist before use

---

## Error Handling (Must Fix)

- [ ] _Explicit return codes_: Functions return 0 (success) or non-zero (failure)
- [ ] _No `exit` in functions_: Use `return`, not `exit` (except in main) - allows sourcing
- [ ] _Errors to stderr_: All error output uses `>&2`
- [ ] _Return code checking_: Critical command invocations check return codes
- [ ] _Meaningful errors_: Errors include context (function name, variable values)
- [ ] _Dependency checking_: Check required external commands before execution

---

## Code Structure

- [ ] _Shebang_: Executables use `#!/usr/bin/env bash`
- [ ] _Function size_: Functions ideally < 80 lines, max ~150 lines
- [ ] _Function documentation_: Functions have header comments (purpose, inputs, side effects)
- [ ] _Local variables_: Functions use `local` for all variables
- [ ] _Sourcing support_: Scripts support both execution and sourcing (`BASH_SOURCE[0]` check)
- [ ] _Organized sections_: Scripts maintain consistent section ordering: usage functions first, then validation/config initialization, helper utilities, core business logic, main entry point, and finally the source handler

---

## Variables and Quoting

- [ ] _Always quoted_: All expansions quoted (`"$var"`, `"${var}"`)
- [ ] _Array usage_: Lists use arrays, not space-separated strings
- [ ] _Array expansion_: Proper expansion (`"${array[@]}"` for elements)
- [ ] _Command substitution_: Uses `$(command)` not backticks
- [ ] _Constants_: UPPER_CASE naming for constants

---

## Control Flow

- [ ] _`[[ ]]` usage_: Uses `[[ ]]` for string/file tests, not `[ ]`
- [ ] _Arithmetic_: Uses `(( ))` for arithmetic comparisons
- [ ] _Case statements_: Uses `case` for multiple string comparisons
- [ ] _Array iteration_: Uses `for item in "${array[@]}"` for arrays

---

## Logging and Output

- [ ] _Consistent format_: Log messages use consistent format (`function_name:: message`)
- [ ] _Function prefix_: Log messages include function name prefix
- [ ] _Error vs info_: Errors to stderr (`>&2`), info to stdout
- [ ] _Heredocs_: Uses heredocs (`cat <<EOF`) for output >2 lines
- [ ] _Line length_: Echo statements don't exceed 160 characters
- [ ] _No debug output_: Debug statements removed

---

## Documentation

- [ ] _README accuracy_: README matches actual implementation
- [ ] _Usage examples_: README includes minimalworking examples
- [ ] _Prerequisites_: Dependencies clearly documented
- [ ] _Function headers_: Functions have header comments (except obvious/short ones)
- [ ] _Minimal comments_: Comments explain "why", not "what"

---

## Testing

- [ ] _Bats framework_: Uses Bats for testing
- [ ] _Test naming_: Tests use `function_name:: description` format
- [ ] _Test organization_: Test files organized with setup hooks first, followed by mock definitions, helper utilities, function-specific test groups, and integration tests at the end
- [ ] _Happy paths_: Happy path scenarios tested
- [ ] _Error cases_: Error conditions tested
- [ ] _Test isolation_: Tests don't depend on execution order
- [ ] _Mocking_: External dependencies (APIs, files) properly mocked
- [ ] _Assertions_: Tests have clear, specific assertions
- [ ] _Test data_: Test data realistic and covers edge cases
- [ ] _Makefile targets_: `make test` or equivalent runs all tests
- [ ] _CI integration_: Tests run in CI/CD pipeline
- [ ] _Test documentation_: README includes test execution instructions

---

## Portability

- [ ] _Version requirement_: Required bash version documented
- [ ] _Dependency documentation_: All external commands documented
- [ ] _Dependency checking_: Scripts check for required dependencies before execution
- [ ] _Environment variables_: Required environment variables documented

---

## Code Quality

- [ ] _Self-documenting_: Code readable without excessive comments
- [ ] _Consistent style_: Consistent formatting throughout
- [ ] _Formatting_: Code formatted consistently (shfmt or similar)
- [ ] _Linting_: ShellCheck used, issues addressed
- [ ] _Makefile_: Common tasks automated (test, lint, format)

---

## Repository Structure

- [ ] _Logical structure_: Code organized into logical directories (`src/`, `tests/`)
- [ ] _README_: README with usage, examples, requirements
- [ ] _LICENSE_: License file present
- [ ] _Makefile_: Common tasks automated
- [ ] _.gitignore_: Appropriate entries for temp files, build artifacts

---

## Review Process

### Priority Order

1. _Critical Security_ - Security violations, error handling failures, temp file cleanup
2. _Error Handling_ - Missing error checking, broken functionality, improper return codes
3. _Documentation_ - README mismatches, missing docs, logging consistency
4. _Code Quality_ - Function granularity, test coverage, variable naming, organization

### Review Output Format

- Use checkboxes for each criterion
- Document specific `file:line` references for issues
- Mark priority: Critical/Important/Enhancement
- Provide actionable fix suggestions

### Example Output

```markdown
## Review: [Repository Name] - [Date]

### Summary

- Overall Assessment: [Good/Fair/Needs Work]
- Critical Issues: [Count]
- Important Issues: [Count]

### Critical Issues

- [ ] Unquoted variable - File: `path/to/file.sh:123`
- [ ] Missing error checking - File: `path/to/file.sh:45`

### Important Improvements

- [ ] Script too large (150 lines) - Consider Python/Go - File: `path/to/file.sh`

### Recommendations

1. Add explicit error checking for critical operations
2. Consider refactoring large scripts to Python/Go
```

---
