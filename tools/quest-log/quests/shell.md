# Shell Standards

## Purpose

Keep bash and zsh scripts safe to run, easy to read, and consistent about errors and cleanup.

## Priority

- Level 2 of 2

## Standards

- Use `#!/usr/bin/env bash` or `#!/usr/bin/env zsh` for executables, and match the shell to the features used.
- For bash scripts, stay compatible with bash 3.2+. For zsh scripts, stay compatible with zsh 5.0+.
- In the direct-run entry block only, enable strict mode when it fits, for example `set -euo pipefail` or `set -eo pipefail`. Set `umask 077` when the script handles sensitive files.
- Quote every expansion: `"${var}"` not bare `$var`.
- Send errors to stderr with `>&2`.
- Return explicit integer status codes from functions. Use `return`, not `exit`, inside functions.
- Validate inputs at boundaries. Add function comments for invoked scripts unless the function is obvious and short.
- For complex helpers, include Inputs, Outputs, Side Effects, and Returns when they clarify behavior.
- Group scripts as usage, validation and config, helpers, core logic, `main`, then the source guard.

## Usage

### Allowed

- `[[ ... ]]` in bash, `$(command)` instead of backticks, `(( ... ))` for integers.
- Heredocs with `cat <<EOF` for user-visible text longer than two lines.
- `trap` to remove temp dirs the script created. Short-lived temp files may use `rm` in the same scope.
- Explicit paths for destructive commands, for example `rm -v ./*`.
- Builtins instead of external commands when they keep the script clear.
- `command -v` for dependency checks with a clear stderr message when something is missing.
- `mktemp` or `mktemp -d` with a template. `chmod 0600` on temp files that may hold secrets.
- Array literals for lists, for example `flags=(--foo --bar='baz')`.
- Separate define, assign, and export steps when that makes variable intent clearer.
- Function-name prefixes in helper error output, for example `load_config:: file is missing`.
- A blank line before the final `return` in a function, except in `main`.
- Bats for non-trivial shell. Use `@test "name:: description" {` for direct function tests. Use `setup_file` and `setup` as the project already does.
- Worktrees for Bats tests that require git interaction. Avoid real side effects unless that behavior is under test.
- Spacing before `run` in Bats tests to show what is being changed, mocked, or asserted.
- Single line conditional checks, `some_command || return 1`

### Denied

- `echo` lines longer than 160 characters. Use a heredoc or a loop instead.
- Removing paths the script did not create.
- `rm -rf /`, `eval`, `exec`, or `sudo`.
- `declare -a` for simple array assignment. Use `name=(a b)` and `"${name[@]}"`.
- Required function comments in test scripts when names and setup are already clear.

## Example

### Script

```bash
#!/usr/bin/env bash
#
# Validate local dependencies and an optional API token.
#

########################################################
# Defaults
########################################################
REQUIRED_COMMANDS=("jq" "curl")

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help      Show help
  --health-check  Validate local dependencies and token setup
EOF

  return 0
}

# Check for required external commands
#
# Side Effects:
# - Writes missing dependency messages to stderr
#
# Returns:
# - 0 when all commands exist
# - 1 when any command is missing
check_dependencies() {
  local missing=()
  local cmd

  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "check_dependencies:: missing dependencies: ${missing[*]}" >&2
    return 1
  fi

  return 0
}

# Validate API token configuration when present
#
# Reads environment:
# - API_TOKEN
#
# Outputs:
# - One status line to stdout
#
# Returns:
# - 0 when token setup is acceptable
validate_token() {
  if [[ -z "${API_TOKEN:-}" ]]; then
    echo "validate_token:: API_TOKEN not set, skipping API check"
    return 0
  fi

  if [[ "${#API_TOKEN}" -lt 8 ]]; then
    echo "validate_token:: API_TOKEN is too short" >&2
    return 1
  fi

  echo "validate_token:: API token is configured"

  return 0
}

########################################################
# Core
########################################################
health_check() {
  local errors=0

  if ! check_dependencies; then
    errors=$((errors + 1))
  fi

  if ! validate_token; then
    errors=$((errors + 1))
  fi

  if [[ "${errors}" -eq 0 ]]; then
    echo "health_check:: passed"
    return 0
  fi

  echo "health_check:: failed with ${errors} error(s)" >&2

  return 1
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage

        return 0
        ;;
      --health-check)
        health_check

        return $?
        ;;
      *)
        echo "main:: unknown option '$1'" >&2
        echo "main:: use '$(basename "$0") --help' for usage" >&2

        return 1
        ;;
    esac
  done

  usage

  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -eo pipefail
  umask 077
  main "$@"
  exit $?
fi
```

### Bats

```bash
#!/usr/bin/env bats
#
# Tests for bin/example-health-check.sh
#

setup_file() {
  GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
  if [[ -z "${GIT_ROOT}" ]]; then
    fail "Failed to get git root"
  fi

  SCRIPT="${GIT_ROOT}/bin/example-health-check.sh"
  if [[ ! -f "${SCRIPT}" ]]; then
    fail "Script not found: ${SCRIPT}"
  fi

  export GIT_ROOT
  export SCRIPT

  return 0
}

setup() {
  source "${SCRIPT}"
  unset API_TOKEN

  return 0
}

@test "health_check:: passes when dependencies are available" {
  local mock_bin
  mock_bin="${BATS_TEST_TMPDIR}/example-health-check-bin"
  mkdir -p "${mock_bin}"

  printf '#!/usr/bin/env bash\nexit 0\n' >"${mock_bin}/jq"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${mock_bin}/curl"
  chmod +x "${mock_bin}/jq" "${mock_bin}/curl"

  PATH="${mock_bin}:${PATH}"
  export PATH

  run health_check
  [[ "${status}" -eq 0 ]]
  echo "${output}" | grep -q "health_check:: passed"
}

@test "main:: --health-check returns dependency failures" {
  REQUIRED_COMMANDS=("missing-jq" "missing-curl")

  run main --health-check
  [[ "${status}" -eq 1 ]]
  echo "${output}" | grep -q "check_dependencies:: missing dependencies"
}
```
