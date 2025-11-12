# Bash Repository Review Criteria

## Overview

Comprehensive review criteria for bash/shell script repositories. Focus on security, error handling, portability, and maintainability.

---

## Critical Security (Must Fix)

- [ ] _Unquoted variables_: All expansions quoted (`"$var"` not `$var`) - prevents word splitting/pathname expansion
- [ ] _No `eval`/`exec`_: Use parameter expansion or functions instead - prevents arbitrary code execution
- [ ] _No `sudo`_: Scripts should not require elevated privileges - limits blast radius
- [ ] _No dangerous commands_: Validate inputs before destructive operations (`rm -rf /`, etc.)
- [ ] _No hardcoded secrets_: Use environment variables or config files - prevents credential exposure
- [ ] _Input validation_: Validate all user inputs and external data before use
- [ ] _Temporary file cleanup_: All `mktemp` files cleaned via traps, not manual `rm`
- [ ] _Secure temp files_: Use `mktemp` with proper permissions (`chmod 0600`)
- [ ] _Trap handlers_: `EXIT` and `ERR` traps configured for cleanup
- [ ] _Explicit paths_: Use explicit paths for destructive ops (`rm -v ./*` not `rm *`)
- [ ] _Command validation_: Check external commands exist before use
- [ ] _Path validation_: Validate file paths (existence, permissions) before operations

---

## Error Handling (Must Fix)

- [ ] _`set -eo pipefail`_: All scripts use strict error handling
- [ ] _Explicit return codes_: Functions return 0 (success) or non-zero (failure)
- [ ] _No `exit` in functions_: Use `return`, not `exit` (except in main) - allows sourcing
- [ ] _Errors to stderr_: All error output uses `>&2`
- [ ] _Return code checking_: All command invocations check return codes
- [ ] _Meaningful errors_: Errors include context (function name, variable values, file paths)
- [ ] _Error propagation_: Errors properly propagated up call stack
- [ ] _Validation before ops_: Inputs validated before processing
- [ ] _Empty input handling_: Scripts handle empty/null inputs gracefully
- [ ] _Dependency checking_: Check required external commands (`jq`, `curl`, etc.) before execution
- [ ] _Network failure handling_: API calls handle timeouts and connection failures
- [ ] _File system errors_: Handle missing files, permission errors, disk full scenarios

---

## Code Structure

### File Structure

- [ ] _Shebang_: Executables use `#!/usr/bin/env bash`
- [ ] _File header_: Scripts include purpose description in header comments
- [ ] _Function organization_: Functions logically organized (helpers before main)
- [ ] _Sourcing support_: Scripts support both execution and sourcing (`BASH_SOURCE[0]` check)

### Function Design

- [ ] _Single responsibility_: Each function has one clear purpose
- [ ] _Function size_: Ideally < 50 lines, max ~100 lines
- [ ] _Function documentation_: Header comments include purpose, inputs, side effects, return values, API references
- [ ] _Function naming_: Descriptive verb-based names (`create_block`, not `cb`)
- [ ] _Local variables_: Functions use `local` for all variables (except intentional globals)

### Code Organization

- [ ] _Reusable functions_: Common operations extracted into reusable functions
- [ ] _No duplication_: DRY principle followed
- [ ] _Separation of concerns_: Business logic separated from I/O, validation, formatting

---

## Variables and Quoting

- [ ] _Local scope_: Functions declare variables as `local` before use
- [ ] _Explicit declaration_: Variables declared separately from assignment when needed
- [ ] _Export only when needed_: `export` used only for variables that need inheritance
- [ ] _Constants_: UPPER_CASE naming, defined at top of file
- [ ] _Descriptive names_: Clear names (`input_payload_file` not `inp`)
- [ ] _Consistent naming_: Consistent patterns (`input_*`, `output_*`, `temp_*`)
- [ ] _No magic values_: Magic numbers/strings extracted to named constants
- [ ] _Array usage_: Lists use arrays, not space-separated strings
- [ ] _Always quoted_: All expansions quoted (`"$var"`, `"${var}"`)
- [ ] _Array expansion_: Proper expansion (`"${array[@]}"` for elements, `"${array[*]}"` for string)
- [ ] _Command substitution_: Uses `$(command)` not backticks
- [ ] _Arithmetic_: Uses `(( ... ))` for conditionals, not `$(( ... ))`

