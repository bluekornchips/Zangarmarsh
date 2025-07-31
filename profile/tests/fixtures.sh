#!/bin/bash
set -euo pipefail

# Test fixtures and helper functions for shell tests
# This file provides mock utilities and helper functions for testing shell scripts
# Includes git repository mocking, kubectl context mocking, and utility functions

GIT_ROOT=$(git rev-parse --show-toplevel)

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
		# shellcheck disable=SC2317
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
		kubectl() {
			# shellcheck disable=SC2317
			return 1
		}
		export -f kubectl
	fi
}
