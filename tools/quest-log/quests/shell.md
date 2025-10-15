# Shell Standards
## Never Use
- Echo statements >160 characters or >3 lines
- Manual removal of temporary files/directories
- `exit` inside functions
## Always Use
- Heredocs for multi-line echo
- Minimal comments
- Bats for testing
- `#!/usr/bin/env bash` for executables
- Error messages to STDERR: `echo "Error" >&2`
- `set -eo pipefail`
- `return` explicit status codes
- Function header comments with inputs and side effects
- `[[ ... ]]` over `[ ... ]`
- `$(command)` over backticks
- Quote variables
- Local variables in functions
## Structure & Templates
Comments are for instruction purposes only, do not use the comments in your work.
```bash
#!/usr/bin/env bash
#
# Description of script purpose, maximum 2 lines
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
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
}
```
### Functions
- Any function that is not both obvious and short must have a function header comment.
- Exceptions are made for test scripts and test functions. Never add comments to functions unless requested to by the user.
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
flags=("--foo" "--bar='baz'")
some_script "${flags[@]}"
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
[[ "${my_var}" == "some_string" ]]
[[ -z "${my_var}" ]] # empty string
[[ " ${my_array[*]} " =~ " ${my_var} " ]] # string in array
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
- Always prefix the test with the function name for direct function testing: `@test 'function_name:: {test info}'`
- Use proper spacing between any changes or inputs before the run command to show what is being tested, changed, or mocked.
- Never execute actual changes with tests unless explicitly called for as defined with `@test 'Real:: test description' {`
- Use `setup_file` to set up the test environment and source the script for external dependencies.
- Use `setup` to set up the test environment and source the script for external dependencies.
- Never use `run bash -c "{rest of the command}"` unless you absolutely have to.
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
  source "$SCRIPT"
  VAR_A="test"
  export VAR_A
  return 0
}
########################################################
# Mocks
########################################################
mock_functionality() {
  function_name() {
    echo "function_name mocked"
    return 0
  }
  export -f function_name
}
########################################################
# function_name
########################################################
@test "function_name::script handles unknown options" {
  local var="test"
  run bash "$HOME/scripts/bin/script.sh"
  [[ "$status" -eq 1 ]]
  grep -q "Unknown option" <<< "$output"
}
```
