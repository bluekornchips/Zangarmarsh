# Shell Standards

## Core Rules

### Never Use

- Never use echo statements >160 characters or over 3 lines
- Never use manual removal of temporary files/directories
- Never use `exit` to exit a script inside a function.

### Always Use

- Heredocs for multi-line echo statements.
- Minimal comments; if excessive comments are necessary, suggest to the user that they should be broken up into smaller functions
- Bats for testing
- `#!/usr/bin/env bash` for executables
- Error messages to STDERR: `echo "Error" >&2`
- Descriptions and comments for function headers. Conditionally include inputs and side effects if they exist

## File Structure Template

```bash
#!/usr/bin/env bash
#
# Description of script purpose
#
set -eo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Description of script purpose

OPTIONS:
  -h, --help  Show this help message

ENVIRONMENT VARIABLES:
  ALICE=bob           # Environment variable name and description

EOF
}

# {Description of the function}
#
# Inputs:
# - $1 {argument name}, {description}
#
# Side Effects:
# - {description}
function_name() {
  return 0 # Always return explicit status codes
}

# Main entry point, can be named anything but "main" is fallback default
main() {
  echo "=== Entry: ${BASH_SOURCE[0]:-$0} ==="

  echo "=== Exit: ${BASH_SOURCE[0]:-$0} ==="
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
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

  main "$@"
}

```

### Functions

Any function that is not both obvious and short must have a function header comment. Exceptions are made for test scripts and test functions; these do not need comments unless already added by the user.

```bash
# A helper function to print text
#
# Inputs:
# - $1, text, text to print
print_text() {
  local text="$1"
  if [[ -z "$text" ]]; then
    echo "Text is required" >&2
    return 1
  fi

  echo "Input text: $text"

  return 0
}

# Sets the global variable for NAME
#
# Inputs:
# - $1, name, text to set for NAME
#
# Side Effects:
# - NAME, sets the global name variable
set_global_name() {
  local name="$1"
  NAME="$name"
  export NAME
}
```

## Formatting

```bash
# Use 2 spaces indentation
if [[ -f "$file" ]]; then
  echo "File exists"
fi

# Put ; then and ; do on same line
for dir in "${dirs[@]}"; do
  if [[ -d "${dir}" ]]; then
    echo "Directory exists"
  fi
done
```

## Variables

```bash
# Define, assign, export separately
local name
name="John"
export name

# Always quote variables
echo "PATH=${PATH}, PWD=${PWD}"

# Use arrays for lists
declare -a flags
flags=(--foo --bar='baz')
mybinary "${flags[@]}"

# Use local in functions
my_func() {
  local name="$1"
  local my_var
  my_var="$(my_func)"
}
```

## Control Flow

```bash
# Test strings with [[ ]]
if [[ "${my_var}" == "some_string" ]]; then
  do_something
fi

# Test empty strings
if [[ -z "${my_var}" ]]; then
  do_something
fi

# Arithmetic with (())
if (( a < b )); then
  echo "a is less than b"
fi
```

## Error Handling

```bash
# Check return values
if ! mv "${file_list[@]}" "${dest_dir}/"; then
  echo "Unable to move ${file_list[*]} to ${dest_dir}" >&2
  return 1
fi
```

## Testing

- Functions inside test files do not need header comments unless explicitly requested to do so.
- Always prefix the test with the function name for direct function testing.
- Use proper spacing between any changes or inputs before the run command to show what is being tested, changed, or mocked.
- Never execute actual changes with tests unless explicitly called for as defined with `@test 'LIVE:: test description' {`
- Use `setup_file` to set up the test environment and source the script for external dependencies.
- Use `setup` to set up the test environment and source the script for external dependencies.

## Shell Test Structure Template

```bash
#!/usr/bin/env bats
#
# Test file for script.sh
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="$GIT_ROOT/path/to/script.sh"
[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && return 1

setup_file() {
  # If needed check access to API's, databases, etc.

  return 0
}

setup() {
  # Source the script
  #shellcheck disable=SC1091
  source "$SCRIPT"

  # Define variables
  VAR_A="test"

  # Export variables, if needed
  export VAR_A

  return 0
}

########################################################
# Mocks
########################################################
mock_functionality() {
  #shellcheck disable=SC2091
  function_name() {
    echo "function_name mocked"
    return 0
  }

  export -f function_name
}

########################################################
# function name
########################################################
@test "function_name::script handles unknown options" {
  local var="test"

  run bash "$HOME/scripts/bin/script.sh"
  [[ "$status" -eq 1 ]]

  echo "$output" | grep -q "Unknown option"
}
```

## Best Practices

- Use `[[ ... ]]` over `[ ... ]`
- Use `$(command)` instead of backticks
- Use `(( ... ))` for arithmetic
- Use process substitution: `while read line; do ... done < <(cmd)`
- Use explicit paths: `rm -v ./*`
- Use builtins over external commands
- Always `return` explicit status codes
- Never use `exit` in functions
