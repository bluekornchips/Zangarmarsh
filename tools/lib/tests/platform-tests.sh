#!/usr/bin/env bats
#
# Tests for tools/lib/platform.sh
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	SCRIPT="${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
	export SCRIPT

	return 0
}

setup() {
	unset PLATFORM
	unset PLATFORM_OS
	source "${SCRIPT}"

	return 0
}

@test "_detect_platform:: returns a canonical id" {

	run _detect_platform
	[[ "$status" -eq 0 ]]
	[[ "$output" == *-amd64 || "$output" == *-arm64 ]]
}

@test "platform_os_from_id:: maps darwin ids to macos" {

	run platform_os_from_id "darwin-arm64"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "macos" ]]
}

@test "platform_os_from_id:: maps linux ids to linux" {

	run platform_os_from_id "linux-amd64"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "linux" ]]
}

@test "apply_platform_env:: exports PLATFORM and PLATFORM_OS" {
	apply_platform_env
	[[ -n "${PLATFORM}" ]]
	[[ "${PLATFORM_OS}" == "macos" || "${PLATFORM_OS}" == "linux" ]]
}

@test "apply_platform_env:: preserves an existing PLATFORM_OS" {
	PLATFORM="linux-amd64"
	PLATFORM_OS="macos"
	export PLATFORM
	export PLATFORM_OS

	apply_platform_env
	[[ "${PLATFORM_OS}" == "macos" ]]
}
