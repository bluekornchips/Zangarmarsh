#!/usr/bin/env bash
#
# Shared quest-log fixtures for plugin and CLI tests.
# Source from setup so helpers exist in each Bats test shell.
# Requires GIT_ROOT from the calling setup_file.
#

source "${GIT_ROOT}/tests/fixtures.sh" || return 1

# Create a minimal tracked-style plugin tree for tests
#
# Inputs:
# - $1 plugin_dir, destination directory for the fake plugin
#
# Side Effects:
# - Writes plugin.json, one rule, and one skill under plugin_dir
#
# Returns:
# - 0 on success
create_test_plugin_source() {
	local plugin_dir="$1"

	mkdir -p "${plugin_dir}/.cursor-plugin" "${plugin_dir}/rules" "${plugin_dir}/skills/blue-review"
	echo '{"name":"quest-log"}' >"${plugin_dir}/.cursor-plugin/plugin.json"
	echo "rule body" >"${plugin_dir}/rules/always.mdc"
	echo "skill body" >"${plugin_dir}/skills/blue-review/SKILL.md"

	return 0
}

# Create an isolated HOME, plugin source, and plugin install path for one test
#
# Inputs:
# - $1 label, short name used in the temporary directory template
#
# Side Effects:
# - Sets and exports TEST_TEMP_DIR, HOME, PLUGIN_SOURCE_DIR, QUEST_LOG_PLUGIN_DIR,
#   and QUEST_LOG_RULES_DIR
#
# Returns:
# - 0 on success
quest_log_test_home() {
	local label="${1:-quest-log-test}"
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_TEMP_DIR="$(mktemp -d "${base}/${label}.XXXXXX")"
	export TEST_TEMP_DIR

	HOME="${TEST_TEMP_DIR}/home"
	mkdir -p "${HOME}"
	export HOME

	PLUGIN_SOURCE_DIR="${TEST_TEMP_DIR}/plugin"
	create_test_plugin_source "${PLUGIN_SOURCE_DIR}"
	export PLUGIN_SOURCE_DIR

	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log"
	export QUEST_LOG_PLUGIN_DIR

	QUEST_LOG_RULES_DIR="${HOME}/.cursor/rules"
	export QUEST_LOG_RULES_DIR

	return 0
}

# Remove the temporary directory created by quest_log_test_home
#
# Side Effects:
# - Deletes TEST_TEMP_DIR when set
#
# Returns:
# - 0 always
quest_log_test_teardown() {
	if [[ -n "${TEST_TEMP_DIR}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
		if ! rm -rf "${TEST_TEMP_DIR}"; then
			echo "Failed to cleanup test directory: ${TEST_TEMP_DIR}" >&2
		fi
	fi

	return 0
}
