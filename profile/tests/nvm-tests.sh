#!/usr/bin/env bats
#
# Unit tests for the lazy nvm loader in profile/functions.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/functions.sh"
	export SCRIPT

	return 0
}

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/nvm-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	HOME="${TEST_DIR}"
	export HOME
	NVM_DIR="${HOME}/.nvm"
	export NVM_DIR
	ZANGARMARSH_LAZY_LOADING=true
	export ZANGARMARSH_LAZY_LOADING
	ZANGARMARSH_ENABLE_NVM=true
	export ZANGARMARSH_ENABLE_NVM

	source "${SCRIPT}"

	return 0
}

teardown() {
	rm -rf "${TEST_DIR}"
	return 0
}

@test "nvm:: registers a lazy loader function" {
	run declare -f nvm
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "_nvm_load"
}

@test "nvm:: fails when nvm.sh is missing" {
	run nvm --help
	[[ "${status}" -ne 0 ]]
	echo "${output}" | grep -q "NVM not found"
}

@test "nvm:: loads a stub nvm.sh and forwards arguments" {
	mkdir -p "${NVM_DIR}"
	cat >"${NVM_DIR}/nvm.sh" <<'EOF'
nvm() {
	printf 'stub-nvm:%s\n' "$*"
}
EOF

	run nvm --version
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "stub-nvm:--version"
}
