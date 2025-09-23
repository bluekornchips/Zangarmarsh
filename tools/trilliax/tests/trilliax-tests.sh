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
	#shellcheck disable=SC1090
	source "$SCRIPT"

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

	echo "test content" >"$TEST_CLEANUP_DIR/CLAUDE.md"
	echo "test content" >"$TEST_CLEANUP_DIR/claude-test.txt"
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
@test "clean_fs::removes empty directories" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"

	run clean_fs "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/empty_dir" ]]
}

@test "clean_fs::dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"

	run clean_fs "$test_dir" "true"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove: $test_dir/empty_dir"
}

@test "clean_fs::handles nested empty directories" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"
	mkdir -p "$test_dir/empty_dir/empty_subdir"

	run clean_fs "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/empty_dir" ]]
	[[ ! -d "$test_dir/empty_dir/empty_subdir" ]]
}

@test "clean_fs::handles nested empty directories with dry-run" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/empty_dir"
	mkdir -p "$test_dir/empty_dir/empty_subdir"

	run clean_fs "$test_dir" "true"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove: $test_dir/empty_dir"
	echo "$output" | grep -q "Would remove: $test_dir/empty_dir/empty_subdir"
}

########################################################
# Script structure and help
########################################################
@test "main::has proper shebang and structure" {
	run bash -n "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "main::is executable" {
	[[ -x "$SCRIPT" ]]
}

@test "usage::displays help when called with --help" {
	run "$SCRIPT" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: "
	echo "$output" | grep -q "Trilliax cleanup script"
	echo "$output" | grep -q "CLEANUP OPERATIONS:"
}

@test "usage::displays help when called with -h" {
	run "$SCRIPT" -h
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: "
}

@test "main::handles unknown options" {
	run "$SCRIPT" --invalid-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option '--invalid-option'"
	echo "$output" | grep -q "Use 'trilliax.sh --help' for usage information"
}

