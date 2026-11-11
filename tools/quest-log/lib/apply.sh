#!/usr/bin/env bash
#
# Canonical quest-log apply path used by the CLI and profile installer
#

source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"
source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/rules.sh"
source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/cursor-settings.sh"

# Overwrite Cursor user settings, then sync user rules, then install the plugin
#
# Reads environment:
# - ZANGARMARSH_ROOT, checkout that holds tools/quest-log and tools/vscode
# - PLUGIN_SOURCE_DIR, optional plugin source, default tools/quest-log/plugin
# - HOME, used to resolve the install destinations
# - DRY_RUN, when true report without writing
#
# Side Effects:
# - Writes Cursor user settings, managed rules, and the plugin in that order
# - Validates the plugin and rules destinations before the first write
#
# Returns:
# - 0 on success, including dry-run
# - 1 when validation or a write fails
apply_quest_log() {
	local plugin_source_dir="${PLUGIN_SOURCE_DIR:-${ZANGARMARSH_ROOT}/tools/quest-log/plugin}"

	if [[ ! -d "${plugin_source_dir}" ]]; then
		echo "apply_quest_log:: plugin source not found: ${plugin_source_dir}" >&2
		return 1
	fi

	if [[ ! -f "${ZANGARMARSH_ROOT}/tools/vscode/settings.json" ]]; then
		echo "apply_quest_log:: template not found: ${ZANGARMARSH_ROOT}/tools/vscode/settings.json" >&2
		return 1
	fi

	quest_log_plugin_dir >/dev/null || return 1
	quest_log_rules_dir >/dev/null || return 1

	sync_cursor_user_settings || return 1
	install_quest_rules "${plugin_source_dir}/rules" || return 1
	install_quest_plugin "${plugin_source_dir}" || return 1

	return 0
}
