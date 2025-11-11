# Shell Standards

## Critical Violations, Scripts Will Be Rejected

- Never use echo statements with line lengths over 160.
- Never use manual removal of temporary files/directories
- Never use `exit` to exit a script inside a function
- Never use unquoted variables: `echo $var` instead of `echo "$var"`
- Never use `rm -rf /` or similar dangerous commands
- Never use `eval` or `exec`.
- Never use `sudo`.
- Never use `declare` for variable assignment.

## Mandatory Requirements, All Scripts Must Have

- Heredocs for output spread across more than 2 lines.
- Minimal comments.
- Bats for testing
- `#!/usr/bin/env bash` for executables
- Error messages to STDERR: `>&2`
- Descriptions and comments for function headers. Conditionally include inputs and side effects if they exist
- Input validation for all functions
- Proper error handling with `return` status codes.

## Best Practices

- Use bash version 3.2 or greater syntax.
- Use `[[ ... ]]`
- Use `$(command)` instead of backticks
- Use `(( ... ))` for arithmetic
- Use explicit paths: `rm -v ./*`
- Use builtins over external commands
- Always `return` explicit status codes
- Functions in test scripts do not require comments.
- Functions in invoked scripts do require comments unless they are both obvious and short.

## Testing

- Always prefix the test with the function name for direct function testing, such as `@test "function_name:: test description" {`
- Use proper spacing between any changes or inputs before the run command to show what is being tested, changed, or mocked.
- Never execute actual changes with tests unless that functionality already exists.
- Use `setup_file` to set up the test environment and source the script for external dependencies.
- Use `setup` to set up the test environment and source the script for external dependencies.

## File Structure Template

Follow the below template for all scripts. Content inside comment blocks with curly braces are instructions and not intended to be part of the script.

```bash
#!/usr/bin/env bash
#
# {Description of script purpose}
#
set -eo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

{Description of script purpose}

Options:
  -h, --help  {Description of the help option}

EOF
}

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
declare -a flags
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
if (( a < b )); then
  echo "a is less than b"
fi
```

## Error Handling

```bash
# {Check return values}
if ! mv "${file_list[@]}" "${dest_dir}/"; then
  echo "Unable to move ${file_list[*]} to ${dest_dir}" >&2
  return 1
fi
```

## Shell Test Structure Template

```bash
#!/usr/bin/env bats
#
# {Brief description of the test file}
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="$GIT_ROOT/path/to/script.sh"
[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && return 1

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

########################################################
# function_name
########################################################
@test "function_name:: script handles unknown options" {
  local var
  var="test"

  run "$HOME/scripts/bin/script.sh" "$var"
  [[ "$status" -eq 1 ]]

  echo "$output" | grep -q "Unknown option"
}
```
