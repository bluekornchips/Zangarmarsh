#!/usr/bin/env bats

# Test file for penv function in profile/functions.sh

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

source "$GIT_ROOT/profile/tests/fixtures.sh"

# Python virtual environment helper functions for testing

# Create a mock Python virtual environment for testing
create_mock_venv() {
	setup_common_mocks
	mock_command "python3 -m venv .venv" "Virtual environment created successfully"
	mock_file_exists ".venv/bin/activate" true
	mock_dir_exists ".venv" true
}

# Create mock dependency files for testing
create_mock_dependency_file() {
	local file_type="$1"
	case "$file_type" in
	"pyproject")
		cat >pyproject.toml <<EOF
[project]
name = "test-project"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest"]
EOF
		;;
	"requirements")
		echo "pytest" >requirements.txt
		;;
	"invalid")
		cat >pyproject.toml <<EOF
[project]
name = "invalid-project"
version = "0.1.0"
EOF
		;;
	esac
}

# Setup test environment for Python virtual environment testing
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/penv-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	source "$SCRIPT"

	setup_common_mocks

	PLATFORM="linux"
	PLATFORM_OS="linux"
	ZANGARMARSH_VERBOSE=true

	export TEST_DIR
	export PLATFORM
	export PLATFORM_OS
	export ZANGARMARSH_VERBOSE
}

# Clean up test environment
teardown() {
	cleanup_common_mocks
	rm -rf "$TEST_DIR"
}

@test "penv --help should display usage information" {
	run penv --help
	[[ "$status" -eq 0 ]]
}

@test "penv -h should display usage information" {
	run penv -h
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: penv"
}

@test "penv with unknown option should fail" {
	run penv --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
	echo "$output" | grep -q "Use 'penv --help'"
}

@test "penv:: fail with invalid Python version" {
	run penv python9.99
	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "python9.99 not found"
	echo "$output" | grep -q "Available Python versions:"
}

@test "penv:: use default python3 when no version specified" {
	# Mock python3 to succeed
	mock_command "python3" "Python 3.9.7"
	mock_command "python3 -m venv .venv" "Virtual environment created successfully"

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Using Python: python3"
}

@test "penv:: create virtual environment with default Python" {
	run penv
	[[ "$status" -eq 0 ]]
	[[ -d ".venv" ]]
	[[ -f ".venv/bin/activate" ]]
	echo "$output" | grep -q "Virtual environment setup complete"
}

@test "penv:: clean up cache files during creation" {
	mock_dir_exists "__pycache__" true
	mock_dir_exists ".mypy_cache" true
	mock_dir_exists ".pytest_cache" true
	mock_file_exists "test.pyc" true

	run penv
	[[ "$status" -eq 0 ]]

	mock_dir_exists "__pycache__" false
	mock_dir_exists ".mypy_cache" false
	mock_dir_exists ".pytest_cache" false
	mock_file_exists "test.pyc" false
}

@test "penv:: activate existing virtual environment" {
	setup_common_mocks

	mkdir -p .venv/bin
	touch .venv/bin/activate

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Virtual environment exists, activating"
	echo "$output" | grep -q "Activated existing environment"
}

@test "penv -d should force recreate virtual environment" {
	setup_common_mocks

	mkdir -p .venv
	touch .venv/test_file

	run penv -d
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	[[ ! -f ".venv/test_file" ]]
}

@test "penv --delete should force recreate virtual environment" {
	setup_common_mocks

	mkdir -p .venv
	touch .venv/test_file

	run penv --delete
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	[[ ! -f ".venv/test_file" ]]
}

@test "penv:: install dependencies from pyproject.toml" {
	mock_command "pip install -e ." "Requirement already satisfied: test-project in ./.venv/lib/python3.9/site-packages"

	create_mock_dependency_file "pyproject"
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found pyproject.toml. Installing with pip"
}

@test "penv:: install dependencies from requirements.txt" {
	mock_command "pip install -r requirements.txt" "Requirement already satisfied: pytest in ./.venv/lib/python3.9/site-packages"

	create_mock_dependency_file "requirements"
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found requirements.txt. Installing dependencies"
}

@test "penv:: handle missing dependency files gracefully" {
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "No dependency files found"
}

@test "penv:: show Python and pip versions in output" {
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Python version:"
	echo "$output" | grep -q "Pip version:"
}

@test "penv:: handle failed virtual environment creation" {
	# Mock python3 to fail
	python3() { return 1; }
	export -f python3

	run penv
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Failed to create virtual environment"
}

@test "penv:: handle failed virtual environment activation" {

	mkdir -p .venv/bin

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Virtual environment exists, activating"
	echo "$output" | grep -q "Creating virtual environment"
}

@test "penv:: preserve existing environment when no force flag" {
	setup_common_mocks

	# Create actual test directory ad files
	mkdir -p .venv/bin
	touch .venv/bin/activate
	touch .venv/original_file

	run penv
	[[ $status -eq 0 ]]
	[[ -f ".venv/original_file" ]]
}

@test "penv:: handle multiple flags correctly" {
	setup_common_mocks

	mkdir -p .venv
	touch .venv/test_file

	run penv -d --delete
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
}

@test "penv:: handle platform-specific behavior" {
	export PLATFORM="macos"
	export PLATFORM_OS="macos"
	# Mock python3 to fail
	python3() { return 1; }
	export -f python3

	run penv python9.99
	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "Try installing Python via Homebrew"
}
