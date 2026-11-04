#!/usr/bin/env bash
#
# File and directory I/O helpers for quest-log
#

# Show diff between current file and incoming changes
#
# Inputs:
# - $1, file_path, path to the file to compare
# - $2, new_content, the new content to compare against
#
# Side Effects:
# - Displays color-coded diff to terminal
# - Creates and removes a temporary file
#
# Returns:
# - 0 always when the temp file can be created
# - 1 when mktemp fails
show_diff() {
	local file_path="$1"
	local new_content="$2"
	local temp_file
	temp_file=$(mktemp) || {
		echo "show_diff:: Failed to create temporary file" >&2
		return 1
	}

	chmod 0600 "${temp_file}"
	trap 'rm -f -- "${temp_file}"; trap - RETURN' RETURN
	printf '%s' "${new_content}" >"${temp_file}"

	if [[ -f "${file_path}" ]]; then
		local diff_args=(-u)
		if diff -u --color=always /dev/null /dev/null >/dev/null 2>&1; then
			diff_args+=(--color=always)
		fi

		if ! diff "${diff_args[@]}" "${file_path}" "${temp_file}"; then
			echo "show_diff:: Differences found between ${file_path} and ${temp_file}"
		fi
	fi

	rm -f "${temp_file}"
	trap - RETURN

	return 0
}

# Ensure a directory exists
#
# Inputs:
# - $1, dir_path, directory to create
# - $2, label, prefix for error messages
#
# Returns:
# - 0 on success
# - 1 on failure
ensure_dir() {
	local dir_path="$1"
	local label="${2:-ensure_dir}"

	if [[ ! -d "${dir_path}" ]] && ! mkdir -p "${dir_path}"; then
		echo "${label}:: Failed to create directory: ${dir_path}" >&2
		return 1
	fi

	return 0
}

# Read file contents or empty string
#
# Inputs:
# - $1, file_path, path to read
#
# Outputs:
# - file contents to stdout
#
# Returns:
# - 0 always
read_file_or_empty() {
	local file_path="$1"

	if [[ -f "${file_path}" ]]; then
		cat "${file_path}" 2>/dev/null
	fi

	return 0
}

# Write content if it differs from the file on disk
#
# Inputs:
# - $1, file_path, destination path
# - $2, new_content, full new file body
# - $3, error_label, prefix for write failure messages
#
# Side Effects:
# - Sets WRITE_IF_CHANGED_OUTCOME to unchanged, created, updated, or error
# - Writes file_path when content differs
#
# Returns:
# - 0 on success
# - 1 on write failure
write_if_changed() {
	local file_path="$1"
	local new_content="$2"
	local error_label="${3:-write_if_changed}"

	WRITE_IF_CHANGED_OUTCOME="error"

	local existing_content
	existing_content="$(
		read_file_or_empty "${file_path}"
		printf x
	)"
	existing_content="${existing_content%x}"

	local display_path="${file_path}"
	local display_dir
	if display_dir="$(cd "$(dirname "${file_path}")" 2>/dev/null && pwd -P)"; then
		display_path="${display_dir}/$(basename "${file_path}")"
	fi

	if [[ "${existing_content}" == "${new_content}" ]]; then
		echo "No changes: ${display_path}"
		WRITE_IF_CHANGED_OUTCOME="unchanged"
		return 0
	fi

	show_diff "${file_path}" "${new_content}"
	if ! printf '%s' "${new_content}" >"${file_path}"; then
		echo "${error_label}:: Failed to write file: ${display_path}" >&2
		return 1
	fi

	if [[ -n "${existing_content}" ]]; then
		WRITE_IF_CHANGED_OUTCOME="updated"
		echo "Updated: ${display_path}"
	else
		WRITE_IF_CHANGED_OUTCOME="created"
		echo "Created: ${display_path}"
	fi

	return 0
}
