# Shell Standards

## Critical Violations, Scripts Will Be Rejected

- Never use echo statements with line lengths over 160.
- Never remove temporary files or directories manually. Use trap to clean up temporary paths created by the script
- Never use `exit` to exit a script inside a function
- Never use unquoted variables: `echo $var` instead of `echo "$var"`
- Never use `rm -rf /` or similar dangerous commands
- Never use `eval` or `exec`.
- Never use `sudo`.
- Never use `declare -a` for array assignment.

## Mandatory Requirements, All Scripts Must Have

- Heredocs for output spread across more than 2 lines.
- Minimal comments.
- Bats for testing
- `#!/usr/bin/env bash` for executables
- Error messages to STDERR: `>&2`
- Function header comments are required. Include Inputs and Side Effects sections only when they apply
- Input validation for all functions
- Proper error handling with `return` status codes.

## Best Practices

- Use bash version 3.2 or greater syntax.
- Use `[[ ... ]]`
- Use `$(command)` instead of backticks
- Use `(( ... ))` for arithmetic
- Use explicit paths: `rm -v ./*`
- Use builtins over external commands when reasonable
- Using `cat` for heredoc blocks is strongly preferred for readability
- Use array literals for lists. Avoid `declare -a` unless needed
- Always `return` explicit status codes
- Always leave a newline before a return statement at the end of a function.
- Functions in test scripts do not require comments.
- Functions in invoked scripts do require comments unless they are both obvious and short.

## Testing

- Always prefix the test with the function name for direct function testing, such as `@test "function_name:: test description" {`
- Use proper spacing between any changes or inputs before the run command to show what is being tested, changed, or mocked.
- Never execute actual changes with tests unless that functionality already exists.
- Always use worktrees for bats tests that require any form of git interaction in the test file
- Use `setup_file` to set up the test environment and source the script for external dependencies.
- Use `setup` to set up the test environment and source the script for external dependencies.

## File Structure Template

All scripts must maintain a consistent organizational structure. Functions should be grouped into logical sections in the following order: usage and help functions at the top, followed by validation and configuration initialization, then helper utilities, core business logic functions, the main entry point, and finally the source handler that enables both direct execution and sourcing.

Content inside comment blocks with curly braces are instructions and not intended to be part of the script.

```bash
#!/usr/bin/env bash
#
# {Description of script purpose}
#

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

{Description of script purpose}

Options:
  -h, --help  {Description of the help option}

EOF
}

# {Validation functions and configuration setup}
# {Check dependencies, validate inputs, set up configuration}

# {Helper functions used by main functionality}
# {Description of the helper function}
#
# {Reference documentation if needed}
# Inputs:
# - $1 {argument name}, {description}
#
# Side Effects:
# - {description}
helper_function() {
  # {input args defined as locals}
  # {check required values are set}

  # {
  # if [[ -z "${some_var}" ]]; then
  #   echo "helper_function:: some_var is not set" >&2
  #   return 1
  # fi
  # }

  # {Output lines should include the function name in the pattern of `echo "helper_function:: {content}"`}

  return 0 # {Always return explicit status codes}
}

# {Core logic functions}
# {Description of the function}
#
# {Reference documentation if needed}
# Inputs:
# - $1 {argument name}, {description}
#
# Side Effects:
# - {description}
function_name() {
  # {input args defined as locals}
  # {check required values are set}

  # {
  # if [[ -z "${some_var}" ]]; then
  #   echo "function_name:: some_var is not set" >&2
  #   return 1
  # fi
  # }

  # {Output lines should include the function name in the pattern of `echo "function_name:: {content}"`}

  return 0 # {Always return explicit status codes}
}

# {Main entry point, can be named anything but "main" is fallback default}
# {Does not require a function header comment}
main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help) usage && return 0 ;;
      *)
        echo "Unknown option '$1'" >&2
        echo "Use '$(basename "$0") --help' for usage information" >&2
        return 1
        ;;
    esac
  done

  return 0
}

# {Allow script to be executed directly with arguments, or sourced}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
  exit $?
fi

```

## Variables

```bash
# {Define, assign, export separately}
local name
name="John"
export name

# {Always quote variables}
echo "PATH=${PATH}, PWD=${PWD}"

# {Use arrays for lists}
flags=(--foo --bar='baz')
mybinary "${flags[@]}"

```

## Control Flow

```bash
# {Test strings with [[ ]]}
if [[ "${my_var}" == "some_string" ]]; then
  do_something
fi

# {Test empty strings}
if [[ -z "${my_var}" ]]; then
  do_something
fi

# {Arithmetic with (())}
local a
local b
a=5
b=10
if (( a < b )); then
  echo "a is less than b"
fi
```

## Error Handling

```bash
# {Check return values}
function_name() {
  local file_list
  local dest_dir
  file_list=("file1.txt" "file2.txt")
  dest_dir="/tmp"

  if ! mv "${file_list[@]}" "${dest_dir}/"; then
    echo "function_name:: Unable to move ${file_list[*]} to ${dest_dir}" >&2

    return 1
  fi

  return 0
}
```

## Example

```bash
create_temp_dir() {
  local temp_dir
  temp_dir="$(mktemp -d)"

  if [[ "${temp_dir}" = "" ]]; then
    echo "create_temp_dir: mktemp failed" >&2
    return 1
  fi

  trap 'rm -rf "$temp_dir"' EXIT

  return 0
}
```

## Shell Test Structure Template

Test files should be organized with a clear hierarchy: Bats setup hooks (`setup_file` and `setup`) come first to establish the test environment, followed by mock function definitions for external dependencies, then any test helper utilities, function-specific test groups organized by the function being tested, and finally integration tests that exercise the full workflow.

```bash
#!/usr/bin/env bats
#
# {Brief description of the test file}
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="${GIT_ROOT}/path/to/script.sh"
[[ ! -f "$SCRIPT" ]] && echo "setup:: Script not found: $SCRIPT" >&2 && return 1

setup_file() {
  # {If needed check access to API's, databases, etc.}

  return 0
}

setup() {
  # {Source the script}

  source "$SCRIPT"

  # {Define global variables}
  VAR_A="test"

  # {Export global variables}
  export VAR_A

  return 0
}

# {Mock functions for external dependencies}
# {Mock API calls, file operations, etc.}

# {Helper functions for test setup, assertions, etc.}

# tests by function
# {Group tests by function being tested}
# function_name
@test "function_name:: script handles unknown options" {
  local var
  local script_path
  var="test"
  script_path="$HOME/scripts/bin/script.sh"

  run "$script_path" "$var"
  [[ "$status" -eq 1 ]]

  echo "$output" | grep -q "Unknown option"
}

# {End-to-end integration tests}
@test "integration:: full workflow test" {
  # {Integration test implementation}
}
```
