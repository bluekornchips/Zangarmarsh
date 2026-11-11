#!/usr/bin/env bash

# Zangarmarsh shell configuration loader
# Source from an interactive Bash or Zsh session only. Do not execute.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	echo "zangarmarsh:: source this file instead of executing it" >&2
	exit 1
fi

if [[ -n "${ZSH_VERSION:-}" ]]; then
	case "${ZSH_EVAL_CONTEXT:-}" in
	*:file*) ;;
	*)
		echo "zangarmarsh:: source this file instead of executing it" >&2
		exit 1
		;;
	esac
fi

# Interactive shells only. Bats sets ZANGARMARSH_TEST=1 so tests can source
# under bash -c / zsh -c without faking a TTY or job control.
if [[ "${ZANGARMARSH_TEST:-}" != "1" ]]; then
	if [[ -n "${BASH_VERSION:-}" ]]; then
		if [[ "$-" != *i* ]]; then
			echo "zangarmarsh:: interactive shell required" >&2
			return 1
		fi
	elif [[ -n "${ZSH_VERSION:-}" ]]; then
		if [[ ! -o interactive ]]; then
			echo "zangarmarsh:: interactive shell required" >&2
			return 1
		fi
	fi
fi

# Resolve the root from this file. An inherited ZANGARMARSH_ROOT must not
# point a sourced copy at another checkout.
ZANGARMARSH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export ZANGARMARSH_ROOT

source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
if ! apply_platform_env; then
	echo "zangarmarsh:: Failed to detect platform" >&2
	return 1
fi

COMMON_FILES=(
	"config.sh"
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
		local component="${ZANGARMARSH_ROOT}/profile/${file}"
		if [[ ! -f "${component}" ]]; then
			echo "load_common_components:: Required file not found: ${component}" >&2
			return 1
		fi

		source "${component}" || {
			echo "load_common_components:: Failed to source ${component}" >&2
			return 1
		}
	done

	return 0
}

if ! load_common_components; then
	echo "zangarmarsh:: Failed to load common components" >&2
	return 1
fi

source "${ZANGARMARSH_ROOT}/tools/tools.sh" || {
	echo "zangarmarsh:: Failed to source tools/tools.sh" >&2
	return 1
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
	source "${ZANGARMARSH_ROOT}/profile/zsh/profile.zsh" || return 1
elif [[ -n "${BASH_VERSION:-}" ]]; then
	source "${ZANGARMARSH_ROOT}/profile/bash/profile.sh" || return 1
else
	echo "zangarmarsh:: Unsupported shell" >&2
	return 1
fi
