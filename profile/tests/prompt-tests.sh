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

#shellcheck disable=SC1091
source "$GIT_ROOT/profile/tests/fixtures.sh"

# Setup test environment for zsh prompt testing
setup() {
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1

	export TEST_DIR="$test_dir"
	export USER="frodo"
	export HOSTNAME="bag-end"
	export HOME="$test_dir"
	export PWD="$test_dir"
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
}

# Core loading tests
@test "prompt should load successfully in zsh" {
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "prompt should set PROMPT variable in zsh" {
	run zsh -c "source '$SCRIPT' && echo \$PROMPT"
	[ "$status" -eq 0 ]
	[[ -n "$output" ]]
}

@test "prompt should define build_prompt function in zsh" {
	run zsh -c "source '$SCRIPT' && type build_prompt"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "function"
}

@test "prompt should define git_branch function in zsh" {
	run zsh -c "source '$SCRIPT' && type git_branch"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "function"
}

@test "prompt should define kube_context function in zsh" {
	run zsh -c "source '$SCRIPT' && type kube_context"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "function"
}
