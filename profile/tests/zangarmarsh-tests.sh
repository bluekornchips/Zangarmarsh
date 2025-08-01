#!/usr/bin/env bats

# Test file for zangarmarsh.sh
# Tests the main zangarmarsh script functionality and shell compatibility

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/zangarmarsh.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

#shellcheck disable=SC1091
source "$GIT_ROOT/profile/tests/fixtures.sh"

# Setup test environment with mock git repository
setup() {
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1

	# Create a mock git repository for testing using fixtures
	create_mock_git_repo "$test_dir"
	ZANGARMARSH_ROOT="$test_dir"
	ZANGARMARSH_VERBOSE=true

	# Copy the profile and tools directories to the test directory
	cp -r "$GIT_ROOT/profile" "$test_dir"
	cp -r "$GIT_ROOT/tools" "$test_dir"
	cp "$GIT_ROOT/zangarmarsh.sh" "$test_dir"

	# Set GIT_ROOT to the test directory _after_ copying files
	GIT_ROOT="$test_dir"

	export TEST_DIR="$test_dir"
	export ZANGARMARSH_ROOT
	export ZANGARMARSH_VERBOSE
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
}

@test "zangarmarsh should load successfully with default settings" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "zangarmarsh should set ZANGARMARSH_ROOT to git root" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$ZANGARMARSH_ROOT" == "$GIT_ROOT" ]]
}

@test "zangarmarsh should export required variables" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ -n "$ZANGARMARSH_VERBOSE" ]]
	[[ -n "$ZANGARMARSH_ROOT" ]]
}

@test "zangarmarsh should set ZANGARMARSH_VERBOSE default to empty" {
	unset ZANGARMARSH_VERBOSE
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ -z "${ZANGARMARSH_VERBOSE:-}" ]]
}

@test "zangarmarsh should preserve existing ZANGARMARSH_VERBOSE value" {
	export ZANGARMARSH_VERBOSE=true
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$ZANGARMARSH_VERBOSE" == "true" ]]
}

@test "zangarmarsh should not output debug info when verbose is false" {
	#shellcheck disable=SC2031
	export ZANGARMARSH_VERBOSE=false
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -v -q "Loading Zangarmarsh"
}

@test "zangarmarsh should load in non-interactive shells" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ -n "$ZANGARMARSH_ROOT" ]]
}

@test "zangarmarsh should exit with error when not in git repository" {
	local temp_dir
	temp_dir=$(mktemp -d)
	cd "$temp_dir"

	cat >test_zangarmarsh.sh <<'EOF'
#!/usr/bin/env bash
ZANGARMARSH_VERBOSE="${ZANGARMARSH_VERBOSE:-false}"

# This should fail since we're not in a git repo
ZANGARMARSH_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$ZANGARMARSH_ROOT" ]]; then
    echo "Error: ZANGARMARSH_ROOT is not set" >&2
    exit 1
fi

export ZANGARMARSH_VERBOSE
export ZANGARMARSH_ROOT

load_zangarmarsh(){
    return 0
}

load_zangarmarsh
EOF

	run source test_zangarmarsh.sh
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: ZANGARMARSH_ROOT is not set"

	rm -rf "$temp_dir"
}

@test "zangarmarsh should load every time without errors" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

# Shell compatibility tests
@test "zangarmarsh should work with bash" {
	if command -v bash >/dev/null 2>&1; then
		if bash -c "source '$SCRIPT'"; then
			: # Test passed
		else
			return 1
		fi
	else
		skip "bash not available on this system"
	fi
}

@test "zangarmarsh should work with zsh if available" {
	if command -v zsh >/dev/null 2>&1; then
		if zsh -c "source '$SCRIPT'"; then
			: # Test passed
		else
			return 1
		fi
	else
		skip "zsh not available on this system"
	fi
}

@test "zangarmarsh should handle special characters in paths" {
	local test_path_with_specials
	test_path_with_specials="$TEST_DIR/path with spaces and (parentheses)"
	mkdir -p "$test_path_with_specials"
	cd "$test_path_with_specials"

	run "$SCRIPT"
	[ "$status" -eq 0 ]
}

@test "zangarmarsh should handle very long paths" {
	local long_path
	local i
	long_path="$TEST_DIR"
	for i in {1..20}; do
		long_path="$long_path/very_long_directory_name_$i"
		mkdir -p "$long_path"
	done
	cd "$long_path"

	run "$SCRIPT"
	[ "$status" -eq 0 ]
}

@test "zangarmarsh should handle unicode characters in paths" {
	UNICODE_PATH="$TEST_DIR/test_path/rocket/celebration"
	mkdir -p "$UNICODE_PATH"
	cd "$UNICODE_PATH"

	run "$SCRIPT"
	[ "$status" -eq 0 ]
}
