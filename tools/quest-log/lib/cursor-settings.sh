#!/usr/bin/env bash
#
# Cursor user settings path and overwrite helpers for quest-log
#

source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/io.sh"

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
# - 1 when HOME is empty or platform detection fails
cursor_user_settings_path() {
	if [[ -z "${HOME:-}" ]]; then
		echo "cursor_user_settings_path:: HOME is required" >&2
		return 1
	fi

	# Detect for this call only. Do not reuse sticky PLATFORM from the profile;
	# settings path must follow the host OS seen now.
	local platform_id
	platform_id="$(_detect_platform)" || return 1
	local platform_os
	platform_os="$(platform_os_from_id "${platform_id}")" || return 1

	if [[ "${platform_os}" == "macos" ]]; then
		printf '%s\n' "${HOME}/Library/Application Support/Cursor/User/settings.json"
	else
		printf '%s\n' "${HOME}/.config/Cursor/User/settings.json"
	fi

	return 0
}

# Write the tracked Cursor settings template over the host Cursor user settings
#
# Reads environment:
# - ZANGARMARSH_ROOT, template at tools/vscode/settings.json
# - HOME, used to resolve the settings path
# - DRY_RUN, when true report without writing
#
# Side Effects:
# - Replaces the host Cursor User/settings.json when its content differs
#
# Returns:
# - 0 on success, including dry-run and unchanged content
# - 1 when the template cannot be read or the write fails
sync_cursor_user_settings() {
	local settings_file
	settings_file="$(cursor_user_settings_path)" || return 1

	local new_content
	new_content="$(cat "${ZANGARMARSH_ROOT}/tools/vscode/settings.json")" || return 1
	write_if_changed "${settings_file}" "${new_content}"$'\n' "sync_cursor_user_settings" || return 1

	return 0
}
