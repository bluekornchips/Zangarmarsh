#!/usr/bin/env bash
#
# Arcane Linguist - Simple ZSH Command Parser
# Takes input, processes spells, returns output
#
set -euo pipefail

# Parse a single command line
parse_command() {
	local line="$1"

	# Handle zsh history format: ': timestamp:duration;command'
	if [[ "$line" =~ ^:[[:space:]]*[0-9]+:[0-9]*\;(.*)$ ]]; then
		echo "${BASH_REMATCH[1]}"
	elif [[ "$line" =~ ^[^:] ]]; then
		echo "$line"
	fi
}

# Main - read stdin, parse each line, output to stdout
# Only run if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	while IFS= read -r line; do
		[[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
		parsed=$(parse_command "$line")
		[[ -n "$parsed" ]] && echo "$parsed"
	done
fi
