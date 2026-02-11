#!/usr/bin/env bash

# Zangarmarsh shell configuration loader
# This script should be sourced, not executed

# Set the project root to the directory containing this script
if [[ -n "${BASH_SOURCE[0]}" ]]; then
	SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [[ -n "${0}" ]]; then
	SCRIPT_PATH="${0}"
else
	SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
fi

ZANGARMARSH_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
export ZANGARMARSH_ROOT

# Common configuration files to load
COMMON_FILES=(
	"aliases.sh"
	"functions.sh"
)

# Load common shell configuration components from profile directory
load_common_components() {
	local file
	local file_path

	for file in "${COMMON_FILES[@]}"; do
		file_path="$ZANGARMARSH_ROOT/profile/$file"
		if [[ -f "$file_path" ]]; then

			source "$file_path" 2>/dev/null || {
				[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Failed to source $file_path" >&2
			}
		fi
	done
}
load_common_components

SHELL_NAME=$(ps -p "$$" -o comm= 2>/dev/null | tail -1)
[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Shell detection: ZSH_VERSION='${ZSH_VERSION:-}', BASH_VERSION='${BASH_VERSION:-}', SHELL_NAME='$SHELL_NAME'" >&2
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL_NAME" == *zsh ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Sourcing profile/zsh/profile.sh" >&2

	source "$ZANGARMARSH_ROOT/profile/zsh/profile.sh"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL_NAME" == *bash ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Loading bash components" >&2
	source "$ZANGARMARSH_ROOT/profile/bash/profile.sh"
else
	echo "Unsupported shell: $SHELL" >&2
fi
