#!/usr/bin/env bash
#
# Quest-log Cursor plugin install and uninstall helpers
#
# Requires:
# - ZANGARMARSH_ROOT set to the Zangarmarsh repository root before sourcing
#

if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
	printf 'plugin.sh:: ZANGARMARSH_ROOT is required\n' >&2
	return 1
fi
source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/io.sh"

# Resolve the local Cursor plugin install directory
#
# Reads environment:
# - QUEST_LOG_PLUGIN_DIR, optional override
# - HOME, used when QUEST_LOG_PLUGIN_DIR is unset
#
# Outputs:
# - Absolute plugin install path, to stdout
#
# Returns:
# - 0 on success
# - 1 when HOME is empty and no override is set
quest_log_plugin_dir() {
	if [[ -n "${QUEST_LOG_PLUGIN_DIR:-}" ]]; then
		printf '%s\n' "${QUEST_LOG_PLUGIN_DIR}"
		return 0
	fi

	if [[ -z "${HOME:-}" ]]; then
		printf 'quest_log_plugin_dir:: HOME is required\n' >&2
		return 1
	fi

	printf '%s/.cursor/plugins/local/quest-log\n' "${HOME}"

	return 0
}

# Validate the plugin installation path before any deletion
#
# Inputs:
# - $1, install_dir, requested plugin installation directory
#
# Returns:
# - 0 when install_dir is an absolute child of ~/.cursor/plugins/local
# - 1 when the path is unsafe or invalid
validate_plugin_install_dir() {
	local install_dir="$1"
	local allowed_root="${HOME}/.cursor/plugins/local"

	if [[ -z "${HOME:-}" || -z "${install_dir}" || "${install_dir}" != /* ]]; then
		echo "validate_plugin_install_dir:: absolute install path is required" >&2
		return 1
	fi

	case "${install_dir}" in
	*"/../"* | *"/./"* | */.. | */.)
		echo "validate_plugin_install_dir:: path traversal is not allowed" >&2
		return 1
		;;
	esac

	case "${install_dir}" in
	"${allowed_root}"/*) ;;
	*)
		echo "validate_plugin_install_dir:: install path must be below ${allowed_root}" >&2
		return 1
		;;
	esac

	if [[ "${install_dir}" == "${allowed_root}" || "${install_dir}" == */. || "${install_dir}" == */.. ]]; then
		echo "validate_plugin_install_dir:: refusing unsafe install path: ${install_dir}" >&2
		return 1
	fi

	return 0
}

# Copy the tracked quest-log plugin tree into the local Cursor plugins path
#
# Inputs:
# - $1, plugin_source_dir, the tracked plugin tree under tools/quest-log/plugin
#
# Reads environment:
# - QUEST_LOG_PLUGIN_DIR, optional install destination
# - DRY_RUN, when true report without writing
# - HOME, used to resolve the default install path
#
# Side Effects:
# - Replaces the install directory from a staged copy of plugin_source_dir,
#   so stale files never survive a run
#
# Returns:
# - 0 on success, including dry-run
# - 1 when the source is invalid, the path is unsafe, or the copy fails
install_quest_plugin() {
	local plugin_source_dir="$1"

	[[ -f "${plugin_source_dir}/.cursor-plugin/plugin.json" ]] || {
		echo "install_quest_plugin:: plugin manifest not found: ${plugin_source_dir}/.cursor-plugin/plugin.json" >&2
		return 1
	}

	local install_dir
	install_dir="$(quest_log_plugin_dir)" || return 1
	validate_plugin_install_dir "${install_dir}" || return 1

	local install_parent
	install_parent="$(dirname "${install_dir}")"
	ensure_dir "${install_parent}" "install_quest_plugin" || return 1

	echo "install_quest_plugin: running"

	if [[ "${DRY_RUN:-false}" == true ]]; then
		echo "install_quest_plugin: would replace ${install_dir}"
		return 0
	fi

	local staging_dir
	staging_dir="$(mktemp -d "${install_parent}/.quest-log-staging.XXXXXX")" || {
		echo "install_quest_plugin:: Failed to create staging directory" >&2
		return 1
	}

	if ! cp -R "${plugin_source_dir}/." "${staging_dir}/"; then
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: copy failed" >&2
		return 1
	fi

	local backup_dir
	backup_dir="$(mktemp -d "${install_parent}/.quest-log-backup.XXXXXX")" || {
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: Failed to create backup directory" >&2
		return 1
	}
	rmdir "${backup_dir}" || {
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: Failed to prepare backup directory" >&2
		return 1
	}

	if [[ -e "${install_dir}" || -L "${install_dir}" ]]; then
		if ! mv "${install_dir}" "${backup_dir}"; then
			rm -rf "${staging_dir}"
			echo "install_quest_plugin:: Failed to stage existing installation" >&2
			return 1
		fi
	fi

	if ! mv "${staging_dir}" "${install_dir}"; then
		if [[ -e "${backup_dir}" || -L "${backup_dir}" ]]; then
			mv "${backup_dir}" "${install_dir}" || true
		fi
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: Failed to activate staged installation" >&2
		return 1
	fi

	rm -rf "${backup_dir}"

	echo "install_quest_plugin: complete"

	return 0
}

# Remove the locally installed quest-log Cursor plugin directory
#
# Reads environment:
# - QUEST_LOG_PLUGIN_DIR, optional install destination
# - DRY_RUN, when true report without deleting
# - HOME, used to resolve the default install path
#
# Side Effects:
# - Deletes the validated install directory, unless DRY_RUN is true
#
# Returns:
# - 0 on success, including when absent or in dry-run mode
# - 1 when the path is unsafe or removal fails
uninstall_quest_plugin() {
	local install_dir

	install_dir="$(quest_log_plugin_dir)" || return 1
	validate_plugin_install_dir "${install_dir}" || return 1

	if [[ ! -e "${install_dir}" && ! -L "${install_dir}" ]]; then
		echo "uninstall_quest_plugin: not installed in ${install_dir}"
		return 0
	fi

	if [[ "${DRY_RUN:-false}" == true ]]; then
		echo "uninstall_quest_plugin: would remove ${install_dir}"
		return 0
	fi

	if ! rm -rf -- "${install_dir}"; then
		echo "uninstall_quest_plugin:: failed to remove ${install_dir}" >&2
		return 1
	fi

	if [[ -e "${install_dir}" || -L "${install_dir}" ]]; then
		echo "uninstall_quest_plugin:: failed to remove ${install_dir}" >&2
		return 1
	fi

	echo "uninstall_quest_plugin: removed ${install_dir}"

	return 0
}
