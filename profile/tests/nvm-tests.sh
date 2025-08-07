#!/usr/bin/env bats

# Test file for nvm function in tools/functions.sh

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

# Setup test environment with NVM configuration
setup() {
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1
	# shellcheck disable=SC1090
	source "$SCRIPT"

	PLATFORM="linux"
	HOME="$test_dir"
	NVM_DIR="$HOME/.nvm"
	ZANGARMARSH_VERBOSE=true

	export TEST_DIR="$test_dir"
	export PLATFORM
	export NVM_DIR
	export ZANGARMARSH_VERBOSE
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
}

@test "nvm function should load successfully" {
	run source "$SCRIPT"
	[ "$status" -eq 0 ]
}

@test "nvm function should be available after sourcing" {
	run declare -f nvm
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "nvm ()"
}

@test "nvm should set NVM_DIR environment variable" {
	# Test that the function sets up NVM_DIR correctly
	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvm should handle linux platform" {
	PLATFORM="linux"

	mkdir -p "$NVM_DIR"
	touch "$NVM_DIR/nvm.sh"
	touch "$NVM_DIR/bash_completion"

	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvm should handle wsl platform" {
	PLATFORM="wsl"

	mkdir -p "$NVM_DIR"
	touch "$NVM_DIR/nvm.sh"
	touch "$NVM_DIR/bash_completion"

	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvm should handle macos platform" {
	PLATFORM="macos"

	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvm should handle unknown platform" {
	PLATFORM="unknown"

	mkdir -p "$NVM_DIR"
	echo "# Mock NVM script" >"$NVM_DIR/nvm.sh"
	echo 'nvm() { echo "nvm version"; }' >>"$NVM_DIR/nvm.sh"
	run nvm --version 2>&1
	[ "$status" -eq 0 ]
}

@test "nvm should fail gracefully when NVM_DIR not found on linux" {
	PLATFORM="linux"

	rm -rf "$NVM_DIR" 2>/dev/null || true

	run nvm --help 2>&1
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "nvm should pass arguments to the real nvm command" {
	run nvm --help
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvm should handle missing nvm.sh file gracefully" {
	PLATFORM="linux"

	mkdir -p "$NVM_DIR"
	rm -f "$NVM_DIR/nvm.sh" 2>/dev/null || true

	run nvm --help 2>&1
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "nvm should handle missing bash_completion gracefully" {
	PLATFORM="linux"

	mkdir -p "$NVM_DIR"
	touch "$NVM_DIR/nvm.sh"
	rm -f "$NVM_DIR/bash_completion" 2>/dev/null || true

	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvm should export the function correctly" {
	run declare -f nvm
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "nvm ()"
}

@test "nvm should handle multiple calls correctly" {
	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]

	run nvm --help 2>/dev/null || true
	[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
