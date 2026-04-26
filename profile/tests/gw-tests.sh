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
	run gw feature-one
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "gw:: not in a git repository"
}

@test "gw:: passes add through from repository root" {
	local repo_dir
	local worktree_dir
	repo_dir="$TEST_DIR/repo"
	worktree_dir="$TEST_DIR/add-root"

	mkdir -p "$repo_dir"
	create_mock_git_repo "$repo_dir"

	run gw add "$worktree_dir" HEAD
	[[ "$status" -eq 0 ]]
	[[ -d "$worktree_dir" ]]
}

@test "gw:: passes add through from subdirectory" {
	local repo_dir
	local worktree_dir
	repo_dir="$TEST_DIR/repo"
	worktree_dir="$TEST_DIR/add-subdir"

	mkdir -p "$repo_dir"
	create_mock_git_repo "$repo_dir"
	mkdir -p "$repo_dir/subdir"
	cd "$repo_dir/subdir" || exit 1

	run gw add "$worktree_dir" HEAD
	[[ "$status" -eq 0 ]]
	[[ -d "$worktree_dir" ]]
}

@test "gw:: passes remove through to git worktree" {
	local repo_dir
	local worktree_dir
	repo_dir="$TEST_DIR/repo"
	worktree_dir="$TEST_DIR/remove-me"

	mkdir -p "$repo_dir"
	create_mock_git_repo "$repo_dir"
	git -C "$repo_dir" worktree add "$worktree_dir" HEAD >/dev/null 2>&1

	run gw remove "$worktree_dir"
	[[ "$status" -eq 0 ]]
	[[ ! -d "$worktree_dir" ]]
}

@test "gw:: creates worktree from current branch when base is omitted" {
	local repo_dir
	local worktree_dir
	local current_branch
	repo_dir="$TEST_DIR/repo"
	worktree_dir="$TEST_DIR/feature-one"

	mkdir -p "$repo_dir"
	create_mock_git_repo "$repo_dir"
	current_branch="$(git -C "$repo_dir" branch --show-current)"

	run gw feature-one
	[[ "$status" -eq 0 ]]
	[[ -d "$worktree_dir" ]]
	[[ "$(git -C "$worktree_dir" branch --show-current)" == "feature-one" ]]
	[[ "$(git -C "$worktree_dir" merge-base feature-one "$current_branch")" == "$(git -C "$repo_dir" rev-parse "$current_branch")" ]]
}

@test "gw:: creates worktree from explicit base branch" {
	local repo_dir
	local worktree_dir
	repo_dir="$TEST_DIR/repo"
	worktree_dir="$TEST_DIR/feature-two"

	mkdir -p "$repo_dir"
	create_mock_git_repo "$repo_dir"
	git -C "$repo_dir" checkout -b base-branch >/dev/null 2>&1
	echo "base content" >"$repo_dir/base_file"
	git -C "$repo_dir" add base_file >/dev/null 2>&1
	git -C "$repo_dir" commit -m "Base commit" >/dev/null 2>&1

	run gw feature-two base-branch
	[[ "$status" -eq 0 ]]
	[[ -d "$worktree_dir" ]]
	[[ -f "$worktree_dir/base_file" ]]
	[[ "$(git -C "$worktree_dir" branch --show-current)" == "feature-two" ]]
}

@test "gw:: fails when shortcut receives too many arguments" {
	create_mock_git_repo "$TEST_DIR"

	run gw feature-three base-branch extra-arg
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"gw:: shortcut accepts at most two arguments"* ]]
}

@test "gw:: fails when no shortcut name is provided" {
	create_mock_git_repo "$TEST_DIR"

	run gw
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"gw:: name is required unless using add or remove"* ]]
}
