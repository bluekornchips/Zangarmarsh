#!/usr/bin/env bash
#
# Sync VSCode settings from the Zangarmarsh repo into a target project directory
#
# Requires write_if_changed and the STATS_* counters from
# tools/quest-log/lib/io.sh, already sourced by the caller before this file.
#

# Copy .vscode template files into a destination project, reporting diffs
#
# Inputs:
# - $1 zangarmarsh_root, source repository root
# - $2 dest_root, destination project root
#
# Side Effects:
# - Writes files under ${dest_root}/.vscode
# - Prints a diff and updates STATS_* counters for each file via write_if_changed
#
# Returns:
# - 0 on success
# - 1 when a template file cannot be read or written
copy_vscode_template() {
	local zangarmarsh_root="$1"
	local dest_root="$2"

	if [[ -z "${zangarmarsh_root}" || -z "${dest_root}" ]]; then
		echo "copy_vscode_template:: zangarmarsh_root and dest_root are required" >&2
		return 1
	fi

	local template_file
	while IFS= read -r -d '' template_file; do
		local file_name
		file_name="$(basename "${template_file}")"

		local new_content
		if ! new_content="$(cat "${template_file}")"; then
			echo "copy_vscode_template:: Failed to read ${template_file}" >&2
			return 1
		fi

		if ! write_if_changed "${dest_root}/.vscode/${file_name}" "${new_content}" "rule" "copy_vscode_template"; then
			return 1
		fi
	done < <(find "${zangarmarsh_root}/.vscode" -maxdepth 1 -type f -print0)

	return 0
}

# Copy .vscode from Zangarmarsh into GIT_ROOT
#
# Inputs:
# - $1 zangarmarsh_root, optional source repository root
#
# Reads environment:
# - GIT_ROOT, destination project directory, usually the current git root
# - ZANGARMARSH_ROOT, used when zangarmarsh_root argument is empty
#
# Side Effects:
# - Creates ${GIT_ROOT}/.vscode from the Zangarmarsh template, file by file
#
# Returns:
# - 0 on success
# - 1 when GIT_ROOT is unset, source is missing, or a file write fails
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

	if ! ensure_dir "${GIT_ROOT}/.vscode" "vscodeoverride"; then
		return 1
	fi

	if ! copy_vscode_template "${zangarmarsh_root}" "${GIT_ROOT}"; then
		return 1
	fi

	echo "vscodeoverride: complete"

	return 0
}
