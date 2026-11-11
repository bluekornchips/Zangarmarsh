#!/usr/bin/env bats
#
# Tests for tools/quest-log/lib/plugin.sh and tools/quest-log/lib/rules.sh
#

# Resolve the quest-log root and load the repo fixtures for this file
#
# Side Effects:
# - Sets GIT_ROOT and exports QUEST_LOG_ROOT
#
# Returns:
# - 0 on success
# - 1 when git or the repo fixtures cannot be loaded
setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	QUEST_LOG_ROOT="${ZANGARMARSH_ROOT}/tools/quest-log"
	export QUEST_LOG_ROOT

	return 0
}

# Load the quest-log fixtures and the plugin and rules libraries before each test
#
# Side Effects:
# - Creates a temporary HOME and sources plugin.sh and rules.sh
#
# Returns:
# - 0 on success
setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	plugin_lib_test_setup
	return 0
}

# Remove the temporary directory created for one test
#
# Returns:
# - 0 always
teardown() {
	quest_log_test_teardown
	return 0
}

# Isolate HOME and source plugin and rules libraries for one plugin test
#
# Side Effects:
# - Sets and exports DRY_RUN=false and creates a temporary HOME
# - Sources plugin.sh and rules.sh
#
# Returns:
# - 0 on success
# - 1 when sourcing or directory change fails
plugin_lib_test_setup() {
	local return_dir="${PWD}"

	DRY_RUN=false
	export DRY_RUN
	quest_log_test_home "quest-log-plugin-test"

	cd "${ZANGARMARSH_ROOT}" || return 1
	source_for_test "${QUEST_LOG_ROOT}/lib/plugin.sh" || return 1
	source_for_test "${QUEST_LOG_ROOT}/lib/rules.sh" || return 1

	cd "${TEST_TEMP_DIR}" || {
		cd "${return_dir}" || true
		return 1
	}

	return 0
}

@test "quest_log_plugin_dir:: defaults under HOME" {
	run quest_log_plugin_dir
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "quest_log_plugin_dir:: fails when HOME is empty" {
	HOME="" run quest_log_plugin_dir
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "HOME is required"
}

@test "quest_log_plugin_dir:: refuses a symlinked install directory" {
	mkdir -p "${HOME}/.cursor/plugins/local" "${TEST_TEMP_DIR}/outside"
	ln -s "${TEST_TEMP_DIR}/outside" "${HOME}/.cursor/plugins/local/quest-log"

	run quest_log_plugin_dir
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "refusing symlink"
}

@test "quest_log_plugin_dir:: refuses a symlinked plugins directory" {
	mkdir -p "${TEST_TEMP_DIR}/outside/local" "${HOME}/.cursor"
	ln -s "${TEST_TEMP_DIR}/outside" "${HOME}/.cursor/plugins"

	run quest_log_plugin_dir
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "refusing symlink"
}

@test "install_quest_plugin:: fails when plugin manifest is missing" {
	command rm -f "${PLUGIN_SOURCE_DIR}/.cursor-plugin/plugin.json"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "install_quest_plugin:: plugin manifest not found"
}

@test "install_quest_plugin:: dry-run reports without writing" {
	DRY_RUN=true

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "would replace"
	[[ ! -e "${HOME}/.cursor" ]]
}

@test "install_quest_plugin:: installs plugin files into an empty directory" {
	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${TEST_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	cmp -s "${PLUGIN_SOURCE_DIR}/rules/always.mdc" "${TEST_PLUGIN_DIR}/rules/always.mdc"
	[[ ! -e "${HOME}/.cursor/plugins/local/quest-log.staging" ]]
	[[ ! -e "${HOME}/.cursor/plugins/local/quest-log.removing" ]]
}

@test "install_quest_plugin:: updates changed files" {
	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 0 ]]

	echo "new rule" >"${PLUGIN_SOURCE_DIR}/rules/always.mdc"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 0 ]]
	grep -q "new rule" "${TEST_PLUGIN_DIR}/rules/always.mdc"
}

@test "install_quest_plugin:: prunes removed rules and skills" {
	echo "drop-me" >"${PLUGIN_SOURCE_DIR}/rules/stale.mdc"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/stale.mdc" ]]

	command rm -f "${PLUGIN_SOURCE_DIR}/rules/stale.mdc"
	command rm -rf "${PLUGIN_SOURCE_DIR}/skills/blue-review"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "${status}" -eq 0 ]]
	[[ ! -f "${TEST_PLUGIN_DIR}/rules/stale.mdc" ]]
	[[ ! -f "${TEST_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/always.mdc" ]]
}

@test "uninstall_quest_plugin:: reports not installed when absent" {
	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "not installed"
}

