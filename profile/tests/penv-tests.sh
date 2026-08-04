#!/usr/bin/env bats

# Test file for penv function in profile/functions.sh

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
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

# Stub python3 -m venv so tests do not pay real venv creation cost, which can be a lot on my lapto.
mock_fast_venv() {
	python3() {
		if [[ "${1:-}" == "-m" && "${2:-}" == "venv" ]]; then
			local env_dir="${3:-.venv}"
			mkdir -p "${env_dir}/bin"
			cat >"${env_dir}/bin/activate" <<'EOF'
VIRTUAL_ENV="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export VIRTUAL_ENV
PATH="${VIRTUAL_ENV}/bin:${PATH}"
export PATH
EOF
			printf '#!/usr/bin/env bash\necho "Python 3.12.0"\n' >"${env_dir}/bin/python"
			printf '#!/usr/bin/env bash\necho "pip 24.0 from fake"\n' >"${env_dir}/bin/pip"
			chmod +x "${env_dir}/bin/python" "${env_dir}/bin/pip"
			ln -sf python "${env_dir}/bin/python3"
			return 0
		fi
		command python3 "$@"
	}
	export -f python3
}

# Setup test environment for Python virtual environment testing
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/penv-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	source "$SCRIPT"
	mock_fast_venv

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
	rm -rf "$TEST_DIR"
}

@test "penv:: --help should display usage information" {
	run penv --help
	[[ "$status" -eq 0 ]]
}

@test "penv:: -h should display usage information" {
	run penv -h
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: penv"
}

@test "penv:: unknown option should fail" {
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
	mkdir -p __pycache__ .mypy_cache .pytest_cache
	touch test.pyc

	run penv
	[[ "$status" -eq 0 ]]
}

@test "penv:: activate existing virtual environment" {
	mkdir -p .venv/bin
	touch .venv/bin/activate

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Virtual environment exists, activating"
	echo "$output" | grep -q "Activated existing environment"
}

@test "penv:: -d should force recreate" {
	mkdir -p .venv
	touch .venv/test_file

	run penv -d
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	[[ ! -f ".venv/test_file" ]]
}

@test "penv:: --delete should force recreate" {
	mkdir -p .venv
	touch .venv/test_file

	run penv --delete
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	[[ ! -f ".venv/test_file" ]]
}

@test "penv:: install dependencies from pyproject.toml" {
	create_mock_dependency_file "pyproject"
	pip() { return 0; }
	export -f pip

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found pyproject.toml. Installing with pip"
}

@test "penv:: install dependencies from requirements.txt" {
	create_mock_dependency_file "requirements"
	pip() { return 0; }
	export -f pip

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
	# Create actual test directory and files
	mkdir -p .venv/bin
	touch .venv/bin/activate
	touch .venv/original_file

	run penv
	[[ $status -eq 0 ]]
	[[ -f ".venv/original_file" ]]
}

@test "penv:: handle multiple flags correctly" {
	mkdir -p .venv
	touch .venv/test_file

	run penv -d --delete
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
}

@test "penv:: handle platform-specific behavior" {
	PLATFORM="macos"
	export PLATFORM
	PLATFORM_OS="macos"
	export PLATFORM_OS
	# Mock python3 to fail
	python3() { return 1; }
	export -f python3

	run penv python9.99
	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "Try installing Python from https://www.python.org/downloads/"
}
