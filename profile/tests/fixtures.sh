#!/usr/bin/env bash

# Test fixtures and helper functions for shell tests
# This file provides mock utilities and helper functions for testing shell scripts
# Includes git repository mocking, kubectl context mocking, and utility functions

GIT_ROOT=$(git rev-parse --show-toplevel)

# Mocking framework for faster tests
# Global variables to track mocked commands and their behaviors
# These need to be declared before use
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

# Initialize on source
init_mock_arrays

# Mock a command with specific behavior
# Usage: mock_command <command> <stdout> <stderr> <exit_code>
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

# Mock a command that outputs multiple lines
# Usage: mock_command_multiline <command> <exit_code> "line1" "line2" "line3"
mock_command_multiline() {
	local cmd="$1"
	local exit_code="${2:-0}"
	shift 2
	local output="$*"

	MOCK_COMMANDS["$cmd"]="mocked"
	MOCK_STDOUT["$cmd"]="$output"
	MOCK_STDERR["$cmd"]=""
	MOCK_EXIT_CODES["$cmd"]="$exit_code"
	MOCK_CALL_COUNTS["$cmd"]="0"
}

# Mock a command that fails
# Usage: mock_command_fail <command> <error_message> <exit_code>
mock_command_fail() {
	local cmd="$1"
	local error_msg="${2:-Command failed}"
	local exit_code="${3:-1}"

	mock_command "$cmd" "" "$error_msg" "$exit_code"
}

# Mock a command that succeeds but produces no output
# Usage: mock_command_silent <command> <exit_code>
mock_command_silent() {
	local cmd="$1"
	local exit_code="${2:-0}"

	mock_command "$cmd" "" "" "$exit_code"
}

# Get call count for a mocked command
get_mock_call_count() {
	local cmd="$1"
	echo "${MOCK_CALL_COUNTS["$cmd"]:-0}"
}

# Reset all mocks
reset_mocks() {
	MOCK_COMMANDS=()
	MOCK_STDOUT=()
	MOCK_STDERR=()
	MOCK_EXIT_CODES=()
	MOCK_CALL_COUNTS=()
}

# Check if a command is mocked
is_command_mocked() {
	local cmd="$1"
	[[ "${MOCK_COMMANDS["$cmd"]}" == "mocked" ]]
}

# Execute a mocked command
execute_mock() {
	local cmd="$1"
	shift

	if ! is_command_mocked "$cmd"; then
		echo "Command '$cmd' is not mocked" >&2
		return 127
	fi

	local call_count="${MOCK_CALL_COUNTS["$cmd"]:-0}"
	MOCK_CALL_COUNTS["$cmd"]="$((call_count + 1))"

	local stdout="${MOCK_STDOUT["$cmd"]}"
	local stderr="${MOCK_STDERR["$cmd"]}"
	local exit_code="${MOCK_EXIT_CODES["$cmd"]}"

	if [[ -n "$stdout" ]]; then
		echo "$stdout"
	fi

	if [[ -n "$stderr" ]]; then
		echo "$stderr" >&2
	fi

	return "$exit_code"
}

# Mock file system operations
# Mock file/directory existence checks
declare -A MOCK_FILE_EXISTS
declare -A MOCK_DIR_EXISTS

# Mock file existence
# Usage: mock_file_exists <path> <exists>
mock_file_exists() {
	local path="$1"
	local exists="${2:-true}"
	MOCK_FILE_EXISTS["$path"]="$exists"
}

# Mock directory existence
# Usage: mock_dir_exists <path> <exists>
mock_dir_exists() {
	local path="$1"
	local exists="${2:-true}"
	MOCK_DIR_EXISTS["$path"]="$exists"
}

# Reset file mocks
reset_file_mocks() {
	MOCK_FILE_EXISTS=()
	MOCK_DIR_EXISTS=()
}

# Check if file is mocked to exist
is_file_mocked() {
	local path="$1"
	[[ "${MOCK_FILE_EXISTS["$path"]}" == "true" ]]
}

# Check if directory is mocked to exist
is_dir_mocked() {
	local path="$1"
	[[ "${MOCK_DIR_EXISTS["$path"]}" == "true" ]]
}

# Common test setup that applies mocks
setup_common_mocks() {
	mock_command "python3" "Python 3.9.7"
	mock_command "pip" "pip 22.3.1 from /usr/lib/python3/dist-packages/pip (python 3.9)"
	mock_command "git" "git version 2.34.1"
	mock_command "which" "/usr/bin/python3"
	mock_command "node" "v18.17.0"
	mock_command "npm" "8.15.0"

	# Mock file operations
	mock_command "mkdir" "" "" 0
	mock_command "touch" "" "" 0
	mock_command "cp" "" "" 0
	mock_command "rm" "" "" 0

	# Mock python virtual environment creation
	mock_command "python3 -m venv .venv" "Virtual environment created successfully"
}

cleanup_common_mocks() {
	reset_mocks
	reset_file_mocks
}

# Helper function to strip ANSI color codes for testing
strip_ansi() {
	local input="$1"
	echo "${input//$'\x1b'\[[0-9;]*m/}"
}

# Create a mock git repository for testing purposes
create_mock_git_repo() {
	local test_dir="$1"

	cd "$test_dir" || {
		echo "test_dir does not exist: $test_dir" >&2
		exit 1
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
		echo "Failed to cd to test_dir: $test_dir" >&2
		exit 1
	}
	git checkout -b "$branch_name" >/dev/null 2>&1
}

# Create a mock git tag for testing
create_mock_git_tag() {
	local test_dir="$1"
	local tag_name="$2"
	cd "$test_dir" || {
		echo "Failed to cd to test_dir: $test_dir" >&2
		exit 1
	}
	git tag "$tag_name" >/dev/null 2>&1
	git checkout "$tag_name" >/dev/null 2>&1
}

# Create a mock detached HEAD state for testing
create_mock_git_detached() {
	local test_dir="$1"
	cd "$test_dir" || {
		echo "Failed to cd to test_dir: $test_dir" >&2
		exit 1
	}
	git checkout --detach HEAD >/dev/null 2>&1
}

# Mock kubectl context for testing Kubernetes functionality
mock_kubectl_context() {
	local context_name="$1"
	local test_dir="$2"
	if [[ -n "$context_name" ]]; then
		export KUBECONFIG="$test_dir/kubeconfig"
		export MOCK_KUBECTL_CONTEXT="$context_name"
		cat >"$KUBECONFIG" <<EOF
apiVersion: v1
kind: Config
current-context: $context_name
contexts:
	- name: $context_name
		context:
		cluster: test-cluster
		user: test-user
clusters:
	- name: test-cluster
		cluster:
		server: https://test-server
users:
	- name: test-user
		user:
			token: test-user-token
EOF
		# Create mock kubectl function
		# shellcheck disable=SC2317,SC2329
		kubectl() {
			if [[ "$1" == "config" && "$2" == "current-context" ]]; then
				echo "$MOCK_KUBECTL_CONTEXT"
			else
				return 1
			fi
		}
		export -f kubectl
	else
		unset KUBECONFIG
		unset MOCK_KUBECTL_CONTEXT
		# Create mock kubectl that fails
		# shellcheck disable=SC2317,SC2329
		kubectl() {
			return 1
		}
		export -f kubectl
	fi
}
