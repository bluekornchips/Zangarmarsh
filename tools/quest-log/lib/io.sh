#!/usr/bin/env bash
#
# File and directory I/O helpers for quest-log
#

source "${ZANGARMARSH_ROOT}/tools/lib/fs.sh"

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
	temp_file="$(mktemp "${TMPDIR:-/tmp}/zangarmarsh-diff.XXXXXX")" || {
		echo "show_diff:: Failed to create temporary file" >&2
		return 1
	}

	chmod 0600 "${temp_file}"
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

	rm -f -- "${temp_file}"

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
# - Sets WRITE_IF_CHANGED_OUTCOME from WRITE_ATOMIC_OUTCOME
# - Writes file_path when content differs
#
# Returns:
# - 0 on success
# - 1 on write failure
write_if_changed() {
	local file_path="$1"
	local new_content="$2"
	local error_label="${3:-write_if_changed}"

	if [[ "${DRY_RUN:-false}" != "true" ]]; then
		show_diff "${file_path}" "${new_content}"
	fi

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		write_atomic "${file_path}" "" "${error_label}" || {
			WRITE_IF_CHANGED_OUTCOME="error"
			return 1
		}
		WRITE_IF_CHANGED_OUTCOME="${WRITE_ATOMIC_OUTCOME}"
		return 0
	fi

	local parent
	parent="$(dirname "${file_path}")"
	ensure_dir "${parent}" "${error_label}" || return 1

	local stage
	stage="$(mktemp "${parent}/.zangarmarsh.XXXXXX")" || {
		echo "${error_label}:: Failed to create staging file" >&2
		WRITE_IF_CHANGED_OUTCOME="error"
		return 1
	}

	if ! printf '%s' "${new_content}" >"${stage}"; then
		rm -f -- "${stage}"
		echo "${error_label}:: Failed to stage content" >&2
		WRITE_IF_CHANGED_OUTCOME="error"
		return 1
	fi

	write_atomic "${file_path}" "${stage}" "${error_label}" || {
		rm -f -- "${stage}"
		WRITE_IF_CHANGED_OUTCOME="error"
		return 1
	}

	rm -f -- "${stage}"
	WRITE_IF_CHANGED_OUTCOME="${WRITE_ATOMIC_OUTCOME}"

	return 0
}
