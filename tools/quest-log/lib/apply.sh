#!/usr/bin/env bash
#
# Canonical quest-log apply path used by the CLI and profile installer
#

if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
	printf 'apply.sh:: ZANGARMARSH_ROOT is required\n' >&2
	return 1
fi

if ! declare -F install_quest_plugin >/dev/null 2>&1; then
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"
fi

if ! declare -F sync_cursor_user_settings >/dev/null 2>&1; then
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/cursor-settings.sh"
fi

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

# Restore plugin from an apply-time backup after a successful install
#
# Plugin install is self-atomic. This only undoes a successful install when a
# later settings write fails in both mode.
#
# Inputs:
# - $1 backup_root, temporary directory that may contain plugin/
# - $2 plugin_dir, live plugin install path
# - $3 had_plugin, true when a plugin tree existed before apply
#
# Side Effects:
# - Restores or uninstalls the live plugin
#
# Returns:
# - 0 when restore work succeeds
# - 1 when a restore write fails
_restore_quest_log_plugin() {
	local backup_root="$1"
	local plugin_dir="$2"
	local had_plugin="$3"

	if [[ "${had_plugin}" == true && -d "${backup_root}/plugin" ]]; then
		rm -rf -- "${plugin_dir}"
		if ! mv "${backup_root}/plugin" "${plugin_dir}"; then
			echo "_restore_quest_log_plugin:: Failed to restore previous plugin" >&2
			return 1
		fi

		return 0
	fi

	uninstall_quest_plugin || return 1

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
# - Installs the plugin and/or overwrites Cursor user settings
# - On both mode, restores a successful plugin install when settings sync fails
# - Sets PLUGIN_ACTION to installed, dry-run, or skipped
#
# Returns:
# - 0 on success
# - 1 on validation, write, or restore failure
apply_quest_log() {
	local mode="both"
	local backup_root=""
	local had_plugin=false
	local had_settings=false
	local plugin_dir
	local settings_file
	local restore_status=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--plugin-only)
			mode="plugin"
			shift
			;;
		--settings-only)
			mode="settings"
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
	export PLUGIN_SOURCE_DIR
	PLUGIN_ACTION="skipped"

	if [[ "${mode}" != "settings" ]]; then
		if [[ ! -d "${PLUGIN_SOURCE_DIR}" ]]; then
			echo "apply_quest_log:: plugin source not found: ${PLUGIN_SOURCE_DIR}" >&2
			return 1
		fi
	fi

	if [[ "${mode}" != "plugin" ]]; then
		if [[ ! -f "${ZANGARMARSH_ROOT}/tools/vscode/settings.json" ]]; then
			echo "apply_quest_log:: template not found: ${ZANGARMARSH_ROOT}/tools/vscode/settings.json" >&2
			return 1
		fi
	fi

	plugin_dir="$(quest_log_plugin_dir)" || return 1
	settings_file="$(cursor_user_settings_path)" || return 1

	if [[ "${DRY_RUN:-false}" == true ]]; then
		if [[ "${mode}" != "settings" ]]; then
			install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
			PLUGIN_ACTION="dry-run"
		fi
		if [[ "${mode}" != "plugin" ]]; then
			sync_cursor_user_settings || return 1
		fi
		return 0
	fi

	case "${mode}" in
	plugin)
		install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
		PLUGIN_ACTION="installed"
		return 0
		;;
	settings)
		backup_root="$(mktemp -d "${TMPDIR:-/tmp}/quest-log-apply.XXXXXX")" || {
			echo "apply_quest_log:: Failed to create apply backup directory" >&2
			return 1
		}
		trap 'rm -rf -- "'"${backup_root}"'"' RETURN

		if [[ -f "${settings_file}" ]]; then
			if ! cp "${settings_file}" "${backup_root}/settings.json"; then
				echo "apply_quest_log:: Failed to back up existing Cursor settings" >&2
				return 1
			fi
			chmod 0600 "${backup_root}/settings.json" || {
				echo "apply_quest_log:: Failed to harden Cursor settings backup permissions" >&2
				return 1
			}
			had_settings=true
		fi

		if ! sync_cursor_user_settings; then
			_restore_quest_log_settings "${backup_root}" "${settings_file}" "${had_settings}" || return 1
			return 1
		fi

		return 0
		;;
	both)
		backup_root="$(mktemp -d "${TMPDIR:-/tmp}/quest-log-apply.XXXXXX")" || {
			echo "apply_quest_log:: Failed to create apply backup directory" >&2
			return 1
		}
		trap 'rm -rf -- "'"${backup_root}"'"' RETURN

		if [[ -e "${plugin_dir}" ]]; then
			if ! cp -R "${plugin_dir}" "${backup_root}/plugin"; then
				echo "apply_quest_log:: Failed to back up existing plugin" >&2
				return 1
			fi
			had_plugin=true
		fi

		if [[ -f "${settings_file}" ]]; then
			if ! cp "${settings_file}" "${backup_root}/settings.json"; then
				echo "apply_quest_log:: Failed to back up existing Cursor settings" >&2
				return 1
			fi
			chmod 0600 "${backup_root}/settings.json" || {
				echo "apply_quest_log:: Failed to harden Cursor settings backup permissions" >&2
				return 1
			}
			had_settings=true
		fi

		# Plugin install owns its own rollback. Do not outer-restore on install failure.
		if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}"; then
			return 1
		fi
		PLUGIN_ACTION="installed"

		if ! sync_cursor_user_settings; then
			_restore_quest_log_plugin "${backup_root}" "${plugin_dir}" "${had_plugin}" || restore_status=1
			_restore_quest_log_settings "${backup_root}" "${settings_file}" "${had_settings}" || restore_status=1
			[[ "${restore_status}" -eq 0 ]] || return 1
			return 1
		fi

		return 0
		;;
	*)
		echo "apply_quest_log:: unknown mode: ${mode}" >&2
		return 1
		;;
	esac
}
