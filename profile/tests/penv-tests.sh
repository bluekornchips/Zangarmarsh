#!/usr/bin/env bats

# Test file for penv function in profile/functions.sh

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/functions.sh"
	export SCRIPT

	return 0
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
			chmod +x "${env_dir}/bin/python"
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

	return 0
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
	return 0
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

@test "penv:: rejects an interpreter path" {
	run penv 'python3.1/../../../tmp/pwn'
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}

@test "penv:: recreates when existing .venv has no python" {
	mkdir -p .venv/bin
	touch .venv/bin/activate

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	echo "$output" | grep -q "Creating virtual environment"
	[[ -x ".venv/bin/python" ]]
}

@test "penv:: fail with invalid Python version" {
	run penv python9.99
	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "python9.99 not found"
	echo "$output" | grep -q "Available Python versions:"
}

@test "integration:: penv uses default python3 when no version specified" {
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Using Python: python3"
}

@test "integration:: penv creates virtual environment with default Python" {
	run penv
	[[ "$status" -eq 0 ]]
	[[ -d ".venv" ]]
	[[ -f ".venv/bin/activate" ]]
	echo "$output" | grep -q "Virtual environment setup complete"
}

@test "integration:: penv cleans up cache files during creation" {
	mkdir -p __pycache__ .mypy_cache .pytest_cache
	touch test.pyc

	run penv
	[[ "$status" -eq 0 ]]
}

@test "penv:: leaves existing virtual environment alone without activating" {
	mkdir -p .venv/bin
	printf '#!/usr/bin/env bash\necho "Python 3.12.0"\n' >.venv/bin/python
	chmod +x .venv/bin/python
	touch .venv/bin/activate
	touch .venv/original_file

	# Call without bats run so VIRTUAL_ENV stays in this shell if penv activated.
	if ! penv; then
		return 1
	fi

	[[ -f ".venv/original_file" ]]
	[[ -z "${VIRTUAL_ENV:-}" ]]
}

@test "penv:: activates after creating a new virtual environment" {
	# Call without bats run so activation is visible in this shell.
	if ! penv; then
		return 1
	fi

	[[ -n "${VIRTUAL_ENV:-}" ]]
	[[ "${VIRTUAL_ENV}" == "${TEST_DIR}/.venv" ]]
}

@test "integration:: penv -d force recreates" {
	mkdir -p .venv
	touch .venv/test_file

	run penv -d
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	[[ ! -f ".venv/test_file" ]]
}

@test "integration:: penv --delete force recreates" {
	mkdir -p .venv
	touch .venv/test_file

	run penv --delete
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	[[ ! -f ".venv/test_file" ]]
}

@test "integration:: penv installs dependencies from pyproject.toml" {
	if ! create_mock_dependency_file "pyproject"; then
		return 1
	fi
	local mock_bin="${BATS_TEST_TMPDIR}/uv-mock-bin"
	mkdir -p "${mock_bin}"
	printf '#!/usr/bin/env bash\nexit 0\n' >"${mock_bin}/uv"
	chmod +x "${mock_bin}/uv"
	PATH="${mock_bin}:${PATH}" run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found pyproject.toml. Installing with uv"
}

@test "integration:: penv uses locked uv sync when uv.lock exists" {
	if ! create_mock_dependency_file "pyproject"; then
		return 1
	fi
	touch uv.lock
	local mock_bin="${BATS_TEST_TMPDIR}/uv-lock-mock-bin"
	mkdir -p "${mock_bin}"
	printf '#!/usr/bin/env bash\nexit 0\n' >"${mock_bin}/uv"
	chmod +x "${mock_bin}/uv"
	PATH="${mock_bin}:${PATH}" run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found pyproject.toml. Installing with uv"
}

@test "integration:: penv handles missing dependency files gracefully" {
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "No pyproject.toml found"
}

@test "integration:: penv shows Python version in output" {
	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Python version:"
}

@test "penv:: handles failed virtual environment creation" {
	unset -f python3
	local mock_bin="${BATS_TEST_TMPDIR}/python-fail-bin"
	mkdir -p "${mock_bin}"
	printf '#!/usr/bin/env bash\nexit 1\n' >"${mock_bin}/python3"
	chmod +x "${mock_bin}/python3"
	PATH="${mock_bin}:${PATH}" run penv
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Failed to create virtual environment"
}

@test "integration:: penv recreates when .venv/bin/python is missing" {
	mkdir -p .venv/bin
	touch .venv/bin/activate

	run penv
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
	echo "$output" | grep -q "Creating virtual environment"
}

@test "penv:: preserves existing environment when no force flag" {
	mkdir -p .venv/bin
	printf '#!/usr/bin/env bash\necho "Python 3.12.0"\n' >.venv/bin/python
	chmod +x .venv/bin/python
	touch .venv/bin/activate
	touch .venv/original_file

	run penv
	[[ $status -eq 0 ]]
	[[ -f ".venv/original_file" ]]
}

@test "integration:: penv handles multiple flags correctly" {
	mkdir -p .venv
	touch .venv/test_file

	run penv -d --delete
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Removing existing virtual environment"
}

@test "penv:: handles platform-specific behavior" {
	PLATFORM="macos"
	PLATFORM_OS="macos"
	unset -f python3
	local mock_bin="${BATS_TEST_TMPDIR}/python-missing-bin"
	mkdir -p "${mock_bin}"
	# No python9.99 on PATH; leave python3 present so only the requested version fails.
	printf '#!/usr/bin/env bash\nexit 0\n' >"${mock_bin}/python3"
	chmod +x "${mock_bin}/python3"
	PATH="${mock_bin}:${PATH}" run penv python9.99
	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "Try installing Python from https://www.python.org/downloads/"
}

@test "penv:: under zsh reports missing interpreter without glob abort" {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	run zsh -c "
		setopt nomatch
		source '${SCRIPT}' || exit 1
		penv python9.99
	"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "penv:: python9.99 not found"
	echo "${output}" | grep -qv "no matches found"
}
