#!/usr/bin/env bash
#
# Sync VSCode settings from the Zangarmarsh repo into a target project directory
#

# Copy .vscode template files into a destination project
#
# Inputs:
# - $1 zangarmarsh_root, source repository root
# - $2 dest_root, destination project root
#
# Side Effects:
# - Writes files under ${dest_root}/.vscode
#
# Returns:
# - 0 on success
# - 1 when copy fails
copy_vscode_template() {
	local zangarmarsh_root="$1"
	local dest_root="$2"

	if [[ -z "${zangarmarsh_root}" || -z "${dest_root}" ]]; then
		echo "copy_vscode_template:: zangarmarsh_root and dest_root are required" >&2
		return 1
	fi

	if ! cp -rf "${zangarmarsh_root}/.vscode/"* "${dest_root}/.vscode/" 2>/dev/null; then
		echo "copy_vscode_template:: Failed to copy VSCode settings" >&2
		return 1
	fi

	return 0
}

# Copy .vscode from Zangarmarsh into GIT_ROOT when they differ
#
# Inputs:
# - $1 zangarmarsh_root, optional source repository root
#
# Reads environment:
# - GIT_ROOT, destination project directory, usually the current git root
# - FORCE, when true replace existing settings in the destination
# - ZANGARMARSH_ROOT, used when zangarmarsh_root argument is empty
#
# Side Effects:
# - Creates or updates ${GIT_ROOT}/.vscode from the Zangarmarsh template
#
# Returns:
# - 0 on success
# - 1 when GIT_ROOT is unset, source is missing, or copy fails
vscodeoverride() {
	local zangarmarsh_root="${1:-${ZANGARMARSH_ROOT:-}}"

	if [[ -z "${GIT_ROOT:-}" ]]; then
		echo "vscodeoverride:: GIT_ROOT is not set" >&2
		return 1
	fi

	if [[ -z "${zangarmarsh_root}" ]]; then
		if ! zangarmarsh_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" 2>/dev/null; then
			echo "vscodeoverride:: could not resolve Zangarmarsh root" >&2
			return 1
		fi
	fi

	echo "vscodeoverride: running"

	if [[ ! -d "${zangarmarsh_root}/.vscode" ]]; then
		echo "vscodeoverride:: VSCode settings directory not found in ${zangarmarsh_root}/.vscode" >&2
		return 1
	fi

	if [[ "${GIT_ROOT}" == "${zangarmarsh_root}" ]]; then
		echo "vscodeoverride: complete"
		return 0
	fi

	mkdir -p "${GIT_ROOT}/.vscode"

	if [[ "${FORCE:-}" = "true" ]]; then
		if ! copy_vscode_template "${zangarmarsh_root}" "${GIT_ROOT}"; then
			return 1
		fi
	elif [[ ! "$(ls -A "${GIT_ROOT}/.vscode" 2>/dev/null)" ]]; then
		if ! copy_vscode_template "${zangarmarsh_root}" "${GIT_ROOT}"; then
			return 1
		fi
	else
		echo "vscodeoverride: existing settings kept, use FORCE=true to replace"
	fi

	echo "vscodeoverride: complete"

	return 0
}
