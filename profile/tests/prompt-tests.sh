#!/usr/bin/env bats

# Test file for zsh prompt functionality in profile/zsh/prompt.sh

if ! command -v zsh >/dev/null 2>&1; then
	echo "zsh not available, skipping prompt tests" >&2
	exit 0
fi

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/zsh/prompt.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

# Setup test environment for zsh prompt testing
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/prompt-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	export TEST_DIR
	export USER="frodo"
	export HOSTNAME="bag-end"
	export HOME="${TEST_DIR}"
	export PWD="${TEST_DIR}"
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
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
