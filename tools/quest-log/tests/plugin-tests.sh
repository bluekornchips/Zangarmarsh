#!/usr/bin/env bats
#
# Tests for tools/quest-log/lib/plugin.sh
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	QUEST_LOG_ROOT="${ZANGARMARSH_ROOT}/tools/quest-log"
	SCRIPT="${QUEST_LOG_ROOT}/quest-log.sh"
	ZANGARMARSH_VSCODE_DIR="${ZANGARMARSH_ROOT}/.vscode"
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

teardown_file() {
	return 0
}

plugin_lib_test_setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local return_dir="${PWD}"

	TEST_TEMP_DIR="$(mktemp -d "${base}/quest-log-plugin-test.XXXXXX")"

	HOME="${TEST_TEMP_DIR}/home"
	mkdir -p "${HOME}"
	export HOME

	PLUGIN_SOURCE_DIR="${TEST_TEMP_DIR}/plugin"
	create_test_plugin_source "${PLUGIN_SOURCE_DIR}"
	export PLUGIN_SOURCE_DIR

	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log"
	export QUEST_LOG_PLUGIN_DIR

	DRY_RUN=false
	export DRY_RUN
	export TEST_TEMP_DIR
	export ZANGARMARSH_ROOT

	cd "${ZANGARMARSH_ROOT}" || return 1
	set +e
	trap - EXIT ERR
	source "${QUEST_LOG_ROOT}/lib/plugin.sh"
	trap - EXIT ERR
	set +e

	cd "${TEST_TEMP_DIR}" || {
		cd "${return_dir}" || true
		return 1
	}

	return 0
}

########################################################
# quest_log_plugin_dir
########################################################

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
	HOME=""

	run quest_log_plugin_dir
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "HOME is required"
}

########################################################
# validate_plugin_install_dir
########################################################

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

@test 'validate_plugin_install_dir:: rejects the local plugins root itself' {
	run validate_plugin_install_dir "${HOME}/.cursor/plugins/local"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "refusing unsafe install path\|install path must be below"
}

########################################################
# install_quest_plugin
########################################################

@test 'install_quest_plugin:: fails when plugin manifest is missing' {
	rm -f "${PLUGIN_SOURCE_DIR}/.cursor-plugin/plugin.json"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install_quest_plugin:: plugin manifest not found"
}

@test 'install_quest_plugin:: rejects an install path outside the Cursor local plugin directory' {
	QUEST_LOG_PLUGIN_DIR="${TEST_TEMP_DIR}/unsafe-install"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be below"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'install_quest_plugin:: rejects path traversal in the install directory' {
	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log/../../unsafe-install"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
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
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/quest-review/SKILL.md" ]]
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

	rm -f "${PLUGIN_SOURCE_DIR}/rules/stale.mdc"
	rm -rf "${PLUGIN_SOURCE_DIR}/skills/quest-review"

	run install_quest_plugin "${PLUGIN_SOURCE_DIR}"
	[[ "$status" -eq 0 ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/rules/stale.mdc" ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/skills/quest-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
}

########################################################
# uninstall_quest_plugin
########################################################

@test 'uninstall_quest_plugin:: reports not installed when absent' {
	run uninstall_quest_plugin
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "not installed"
}

@test 'uninstall_quest_plugin:: removes an installed plugin directory' {
	install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null

	run uninstall_quest_plugin
	[[ "$status" -eq 0 ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	echo "$output" | grep -q "removed"
}

@test 'uninstall_quest_plugin:: dry-run leaves the plugin directory in place' {
	install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null
	DRY_RUN=true

	run uninstall_quest_plugin
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would remove"
	[[ -d "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'uninstall_quest_plugin:: rejects an install path outside the Cursor local plugin directory' {
	QUEST_LOG_PLUGIN_DIR="${TEST_TEMP_DIR}/unsafe-install"
	mkdir -p "${QUEST_LOG_PLUGIN_DIR}"

	run uninstall_quest_plugin
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install path must be below"
	[[ -d "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'uninstall_quest_plugin:: rejects path traversal in the install directory' {
	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log/../../unsafe-install"
	mkdir -p "${HOME}/.cursor/plugins/local/unsafe-install"

	run uninstall_quest_plugin
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "path traversal is not allowed"
	[[ -d "${HOME}/.cursor/plugins/local/unsafe-install" ]]
}

@test 'uninstall_quest_plugin:: fails when removal does not clear the path' {
	install_quest_plugin "${PLUGIN_SOURCE_DIR}" >/dev/null

	rm() {
		# Leave the install tree in place to force the post-remove check.
		return 0
	}

	run uninstall_quest_plugin
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "failed to remove"
	[[ -d "${QUEST_LOG_PLUGIN_DIR}" ]]
}
