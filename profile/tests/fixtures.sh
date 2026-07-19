#!/usr/bin/env bash

# Test fixtures and helper functions for shell tests
# Provides git repository mocking for Bats tests

GIT_ROOT=$(git rev-parse --show-toplevel)

# Create a mock git repository for testing purposes
create_mock_git_repo() {
	local test_dir="$1"

	cd "$test_dir" || {
		echo "create_mock_git_repo:: test_dir does not exist: ${test_dir}" >&2
		return 1
	}

	git init >/dev/null 2>&1
	git config user.name "Test User" >/dev/null 2>&1
	git config user.email "test@example.test" >/dev/null 2>&1
	echo "test content" >test_file
	git add test_file >/dev/null 2>&1
	git commit -m "Initial commit" >/dev/null 2>&1
}

# Create a mock git branch for testing
create_mock_git_branch() {
	local test_dir="$1"
	local branch_name="$2"

	cd "$test_dir" || {
		echo "create_mock_git_branch:: failed to cd to test_dir: ${test_dir}" >&2
		return 1
	}
	git checkout -b "$branch_name" >/dev/null 2>&1
}
