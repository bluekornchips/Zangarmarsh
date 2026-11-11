#!/usr/bin/env bash
#
# Quest-log Cursor plugin install and uninstall helpers
#

source "${ZANGARMARSH_ROOT}/tools/lib/fs.sh"

# Print the local Cursor plugin install directory after owned_path accepts it
#
# Reads environment:
# - HOME, used to resolve ~/.cursor/plugins/local/quest-log
#
# Outputs:
# - Absolute plugin install path, to stdout
#
# Returns:
# - 0 when the path is owned
# - 1 when HOME is empty or the path fails owned_path
quest_log_plugin_dir() {
	local plugins_root="${HOME:-}/.cursor/plugins/local"
	local install_dir="${plugins_root}/quest-log"
	owned_path "${install_dir}" "${plugins_root}" "quest_log_plugin_dir" || return 1
	printf '%s\n' "${install_dir}"

	return 0
}

# Replace the local Cursor plugin with a fresh copy of the tracked plugin tree
#
# Inputs:
# - $1, plugin_source_dir, the tracked plugin tree under tools/quest-log/plugin
#
# Reads environment:
# - DRY_RUN, when true report without writing
# - HOME, used to resolve the install path
#
# Side Effects:
# - Copies plugin_source_dir to quest-log.staging beside the install path
# - Moves the live install to quest-log.removing, moves the staged copy into place,
#   then deletes quest-log.removing
# - Deletes leftover staging and removing paths first, so an interrupted run is
#   repaired by the next run
#
# Returns:
# - 0 on success, including dry-run
# - 1 when the source is invalid, the path is unsafe, or a step fails
install_quest_plugin() {
	local plugin_source_dir="$1"

	[[ -f "${plugin_source_dir}/.cursor-plugin/plugin.json" ]] || {
		echo "install_quest_plugin:: plugin manifest not found: ${plugin_source_dir}/.cursor-plugin/plugin.json" >&2
		return 1
	}

	local install_dir
	install_dir="$(quest_log_plugin_dir)" || return 1
	local install_parent
	install_parent="$(dirname "${install_dir}")"
	local staging_dir="${install_parent}/quest-log.staging"
	local removing_dir="${install_parent}/quest-log.removing"

	owned_path "${staging_dir}" "${install_parent}" "install_quest_plugin" || return 1
	owned_path "${removing_dir}" "${install_parent}" "install_quest_plugin" || return 1

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "install_quest_plugin: would replace ${install_dir}"
		return 0
	fi

	ensure_dir "${install_parent}" "install_quest_plugin" || return 1

	# A partial copy from an interrupted run must never reach the install path,
	# so the staged copy is always rebuilt from source.
	rm -rf -- "${staging_dir}" "${removing_dir}" || return 1
	cp -R "${plugin_source_dir}" "${staging_dir}" || return 1

	if [[ -e "${install_dir}" ]]; then
		mv "${install_dir}" "${removing_dir}" || {
			echo "install_quest_plugin:: failed to move ${install_dir} aside" >&2
			return 1
		}
	fi

	mv "${staging_dir}" "${install_dir}" || {
		echo "install_quest_plugin:: failed to move ${staging_dir} into place" >&2
		return 1
	}

	rm -rf -- "${removing_dir}" || {
		echo "install_quest_plugin:: failed to remove ${removing_dir}" >&2
		return 1
	}

	echo "install_quest_plugin: complete"

	return 0
}

# Remove the locally installed quest-log Cursor plugin directory
#
# Reads environment:
# - DRY_RUN, when true report without deleting
# - HOME, used to resolve the install path
#
# Side Effects:
# - Deletes the install directory unless DRY_RUN is true
#
# Returns:
# - 0 on success, including when absent or in dry-run mode
# - 1 when the path is unsafe or removal fails
uninstall_quest_plugin() {
	local install_dir
	install_dir="$(quest_log_plugin_dir)" || return 1

	if [[ ! -e "${install_dir}" ]]; then
		echo "uninstall_quest_plugin: not installed in ${install_dir}"
		return 0
	fi

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "uninstall_quest_plugin: would remove ${install_dir}"
		return 0
	fi

	rm -rf -- "${install_dir}" || {
		echo "uninstall_quest_plugin:: failed to remove ${install_dir}" >&2
		return 1
	}

	echo "uninstall_quest_plugin: removed ${install_dir}"

	return 0
}
