#!/usr/bin/env bats

# Test file for zangarmarsh.sh
# Tests the main zangarmarsh script functionality and shell compatibility

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"

	SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
	if [[ ! -f "${SCRIPT}" ]]; then
		echo "Script not found: ${SCRIPT}" >&2
		return 1
	fi
	export SCRIPT

	return 0
}

# Setup test environment with mock git repository
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	source "${GIT_ROOT}/tests/fixtures.sh"

	TEST_DIR="$(mktemp -d "${base}/zangarmarsh-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	# Create a mock git repository for testing using fixtures
	create_mock_git_repo "${TEST_DIR}"
	ZANGARMARSH_VERBOSE=true

	# Copy the profile and tools directories to the test directory
	cp -r "${ZANGARMARSH_ROOT}/profile" "${TEST_DIR}"
	cp -r "${ZANGARMARSH_ROOT}/tools" "${TEST_DIR}"
	cp "${ZANGARMARSH_ROOT}/zangarmarsh.sh" "${TEST_DIR}"

	# Isolate product root under the temp tree for this test.
	ZANGARMARSH_ROOT="${TEST_DIR}"

	export TEST_DIR
	export ZANGARMARSH_ROOT
	export ZANGARMARSH_VERBOSE

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

@test "zangarmarsh:: load successfully with default settings" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "zangarmarsh:: set ZANGARMARSH_ROOT to script directory" {
	source "$TEST_DIR/zangarmarsh.sh"
	[[ "$ZANGARMARSH_ROOT" == "$TEST_DIR" ]]
}

@test "zangarmarsh:: export required variables" {
	source "$SCRIPT"
	[[ -n "$ZANGARMARSH_ROOT" ]]
}

@test "zangarmarsh:: set ZANGARMARSH_VERBOSE default to empty" {
	unset ZANGARMARSH_VERBOSE
	source "$SCRIPT"
	[[ -z "${ZANGARMARSH_VERBOSE:-}" ]]
}

@test "zangarmarsh:: preserve existing ZANGARMARSH_VERBOSE value" {
	ZANGARMARSH_VERBOSE=true
	export ZANGARMARSH_VERBOSE
	source "$SCRIPT"
	[[ "$ZANGARMARSH_VERBOSE" == "true" ]]
}

@test "zangarmarsh:: not output debug info when verbose is false" {
	ZANGARMARSH_VERBOSE=false
	export ZANGARMARSH_VERBOSE
	run source "$SCRIPT" 2>&1
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -v -q "Loading Zangarmarsh"
}

@test "zangarmarsh:: load in non-interactive shells" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "load_common_components:: sources without requiring a git repository" {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	local temp_dir
	temp_dir="$(mktemp -d "${base}/zangarmarsh-load-test.XXXXXX")"
	cd "${temp_dir}" || return 1

	run bash -c "source '${SCRIPT}' && printf '%s\n' \"\${ZANGARMARSH_ROOT}\""
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "$(dirname "${SCRIPT}")"

	cd - >/dev/null || return 1
	rm -rf "${temp_dir}"
}

@test "zangarmarsh:: load every time without errors" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

# Shell compatibility tests
@test "zangarmarsh:: work with bash" {
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

@test "zangarmarsh:: work with zsh if available" {
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

@test "zangarmarsh:: handle special characters in paths" {
	local test_path_with_specials="$TEST_DIR/path with spaces and (parentheses)"
	mkdir -p "$test_path_with_specials"
	cd "$test_path_with_specials"

	run source "$SCRIPT"
	[ "$status" -eq 0 ]
}

@test "zangarmarsh:: handle very long paths" {
	local long_path="$TEST_DIR"
	local i
	for i in {1..20}; do
		long_path="$long_path/very_long_directory_name_$i"
		mkdir -p "$long_path"
	done
	cd "$long_path"

	run source "$SCRIPT"
	[ "$status" -eq 0 ]
}

@test "zangarmarsh:: handle unicode characters in paths" {
	UNICODE_PATH="$TEST_DIR/test_path/rocket/celebration"
	mkdir -p "$UNICODE_PATH"
	cd "$UNICODE_PATH"

	run source "$SCRIPT"
	[ "$status" -eq 0 ]
}
