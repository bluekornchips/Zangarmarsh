#!/usr/bin/env bash

# Test fixtures and helper functions for shell tests
# Provides git repository mocking and common command mocks

GIT_ROOT=$(git rev-parse --show-toplevel)

# Mocking framework for faster tests
init_mock_arrays() {
	if [[ ! -v MOCK_COMMANDS ]]; then
		declare -gA MOCK_COMMANDS
		declare -gA MOCK_STDOUT
		declare -gA MOCK_STDERR
		declare -gA MOCK_EXIT_CODES
		declare -gA MOCK_CALL_COUNTS
		declare -gA MOCK_FILE_EXISTS
		declare -gA MOCK_DIR_EXISTS
	fi
}

init_mock_arrays

mock_command() {
	local cmd="$1"
	local stdout="${2:-}"
	local stderr="${3:-}"
	local exit_code="${4:-0}"

	MOCK_COMMANDS["$cmd"]="mocked"
	MOCK_STDOUT["$cmd"]="$stdout"
	MOCK_STDERR["$cmd"]="$stderr"
	MOCK_EXIT_CODES["$cmd"]="$exit_code"
	MOCK_CALL_COUNTS["$cmd"]="0"
}

reset_mocks() {
	MOCK_COMMANDS=()
	MOCK_STDOUT=()
	MOCK_STDERR=()
	MOCK_EXIT_CODES=()
	MOCK_CALL_COUNTS=()
}

is_command_mocked() {
	local cmd="$1"
	[[ "${MOCK_COMMANDS["$cmd"]}" == "mocked" ]]
}

declare -A MOCK_FILE_EXISTS
declare -A MOCK_DIR_EXISTS

mock_file_exists() {
	local path="$1"
	local exists="${2:-true}"
	MOCK_FILE_EXISTS["$path"]="$exists"
}

mock_dir_exists() {
	local path="$1"
	local exists="${2:-true}"
	MOCK_DIR_EXISTS["$path"]="$exists"
}

reset_file_mocks() {
	MOCK_FILE_EXISTS=()
	MOCK_DIR_EXISTS=()
}

setup_common_mocks() {
	mock_command "python3" "Python 3.9.7"
	mock_command "pip" "pip 22.3.1 from /usr/lib/python3/dist-packages/pip (python 3.9)"
	mock_command "git" "git version 2.34.1"
	mock_command "which" "/usr/bin/python3"
	mock_command "node" "v18.17.0"
	mock_command "npm" "8.15.0"
	mock_command "mkdir" "" "" 0
	mock_command "touch" "" "" 0
	mock_command "cp" "" "" 0
	mock_command "rm" "" "" 0
	mock_command "python3 -m venv .venv" "Virtual environment created successfully"
}

cleanup_common_mocks() {
	reset_mocks
	reset_file_mocks
}

# Create a mock git repository for testing purposes
create_mock_git_repo() {
	local test_dir="$1"

	cd "$test_dir" || {
		echo "create_mock_git_repo:: test_dir does not exist: ${test_dir}" >&2
		return 1
	}

	git init >/dev/null 2>&1
	git config user.name "Frodo Baggins" >/dev/null 2>&1
	git config user.email "frodo@shire.test" >/dev/null 2>&1
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