@test "uninstall_quest_plugin:: removes an installed plugin directory" {
	if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null; then
		return 1
	fi

	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	[[ ! -e "${TEST_PLUGIN_DIR}" ]]
	echo "${output}" | grep -q "removed"
}

@test "uninstall_quest_plugin:: dry-run leaves the plugin directory in place" {
	if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null; then
		return 1
	fi
	DRY_RUN=true

	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "would remove"
	[[ -d "${TEST_PLUGIN_DIR}" ]]
}

@test "uninstall_quest_plugin:: fails when removal fails" {
	if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null; then
		return 1
	fi

	# Stub rm so the removal step fails
	#
	# Returns:
	# - 1 always
	rm() {
		return 1
	}

	run uninstall_quest_plugin
	unset -f rm
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "failed to remove"
	[[ -d "${TEST_PLUGIN_DIR}" ]]
}

@test "quest_log_rules_dir:: defaults under HOME" {
	run quest_log_rules_dir
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${HOME}/.cursor/rules" ]]
}

@test "quest_log_rules_dir:: fails when HOME is empty" {
	HOME="" run quest_log_rules_dir
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "HOME is required"
}

@test "quest_log_rules_dir:: refuses a symlinked rules directory" {
	mkdir -p "${HOME}/.cursor" "${TEST_TEMP_DIR}/outside"
	ln -s "${TEST_TEMP_DIR}/outside" "${TEST_RULES_DIR}"

	run quest_log_rules_dir
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "refusing symlink"
}

@test "install_quest_rules:: dry-run reports without writing" {
	DRY_RUN=true

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Would write: .*zangarmarsh-always.mdc"
	[[ ! -e "${HOME}/.cursor" ]]
}

@test "install_quest_rules:: installs zangarmarsh-prefixed rules without unprefixed copies" {
	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_RULES_DIR}/zangarmarsh-always.mdc" ]]
	[[ ! -e "${TEST_RULES_DIR}/always.mdc" ]]
	cmp -s "${PLUGIN_SOURCE_DIR}/rules/always.mdc" "${TEST_RULES_DIR}/zangarmarsh-always.mdc"
}

@test "install_quest_rules:: leaves non-managed files in place" {
	mkdir -p "${TEST_RULES_DIR}"
	echo "mine" >"${TEST_RULES_DIR}/user-owned.mdc"

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_RULES_DIR}/zangarmarsh-always.mdc" ]]
	grep -q "mine" "${TEST_RULES_DIR}/user-owned.mdc"
}

@test "install_quest_rules:: prunes removed zangarmarsh rules" {
	echo "drop-me" >"${PLUGIN_SOURCE_DIR}/rules/stale.mdc"

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_RULES_DIR}/zangarmarsh-stale.mdc" ]]

	command rm -f "${PLUGIN_SOURCE_DIR}/rules/stale.mdc"

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]
	[[ ! -f "${TEST_RULES_DIR}/zangarmarsh-stale.mdc" ]]
	[[ -f "${TEST_RULES_DIR}/zangarmarsh-always.mdc" ]]
}

@test "install_quest_rules:: updates changed rule content" {
	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]

	echo "new rule" >"${PLUGIN_SOURCE_DIR}/rules/always.mdc"

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "${status}" -eq 0 ]]
	grep -q "new rule" "${TEST_RULES_DIR}/zangarmarsh-always.mdc"
}

@test "uninstall_quest_rules:: reports not installed when no managed rules exist" {
	run uninstall_quest_rules
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "not installed"
}

@test "uninstall_quest_rules:: removes managed rules and keeps user files" {
	mkdir -p "${TEST_RULES_DIR}"
	echo "mine" >"${TEST_RULES_DIR}/user-owned.mdc"

	if ! install_quest_rules "${PLUGIN_SOURCE_DIR}/rules" >/dev/null; then
		return 1
	fi

	run uninstall_quest_rules
	[[ "${status}" -eq 0 ]]
	[[ ! -f "${TEST_RULES_DIR}/zangarmarsh-always.mdc" ]]
	grep -q "mine" "${TEST_RULES_DIR}/user-owned.mdc"
	echo "${output}" | grep -q "Removed: .*zangarmarsh-always.mdc"
}

@test "uninstall_quest_rules:: dry-run leaves managed rules in place" {
	if ! install_quest_rules "${PLUGIN_SOURCE_DIR}/rules" >/dev/null; then
		return 1
	fi
	DRY_RUN=true

	run uninstall_quest_rules
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Would remove: .*zangarmarsh-always.mdc"
	[[ -f "${TEST_RULES_DIR}/zangarmarsh-always.mdc" ]]
}
