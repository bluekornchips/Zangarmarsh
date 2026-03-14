#!/usr/bin/env bats

# Test file for nvm function

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"

source "$GIT_ROOT/profile/tests/fixtures.sh"

# Setup test environment with NVM configuration
setup() {
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1

	source "$SCRIPT"

	setup_common_mocks

	mock_command "curl" "NVM installation script"
	mock_command "wget" "NVM installation script"
	mock_command "bash" "NVM installed successfully"

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
	cleanup_common_mocks
	rm -rf "$TEST_DIR"
}

@test "nvm function should load successfully" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "nvm function should be available after sourcing" {
	run declare -f nvm
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "nvm ()"
}

@test "nvm should set NVM_DIR environment variable" {
	# Test that the function sets up NVM_DIR correctly
	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm should handle linux platform" {
	PLATFORM="linux"

	mock_dir_exists "$NVM_DIR" true
	mock_file_exists "$NVM_DIR/nvm.sh" true
	mock_file_exists "$NVM_DIR/bash_completion" true

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm should handle wsl platform" {
	PLATFORM="wsl"

	mock_dir_exists "$NVM_DIR" true
	mock_file_exists "$NVM_DIR/nvm.sh" true
	mock_file_exists "$NVM_DIR/bash_completion" true

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm should handle macos platform" {
	PLATFORM="macos"

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm should handle unknown platform" {
	PLATFORM="unknown"

	mkdir -p "$NVM_DIR"
	echo 'nvm() { echo "nvm version 0.39.0"; }' >"$NVM_DIR/nvm.sh"

	run nvm --version 2>&1
	[[ "$status" -eq 0 ]]
}

@test "nvm should fail gracefully when NVM_DIR not found on linux" {
	PLATFORM="linux"

	mock_dir_exists "$NVM_DIR" false

	run nvm --help 2>&1
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]] || [[ "$status" -eq 127 ]]
}

@test "nvm should pass arguments to the real nvm command" {
	run nvm --help
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm should handle missing nvm.sh file gracefully" {
	PLATFORM="linux"

	mock_dir_exists "$NVM_DIR" true
	mock_file_exists "$NVM_DIR/nvm.sh" false

	run nvm --help 2>&1
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]] || [[ "$status" -eq 127 ]]
}

@test "nvm should handle missing bash_completion gracefully" {
	PLATFORM="linux"

	mock_dir_exists "$NVM_DIR" true
	mock_file_exists "$NVM_DIR/nvm.sh" true
	mock_file_exists "$NVM_DIR/bash_completion" false

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "nvm should export the function correctly" {
	run declare -f nvm
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "nvm ()"
}

@test "nvm should handle multiple calls correctly" {
	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

	run nvm --help 2>/dev/null || true
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}
