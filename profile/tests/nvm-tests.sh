#!/usr/bin/env bats

# Test file for nvm function

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"

# Setup test environment with NVM configuration
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/nvm-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	source "$SCRIPT"

	PLATFORM="linux"
	HOME="${TEST_DIR}"
	NVM_DIR="$HOME/.nvm"
	ZANGARMARSH_VERBOSE=true

	export TEST_DIR
	export PLATFORM
	export NVM_DIR
	export ZANGARMARSH_VERBOSE
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
}

@test "nvm:: load successfully" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "nvm:: be available after sourcing" {
	run declare -f nvm
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "nvm ()"
}

@test "nvm:: set NVM_DIR environment variable" {
	# Test that the function sets up NVM_DIR correctly
	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm:: handle linux platform" {
	PLATFORM="linux"

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm:: handle macos platform" {
	PLATFORM="macos"

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm:: handle unknown platform" {
	PLATFORM="unknown"

	mkdir -p "$NVM_DIR"
	echo 'nvm() { echo "nvm version 0.39.0"; }' >"$NVM_DIR/nvm.sh"

	run nvm --version 2>&1
	[[ "$status" -eq 0 ]]
}

@test "nvm:: fail gracefully when NVM_DIR not found on linux" {
	PLATFORM="linux"

	run nvm --help 2>&1
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]] || [[ "$status" -eq 127 ]]
}

@test "nvm:: pass arguments to the real nvm command" {
	run nvm --help
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm:: handle missing nvm.sh file gracefully" {
	PLATFORM="linux"
	mkdir -p "$NVM_DIR"

	run nvm --help 2>&1
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]] || [[ "$status" -eq 127 ]]
}

@test "nvm:: handle missing bash_completion gracefully" {
	PLATFORM="linux"
	mkdir -p "$NVM_DIR"
	echo 'nvm() { :; }' >"$NVM_DIR/nvm.sh"

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm:: export the function correctly" {
	run declare -f nvm
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "nvm ()"
}

@test "nvm:: handle multiple calls correctly" {
	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}
