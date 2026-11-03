#!/usr/bin/env bats
#
# Unit and integration tests for tool functions after sourcing zangarmarsh.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1
	SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
	export SCRIPT

	return 0
}

@test "tool_functions:: questlog is a function after bash source" {
	run bash -c "source '${SCRIPT}' && type questlog"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "questlog is a function"
}

@test "tool_functions:: bash source exports PLATFORM_OS" {
	run bash -c "source '${SCRIPT}' && printf '%s\n' \"\${PLATFORM_OS}\""
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "macos" || "${output}" == "linux" ]]
}

@test "tool_functions:: questlog --help works after bash and zsh source" {
	run bash -c "source '${SCRIPT}' && questlog --help"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"

	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local home
	home="$(mktemp -d "${base}/tool-functions-zsh.XXXXXX")" || return 1
	printf '\n' >"${home}/.zshrc"
	touch "${home}/.zcompdump"

	run env HOME="${home}" ZDOTDIR="${home}" ZSH="${home}/.oh-my-zsh" \
		zsh -c "source '${SCRIPT}' && questlog --help"
	local cmd_status="${status}"
	rm -rf "${home}"
	[[ "${cmd_status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"
}
