#!/usr/bin/env bats

# Test file for list_changed_files in profile/functions.sh

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
		return 1
	}
	git init >/dev/null 2>&1
	git config user.name "Test User" >/dev/null 2>&1
	git config user.email "test@example.com" >/dev/null 2>&1
	echo "test content" >test_file
	git add test_file >/dev/null 2>&1
	git commit -m "Initial commit" >/dev/null 2>&1
}

create_mock_git_branch() {
	local test_dir="$1"
	local branch_name="$2"
	cd "$test_dir" || {
		echo "Failed to cd to test_dir: $test_dir" >&2
		return 1
	}
	git checkout -b "$branch_name" >/dev/null 2>&1
}

setup_repo_with_committed_files() {
	create_mock_git_repo "$TEST_DIR"
	create_mock_git_branch "$TEST_DIR" other
	git checkout - >/dev/null 2>&1
	local f
	for f in "$@"; do
		touch "$TEST_DIR/$f"
	done
	git add "$@" >/dev/null 2>&1
	git commit -m "Add files" >/dev/null 2>&1
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

@test "list_changed_files:: returns 1 when origin_branch is missing" {
	run list_changed_files
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "list_changed_files:: origin_branch is required"
}

@test "list_changed_files:: returns 1 when not in a git repository" {
	run list_changed_files main
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "list_changed_files:: not in a git repository"
}

@test "list_changed_files:: returns 1 for unknown option" {
	create_mock_git_repo "$TEST_DIR"
	run list_changed_files --unknown main
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "list_changed_files:: unknown option"
}

@test "list_changed_files:: lists all changed files one per line" {
	setup_repo_with_committed_files foo.sh bar.sh baz.txt

	run list_changed_files other
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "foo\.sh$"
	echo "$output" | grep -q "bar\.sh$"
	echo "$output" | grep -q "baz\.txt$"
}
