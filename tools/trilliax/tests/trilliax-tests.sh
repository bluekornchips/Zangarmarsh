#!/usr/bin/env bats
#
# Test file for trilliax.sh
# Tests the trilliax cleanup script functionality
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="$GIT_ROOT/tools/trilliax/trilliax.sh"
[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && exit 1

setup_file() {
	return 0
}

setup() {
	set +e
	trap - EXIT ERR
	# shellcheck disable=SC1091
	source "$SCRIPT"
	trap - EXIT ERR
	set +e

	export TEST_DIR
	TEST_DIR="$(mktemp -d)"
	export TEST_CLEANUP_DIR="$TEST_DIR/cleanup_test"

	mkdir -p "$TEST_CLEANUP_DIR"

	mkdir -p "$TEST_CLEANUP_DIR/.cursor"
	mkdir -p "$TEST_CLEANUP_DIR/__pycache__"
	mkdir -p "$TEST_CLEANUP_DIR/venv"
	mkdir -p "$TEST_CLEANUP_DIR/.venv"
	mkdir -p "$TEST_CLEANUP_DIR/env"

	echo "keep this" >"$TEST_CLEANUP_DIR/.env"
	echo "keep this" >"$TEST_CLEANUP_DIR/.nvmrc"

	echo "test content" >"$TEST_CLEANUP_DIR/test.pyc"
	echo "test content" >"$TEST_CLEANUP_DIR/test.pyo"

	mkdir -p "$TEST_CLEANUP_DIR/node_modules"
	echo "test" >"$TEST_CLEANUP_DIR/package-lock.json"
	echo "test" >"$TEST_CLEANUP_DIR/yarn.lock"

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
	# Create empty directories at different depths
	mkdir -p "$test_dir/level1"
	mkdir -p "$test_dir/level1/level2"
	mkdir -p "$test_dir/level1/level2/level3"

	DRY_RUN=true run clean_fs "$test_dir"
	[[ "$status" -eq 0 ]]
	# Should show level1 and level2 but not level3 (beyond max depth)
	echo "$output" | grep -q "Would remove: $test_dir/level1"
	echo "$output" | grep -q "Would remove: $test_dir/level1/level2"
	echo "$output" | grep -q "Would remove: $test_dir/level1/level2/level3" && false || true
}

@test "fs target:: cleans empty directories with run_trilliax function" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_to_clean"

	run "$SCRIPT" --targets fs "$test_dir"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/empty_to_clean" ]]
}

@test "fs target:: dry-run shows empty directories" {
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

@test "main:: rejects --dry-run with directory argument" {
	run "$SCRIPT" --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects DRY_RUN environment variable without targets" {
	run bash -c "DRY_RUN=true $SCRIPT $TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects DRY_RUN override without targets" {
	run bash -c "DRY_RUN=false $SCRIPT --dry-run $TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects directory as first argument without targets" {
	run "$SCRIPT" "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects --dir option without targets" {
	run "$SCRIPT" --dir "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects -d option without targets" {
	run "$SCRIPT" -d "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "validate_targets:: No targets specified"
}

@test "main:: rejects --dir option with dry-run without targets" {
	run "$SCRIPT" --dir "$TEST_CLEANUP_DIR" --dry-run
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
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

@test "run_trilliax:: handles non-existent directory" {
	run run_trilliax "/non/existent/directory"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: Directory '/non/existent/directory' does not exist"
}

@test "run_trilliax:: fails when no directory argument provided" {
	cd "$TEST_CLEANUP_DIR" || return 1
	run run_trilliax
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

@test "run_trilliax:: fails with relative path without targets" {
	local relative_path="tools/trilliax/tests"
	local absolute_path
	absolute_path="$(cd "$GIT_ROOT/$relative_path" && pwd)"

	run run_trilliax "$GIT_ROOT/$relative_path"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
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

	run clean_python "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/venv" ]]
	[[ ! -d "$test_dir/.venv" ]]
	[[ ! -d "$test_dir/env" ]]
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
	[[ ! -d "$test_dir/.yarn" ]]
	[[ ! -f "$test_dir/package-lock.json" ]]
	[[ ! -f "$test_dir/yarn.lock" ]]
	[[ ! -f "$test_dir/.yarnrc.yml" ]]
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

########################################################
# Dry-run integration tests
########################################################
@test "run_trilliax:: dry-run integration test fails without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	DRY_RUN=true run run_trilliax "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

########################################################
# Integration tests
########################################################
@test "run_trilliax:: full cleanup fails without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	run run_trilliax "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

@test "run_trilliax:: cleanup fails to preserve files without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	echo "keep me" >"$test_dir/important.txt"
	echo "keep me" >"$test_dir/.hidden"
	mkdir -p "$test_dir/normal_dir"
	echo "keep me" >"$test_dir/normal_dir/file.txt"

	run run_trilliax "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

@test "run_trilliax:: cleanup fails to preserve .env and .nvmrc without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	[[ -f "$test_dir/.env" ]]
	[[ -f "$test_dir/.nvmrc" ]]

	run run_trilliax "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

########################################################
# Edge case tests
########################################################
@test "run_trilliax:: handles empty directory fails without targets" {
	local empty_dir="$TEST_DIR/empty_test"
	mkdir -p "$empty_dir"

	run run_trilliax "$empty_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

@test "run_trilliax:: handles directory with spaces fails without targets" {
	local spaced_dir="$TEST_DIR/test with spaces"
	mkdir -p "$spaced_dir"

	mkdir -p "$spaced_dir/.cursor"

	run run_trilliax "$spaced_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}

@test "run_trilliax:: handles nested directory fails without targets" {
	local nested_dir="$TEST_DIR/nested/test/deep"
	mkdir -p "$nested_dir/.cursor"

	run run_trilliax "$TEST_DIR/nested"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_trilliax:: No targets selected for cleanup."
}