---

## Control Flow

- [ ] _`[[ ]]` usage_: Uses `[[ ]]` for string/file tests, not `[ ]`
- [ ] _Arithmetic comparisons_: Uses `(( ))` for arithmetic
- [ ] _Pattern matching_: Appropriate operators (`==`, `=~`, `-z`, `-n`, `-f`, etc.)
- [ ] _Case statements_: Uses `case` for multiple string comparisons
- [ ] _Array iteration_: Uses `for item in "${array[@]}"` for arrays
- [ ] _Safe iteration_: Handles empty arrays/inputs gracefully
- [ ] _Loop scoping_: Loop variables don't leak to parent scope
- [ ] _Readable conditions_: Complex conditions broken into intermediate variables
- [ ] _Early returns_: Uses early returns to reduce nesting
- [ ] _Clear intent_: Code intent obvious without excessive comments

---

## Logging and Output

- [ ] _Consistent format_: Log messages use consistent format (`function_name: message`)
- [ ] _Function prefix_: Log messages include function name prefix
- [ ] _Error vs info_: Errors to stderr (`>&2`), info to stdout
- [ ] _Concise messages_: Provide context without verbosity
- [ ] _Heredocs_: Uses heredocs (`cat <<EOF`) for output >2 lines
- [ ] _Line length_: Echo statements don't exceed 160 characters
- [ ] _Structured output_: JSON/structured output properly formatted and validated
- [ ] _No debug output_: Debug statements removed or gated behind debug flag
- [ ] _Operation logging_: Significant operations logged (API calls, file operations)
- [ ] _Error context_: Error logs include relevant context (file paths, variable values)
- [ ] _Success confirmation_: Critical operations log success when appropriate

---

## Documentation

- [ ] _README accuracy_: README matches actual implementation
- [ ] _Usage examples_: README includes working, tested examples
- [ ] _Prerequisites_: Dependencies and requirements clearly documented
- [ ] _Installation_: Installation steps clear and complete
- [ ] _Function headers_: All functions have header comments (except obvious/short ones)
- [ ] _Input documentation_: Function inputs clearly documented
- [ ] _Side effects_: Side effects explicitly documented
- [ ] _Return values_: Return codes and output documented
- [ ] _API references_: External API usage includes reference links
- [ ] _Minimal comments_: Comments explain "why", not "what"
- [ ] _Complex logic_: Complex jq expressions, regex patterns, algorithms explained
- [ ] _Workarounds_: Workarounds and non-obvious solutions documented
- [ ] _TODOs_: TODOs include context and impact assessment

---

## Testing

- [ ] _Bats framework_: Uses Bats for all testing
- [ ] _Test organization_: Tests mirror source structure
- [ ] _Test naming_: Tests use `function_name:: description` format
- [ ] _Happy paths_: Happy path scenarios tested
- [ ] _Error cases_: Error conditions and edge cases tested
- [ ] _Setup/teardown_: Proper use of `setup_file()` and `setup()` functions
- [ ] _Test isolation_: Tests don't depend on execution order
- [ ] _Mocking_: External dependencies (APIs, files) properly mocked
- [ ] _Assertions_: Tests have clear, specific assertions
- [ ] _Test data_: Test data realistic and covers edge cases
- [ ] _Makefile targets_: `make test` or equivalent runs all tests
- [ ] _CI integration_: Tests run in CI/CD pipeline
- [ ] _Test documentation_: README includes test execution instructions

---

## Portability

- [ ] _Version requirement_: Required bash version documented (e.g., "Bash 4.0+")
- [ ] _Compatible syntax_: Uses syntax compatible with documented version
- [ ] _No bashisms without need_: Avoids bashisms when POSIX would work
- [ ] _Dependency documentation_: All external commands documented (`jq`, `curl`, etc.)
- [ ] _Version requirements_: External tool version requirements specified if critical
- [ ] _Dependency checking_: Scripts check for required dependencies before execution
- [ ] _Fallback behavior_: Handles missing optional dependencies gracefully
- [ ] _Environment variables_: Required environment variables documented
- [ ] _Path assumptions_: No hardcoded absolute paths (uses relative or configurable paths)
- [ ] _Platform assumptions_: Platform-specific behavior documented (Linux, macOS, WSL)

