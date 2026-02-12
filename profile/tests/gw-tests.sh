#!/usr/bin/env bats

# Test file for gw function in profile/functions.sh

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

create_mock_git_repo() {
	local test_dir="$1"
	cd "$test_dir" || {
		echo "test_dir does not exist: $test_dir" >&2
		exit 1
	}
	git init >/dev/null 2>&1
	git config user.name "Test User" >/dev/null 2>&1
	git config user.email "test@example.com" >/dev/null 2>&1
	echo "test content" >test_file
	git add test_file >/dev/null 2>&1
	git commit -m "Initial commit" >/dev/null 2>&1
}

setup() {
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1

	source "$SCRIPT"

	export TEST_DIR="$test_dir"
}

teardown() {
	rm -rf "$TEST_DIR"
}

@test "gw:: returns 1 when not in a git repository" {
	run gw list
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "gw:: not in a git repository"
}

@test "gw:: runs worktree list from repository root" {
	create_mock_git_repo "$TEST_DIR"

	run gw list
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "$TEST_DIR"
}

@test "gw:: runs worktree list from subdirectory" {
	create_mock_git_repo "$TEST_DIR"
	mkdir -p "$TEST_DIR/subdir"
	cd "$TEST_DIR/subdir" || exit 1

	run gw list
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "$TEST_DIR"
}

@test "gw:: passes arguments through to git worktree" {
	create_mock_git_repo "$TEST_DIR"

	run gw list --porcelain
	[[ "$status" -eq 0 ]]
	echo "$output" | head -1 | grep -q "worktree"
}

@test "gw:: fails with invalid worktree subcommand" {
	create_mock_git_repo "$TEST_DIR"

	run gw invalid-subcommand
	[[ "$status" -ne 0 ]]
}
