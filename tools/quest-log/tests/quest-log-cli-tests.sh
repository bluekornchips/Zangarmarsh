#!/usr/bin/env bats
#
# Tests for print_summary, apply_quest_log, and run_quest_log
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
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
	quest_log_test_setup

	return 0
}

teardown() {
	quest_log_test_teardown

	return 0
}

teardown_file() {
	return 0
}

quest_log_test_setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local return_dir="${PWD}"

	TEST_TEMP_DIR="$(mktemp -d "${base}/quest-log-test.XXXXXX")"

	HOME="${TEST_TEMP_DIR}/home"
	mkdir -p "${HOME}"
	export HOME

	PLUGIN_SOURCE_DIR="${TEST_TEMP_DIR}/plugin"
	create_test_plugin_source "${PLUGIN_SOURCE_DIR}"
	export PLUGIN_SOURCE_DIR

	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log"
	export QUEST_LOG_PLUGIN_DIR

	export TEST_TEMP_DIR
	export ZANGARMARSH_ROOT

	cd "${ZANGARMARSH_ROOT}" || return 1
	set +e
	trap - EXIT ERR
	source "$SCRIPT"
	SCRIPT_DIR="${QUEST_LOG_ROOT}"
	export SCRIPT_DIR
	export QUEST_LOG_ROOT
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh"
	trap - EXIT ERR
	set +e

	cd "${TEST_TEMP_DIR}" || {
		cd "${return_dir}" || true
		return 1
	}

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0
	PLUGIN_ACTION=""

	return 0
}

########################################################
# print_summary
########################################################

@test 'print_summary:: displays summary with all statistics' {
	STATS_CREATED=2
	STATS_UPDATED=3
	STATS_UNCHANGED=1
	STATS_ERRORS=0
	PLUGIN_ACTION="installed"

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "quest-log summary"
	echo "$output" | grep -q "plugin: installed"
	echo "$output" | grep -q "cursor created: 2"
	echo "$output" | grep -q "cursor updated: 3"
	echo "$output" | grep -q "cursor unchanged: 1"
	echo "$output" | grep -q "cursor total: 6"
}

@test 'print_summary:: returns error status when errors exist' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=1

	run print_summary
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "cursor: 1 error(s)"
	echo "$output" | grep -q "print_summary:: cursor settings sync failed"
}

@test 'print_summary:: reports no cursor file sync when counters are zero' {
	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "cursor: no files synced"
}

########################################################
# sync_cursor_user_settings / run_quest_log
########################################################

@test 'run_quest_log:: overwrites Cursor user settings from template' {
	mkdir -p "${HOME}/.config/Cursor/User"
	printf '%s\n' '{
    "window.autoDetectColorScheme": true,
    "workbench.preferredDarkColorTheme": "Visual Studio Dark",
    "git.suggestSmartCommit": false
}' >"${HOME}/.config/Cursor/User/settings.json"

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "sync_cursor_user_settings:: writing"
	jq -e '.["workbench.colorTheme"] == "Default Dark+"' "${HOME}/.config/Cursor/User/settings.json"
	jq -e '.["editor.formatOnSave"] == true' "${HOME}/.config/Cursor/User/settings.json"
	jq -e 'has("git.suggestSmartCommit") | not' "${HOME}/.config/Cursor/User/settings.json"
}

@test 'run_quest_log:: writes macOS Application Support settings path' {
	uname() {
		[[ "$1" == "-s" ]] && {
			echo "Darwin"
			return 0
		}
		command uname "$@"
	}
	export -f uname

	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "${HOME}/Library/Application Support/Cursor/User/settings.json" ]]
	jq -e '.["editor.formatOnSave"] == true' "${HOME}/Library/Application Support/Cursor/User/settings.json"
	[[ ! -e "${HOME}/.config/Cursor/User/settings.json" ]]
}

@test 'run_quest_log:: fails when plugin source is missing' {
	PLUGIN_SOURCE_DIR="/tmp/does-not-exist-plugin"
	export PLUGIN_SOURCE_DIR

	run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "plugin source not found"
}

