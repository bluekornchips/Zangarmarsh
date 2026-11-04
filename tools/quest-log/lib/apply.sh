#!/usr/bin/env bash
#
# Canonical quest-log apply path used by the CLI and profile installer
#

source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"
source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/cursor-settings.sh"

# Restore settings from an apply-time backup when settings sync fails
#
# Inputs:
# - $1 backup_root, temporary directory that may contain settings.json
# - $2 settings_file, live Cursor settings path
# - $3 had_settings, true when a settings file existed before apply
#
# Side Effects:
# - Restores or removes live Cursor settings
#
# Returns:
# - 0 when restore work succeeds
# - 1 when a restore write fails
_restore_quest_log_settings() {
	local backup_root="$1"
	local settings_file="$2"
	local had_settings="$3"

	if [[ "${had_settings}" == true && -f "${backup_root}/settings.json" ]]; then
		if ! mkdir -p "$(dirname "${settings_file}")" || ! cp "${backup_root}/settings.json" "${settings_file}"; then
			echo "_restore_quest_log_settings:: Failed to restore previous Cursor settings" >&2
			return 1
		fi

		return 0
	fi

	if [[ -e "${settings_file}" || -L "${settings_file}" ]]; then
		if ! rm -f -- "${settings_file}"; then
			echo "_restore_quest_log_settings:: Failed to remove incomplete Cursor settings" >&2
			return 1
		fi
	fi

	return 0
}

# Copy existing Cursor settings into the apply backup directory
#
# Inputs:
# - $1 backup_root, temporary directory created for this apply
# - $2 settings_file, live Cursor settings path that already exists
#
# Returns:
# - 0 when the settings file was backed up
# - 1 when the copy or permission change fails
_quest_log_backup_settings() {
	local backup_root="$1"
	local settings_file="$2"

	if ! cp "${settings_file}" "${backup_root}/settings.json"; then
		echo "apply_quest_log:: Failed to back up existing Cursor settings" >&2
		return 1
	fi

	chmod 0600 "${backup_root}/settings.json" || {
		echo "apply_quest_log:: Failed to harden Cursor settings backup permissions" >&2
		return 1
	}

	return 0
}

# Apply plugin install and/or Cursor settings overwrite
#
# Inputs:
# - --plugin-only, skip settings sync
# - --settings-only, skip plugin install
#
# Reads environment:
# - ZANGARMARSH_ROOT, HOME, DRY_RUN, PLUGIN_SOURCE_DIR
#
# Side Effects:
# - Overwrites Cursor user settings and/or installs the plugin
# - On settings failure, restores previous settings when a backup exists
# - Sets PLUGIN_ACTION to installed, dry-run, or skipped
#
# Returns:
# - 0 on success
# - 1 on validation, write, or restore failure
apply_quest_log() {
	local do_plugin=true
	local do_settings=true

	while (($# > 0)); do
		case "$1" in
		--plugin-only)
			do_settings=false
			shift
			;;
		--settings-only)
			do_plugin=false
			shift
			;;
		*)
			echo "apply_quest_log:: Unknown option: ${1}" >&2
			return 1
			;;
		esac
	done

	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "apply_quest_log:: ZANGARMARSH_ROOT is required" >&2
		return 1
	fi

	if [[ -z "${HOME:-}" ]]; then
		echo "apply_quest_log:: HOME is required" >&2
		return 1
	fi

	PLUGIN_SOURCE_DIR="${PLUGIN_SOURCE_DIR:-${ZANGARMARSH_ROOT}/tools/quest-log/plugin}"
	export PLUGIN_ACTION="skipped"

	if [[ "${do_plugin}" == true && ! -d "${PLUGIN_SOURCE_DIR}" ]]; then
		echo "apply_quest_log:: plugin source not found: ${PLUGIN_SOURCE_DIR}" >&2
		return 1
	fi

	if [[ "${do_settings}" == true && ! -f "${ZANGARMARSH_ROOT}/tools/vscode/settings.json" ]]; then
		echo "apply_quest_log:: template not found: ${ZANGARMARSH_ROOT}/tools/vscode/settings.json" >&2
		return 1
	fi

	local plugin_dir
	plugin_dir="$(quest_log_plugin_dir)" || return 1
	local settings_file
	settings_file="$(cursor_user_settings_path)" || return 1

	if [[ "${do_plugin}" == true ]]; then
		echo "apply_quest_log:: plugin destination: ${plugin_dir}"
	fi

	if [[ "${do_settings}" == true ]]; then
		echo "apply_quest_log:: settings destination: ${settings_file}"
	fi

	if [[ "${DRY_RUN:-}" == "true" ]]; then
		if [[ "${do_settings}" == true ]]; then
			sync_cursor_user_settings || return 1
		fi

		if [[ "${do_plugin}" == true ]]; then
			install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
			PLUGIN_ACTION="dry-run"
		fi

		return 0
	fi

	if [[ "${do_plugin}" == true && "${do_settings}" == false ]]; then
		install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
		PLUGIN_ACTION="installed"

		return 0
	fi

	local backup_root
	backup_root="$(mktemp -d "${TMPDIR:-/tmp}/quest-log-apply.XXXXXX")" || {
		echo "apply_quest_log:: Failed to create apply backup directory" >&2
		return 1
	}

	trap 'rm -rf -- "${backup_root}"; trap - RETURN' RETURN

	local had_settings=false
	if [[ -f "${settings_file}" ]]; then
		_quest_log_backup_settings "${backup_root}" "${settings_file}" || return 1
		had_settings=true
	fi

	if ! sync_cursor_user_settings; then
		_restore_quest_log_settings "${backup_root}" "${settings_file}" "${had_settings}" || true
		return 1
	fi

	if [[ "${do_plugin}" == true ]]; then
		install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
		PLUGIN_ACTION="installed"
	fi

	return 0
}
