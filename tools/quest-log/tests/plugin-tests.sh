#!/usr/bin/env bats
#
# Tests for tools/quest-log/lib/plugin.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	QUEST_LOG_ROOT="${ZANGARMARSH_ROOT}/tools/quest-log"
	SCRIPT="${QUEST_LOG_ROOT}/quest-log.sh"
	ZANGARMARSH_VSCODE_DIR="${ZANGARMARSH_ROOT}/tools/vscode"
	export QUEST_LOG_ROOT
	export SCRIPT
	export ZANGARMARSH_VSCODE_DIR

	return 0
}

setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	plugin_lib_test_setup

	return 0
}

teardown() {
	quest_log_test_teardown
	return 0
}

# Isolate HOME and source plugin and rules libraries for one plugin test
#
# Side Effects:
# - Sets DRY_RUN and creates a temporary HOME via quest_log_test_home
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

@test 'quest_log_plugin_dir:: uses QUEST_LOG_PLUGIN_DIR when set' {
	run quest_log_plugin_dir
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'quest_log_plugin_dir:: defaults under HOME when override is unset' {
	unset QUEST_LOG_PLUGIN_DIR

	run quest_log_plugin_dir
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${HOME}/.cursor/plugins/local/quest-log" ]]
}

@test 'quest_log_plugin_dir:: fails when HOME is empty and no override is set' {
	unset QUEST_LOG_PLUGIN_DIR

	HOME="" run quest_log_plugin_dir
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "HOME is required"
}

@test 'validate_plugin_install_dir:: accepts a child of the Cursor local plugin directory' {
	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local/quest-log"
	[[ "$status" -eq 0 ]]
}

@test 'validate_plugin_install_dir:: rejects a relative path' {
	run validate_plugin_install_dir "relative/quest-log"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "absolute install path is required"
}

@test 'validate_plugin_install_dir:: rejects path traversal' {
	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local/quest-log/../escape"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "path traversal is not allowed"
}

@test 'validate_plugin_install_dir:: rejects a path outside the Cursor local plugin directory' {
	run validate_plugin_install_dir "${TEST_TEMP_DIR}/unsafe-install"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be below"
}

@test 'validate_plugin_install_dir:: rejects a trailing slash' {
	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local/quest-log/"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "trailing slash is not allowed"
}

@test 'validate_plugin_install_dir:: rejects a symlinked install directory' {
	mkdir -p "${HOME}/.cursor/plugins/local" "${TEST_TEMP_DIR}/outside"
	ln -s "${TEST_TEMP_DIR}/outside" "${HOME}/.cursor/plugins/local/quest-log"

	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local/quest-log"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "refusing symlink"
}

@test 'validate_plugin_install_dir:: rejects a symlinked plugins directory' {
	mkdir -p "${TEST_TEMP_DIR}/outside/local" "${HOME}/.cursor"
	ln -s "${TEST_TEMP_DIR}/outside" "${HOME}/.cursor/plugins"

	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local/quest-log"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "refusing symlink"
}

@test 'validate_plugin_install_dir:: rejects the local plugins root itself' {
	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "refusing unsafe install path\|install path must be below"
}

@test 'install_quest_plugin:: fails when plugin manifest is missing' {
	command rm -f "${PLUGIN_SOURCE_DIR}/.cursor-plugin/plugin.json"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install_quest_plugin:: plugin manifest not found"
}

@test 'install_quest_plugin:: rejects an install path outside the Cursor local plugin directory' {
	local unsafe="${TEST_TEMP_DIR}/unsafe-install"

	QUEST_LOG_PLUGIN_DIR="${unsafe}" run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be below"
	[[ ! -e "${unsafe}" ]]
}

@test 'install_quest_plugin:: rejects path traversal in the install directory' {
	local unsafe="${HOME}/.cursor/plugins/local/quest-log/../../unsafe-install"

	QUEST_LOG_PLUGIN_DIR="${unsafe}" run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "path traversal is not allowed"
}

@test 'install_quest_plugin:: dry-run reports without writing' {
	DRY_RUN=true

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'install_quest_plugin:: installs plugin files into an empty directory' {
	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	cmp -s "${PLUGIN_SOURCE_DIR}/rules/always.mdc" "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc"
}

@test 'install_quest_plugin:: updates changed files' {
	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]

	echo "new rule" >"${PLUGIN_SOURCE_DIR}/rules/always.mdc"
	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]
	grep -q "new rule" "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc"
}

@test 'install_quest_plugin:: prunes removed rules and skills' {
	echo "drop-me" >"${PLUGIN_SOURCE_DIR}/rules/stale.mdc"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/stale.mdc" ]]

	command rm -f "${PLUGIN_SOURCE_DIR}/rules/stale.mdc"
	command rm -rf "${PLUGIN_SOURCE_DIR}/skills/blue-review"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/rules/stale.mdc" ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
}

@test 'uninstall_quest_plugin:: reports not installed when absent' {
	run uninstall_quest_plugin
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "not installed"
}

