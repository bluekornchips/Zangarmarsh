#!/usr/bin/env bash

# Zangarmarsh shell configuration loader
# This script should be sourced, not executed

if [[ -n "${BASH_SOURCE[0]}" ]]; then
	SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [[ -n "${0}" ]]; then
	SCRIPT_PATH="${0}"
else
	SCRIPT_PATH="$(cd "$(dirname "${0}")" && pwd)/$(basename "${0}")"
fi

# Always resolve from this file's location. An inherited ZANGARMARSH_ROOT from
# another tree would make a sourced copy keep the wrong root.
LOADER_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
source "${LOADER_DIR}/tools/lib/repo.sh"
ZANGARMARSH_ROOT="${LOADER_DIR}"
export ZANGARMARSH_ROOT

source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
if ! apply_platform_env; then
	echo "zangarmarsh:: Failed to detect platform" >&2
	return 1
fi

# Common configuration files to load
COMMON_FILES=(
	"aliases.sh"
	"functions.sh"
)

# Load common shell configuration components from profile directory
#
# Inputs:
# - Uses ZANGARMARSH_ROOT and COMMON_FILES
#
# Side Effects:
# - Sources each required file under profile listed in COMMON_FILES
#
# Returns:
# - 0 on success
# - 1 when a required file is missing or sourcing fails
load_common_components() {
	local file
	local file_path
	for file in "${COMMON_FILES[@]}"; do
		file_path="${ZANGARMARSH_ROOT}/profile/${file}"
		if [[ ! -f "${file_path}" ]]; then
			echo "load_common_components:: Required file not found: ${file_path}" >&2
			return 1
		fi

		if ! source "${file_path}"; then
			echo "load_common_components:: Failed to source ${file_path}" >&2
			return 1
		fi
	done

	return 0
}

if ! load_common_components; then
	echo "zangarmarsh:: Failed to load common components" >&2
	return 1
fi

SHELL_NAME=""
if [[ -z "${ZSH_VERSION:-}" && -z "${BASH_VERSION:-}" ]]; then
	SHELL_NAME=$(ps -p "$$" -o comm= 2>/dev/null | tail -1)
fi
if [[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]]; then
	echo "Shell detection: ZSH_VERSION='${ZSH_VERSION:-}'" >&2
	echo "BASH_VERSION='${BASH_VERSION:-}', SHELL_NAME='${SHELL_NAME}'" >&2
fi
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL_NAME}" == *zsh* ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Sourcing profile/zsh/profile.zsh" >&2

	source "${ZANGARMARSH_ROOT}/profile/zsh/profile.zsh"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL_NAME}" == *bash* ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Loading bash components" >&2
	source "${ZANGARMARSH_ROOT}/profile/bash/profile.sh"
else
	echo "zangarmarsh:: Unsupported shell: ${SHELL_NAME:-${SHELL:-unknown}}" >&2
	return 1
fi