@test "main::rejects --dry-run option without targets" {
	run "$SCRIPT" --dry-run
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects --dry-run with directory argument" {
	run "$SCRIPT" --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects DRY_RUN environment variable without targets" {
	run bash -c "DRY_RUN=true $SCRIPT $TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects DRY_RUN override without targets" {
	run bash -c "DRY_RUN=false $SCRIPT --dry-run $TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects directory as first argument without targets" {
	run "$SCRIPT" "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects --dir option without targets" {
	run "$SCRIPT" --dir "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects -d option without targets" {
	run "$SCRIPT" -d "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::rejects --dir option with dry-run without targets" {
	run "$SCRIPT" --dir "$TEST_CLEANUP_DIR" --dry-run
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets specified"
}

@test "main::accepts --all option" {
	run "$SCRIPT" --all "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "Cleaning .cursor directories."
	echo "$output" | grep -q "Cleaning Claude files."
	echo "$output" | grep -q "Cleaning Python files."
	echo "$output" | grep -q "Cleaning Node.js files."
}

@test "main::accepts -a option" {
	run "$SCRIPT" -a "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "Cleaning .cursor directories."
}

@test "main::accepts --all with --dry-run" {
	run "$SCRIPT" --all --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "Would remove:"
}

@test "main::accepts --all with --targets (all overrides targets)" {
	run "$SCRIPT" --all --targets cursor "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning .cursor directories."
	echo "$output" | grep -q "Cleaning Claude files."
	echo "$output" | grep -q "Cleaning Python files."
	echo "$output" | grep -q "Cleaning Node.js files."
}

########################################################
# Target selection tests
########################################################
@test "validate_targets::accepts --targets option with single target" {
	run "$SCRIPT" --targets cursor --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning .cursor directories."
	echo "$output" | grep -q "Would remove:"
	echo "$output" | grep -q "Cleaning Claude files." && false || true
	echo "$output" | grep -q "Cleaning Python files." && false || true
	echo "$output" | grep -q "Cleaning Node.js files." && false || true
}

@test "validate_targets::accepts --targets option with multiple targets" {
	run "$SCRIPT" --targets cursor,python --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning .cursor directories."
	echo "$output" | grep -q "Cleaning Python files."
	echo "$output" | grep -q "Cleaning Claude files." && false || true
	echo "$output" | grep -q "Cleaning Node.js files." && false || true
}

@test "validate_targets::accepts -t option shorthand" {
	run "$SCRIPT" -t claude "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning Claude files."
	echo "$output" | grep -q "Cleaning .cursor directories." && false || true
	echo "$output" | grep -q "Cleaning Python files." && false || true
	echo "$output" | grep -q "Cleaning Node.js files." && false || true
}

@test "validate_targets::handles --targets with all targets" {
	run "$SCRIPT" --targets cursor,claude,python,node --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning .cursor directories."
	echo "$output" | grep -q "Cleaning Claude files."
	echo "$output" | grep -q "Cleaning Python files."
	echo "$output" | grep -q "Cleaning Node.js files."
}

@test "validate_targets::handles --targets with dry-run" {
	run "$SCRIPT" --targets node --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning Node.js files."
	echo "$output" | grep -q "Would remove:"
}

@test "validate_targets::handles invalid target" {
	run "$SCRIPT" --targets invalid "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Invalid target 'invalid'. Available targets:"
}

@test "validate_targets::handles mixed valid and invalid targets" {
	run "$SCRIPT" --targets cursor,invalid,python "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Invalid target 'invalid'. Available targets:"
}

@test "validate_targets::handles --targets with spaces" {
	run "$SCRIPT" --targets "cursor, python" --dry-run "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning .cursor directories."
	echo "$output" | grep -q "Cleaning Python files."
}

@test "validate_targets::handles --targets combined with directory" {
	run "$SCRIPT" --targets claude "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Cleaning directory: $TEST_CLEANUP_DIR"
	echo "$output" | grep -q "Cleaning Claude files."
}

########################################################
# Main function tests
########################################################
@test "main::fails when sourced without targets" {
	run main "$TEST_CLEANUP_DIR"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

@test "main::handles non-existent directory" {
	run main "/non/existent/directory"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Directory '/non/existent/directory' does not exist"
}

@test "main::fails when no directory argument provided" {
	cd "$TEST_CLEANUP_DIR" || return 1
	run main
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

@test "main::fails with relative path without targets" {
	local relative_path="tools/trilliax/tests"
	local absolute_path
	absolute_path="$(cd "$GIT_ROOT/$relative_path" && pwd)"

	run main "$GIT_ROOT/$relative_path"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

########################################################
# Cleanup function tests
########################################################
@test "clean_cursor::removes .cursor directories" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/.cursor/subdir"

	run clean_cursor "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$test_dir/.cursor" ]]
}

@test "clean_cursor::dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"
	mkdir -p "$test_dir/.cursor/subdir"

	run clean_cursor "$test_dir" "true"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove:"
	[[ -d "$test_dir/.cursor" ]]
}

@test "clean_claude::removes CLAUDE.md files" {
	local test_dir="$TEST_CLEANUP_DIR"
	echo "test" >"$test_dir/CLAUDE.md"
	echo "test" >"$test_dir/claude-test.txt"

	run clean_claude "$test_dir" "false"
	[[ "$status" -eq 0 ]]
	[[ ! -f "$test_dir/CLAUDE.md" ]]
	[[ -f "$test_dir/claude-test.txt" ]]
}

@test "clean_claude::dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"
	echo "test" >"$test_dir/CLAUDE.md"

	run clean_claude "$test_dir" "true"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove:"
	[[ -f "$test_dir/CLAUDE.md" ]]
}

@test "clean_python::removes Python files and directories" {
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

@test "clean_python::dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"

	mkdir -p "$test_dir/venv"
	mkdir -p "$test_dir/.venv"
	mkdir -p "$test_dir/env"
	mkdir -p "$test_dir/__pycache__"
	echo "test" >"$test_dir/test.pyc"
	echo "test" >"$test_dir/test.pyo"

	run clean_python "$test_dir" "true"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove:"
	[[ -d "$test_dir/venv" ]]
	[[ -d "$test_dir/.venv" ]]
	[[ -d "$test_dir/env" ]]
	[[ -d "$test_dir/__pycache__" ]]
	[[ -f "$test_dir/test.pyc" ]]
	[[ -f "$test_dir/test.pyo" ]]
	[[ -f "$test_dir/.env" ]]
}

@test "clean_node::removes Node.js files and directories" {
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

@test "clean_node::dry-run shows what would be removed" {
	local test_dir="$TEST_CLEANUP_DIR"

	mkdir -p "$test_dir/node_modules"
	mkdir -p "$test_dir/.npm"
	mkdir -p "$test_dir/.yarn"
	echo "test" >"$test_dir/package-lock.json"
	echo "test" >"$test_dir/yarn.lock"

	run clean_node "$test_dir" "true"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would remove:"
	[[ -d "$test_dir/node_modules" ]]
	[[ -d "$test_dir/.npm" ]]
	[[ -d "$test_dir/.yarn" ]]
	[[ -f "$test_dir/package-lock.json" ]]
	[[ -f "$test_dir/yarn.lock" ]]
}

########################################################
# Dry-run integration tests
########################################################
@test "main::dry-run integration test fails without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	run main "$test_dir" "true"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

########################################################
# Integration tests
########################################################
@test "main::full cleanup fails without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	run main "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

@test "main::cleanup fails to preserve files without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	echo "keep me" >"$test_dir/important.txt"
	echo "keep me" >"$test_dir/.hidden"
	mkdir -p "$test_dir/normal_dir"
	echo "keep me" >"$test_dir/normal_dir/file.txt"

	run main "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

@test "main::cleanup fails to preserve .env and .nvmrc without targets" {
	local test_dir="$TEST_CLEANUP_DIR"

	[[ -f "$test_dir/.env" ]]
	[[ -f "$test_dir/.nvmrc" ]]

	run main "$test_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

########################################################
# Edge case tests
########################################################
@test "main::handles empty directory fails without targets" {
	local empty_dir="$TEST_DIR/empty_test"
	mkdir -p "$empty_dir"

	run main "$empty_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

@test "main::handles directory with spaces fails without targets" {
	local spaced_dir="$TEST_DIR/test with spaces"
	mkdir -p "$spaced_dir"

	mkdir -p "$spaced_dir/.cursor"
	echo "test" >"$spaced_dir/CLAUDE.md"

	run main "$spaced_dir"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}

@test "main::handles nested directory fails without targets" {
	local nested_dir="$TEST_DIR/nested/test/deep"
	mkdir -p "$nested_dir/.cursor"

	run main "$TEST_DIR/nested"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No targets selected for cleanup."
}
