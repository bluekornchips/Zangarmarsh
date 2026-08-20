#!/usr/bin/env bash
#
# Shared quest-log fixtures for plugin and CLI tests.
# Source from setup so helpers exist in each Bats test shell.
#

create_test_plugin_source() {
	local plugin_dir="$1"

	mkdir -p "${plugin_dir}/.cursor-plugin" "${plugin_dir}/rules" "${plugin_dir}/skills/blue-review"
	echo '{"name":"quest-log"}' >"${plugin_dir}/.cursor-plugin/plugin.json"
	echo "rule body" >"${plugin_dir}/rules/always.mdc"
	echo "skill body" >"${plugin_dir}/skills/blue-review/SKILL.md"

	return 0
}

quest_log_test_teardown() {
	if [[ -n "${TEST_TEMP_DIR}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
		if ! rm -rf "${TEST_TEMP_DIR}"; then
			echo "Failed to cleanup test directory: ${TEST_TEMP_DIR}" >&2
		fi
	fi

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0

	return 0
}