@test 'uninstall_quest_plugin:: removes an installed plugin directory' {
	if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null; then
		return 1
	fi

	run uninstall_quest_plugin
	[[ "$status" -eq 0 ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	echo "$output" | grep -q "removed"
}

@test 'uninstall_quest_plugin:: dry-run leaves the plugin directory in place' {
	if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null; then
		return 1
	fi
	DRY_RUN=true

	run uninstall_quest_plugin
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would remove"
	[[ -d "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'uninstall_quest_plugin:: rejects an install path outside the Cursor local plugin directory' {
	local unsafe="${TEST_TEMP_DIR}/unsafe-install"
	mkdir -p "${unsafe}"

	QUEST_LOG_PLUGIN_DIR="${unsafe}" run uninstall_quest_plugin
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be below"
	[[ -d "${unsafe}" ]]
}

@test 'uninstall_quest_plugin:: rejects path traversal in the install directory' {
	local leaf="${HOME}/.cursor/plugins/local/unsafe-install"
	mkdir -p "${leaf}"

	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log/../../unsafe-install" run uninstall_quest_plugin
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "path traversal is not allowed"
	[[ -d "${leaf}" ]]
}

@test 'uninstall_quest_plugin:: fails when removal does not clear the path' {
	if ! install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null; then
		return 1
	fi

	rm() {
		# Leave the install tree in place to force the post-remove check.

		return 0
	}

	run uninstall_quest_plugin
	unset -f rm
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "failed to remove"
	[[ -d "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'quest_log_rules_dir:: uses QUEST_LOG_RULES_DIR when set' {
	run quest_log_rules_dir
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${QUEST_LOG_RULES_DIR}" ]]
}

@test 'quest_log_rules_dir:: defaults under HOME when override is unset' {
	unset QUEST_LOG_RULES_DIR

	run quest_log_rules_dir
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${HOME}/.cursor/rules" ]]
}

@test 'quest_log_rules_dir:: fails when HOME is empty and no override is set' {
	unset QUEST_LOG_RULES_DIR

	HOME="" run quest_log_rules_dir
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "HOME is required"
}

@test 'validate_rules_install_dir:: accepts ~/.cursor/rules' {
	run validate_rules_install_dir "${HOME}/.cursor/rules"
	[[ "$status" -eq 0 ]]
}

@test 'validate_rules_install_dir:: rejects a path other than ~/.cursor/rules' {
	run validate_rules_install_dir "${HOME}/.cursor/plugins/local/quest-log"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be"
}

@test 'validate_rules_install_dir:: rejects path traversal' {
	run validate_rules_install_dir "${HOME}/.cursor/rules/../escape"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "path traversal is not allowed"
}

@test 'validate_rules_install_dir:: rejects a trailing slash' {
	run validate_rules_install_dir "${HOME}/.cursor/rules/"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "trailing slash is not allowed"
}

@test 'validate_rules_install_dir:: rejects a symlinked rules directory' {
	mkdir -p "${HOME}/.cursor" "${TEST_TEMP_DIR}/outside"
	ln -s "${TEST_TEMP_DIR}/outside" "${HOME}/.cursor/rules"

	run validate_rules_install_dir "${HOME}/.cursor/rules"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "refusing symlink"
}

@test 'install_quest_rules:: dry-run reports without writing' {
	DRY_RUN=true

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would sync"
	[[ ! -e "${QUEST_LOG_RULES_DIR}" ]]
}

@test 'install_quest_rules:: installs rules and writes a manifest' {
	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/.quest-log.manifest" ]]
	grep -Fxq "always.mdc" "${QUEST_LOG_RULES_DIR}/.quest-log.manifest"
	cmp -s "${PLUGIN_SOURCE_DIR}/rules/always.mdc" "${QUEST_LOG_RULES_DIR}/always.mdc"
}

@test 'install_quest_rules:: leaves non-managed files in place' {
	mkdir -p "${QUEST_LOG_RULES_DIR}"
	echo "mine" >"${QUEST_LOG_RULES_DIR}/user-owned.mdc"

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
	grep -q "mine" "${QUEST_LOG_RULES_DIR}/user-owned.mdc"
}

@test 'install_quest_rules:: prunes removed managed rules' {
	echo "drop-me" >"${PLUGIN_SOURCE_DIR}/rules/stale.mdc"

	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/stale.mdc" ]]

	command rm -f "${PLUGIN_SOURCE_DIR}/rules/stale.mdc"
	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]
	[[ ! -f "${QUEST_LOG_RULES_DIR}/stale.mdc" ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
}

@test 'install_quest_rules:: updates changed rule content' {
	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]

	echo "new rule" >"${PLUGIN_SOURCE_DIR}/rules/always.mdc"
	run install_quest_rules "${PLUGIN_SOURCE_DIR}/rules"
	[[ "$status" -eq 0 ]]
	grep -q "new rule" "${QUEST_LOG_RULES_DIR}/always.mdc"
}

@test 'uninstall_quest_rules:: reports not installed when manifest is absent' {
	run uninstall_quest_rules
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "not installed"
}

@test 'uninstall_quest_rules:: removes managed rules and keeps user files' {
	mkdir -p "${QUEST_LOG_RULES_DIR}"
	echo "mine" >"${QUEST_LOG_RULES_DIR}/user-owned.mdc"

	if ! install_quest_rules "${PLUGIN_SOURCE_DIR}/rules" >/dev/null; then
		return 1
	fi

	run uninstall_quest_rules
	[[ "$status" -eq 0 ]]
	[[ ! -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
	[[ ! -f "${QUEST_LOG_RULES_DIR}/.quest-log.manifest" ]]
	grep -q "mine" "${QUEST_LOG_RULES_DIR}/user-owned.mdc"
	echo "$output" | grep -q "removed managed rules"
}

@test 'uninstall_quest_rules:: dry-run leaves managed rules in place' {
	if ! install_quest_rules "${PLUGIN_SOURCE_DIR}/rules" >/dev/null; then
		return 1
	fi
	DRY_RUN=true

	run uninstall_quest_rules
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would remove"
	[[ -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/.quest-log.manifest" ]]
}

@test 'uninstall_quest_rules:: rejects an install path outside ~/.cursor/rules' {
	local unsafe="${TEST_TEMP_DIR}/unsafe-rules"
	mkdir -p "${unsafe}"

	QUEST_LOG_RULES_DIR="${unsafe}" run uninstall_quest_rules
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be"
	[[ -d "${unsafe}" ]]
}
