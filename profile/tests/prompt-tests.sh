#!/usr/bin/env bats

# Test file for zsh prompt functionality in profile/zsh/prompt.zsh

setup_file() {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"

	SCRIPT="${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh"
	[[ -f "$SCRIPT" ]] || {
		echo "Script not found: $SCRIPT" >&2
		return 1
	}
	export SCRIPT

	return 0
}

# Setup test environment for zsh prompt testing
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/prompt-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	export TEST_DIR
	USER="testuser"
	export USER
	HOSTNAME="testhost"
	export HOSTNAME
	HOME="${TEST_DIR}"
	export HOME
	PWD="${TEST_DIR}"
	export PWD

	return 0
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"

	return 0
}

teardown_file() {
	return 0
}

# Core loading tests
@test "prompt:: load successfully in zsh" {
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "prompt:: set PROMPT variable in zsh" {
	run zsh -c "source '$SCRIPT' && echo \$PROMPT"
	[ "$status" -eq 0 ]
	[[ -n "$output" ]]
}

@test "prompt:: define build_prompt function in zsh" {
	run zsh -c "source '$SCRIPT' && type build_prompt"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "function"
}

@test "prompt:: define git_branch function in zsh" {
	run zsh -c "source '$SCRIPT' && type git_branch"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "function"
}

@test "prompt:: define kube_context function in zsh" {
	run zsh -c "source '$SCRIPT' && type kube_context"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "function"
}
