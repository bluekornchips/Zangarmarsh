# Shell Standards

## Core Rules

### Never Use

- Echo statements >160 characters or 2+ lines
- Manual removal of temporary files/directories
- Double asterisks for bolding

### Always Use

- Heredocs for multi-line strings
- Bats for testing
- `#!/usr/bin/env bash` for executables
- Error messages to STDERR: `echo "Error" >&2`

## File Structure

```bash
#!/usr/bin/env bash
#
# Description of script purpose
```

### Function Comments

Any function that is not both obvious and short must have a function header comment. Exceptions are made for test scripts and test functions; these do not need comments unless already added by the user.

```bash
# Function description
function cleanup() {
  # Implementation comment
}
```

## Formatting

- Use 2 spaces for indentation
- Put `; then` and `; do` on same line as `if`, `for`, or `while`
- Use blank lines between blocks

```bash
if [[ -f "$file" ]]; then
  echo "File exists"
fi

for dir in "${dirs[@]}"; do
  if [[ -d "${dir}" ]]; then
    echo "Directory exists"
  fi
done
```

## Variables

```bash
# Quote variables
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
# Test strings
if [[ "${my_var}" == "some_string" ]]; then
  do_something
fi

# Test empty strings
if [[ -z "${my_var}" ]]; then
  do_something
fi

# Arithmetic
if (( a < b )); then
  echo "a is less than b"
fi
```

## Error Handling

```bash
# Check return values
if ! mv "${file_list[@]}" "${dest_dir}/"; then
  echo "Unable to move ${file_list[*]} to ${dest_dir}" >&2
  exit 1
fi
```

## Testing

```bash
# Bats example
@test "script handles unknown options" {
  run bash "$HOME/scripts/bin/script.sh"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Unknown option"
}
```

## Best Practices

- Use `[[ ... ]]` over `[ ... ]`, even in bats tests.
- Use `$(command)` instead of backticks
- Use `(( ... ))` for arithmetic
- Use process substitution for pipes to while
- Use explicit paths for wildcards: `rm -v ./*`
- Use builtins over external commands when possible
