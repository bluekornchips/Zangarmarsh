#!/usr/bin/env bats
#
# Test file for trilliax.sh
# Tests the trilliax cleanup script functionality
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/tools/trilliax/trilliax.sh"
	export SCRIPT

	return 0
}

setup() {
	source "${GIT_ROOT}/tests/fixtures.sh"
	source_for_test "$SCRIPT" || return 1

	TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trilliax-test.XXXXXX")"
	TEST_DIR="$(cd "${TEST_DIR}" && pwd -P)"
	export TEST_DIR
	TEST_CLEANUP_DIR="${TEST_DIR}/cleanup_test"
	export TEST_CLEANUP_DIR
	mkdir -p "${TEST_CLEANUP_DIR}"

	return 0
}

teardown() {
	[[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"

	return 0
}

########################################################
# clean_fs
########################################################
@test "clean_fs:: removes empty directories" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"

	run clean_fs "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/empty_dir" ]]
}

@test "clean_fs:: dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"

	DRY_RUN=true run clean_fs "$test_dir"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_fs:: Would remove: $test_dir/empty_dir"
}

@test "clean_fs:: handles nested empty directories" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"
	mkdir -p "$test_dir/empty_dir/empty_subdir"

	run clean_fs "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/empty_dir" ]]
	[[ ! -d "$test_dir/empty_dir/empty_subdir" ]]
}

@test "clean_fs:: handles nested empty directories with dry-run" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"
	mkdir -p "$test_dir/empty_dir/empty_subdir"

	DRY_RUN=true run clean_fs "$test_dir"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_fs:: Would remove: $test_dir/empty_dir"
	echo "$output" | grep -q "clean_fs:: Would remove: $test_dir/empty_dir/empty_subdir"
}

@test "clean_fs:: respects max depth limit" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/level1/level2/level3"
	mkdir -p "$test_dir/shallow"

	MAX_DEPTH=2
	export MAX_DEPTH

	run clean_fs "$test_dir"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/shallow" ]]
	[[ -d "$test_dir/level1/level2/level3" ]]
}

@test "run_trilliax:: cleans empty directories with fs target" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_to_clean"

	run "$SCRIPT" --targets fs "$test_dir"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/empty_to_clean" ]]
}

@test "run_trilliax:: dry-run shows empty directories for fs target" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_to_preview"

	run "$SCRIPT" --targets fs --dry-run "$test_dir"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_fs:: Would remove: $test_dir/empty_to_preview"
	[[ -d "$test_dir/empty_to_preview" ]] # Should still exist in dry-run mode
}

########################################################
# Script structure and help
########################################################
@test "main:: has proper shebang and structure" {
	run bash -n "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "main:: is executable" {
	[[ -x "$SCRIPT" ]]
}

@test "usage:: displays help when called with --help" {
	run "$SCRIPT" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: "
	echo "$output" | grep -q "Trilliax cleanup script"
	echo "$output" | grep -q "CLEANUP OPERATIONS:"
}

@test "usage:: displays help when called with -h" {
	run "$SCRIPT" -h
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: "
}

@test "main:: handles unknown options" {
	run "$SCRIPT" --invalid-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "trilliax:: Unknown option '--invalid-option'"
	echo "$output" | grep -q "trilliax:: Use 'trilliax.sh --help' for usage information"
}

