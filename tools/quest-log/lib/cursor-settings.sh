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

# Overwrite host Cursor user settings from tools/vscode/settings.json
#
# Reads environment:
# - ZANGARMARSH_ROOT, HOME, DRY_RUN
#
# Side Effects:
# - Replaces the host Cursor User/settings.json with the template
# - Updates STATS_CREATED, STATS_UPDATED, STATS_UNCHANGED, or STATS_ERRORS
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

	local settings_file
	settings_file="$(cursor_user_settings_path)" || return 1

	if [[ "${DRY_RUN:-}" == "true" ]]; then
		echo "sync_cursor_user_settings:: would overwrite ${settings_file}"
		return 0
	fi

	ensure_dir "$(dirname "${settings_file}")" "sync_cursor_user_settings" || return 1

	local new_content
	new_content="$(cat "${template}")" || return 1
	echo "sync_cursor_user_settings:: writing ${settings_file}"
	write_if_changed "${settings_file}" "${new_content}"$'\n' "sync_cursor_user_settings" || {
		STATS_ERRORS=$((STATS_ERRORS + 1))
		return 1
	}

	case "${WRITE_IF_CHANGED_OUTCOME:-}" in
	unchanged)
		STATS_UNCHANGED=$((STATS_UNCHANGED + 1))
		;;
	created)
		STATS_CREATED=$((STATS_CREATED + 1))
		;;
	updated)
		STATS_UPDATED=$((STATS_UPDATED + 1))
		;;
	esac

	return 0
}
