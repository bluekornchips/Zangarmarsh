#!/usr/bin/env bash
#
# Cursor user settings path and overwrite helpers for quest-log
#

# Resolve the host Cursor user settings path
#
# Reads environment:
# - HOME
#
# Outputs:
# - Absolute settings.json path on stdout
#
# Returns:
# - 0 on success
# - 1 when HOME is empty
cursor_user_settings_path() {
	if [[ -z "${HOME:-}" ]]; then
		echo "cursor_user_settings_path:: HOME is required" >&2
		return 1
	fi

	if [[ "$(uname -s)" == "Darwin" ]]; then
		printf '%s\n' "${HOME}/Library/Application Support/Cursor/User/settings.json"
	else
		printf '%s\n' "${HOME}/.config/Cursor/User/settings.json"
	fi

	return 0
}

# Overwrite host Cursor user settings from tools/vscode/settings.json
#
# Reads environment:
# - ZANGARMARSH_ROOT, HOME, DRY_RUN
#
# Side Effects:
# - Replaces the host Cursor User/settings.json with the template
#
# Returns:
# - 0 on success
# - 1 when the template cannot be read or settings cannot be written
sync_cursor_user_settings() {
	local template="${ZANGARMARSH_ROOT}/tools/vscode/settings.json"

	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "sync_cursor_user_settings:: ZANGARMARSH_ROOT is required" >&2
		return 1
	fi

	if [[ -z "${HOME:-}" ]]; then
		echo "sync_cursor_user_settings:: HOME is required" >&2
		return 1
	fi

	if [[ ! -f "${template}" ]]; then
		echo "sync_cursor_user_settings:: template not found: ${template}" >&2
		return 1
	fi

	local settings_file
	settings_file="$(cursor_user_settings_path)" || return 1

	if [[ "${DRY_RUN:-false}" == true ]]; then
		echo "sync_cursor_user_settings:: would overwrite ${settings_file}"
		return 0
	fi

	ensure_dir "$(dirname "${settings_file}")" "sync_cursor_user_settings" || return 1

	local new_content
	new_content="$(cat "${template}")" || return 1
	echo "sync_cursor_user_settings:: writing ${settings_file}"
	write_if_changed "${settings_file}" "${new_content}"$'\n' "rule" "sync_cursor_user_settings" || return 1

	return 0
}
