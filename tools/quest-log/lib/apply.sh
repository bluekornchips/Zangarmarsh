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

# Restore plugin and settings from an apply-time backup
#
# Inputs:
# - $1 backup_root, temporary directory that may contain plugin/ and settings.json
# - $2 plugin_dir, live plugin install path
# - $3 settings_file, live Cursor settings path
# - $4 restore_plugin, true when plugin changes should be reverted
# - $5 restore_settings, true when settings changes should be reverted
# - $6 had_plugin, true when a plugin tree existed before apply
# - $7 had_settings, true when a settings file existed before apply
#
# Side Effects:
# - Restores backed-up plugin and settings state
#
# Returns:
# - 0 when restore work succeeds
# - 1 when a restore write fails
_restore_quest_log_apply() {
	local backup_root="$1"
	local plugin_dir="$2"
	local settings_file="$3"
	local restore_plugin="$4"
	local restore_settings="$5"
	local had_plugin="$6"
	local had_settings="$7"
	local errors=0

	if [[ "${restore_plugin}" == true ]]; then
		if [[ "${had_plugin}" == true && -d "${backup_root}/plugin" ]]; then
			rm -rf -- "${plugin_dir}"
			if ! mv "${backup_root}/plugin" "${plugin_dir}"; then
				echo "_restore_quest_log_apply:: Failed to restore previous plugin" >&2
				errors=$((errors + 1))
			fi
		else
			uninstall_quest_plugin || errors=$((errors + 1))
		fi
	fi

	if [[ "${restore_settings}" == true ]]; then
		if [[ "${had_settings}" == true && -f "${backup_root}/settings.json" ]]; then
			if ! mkdir -p "$(dirname "${settings_file}")" || ! cp "${backup_root}/settings.json" "${settings_file}"; then
				echo "_restore_quest_log_apply:: Failed to restore previous Cursor settings" >&2
				errors=$((errors + 1))
			fi
		elif [[ -e "${settings_file}" || -L "${settings_file}" ]]; then
			if ! rm -f -- "${settings_file}"; then
				echo "_restore_quest_log_apply:: Failed to remove incomplete Cursor settings" >&2
				errors=$((errors + 1))
			fi
		fi
	fi

	rm -rf -- "${backup_root}"
	[[ "${errors}" -eq 0 ]] || return 1

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
# - Restores both sides when a later write fails
#
# Returns:
# - 0 on success
# - 1 on validation, write, or restore failure
apply_quest_log() {
	local plugin_only=false
	local settings_only=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--plugin-only)
			plugin_only=true
			shift
			;;
		--settings-only)
			settings_only=true
			shift
			;;
		*)
			echo "apply_quest_log:: Unknown option: ${1}" >&2
			return 1
			;;
		esac
	done

	if [[ "${plugin_only}" == true && "${settings_only}" == true ]]; then
		echo "apply_quest_log:: use only one of --plugin-only or --settings-only" >&2
		return 1
	fi

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

	if [[ ! -d "${PLUGIN_SOURCE_DIR}" ]]; then
		echo "apply_quest_log:: plugin source not found: ${PLUGIN_SOURCE_DIR}" >&2
		return 1
	fi

	if [[ "${plugin_only}" != true ]]; then
		if [[ ! -f "${ZANGARMARSH_ROOT}/tools/vscode/settings.json" ]]; then
			echo "apply_quest_log:: template not found: ${ZANGARMARSH_ROOT}/tools/vscode/settings.json" >&2
			return 1
		fi
	fi

	local plugin_dir
	plugin_dir="$(quest_log_plugin_dir)" || return 1
	local settings_file
	settings_file="$(cursor_user_settings_path)" || return 1

	if [[ "${DRY_RUN:-false}" == true ]]; then
		if [[ "${settings_only}" != true ]]; then
			install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
			PLUGIN_ACTION="dry-run"
		fi
		if [[ "${plugin_only}" != true ]]; then
			sync_cursor_user_settings || return 1
		fi
		return 0
	fi

	local backup_root
	backup_root="$(mktemp -d "${TMPDIR:-/tmp}/quest-log-apply.XXXXXX")" || {
		echo "apply_quest_log:: Failed to create apply backup directory" >&2
		return 1
	}

	local had_plugin=false
	local had_settings=false

	if [[ "${settings_only}" != true && -e "${plugin_dir}" ]]; then
		if ! cp -R "${plugin_dir}" "${backup_root}/plugin"; then
			rm -rf -- "${backup_root}"
			echo "apply_quest_log:: Failed to back up existing plugin" >&2
			return 1
		fi
		had_plugin=true
	fi

	if [[ "${plugin_only}" != true && -f "${settings_file}" ]]; then
		if ! cp "${settings_file}" "${backup_root}/settings.json"; then
			rm -rf -- "${backup_root}"
			echo "apply_quest_log:: Failed to back up existing Cursor settings" >&2
			return 1
		fi
		chmod 0600 "${backup_root}/settings.json" || {
			rm -rf -- "${backup_root}"
			echo "apply_quest_log:: Failed to harden Cursor settings backup permissions" >&2
			return 1
		}
		had_settings=true
	fi

	if [[ "${settings_only}" != true ]]; then
		if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}"; then
			_restore_quest_log_apply "${backup_root}" "${plugin_dir}" "${settings_file}" true false "${had_plugin}" "${had_settings}" || true
			return 1
		fi
		PLUGIN_ACTION="installed"
	fi

	if [[ "${plugin_only}" != true ]]; then
		if ! sync_cursor_user_settings; then
			local restore_plugin=true
			[[ "${settings_only}" == true ]] && restore_plugin=false
			_restore_quest_log_apply "${backup_root}" "${plugin_dir}" "${settings_file}" \
				"${restore_plugin}" true "${had_plugin}" "${had_settings}" || true
			return 1
		fi
	fi

	rm -rf -- "${backup_root}"

	return 0
}