@test 'run_quest_log:: displays help message' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
	echo "$output" | grep -q "\-\-help"
}

@test 'run_quest_log:: handles unknown options' {
	run run_quest_log --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'run_quest_log:: rejects leftover directory arguments' {
	run run_quest_log /tmp/some-project
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unexpected argument"
}

@test 'run_quest_log:: dry-run does not write plugin or Cursor settings' {
	run run_quest_log --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	echo "$output" | grep -q "would overwrite"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	[[ ! -e "${HOME}/.config/Cursor/User/settings.json" ]]
}

@test 'run_quest_log:: accepts the short dry-run flag' {
	run run_quest_log -r
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'run_quest_log:: installs plugin and overwrites host Cursor settings' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "${HOME}/.config/Cursor/User/settings.json" ]]
	jq -e '.["editor.formatOnSave"] == true' "${HOME}/.config/Cursor/User/settings.json"
	jq -e --slurpfile t "${ZANGARMARSH_VSCODE_DIR}/settings.json" '. == $t[0]' "${HOME}/.config/Cursor/User/settings.json"
}

@test 'run_quest_log:: displays summary at end of execution' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "quest-log summary"
	echo "$output" | grep -q "plugin: installed"
	echo "$output" | grep -Eq 'cursor: no files synced|cursor total:'
}

@test 'run_quest_log:: reports no changes on a second identical run' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "No changes:"
}

@test 'run_quest_log:: rejects force flag' {
	run run_quest_log --force
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'run_quest_log:: rejects short force flag' {
	run run_quest_log -f
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'apply_quest_log:: plugin-only skips Cursor settings' {
	run apply_quest_log --plugin-only
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ ! -e "${HOME}/.config/Cursor/User/settings.json" ]]
}

@test 'apply_quest_log:: restores plugin when settings sync fails' {
	mkdir -p "${QUEST_LOG_PLUGIN_DIR}/rules"
	echo "previous-plugin" >"${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc"

	sync_cursor_user_settings() {
		echo "sync_cursor_user_settings:: forced failure" >&2
		return 1
	}

	run apply_quest_log
	[[ "$status" -eq 1 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	grep -q "previous-plugin" "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc"
	[[ ! -e "${HOME}/.config/Cursor/User/settings.json" ]]
}

########################################################
# Tracked plugin coherence
########################################################
@test 'tracked plugin:: ships the declared rules and skills' {
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	[[ -f "${tracked_plugin}/.cursor-plugin/plugin.json" ]]
	local rule
	for rule in always never shell bash zsh python lua javascript typescript; do
		[[ -f "${tracked_plugin}/rules/${rule}.mdc" ]]
	done
	local skill
	for skill in blue-author blue-review blue-bash-review blue-lua-review blue-typescript-review blue-python-project-setup; do
		[[ -f "${tracked_plugin}/skills/${skill}/SKILL.md" ]]
	done
	[[ ! -e "${tracked_plugin}/MCP.md" ]]
}

@test 'tracked plugin:: install replaces a live tree with the declared assets' {
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	mkdir -p "${QUEST_LOG_PLUGIN_DIR}/skills/blue-retired" "${QUEST_LOG_PLUGIN_DIR}/rules"
	echo "stale" >"${QUEST_LOG_PLUGIN_DIR}/skills/blue-retired/SKILL.md"
	echo "stale" >"${QUEST_LOG_PLUGIN_DIR}/rules/extra.mdc"

	run install_quest_plugin "${tracked_plugin}"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/bash.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/zsh.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-author/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}/skills/blue-retired" ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/rules/extra.mdc" ]]
}

@test 'quest-log.sh:: --help works without a pre-set ZANGARMARSH_ROOT' {
	run env -u ZANGARMARSH_ROOT HOME="${HOME}" PATH="${PATH}" bash "${SCRIPT}" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
}