@test "main:: rejects --dry-run option without targets" {
	run "$SCRIPT" --dry-run
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects a directory argument without targets" {
	run "$SCRIPT" --dir "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: accepts --all option" {
	run "$SCRIPT" --all "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "run_trilliax:: Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files."
	echo "$output" | grep -q "clean_fs:: Cleaning empty directories."
}

@test "main:: accepts -a option" {
	run "$SCRIPT" -a "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "run_trilliax:: Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
}

@test "main:: accepts --all with --dry-run" {
	mkdir -p "${TEST_CLEANUP_DIR}/empty_dir"

	run "$SCRIPT" --all --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "run_trilliax:: Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "Would remove:"
}

@test "main:: accepts --all with --targets (all overrides targets)" {
	run "$SCRIPT" --all --targets cursor "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files."
	echo "$output" | grep -q "clean_fs:: Cleaning empty directories."
}

########################################################
# Target selection tests
########################################################
@test "validate_targets:: accepts --targets option with single target" {
	mkdir -p "${TEST_CLEANUP_DIR}/.cursor"

	run "$SCRIPT" --targets cursor --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
	echo "$output" | grep -q "Would remove:"
	echo "$output" | grep -q "clean_python:: Cleaning Python files." && false || true
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files." && false || true
}

@test "validate_targets:: accepts --targets option with multiple targets" {
	run "$SCRIPT" --targets cursor,python --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files." && false || true
}

@test "validate_targets:: accepts -t option shorthand" {
	run "$SCRIPT" -t python "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories." && false || true
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files." && false || true
}

@test "validate_targets:: handles --targets with all targets" {
	run "$SCRIPT" --targets cursor,python,node --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files."
}

@test "validate_targets:: handles --targets with dry-run" {
	echo "test" >"${TEST_CLEANUP_DIR}/npm-debug.log"

	run "$SCRIPT" --targets node --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_node:: Cleaning Node.js files."
	echo "$output" | grep -q "Would remove:"
}

@test "validate_targets:: handles invalid target" {
	run "$SCRIPT" --targets invalid "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: Invalid target 'invalid'. Available targets:"
}

@test "validate_targets:: handles mixed valid and invalid targets" {
	run "$SCRIPT" --targets cursor,invalid,python "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: Invalid target 'invalid'. Available targets:"
}

@test "validate_targets:: handles --targets with spaces" {
	run "$SCRIPT" --targets "cursor, python" --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_cursor:: Cleaning .cursor directories."
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
}

@test "validate_targets:: handles --targets combined with directory" {
	run "$SCRIPT" --targets python "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "run_trilliax:: Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "clean_python:: Cleaning Python files."
}

########################################################
# Main
########################################################
@test "run_trilliax:: fails when sourced without targets" {
	run run_trilliax "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "run_trilliax:: handles non-existent directory" {
	run run_trilliax "/non/existent/directory"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: Directory '/non/existent/directory' does not exist"
}

@test "run_trilliax:: cleans a directory whose path contains spaces" {
	local spaced_dir="${TEST_DIR}/test with spaces"
	mkdir -p "${spaced_dir}/empty_dir"

	run "$SCRIPT" --targets fs "${spaced_dir}"
	[[ "$status" -eq 0 ]]
	[[ ! -d "${spaced_dir}/empty_dir" ]]
}

########################################################
# Cleanup
########################################################
@test "clean_cursor:: removes .cursor directories" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/.cursor/subdir"

	run clean_cursor "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/.cursor" ]]
}

@test "clean_cursor:: dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/.cursor/subdir"

	DRY_RUN=true run clean_cursor "$test_dir"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_cursor:: Would remove:"
	[[ -d "$test_dir/.cursor" ]]
}

@test "clean_python:: removes Python files and directories" {
	local test_dir="$TEST_CLEANUP_DIR"

	mkdir -p "$test_dir/venv"
	mkdir -p "$test_dir/.venv"
	mkdir -p "$test_dir/env"
	mkdir -p "$test_dir/__pycache__"
	echo "test" >"$test_dir/test.pyc"
	echo "test" >"$test_dir/test.pyo"
	echo "keep this" >"$test_dir/.env"

	run clean_python "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/venv" ]]
	[[ ! -d "$test_dir/.venv" ]]
	[[ -d "$test_dir/env" ]]
	[[ ! -d "$test_dir/__pycache__" ]]
	[[ ! -f "$test_dir/test.pyc" ]]
	[[ ! -f "$test_dir/test.pyo" ]]
	[[ -f "$test_dir/.env" ]]
}

