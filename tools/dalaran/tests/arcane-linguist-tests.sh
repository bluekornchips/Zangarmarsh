#!/usr/bin/env bats
#
# Test suite for arcane-linguist.sh using Bats
#

GIT_ROOT=$(git rev-parse --show-toplevel)
SCRIPT="$GIT_ROOT/tools/dalaran/arcane-linguist.sh"
[[ ! -f "${SCRIPT}" ]] && echo "Could not find arcane-linguist.sh script" >&2 && exit 1

########################################################
# script validation
########################################################
@test "script exists and is executable" {
	[[ -f "${SCRIPT}" ]]
	[[ -x "${SCRIPT}" ]]
}

@test "script should load successfully" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

########################################################
# basic parsing functionality
########################################################
@test "parse_commands:: handles zsh timestamped format" {
	run bash -c 'echo ": 1753921629:0;git status" | '"$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "git status" ]]
}

@test "parse_commands:: handles plain commands" {
	run bash -c 'echo "git status" | '"$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "git status" ]]
}

@test "parse_commands:: handles empty input" {
	run bash -c 'echo "" | '"$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "parse_commands:: skips empty lines" {
	run bash -c 'echo -e "\n   \n: 1753921629:0;git status\n\n" | '"$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "git status" ]]
}

@test "parse_commands:: handles complex commands" {
	run bash -c 'echo ": 1753921629:0;eval \"\$(ssh-agent)\"" | '"$SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$output" == 'eval "$(ssh-agent)"' ]]
}

########################################################
# Real world tests
########################################################
@test "parse_commands:: can parse actual zsh history successfully" {
	local history_file="$HOME/.zsh_history"

	[[ ! -f "$history_file" ]] && skip "No zsh history file found"

	echo "Reading history file: $history_file" >&3
	echo "Total commands found in history file: $(wc -l <"$history_file")" >&3

	failed_commands=0
	while IFS= read -r line; do
		run bash -c 'echo "$line" | '"$SCRIPT"
		[[ "$status" -eq 0 ]]
		if [[ "$status" -ne 0 ]]; then
			failed_commands=$((failed_commands + 1))
		fi
	done <"$history_file"

	echo "Failed commands: $failed_commands" >&3

	[[ "$failed_commands" -eq 0 ]]
	echo "All commands parsed successfully" >&3
}
