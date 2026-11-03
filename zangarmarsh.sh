#!/usr/bin/env bash

# Zangarmarsh shell configuration loader
# This script should be sourced, not executed

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	echo "zangarmarsh:: source this file instead of executing it" >&2
	exit 1
fi

if [[ -n "${ZSH_VERSION:-}" ]]; then
	case ${ZSH_EVAL_CONTEXT:-} in
	*:file*) ;;
	*)
		echo "zangarmarsh:: source this file instead of executing it" >&2
		exit 1
		;;
	esac
fi

if [[ -n "${BASH_SOURCE[0]}" ]]; then
	SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [[ -n "${0}" ]]; then
	SCRIPT_PATH="${0}"
else
	SCRIPT_PATH="$(cd "$(dirname "${0}")" && pwd)/$(basename "${0}")"
fi

# Always resolve from this file's location. An inherited ZANGARMARSH_ROOT from
# another tree would make a sourced copy keep the wrong root. Do not call
# ensure_zangarmarsh_repo here; that helper reuses a valid inherited root.
LOADER_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
ZANGARMARSH_ROOT="${LOADER_DIR}"
export ZANGARMARSH_ROOT

if [[ "${ZANGARMARSH_LOADED_ROOT:-}" == "${ZANGARMARSH_ROOT}" ]]; then
	return 0
fi

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
	for file in "${COMMON_FILES[@]}"; do
		if [[ ! -f "${ZANGARMARSH_ROOT}/profile/${file}" ]]; then
			echo "load_common_components:: Required file not found: ${ZANGARMARSH_ROOT}/profile/${file}" >&2
			return 1
		fi

		if ! source "${ZANGARMARSH_ROOT}/profile/${file}"; then
			echo "load_common_components:: Failed to source ${ZANGARMARSH_ROOT}/profile/${file}" >&2
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
	SHELL_NAME="$(ps -p "$$" -o comm= 2>/dev/null | tail -n 1 || true)"
	if [[ -z "${SHELL_NAME}" ]]; then
		SHELL_NAME="$(ps -p "$$" -o comm 2>/dev/null | tail -n 1 || true)"
	fi
fi

if [[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]]; then
	echo "Shell detection: ZSH_VERSION='${ZSH_VERSION:-}'" >&2
	echo "BASH_VERSION='${BASH_VERSION:-}', SHELL_NAME='${SHELL_NAME}'" >&2
fi

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL_NAME}" == *zsh* ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Sourcing profile/zsh/profile.zsh" >&2

	source "${ZANGARMARSH_ROOT}/profile/zsh/profile.zsh" || return 1
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL_NAME}" == *bash* ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Loading bash components" >&2
	source "${ZANGARMARSH_ROOT}/profile/bash/profile.sh" || return 1
else
	echo "zangarmarsh:: Unsupported shell: ${SHELL_NAME:-${SHELL:-unknown}}" >&2
	return 1
fi

ZANGARMARSH_LOADED_ROOT="${ZANGARMARSH_ROOT}"