---

## Code Quality

- [ ] _Self-documenting_: Code readable without excessive comments
- [ ] _Clear intent_: Purpose of code blocks obvious
- [ ] _No obfuscation_: No unnecessarily complex expressions
- [ ] _Consistent style_: Consistent formatting and style throughout
- [ ] _Modularity_: Code organized into logical modules/files
- [ ] _Reusability_: Common functionality extracted and reusable
- [ ] _Configuration_: Configuration separated from logic
- [ ] _Version management_: Version information tracked (VERSION file, git tags)
- [ ] _Formatting_: Code formatted consistently (shfmt or similar)
- [ ] _Linting_: ShellCheck or similar linter used, issues addressed
- [ ] _Makefile_: Common tasks automated (test, lint, format, install)
- [ ] _CI/CD_: Automated checks in CI pipeline

---

## Bash Best Practices

- [ ] _Command substitution_: Uses `$(command)` not backticks
- [ ] _Pipe handling_: Proper error handling in pipelines (`set -o pipefail`)
- [ ] _Process substitution_: Uses process substitution when appropriate (`<(command)`)
- [ ] _String manipulation_: Uses parameter expansion when possible (`${var#prefix}`, `${var%suffix}`)
- [ ] _Array operations_: Proper array initialization and manipulation
- [ ] _Quoting in arrays_: Array elements properly quoted in expansions
- [ ] _Builtin preference_: Uses bash builtins when available (`[[ ]]` vs `[ ]`, `printf` vs `echo`)
- [ ] _External command efficiency_: Minimizes external command calls in loops

---

## Repository Structure

- [ ] _Logical structure_: Code organized into logical directories (`src/`, `tests/`, `examples/`)
- [ ] _Separation of concerns_: Source code, tests, documentation, examples separated
- [ ] _Naming consistency_: Consistent naming patterns across files
- [ ] _README_: Comprehensive README with usage, examples, requirements
- [ ] _LICENSE_: License file present
- [ ] _VERSION_: Version tracking (file or git tags)
- [ ] _Makefile_: Common tasks automated
- [ ] _.gitignore_: Appropriate entries for temp files, build artifacts
- [ ] _Examples_: Working examples in `examples/` directory
- [ ] _API docs_: API/function documentation if applicable
- [ ] _Changelog_: Change history maintained (CHANGELOG.md or git history)

---

## Review Process

### Priority Order

1. _Critical Security_ - Security violations, error handling failures, temp file cleanup
2. _Error Handling_ - Missing `set -eo pipefail`, no error checking, broken functionality
3. _Documentation_ - README mismatches, missing docs, logging consistency
4. _Code Quality_ - Function granularity, test coverage, variable naming, organization

### Review Output Format

- Use checkboxes for each criterion
- Document specific `file:line` references for issues
- Mark priority: Critical/Important/Enhancement
- Provide actionable fix suggestions
- Acknowledge good practices found

### Example Output

```markdown
## Review: [Repository Name] - [Date]

### Summary

- Overall Assessment: [Good/Fair/Needs Work]
- Critical Issues: [Count]
- Important Issues: [Count]
- Enhancements: [Count]

### Critical Issues

- [ ] Unquoted variable - File: `path/to/file.sh:123`
- [ ] Missing `set -eo pipefail` - File: `path/to/file.sh:45`

### Important Improvements

- [ ] Function too large (150 lines) - File: `path/to/file.sh:200`

### Strengths

- Excellent test coverage
- Clear function documentation

### Recommendations

1. Add `set -eo pipefail` to all scripts
2. Split `parse_payload()` into smaller functions
```

---

## Notes

- _Context matters_: Some criteria may not apply to all repositories (library vs. application)
- _Prioritize_: Focus on security and correctness first, then maintainability
- _Automation_: Use tools (ShellCheck, shfmt, Bats) to catch many issues automatically
- _Iterative_: Fix critical issues first, then refine
