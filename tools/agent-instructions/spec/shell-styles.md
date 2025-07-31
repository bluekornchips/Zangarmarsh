# Shell Style Guide

**RULE APPLIED: Start each response acknowledging "🐚" to confirm this rule is being followed.**

**Usage**: This guide defines comprehensive standards for writing clean, maintainable shell scripts. It emphasizes best practices, security, and readability for bash scripting.

Names and phrases that reference this rule: "🐚", "shell", "bash", "script", "sh", "shellcheck", "heredoc".

A comprehensive guide for writing clean, maintainable shell scripts.

## Table of Contents

- [Background](#background)
- [Shell Files and Interpreter Invocation](#shell-files-and-interpreter-invocation)
- [Environment](#environment)
- [Comments](#comments)
- [Formatting](#formatting)
- [Features and Bugs](#features-and-bugs)
- [Naming Conventions](#naming-conventions)
- [Calling Commands](#calling-commands)

## Background

### Never Allow

Echo statements for strings that exceed 160 characters and/or two lines.
Manual removal of temporary files or temporary directories is not allowed.

### Always Require

Use heredocs for strings that exceed 160 characters and/or two lines.

```bash
# Single line
echo "Hello, world!"

# Single line with formatting
echo -e "Hello,\nworld!"

# Multi-line, heredoc
cat <<EOF
Hello
world!
THREE LINES
EOF
```

### Bats

Use Bats for shell testing.

```sh
# bats example
@test "uninstall script handles unknown options, should {pass/fail/skip}" {
    run bash "$HOME/scripts/bin/uninstall.sh"
    [ "$status" -eq 1 ] # Status based on pass, fail, or skip.
    echo "$output" | grep -q "Unknown option" # Always echo output to check.
    # If output should always be read on the cli, it must be redirected:
    echo "some output" >&0
}
```

### Which Shell to Use

Bash is the only shell scripting language permitted for executables.

- Executables must start with `#!/bin/bash` and minimal flags
- Use `set` to set shell options so that calling your script as `bash script_name` does not break its functionality
- No need to strive for POSIX-compatibility or avoid "bashisms"

## Shell Files and Interpreter Invocation

### File Extensions

- **Executables**: Should have a `.sh` extension or no extension

### STDOUT vs STDERR

All error messages should go to STDERR.

```bash
if ! do_something; then
  echo "Unable to do_something" >&2
  exit 1
fi
```

## Comments

### File Header

Start each file with a description of its contents.

```bash
#!/bin/bash
#
# Perform hot backups of Oracle databases.
```

### Function Comments

Any function that is not both obvious and short must have a function header comment.

```bash
# Cleanup files from the backup directory.
function cleanup() {
  …
}
```

### Implementation Comments

Comment tricky, non-obvious, interesting or important parts of your code.

### TODO Comments

Use TODO comments for code that is temporary, a short-term solution, or good-enough but not perfect.

```bash
# TODO: Handle the unlikely edge cases (bug ####)
```

## Formatting

### Indentation

- Use 2 spaces for indentation.
- Use blank lines between blocks to improve readability
- The only exception to this rule is when using heredocs, where tabs are required for proper formatting.

```bash
# Example of proper indentation
if [[ -f "$file" ]]; then
  echo "File exists"
fi
# Example of heredoc with tabs
cat <<EOF
  echo "File exists"  # This line will be indented with tabs
fi
EOF
```

### Pipelines

Pipelines should be split one per line if they don't all fit on one line.

```bash
# All fits on one line
command1 | command2

# Long commands
command1 \
  | command2 \
  | command3 \
  | command4
```

### Control Flow

Put `; then` and `; do` on the same line as the `if`, `for`, or `while`.

```bash
# If inside a function remember to declare the loop variable as
# a local to avoid it leaking into the global environment:
local dir
for dir in "${dirs_to_cleanup[@]}"; do
  if [[ -d "${dir}/${SESSION_ID}" ]]; then
    log_date "Cleaning up old files in ${dir}/${SESSION_ID}"
    rm "${dir}/${SESSION_ID}/"* || error_message
  else
    mkdir -p "${dir}/${SESSION_ID}" || error_message
  fi
done
```

### Case Statement

```bash
case "${expression}" in
  a)
    variable="…"
    some_command "${variable}" "${other_expr}" …
    ;;
  absolute)
    actions="relative"
    another_command "${actions}" "${other_expr}" …
    ;;
  *)
    error "Unexpected expression '${expression}'"
    ;;
esac
```

### Variable Expansion

In order of precedence:

1. Stay consistent with what you find
2. Quote your variables
3. Prefer `"${var}"` over `"$var"`

```bash
# Preferred style for 'special' variables:
echo "Positional: $1" "$5" "$3"
echo "Specials: !=$!, -=$-, _=$_. ?=$?, #=$# *=$* @=$@ \$$=$$ …"

# Preferred style for other variables:
echo "PATH=${PATH}, PWD=${PWD}, mine=${some_var}"
```

### Quoting

- Always quote strings containing variables, command substitutions, spaces or shell meta characters
- Use arrays for safe quoting of lists of elements, especially command-line flags
- Use `"$@"` unless you have a specific reason to use `$*`

```bash
# 'Single' quotes indicate that no substitution is desired.
# "Double" quotes indicate that substitution is required/tolerated.

# "quote command substitutions"
flag="$(some_command and its args "$@" 'quoted separately')"

# "quote variables"
echo "${flag}"

# Use arrays with quoted expansion for lists.
declare -a FLAGS
FLAGS=( --foo --bar='baz' )
readonly FLAGS
mybinary "${FLAGS[@]}"
```

## Features and Bugs

### ShellCheck

The [ShellCheck project](https://www.shellcheck.net/) identifies common bugs and warnings for your shell scripts. It is required for all scripts.

### Command Substitution

Use `$(command)` instead of backticks.

```bash
# This is preferred:
var="$(command "$(command1)")"

# This is not:
var="`command \`command1\``"
```

### Test, `[ … ]`, and `[[ … ]]`

`[[ … ]]` is preferred over `[ … ]`, `test` and `/usr/bin/[`.

```bash
# This ensures the string on the left is made up of characters in
# the alnum character class followed by the string name.
if [[ "filename" =~ ^[[:alnum:]]+name ]]; then
  echo "Match"
fi
```

### Testing Strings

Use quotes rather than filler characters where possible.

```bash
# Do this:
if [[ "${my_var}" == "some_string" ]]; then
  do_something
fi

# -z (string length is zero) and -n (string length is not zero) are
# preferred over testing for an empty string
if [[ -z "${my_var}" ]]; then
  do_something
fi
```

### Wildcard Expansion of Filenames

Use an explicit path when doing wildcard expansion of filenames.

```bash
# As filenames can begin with a -, it's a lot safer to
# expand wildcards with ./* instead of *.
rm -v ./*
```

### Arrays

Bash arrays should be used to store lists of elements, to avoid quoting complications.

```bash
# An array is assigned using parentheses, and can be appended to
# with +=( … ).
declare -a flags
flags=(--foo --bar='baz')
flags+=(--greeting="Hello ${name}")
mybinary "${flags[@]}"
```

### Pipes to While

Use process substitution or the `readarray` builtin (bash4+) in preference to piping to `while`.

```bash
# Use process substitution
while read line; do
  if [[ -n "${line}" ]]; then
    last_line="${line}"
  fi
done < <(your_command)

# Or use readarray
readarray -t lines < <(your_command)
for line in "${lines[@]}"; do
  if [[ -n "${line}" ]]; then
    last_line="${line}"
  fi
done
```

### Arithmetic

Always use `(( … ))` or `$(( … ))` rather than `let` or `$[ … ]` or `expr`.

```bash
# Simple calculation used as text
echo "$(( 2 + 2 )) is 4"

# When performing arithmetic comparisons for testing
if (( a < b )); then
  …
fi

# Some calculation assigned to a variable.
(( i = 10 * j + 400 ))
```

## Naming Conventions

### Function Names

Lower-case, with underscores to separate words. Separate libraries with `::`.

```bash
# Single function
my_func() {
  …
}

# Part of a package
mypackage::my_func() {
  …
}
```

### Variable Names

Same as for function names.

```bash
for zone in "${zones[@]}"; do
  something_with "${zone}"
done
```

### Constants, Environment Variables, and readonly Variables

Constants and anything exported to the environment should be capitalized, separated with underscores.

```bash
# Constant
readonly PATH_TO_FILES='/some/path'

# Both constant and exported to the environment
declare -xr ORACLE_SID='PROD'
```

### Source Filenames

Lowercase, with underscores to separate words if desired.

### Use Local Variables

Declare function-specific variables with `local`.

```bash
my_func2() {
  local name="$1"

  # Separate lines for declaration and assignment:
  local my_var
  my_var="$(my_func)"
  (( $? == 0 )) || return

  …
}
```

### Function Location

Put all functions together in the file just below constants. Don't hide executable code between functions.

### main

A function called `main` is required for scripts long enough to contain at least one other function.

```bash
main "$@"
```

## Calling Commands

### Checking Return Values

Always check return values and give informative return values.

```bash
if ! mv "${file_list[@]}" "${dest_dir}/"; then
  echo "Unable to move ${file_list[*]} to ${dest_dir}" >&2
  exit 1
fi

# Or
mv "${file_list[@]}" "${dest_dir}/"
if (( $? != 0 )); then
  echo "Unable to move ${file_list[*]} to ${dest_dir}" >&2
  exit 1
fi
```

### Builtin Commands vs. External Commands

Given the choice between invoking a shell builtin and invoking a separate process, choose the builtin.

```bash
# Prefer this:
addition="$(( X + Y ))"
substitution="${string/#foo/bar}"
if [[ "${string}" =~ foo:(\d+) ]]; then
  extraction="${BASH_REMATCH[1]}"
fi

# Instead of this:
addition="$(expr "${X}" + "${Y}")"
substitution="$(echo "${string}" | sed -e 's/^foo/bar/')"
extraction="$(echo "${string}" | sed -e 's/foo:\([0-9]\)/\1/')"
```
