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
show_diff() {
	local file_path="$1"
	local new_content="$2"
	local temp_file
	temp_file=$(mktemp) || {
		echo "show_diff:: Failed to create temporary file" >&2
		return 1
	}

	trap 'rm -f "${temp_file}"' EXIT ERR
	chmod 0600 "${temp_file}"

	echo "${new_content}" >"${temp_file}"

	if [[ -f "${file_path}" ]]; then
		if ! diff -u --color=always "${file_path}" "${temp_file}"; then
			echo "show_diff:: Differences found between ${file_path} and ${temp_file}"
		fi
	fi

	rm -f "${temp_file}"
	trap - EXIT ERR

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
read_file_or_empty() {
	local file_path="$1"

	if [[ -f "${file_path}" ]]; then
		cat "${file_path}" 2>/dev/null || printf ''
	fi

	return 0
}

# Write content if it differs from the file on disk
#
# Inputs:
# - $1, file_path, destination path
# - $2, new_content, full new file body
# - $3, stats_mode, rule to update STATS for Cursor rules, none for Agent rules and commands
# - $4, error_label, prefix for write failure messages
#
# Returns:
# - 0 on success
# - 1 on write failure
write_if_changed() {
	local file_path="$1"
	local new_content="$2"
	local stats_mode="${3:-none}"
	local error_label="${4:-write_if_changed}"

	local existing_content
	existing_content=$(read_file_or_empty "${file_path}")

	local display_path
	display_path=$(realpath "${file_path}" 2>/dev/null || echo "${file_path}")

	if [[ "${existing_content}" == "${new_content}" ]]; then
		echo "No changes: ${display_path}"
		if [[ "${stats_mode}" == "rule" ]]; then
			STATS_UNCHANGED=$((STATS_UNCHANGED + 1))
		fi
		return 0
	fi

	show_diff "${file_path}" "${new_content}"
	echo "${new_content}" >"${file_path}"
	if [[ ! -f "${file_path}" ]]; then
		echo "${error_label}:: Failed to write file: ${display_path}" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		return 1
	fi

	if [[ "${stats_mode}" == "rule" ]]; then
		if [[ -n "${existing_content}" ]]; then
			echo "Updated: ${display_path}"
			STATS_UPDATED=$((STATS_UPDATED + 1))
		else
			echo "Created: ${display_path}"
			STATS_CREATED=$((STATS_CREATED + 1))
		fi
	else
		if [[ -n "${existing_content}" ]]; then
			echo "Updated: ${file_path}"
		else
			echo "Created: ${file_path}"
		fi
	fi

	return 0
}
