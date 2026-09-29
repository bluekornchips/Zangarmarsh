#!/usr/bin/env bash
#
# Locate the Zangarmarsh repository for loaders and standalone tools
#
# From a tool under tools/<name>/:
#   tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${tool_dir}/../lib/repo.sh"
#   ensure_zangarmarsh_repo "${tool_dir}"
#
# From profile/:
#   profile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${profile_dir}/../tools/lib/repo.sh"
#   ensure_zangarmarsh_repo "${profile_dir}"
#

# Resolve the absolute directory that contains a file, or the directory itself
#
# Inputs:
# - $1 path, file or directory
#
# Outputs:
# - Absolute directory path on stdout
#
# Returns:
# - 0 on success
# - 1 when the path cannot be resolved
absolute_dir_of() {
	local path="${1:-}"

	if [[ -z "${path}" ]]; then
		echo "absolute_dir_of:: path is required" >&2
		return 1
	fi

	if [[ -f "${path}" ]]; then
		cd "$(dirname "${path}")" && pwd
		return $?
	fi

	if [[ -d "${path}" ]]; then
		cd "${path}" && pwd
		return $?
	fi

	echo "absolute_dir_of:: path not found: ${path}" >&2
	return 1
}

# Find the repository directory that contains zangarmarsh.sh
#
# Inputs:
# - $1 start_path, file or directory to walk upward from when ZANGARMARSH_ROOT is unset
#
# Reads environment:
# - ZANGARMARSH_ROOT, reused when it already points at zangarmarsh.sh
#
# Outputs:
# - Absolute repository path on stdout
#
# Returns:
# - 0 when the repository is found
# - 1 when the start path is missing or zangarmarsh.sh cannot be found
resolve_zangarmarsh_repo() {
	local start_path="${1:-}"
	local current

	if [[ -n "${ZANGARMARSH_ROOT:-}" && -f "${ZANGARMARSH_ROOT}/zangarmarsh.sh" ]]; then
		printf '%s\n' "${ZANGARMARSH_ROOT}"
		return 0
	fi

	if [[ -z "${start_path}" ]]; then
		echo "resolve_zangarmarsh_repo:: start path is required when ZANGARMARSH_ROOT is unset" >&2
		return 1
	fi

	current="$(absolute_dir_of "${start_path}")" || return 1

	while [[ -n "${current}" && "${current}" != "/" ]]; do
		if [[ -f "${current}/zangarmarsh.sh" ]]; then
			printf '%s\n' "${current}"
			return 0
		fi

		current="$(cd "${current}/.." && pwd)" || {
			echo "resolve_zangarmarsh_repo:: failed walking parents of ${start_path}" >&2
			return 1
		}
	done

	echo "resolve_zangarmarsh_repo:: zangarmarsh.sh not found above ${start_path}" >&2

	return 1
}

# Set and export ZANGARMARSH_ROOT from an existing value or a start path
#
# Inputs:
# - $1 start_path, file or directory used when ZANGARMARSH_ROOT is unset
#
# Side Effects:
# - Exports ZANGARMARSH_ROOT to the located repository path
#
# Returns:
# - 0 on success
# - 1 when the repository cannot be resolved
ensure_zangarmarsh_repo() {
	local start_path="${1:-}"
	local repo

	repo="$(resolve_zangarmarsh_repo "${start_path}")" || return 1
	ZANGARMARSH_ROOT="${repo}"
	export ZANGARMARSH_ROOT

	return 0
}
