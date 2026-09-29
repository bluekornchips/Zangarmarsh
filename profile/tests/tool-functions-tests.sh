#!/usr/bin/env bats
#
# Tool functions after sourcing zangarmarsh.sh
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
	export SCRIPT

	return 0
}

@test "tool_functions:: questlog is a function after a non-interactive bash source" {
	run bash -c "source '${SCRIPT}' && type questlog"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "questlog is a function"
}

@test "tool_functions:: questlog --help works after a non-interactive bash source" {
	run bash -c "source '${SCRIPT}' && questlog --help"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
}

@test "tool_functions:: questlog --help works after a non-interactive zsh source" {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	run zsh -c "source '${SCRIPT}' && questlog --help"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
}

@test "tool_functions:: bash source exports PLATFORM_OS" {
	run bash -c "source '${SCRIPT}' && printf '%s\n' \"\${PLATFORM_OS}\""
	[[ "$status" -eq 0 ]]
	[[ "$output" == "macos" || "$output" == "linux" ]]
}
