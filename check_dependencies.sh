#!/usr/bin/env bash
#
# Verify local tools required by Makefile format, lint, syntax, shellcheck, and test targets.
#

REQUIRED_COMMANDS=(bash bats jq shellcheck shfmt zsh)

# Confirm each entry in REQUIRED_COMMANDS exists on PATH
#
# Side Effects:
# - Writes a missing-dependency message to stderr when any command is absent
#
# Returns:
# - 0 when every required command exists
# - 1 when REQUIRED_COMMANDS is empty or any command is missing
check_dependencies() {
	if [[ "${#REQUIRED_COMMANDS[@]}" -eq 0 ]]; then
		echo "check_dependencies:: REQUIRED_COMMANDS is empty" >&2
		return 1
	fi

	local missing=()
	local cmd
	for cmd in "${REQUIRED_COMMANDS[@]}"; do
		if ! command -v "${cmd}" >/dev/null 2>&1; then
			missing+=("${cmd}")
		fi
	done

	if [[ "${#missing[@]}" -gt 0 ]]; then
		echo "check_dependencies:: missing: ${missing[*]}" >&2
		return 1
	fi

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	check_dependencies
	exit $?
fi
