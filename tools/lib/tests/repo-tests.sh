#!/usr/bin/env bats
#
# Tests for tools/lib/repo.sh
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	SCRIPT="${ZANGARMARSH_ROOT}/tools/lib/repo.sh"
	export SCRIPT

	return 0
}

setup() {
	source "${SCRIPT}"

	return 0
}

@test "absolute_dir_of:: resolves a file to its parent directory" {
	run absolute_dir_of "${SCRIPT}"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${ZANGARMARSH_ROOT}/tools/lib" ]]
}

@test "absolute_dir_of:: resolves a directory to itself" {
	run absolute_dir_of "${ZANGARMARSH_ROOT}/tools/lib"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${ZANGARMARSH_ROOT}/tools/lib" ]]
}

@test "resolve_zangarmarsh_repo:: reuses a valid ZANGARMARSH_ROOT" {
	run resolve_zangarmarsh_repo
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${ZANGARMARSH_ROOT}" ]]
}

@test "resolve_zangarmarsh_repo:: walks up from a tool script" {
	unset ZANGARMARSH_ROOT

	run resolve_zangarmarsh_repo "${SCRIPT}"
	[[ "$status" -eq 0 ]]
	[[ -f "${output}/zangarmarsh.sh" ]]
}

@test "resolve_zangarmarsh_repo:: fails when start path is missing and env is unset" {
	unset ZANGARMARSH_ROOT

	run resolve_zangarmarsh_repo
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "start path is required"
}

@test "ensure_zangarmarsh_repo:: exports ZANGARMARSH_ROOT" {
	unset ZANGARMARSH_ROOT
	ensure_zangarmarsh_repo "${SCRIPT}"
	[[ -n "${ZANGARMARSH_ROOT}" ]]
	[[ -f "${ZANGARMARSH_ROOT}/zangarmarsh.sh" ]]
}
