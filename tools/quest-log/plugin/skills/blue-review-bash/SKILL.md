---
name: blue-review-bash
description: Bash Repository Review Criteria
disable-model-invocation: true
---

# Bash Repository Review Criteria

## Overview

Pragmatic review criteria for bash and shell script repositories. Focus on security, correctness, and maintainability.

---

## Critical Security Must Fix

- [ ] _Unquoted variables_: Quote every expansion as `"$var"`, never `$var`
- [ ] _No `eval`/`exec`_: Use parameter expansion or functions instead
- [ ] _No hardcoded secrets_: Read secrets from environment variables or config files
- [ ] _Input validation_: Validate user inputs and external data before use
- [ ] _Temporary file cleanup_: Clean every `mktemp` file via traps
- [ ] _Secure temp files_: Create temp files with `mktemp` and `chmod 0600`
- [ ] _Trap handlers_: Configure `EXIT` and `ERR` traps for cleanup
- [ ] _Explicit paths_: Use explicit paths for destructive ops, `rm -v ./*` not `rm *`
- [ ] _Command validation_: Check external commands exist before use

---

## Error Handling Must Fix

- [ ] _Explicit return codes_: Functions return 0 on success and non-zero on failure
- [ ] _No `exit` in functions_: Use `return`, with `exit` only in main, so scripts stay sourceable
- [ ] _Errors to stderr_: Send all error output to `>&2`
- [ ] _Return code checking_: Check return codes of critical command invocations
- [ ] _Meaningful errors_: Include function name and variable values in errors
- [ ] _Dependency checking_: Check required external commands before execution

---

## Code Structure

- [ ] _Shebang_: Executables use `#!/usr/bin/env bash`
- [ ] _Function size_: Functions stay under 80 lines and never exceed about 150
- [ ] _Function headers_: Every function except `main` has a header comment stating purpose and signature, plus Inputs, Outputs, Side Effects, and Returns where they apply
- [ ] _Local variables_: Every function variable is `local`, declared once on the line that first assigns it
- [ ] _Local literals_: Literals and arrays use `local name=value` or `local name=(...)`
- [ ] _Bare local_: A bare `local name` appears only directly above a command substitution, a `for` or `while` using that name, or an `if` or `case` whose branches first assign it
- [ ] _No local block_: A `local` block at the top of a function is a failure
- [ ] _No substitution in local_: Command substitutions are never assigned inside `local` or `export`, per ShellCheck SC2155
- [ ] _Final return spacing_: End every function, including `main`, with `return <code>`. A body of 4 or more lines between the braces gets one empty line before that final `return`. A shorter body gets none.
- [ ] _Early return spacing_: An early `return` stays on the next line after its echo or command, including inside `if`, `case`, and `command || { }`
- [ ] _Return after block_: After a multi-line block closed by `}`, `fi`, `done`, or `esac`, leave one empty line before the next statement in the same scope, including a later `return`. When that next statement is the function-ending `return`, the one empty line serves both jobs.
- [ ] _Block spacing_: One empty line follows each multi-line block closed by `}`, `fi`, `done`, or `esac` before the next statement in that scope
- [ ] _Enclosing closer_: The closer of an enclosing block stays on the next line
- [ ] _Stacked blocks_: Stacked `command || { }` blocks with no empty line between them are a failure
- [ ] _Whitespace lines_: A whitespace-only line does not count as an empty line
- [ ] _Sourcing support_: Scripts support execution and sourcing through a `BASH_SOURCE[0]` check
- [ ] _Organized sections_: Order sections as usage functions, validation and config initialization, helper utilities, core business logic, main entry point, then the source handler

---

## Variables and Quoting

- [ ] _Always quoted_: Quote all expansions as `"$var"` or `"${var}"`
- [ ] _Array usage_: Lists use arrays, not space-separated strings
- [ ] _Array expansion_: Expand elements with `"${array[@]}"`
- [ ] _Command substitution_: Use `$(command)`, not backticks
- [ ] _Constants_: Name constants in UPPER_CASE

---

## Control Flow

- [ ] _`[[ ]]` usage_: Use `[[ ]]` for string and file tests, not `[ ]`
- [ ] _Arithmetic_: Use `(( ))` for arithmetic comparisons
- [ ] _Case statements_: Use `case` for multiple string comparisons
- [ ] _Array iteration_: Use `for item in "${array[@]}"` for arrays

---

## Logging and Output

- [ ] _Consistent format_: Log messages share one format such as `function_name:: message`
- [ ] _Function prefix_: Log messages start with the function name
- [ ] _Error vs info_: Send errors to stderr with `>&2` and info to stdout
- [ ] _Heredocs_: Use heredocs such as `cat <<EOF` for output over 2 lines
- [ ] _Line length_: Echo statements stay within 160 characters
- [ ] _No debug output_: Remove debug statements

---

## Documentation

- [ ] _README accuracy_: README matches the actual implementation
- [ ] _Usage examples_: README includes minimal working examples
- [ ] _Prerequisites_: Document dependencies clearly
- [ ] _Minimal comments_: Inline comments explain why, not what, and never narrate each line

---

## Testing

- [ ] _Bats framework_: Use Bats for testing
- [ ] _Test naming_: Name tests `function_name:: description`
- [ ] _Test organization_: Order test files as setup hooks, mock definitions, helper utilities, function-specific test groups, then integration tests
- [ ] _Happy paths_: Test happy path scenarios
- [ ] _Error cases_: Test error conditions
- [ ] _Test isolation_: Tests never depend on execution order
- [ ] _Mocking_: Mock external dependencies such as APIs and files
- [ ] _Assertions_: Tests have clear, specific assertions
- [ ] _Honest assertions_: Tests assert through the public interface, and expected values come from a literal or the spec, never recomputed the way the code computes them
- [ ] _Test data_: Test data is realistic and covers edge cases
- [ ] _Makefile targets_: `make test` or equivalent runs all tests
- [ ] _CI integration_: Tests run in the CI/CD pipeline
- [ ] _Test documentation_: README includes test execution instructions

---

## Portability

- [ ] _Version requirement_: Document the required bash version
- [ ] _Dependency documentation_: Document all external commands
- [ ] _Dependency checking_: Scripts check required dependencies before execution
- [ ] _Environment variables_: Document required environment variables

---

## Code Quality

- [ ] _Self-documenting_: Code reads clearly without excessive comments
- [ ] _Consistent style_: Formatting is consistent throughout
- [ ] _Formatting_: Format code with shfmt or similar
- [ ] _Linting_: Use ShellCheck and address its issues
- [ ] _Makefile_: Automate common tasks such as test, lint, and format

---

## Repository Structure

- [ ] _Logical structure_: Organize code into logical directories such as `src/` and `tests/`
- [ ] _README_: README covers usage, examples, and requirements
- [ ] _LICENSE_: License file is present
- [ ] _Makefile_: Common tasks are automated
- [ ] _.gitignore_: Entries cover temp files and build artifacts

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
## Review: Repository Name - Date

### Critical Issues

- [ ] Unquoted variable - File: `path/to/file.sh:123`

### Important Improvements

- [ ] Missing error checking - File: `path/to/file.sh:45`
```

---