@test "clean_python:: dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"

	mkdir -p "$test_dir/venv"
	mkdir -p "$test_dir/.venv"
	mkdir -p "$test_dir/env"
	mkdir -p "$test_dir/__pycache__"
	echo "test" >"$test_dir/test.pyc"
	echo "test" >"$test_dir/test.pyo"
	echo "keep this" >"$test_dir/.env"

	DRY_RUN=true run clean_python "$test_dir"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_python:: Would remove:"
	[[ -d "$test_dir/venv" ]]
	[[ -d "$test_dir/.venv" ]]
	[[ -d "$test_dir/env" ]]
	[[ -d "$test_dir/__pycache__" ]]
	[[ -f "$test_dir/test.pyc" ]]
	[[ -f "$test_dir/test.pyo" ]]
	[[ -f "$test_dir/.env" ]]
}

@test "clean_node:: removes Node.js files and directories" {
	local test_dir="$TEST_CLEANUP_DIR"

	mkdir -p "$test_dir/node_modules"
	mkdir -p "$test_dir/.npm"
	mkdir -p "$test_dir/.yarn"
	echo "test" >"$test_dir/package-lock.json"
	echo "test" >"$test_dir/yarn.lock"
	echo "test" >"$test_dir/.yarnrc.yml"
	echo "test" >"$test_dir/npm-debug.log"
	echo "test" >"$test_dir/yarn-error.log"

	run clean_node "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/node_modules" ]]
	[[ ! -d "$test_dir/.npm" ]]
	[[ -d "$test_dir/.yarn" ]]
	[[ -f "$test_dir/package-lock.json" ]]
	[[ -f "$test_dir/yarn.lock" ]]
	[[ -f "$test_dir/.yarnrc.yml" ]]
	[[ ! -f "$test_dir/npm-debug.log" ]]
	[[ ! -f "$test_dir/yarn-error.log" ]]
}

@test "clean_node:: dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"

	mkdir -p "$test_dir/node_modules"
	mkdir -p "$test_dir/.npm"
	mkdir -p "$test_dir/.yarn"
	echo "test" >"$test_dir/package-lock.json"
	echo "test" >"$test_dir/yarn.lock"

	DRY_RUN=true run clean_node "$test_dir"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "clean_node:: Would remove:"
	[[ -d "$test_dir/node_modules" ]]
	[[ -d "$test_dir/.npm" ]]
	[[ -d "$test_dir/.yarn" ]]
	[[ -f "$test_dir/package-lock.json" ]]
	[[ -f "$test_dir/yarn.lock" ]]
}

@test "execute_clean:: skips a sibling that shares the target prefix" {
	local test_dir="$TEST_CLEANUP_DIR"
	local sibling="${test_dir}-other"
	mkdir -p "${sibling}"
	echo keep >"${sibling}/keep.txt"
	TRILLIAX_SIBLING="${sibling}"
	export TRILLIAX_SIBLING

	find() {
		printf '%s\0' "${TRILLIAX_SIBLING}/keep.txt"
		return 0
	}

	DRY_RUN=false run execute_clean "clean_fs" "$test_dir" -type f
	unset -f find
	[[ "$status" -eq 0 ]]
	[[ -f "${sibling}/keep.txt" ]]
}

@test "execute_clean:: rejects a non-integer MAX_DEPTH" {
	local test_dir="$TEST_CLEANUP_DIR"
	MAX_DEPTH="nope"
	export MAX_DEPTH

	run execute_clean "clean_fs" "$test_dir" -type d -empty
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "MAX_DEPTH must be an integer"
}

@test "execute_clean:: honors MAX_DEPTH" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/.cursor"
	mkdir -p "$test_dir/a/.cursor"
	mkdir -p "$test_dir/a/b/.cursor"

	MAX_DEPTH=2
	export MAX_DEPTH

	DRY_RUN=true run execute_clean "clean_cursor" "$test_dir" -type d -name ".cursor"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove: $test_dir/.cursor"
	echo "$output" | grep -q "Would remove: $test_dir/a/.cursor"
	! echo "$output" | grep -q "Would remove: $test_dir/a/b/.cursor"
}

@test "execute_clean:: returns 1 when rm fails" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_fail"

	rm() {
		echo "rm mocked failure" >&2
		return 1
	}

	DRY_RUN=false run execute_clean "clean_fs" "$test_dir" -depth -type d -empty
	unset -f rm
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Failed to remove"
}
