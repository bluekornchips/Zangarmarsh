#!/usr/bin/env bats
#
# Tests for determine_target_directory, print_summary, vscodeoverride,
# install_quest_plugin, and run_quest_log
#

source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"

setup_file() {
	return 0
}

setup() {
	quest_log_test_setup
}

teardown() {
	quest_log_test_teardown
}

########################################################
# determine_target_directory
########################################################

@test 'determine_target_directory:: uses git root when in git repo' {
	mock_git_in_repo
	TARGET_DIR="/some/other/path"
	export TARGET_DIR

	determine_target_directory
	[[ "$TARGET_DIR" == "$TEST_TEMP_DIR" ]]

	run determine_target_directory
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "git_root: ${TEST_TEMP_DIR}"
}

@test 'determine_target_directory:: uses current directory when not in git repo' {
	mock_git_not_in_repo
	TARGET_DIR="$TEST_TEMP_DIR"

	run determine_target_directory
	[[ "$status" -eq 0 ]]
	[[ "$TARGET_DIR" == "$TEST_TEMP_DIR" ]]
	echo "$output" | grep -q "git_root: none"
}

@test 'determine_target_directory:: uses PWD when TARGET_DIR not set and not in git repo' {
	mock_git_not_in_repo
	unset TARGET_DIR

	run determine_target_directory
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "git_root: none"
}

########################################################
# print_summary
########################################################

@test 'print_summary:: displays summary with all statistics' {
	STATS_CREATED=2
	STATS_UPDATED=3
	STATS_UNCHANGED=1
	STATS_ERRORS=0

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Created: 2"
	echo "$output" | grep -q "Updated: 3"
	echo "$output" | grep -q "Unchanged: 1"
	echo "$output" | grep -q "Total processed: 6"
	echo "$output" | grep -q "print_summary:: All files processed successfully"
}

@test 'print_summary:: returns error status when errors exist' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=1

	run print_summary
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Errors: 1"
	echo "$output" | grep -q "print_summary:: Some files failed to sync"
}

########################################################
# vscodeoverride
########################################################

@test 'vscodeoverride:: syncs when destination directory is empty' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	GIT_ROOT="${test_git_root}"
	export GIT_ROOT

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscodeoverride: complete"
	[[ -d "${GIT_ROOT}/.vscode" ]]
	[[ -f "${GIT_ROOT}/.vscode/settings.json" ]]
	cmp -s "${GIT_ROOT}/.vscode/settings.json" "${ZANGARMARSH_VSCODE_DIR}/settings.json"
}

@test 'vscodeoverride:: replaces existing settings by default' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	mkdir -p "${test_git_root}/.vscode"
	echo "existing" >"${test_git_root}/.vscode/settings.json"

	GIT_ROOT="${test_git_root}"
	export GIT_ROOT

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscodeoverride: complete"
	cmp -s "${GIT_ROOT}/.vscode/settings.json" "${ZANGARMARSH_VSCODE_DIR}/settings.json"
}

@test 'vscodeoverride:: fails when GIT_ROOT is not set' {
	unset GIT_ROOT

	run vscodeoverride
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "vscodeoverride:: GIT_ROOT is not set"
}

@test 'vscodeoverride:: fails when Zangarmarsh template is missing' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	local fake_root
	fake_root="$(mktemp -d "${base}/vscodeoverride-no-template.XXXXXX")"

	GIT_ROOT="${test_git_root}"
	export GIT_ROOT

	run vscodeoverride "${fake_root}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "vscodeoverride:: VSCode settings directory not found"
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
# Main
########################################################

@test 'run_quest_log:: fails when target directory does not exist' {
	TARGET_DIR="/tmp/does-not-exist"

	run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Failed to change to target directory"
}

@test 'run_quest_log:: fails when plugin source is missing' {
	PLUGIN_SOURCE_DIR="/tmp/does-not-exist-plugin"
	export PLUGIN_SOURCE_DIR

	run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: plugin source not found"
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

@test 'run_quest_log:: uses git root when in git repository' {
	mock_git_in_repo

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "git_root: ${TEST_TEMP_DIR}"
}

@test 'run_quest_log:: uses specified directory when not in git repository' {
	mock_git_not_in_repo

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "git_root: none"
}

@test 'run_quest_log:: preserves an explicit target directory inside another git repository' {
	local target_dir="${TEST_TEMP_DIR}/external-target"
	mkdir -p "${target_dir}"
	mock_git_in_repo

	run run_quest_log "${target_dir}"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "target_dir: ${target_dir}"
	[[ -f "${target_dir}/.vscode/settings.json" ]]
	[[ ! -f "${TEST_TEMP_DIR}/.vscode/settings.json" ]]
}

@test 'run_quest_log:: dry-run does not write plugin or VS Code files' {
	local target_dir="${TEST_TEMP_DIR}/dry-run-target"
	mkdir -p "${target_dir}"

	run run_quest_log --dry-run "${target_dir}"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	echo "$output" | grep -q "would write"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	[[ ! -e "${target_dir}/.vscode" ]]
}

@test 'run_quest_log:: accepts the short dry-run flag' {
	local target_dir="${TEST_TEMP_DIR}/short-dry-run-target"
	mkdir -p "${target_dir}"

	run run_quest_log -r "${target_dir}"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
}

@test 'run_quest_log:: installs plugin under QUEST_LOG_PLUGIN_DIR and syncs vscode' {
	mock_git_in_repo

	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/quest-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "$TEST_TEMP_DIR/.vscode/settings.json" ]]
}

@test 'run_quest_log:: displays summary at end of execution' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Total processed:"
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

########################################################
# Tracked plugin coherence
########################################################
@test 'tracked plugin:: ships the declared rules and skills' {
	local tracked_plugin="${GIT_ROOT}/tools/quest-log/plugin"
	local rule
	local skill

	[[ -f "${tracked_plugin}/.cursor-plugin/plugin.json" ]]
	for rule in always never shell bash zsh python lua javascript typescript; do
		[[ -f "${tracked_plugin}/rules/${rule}.mdc" ]]
	done
	for skill in quest-author quest-review quest-bash-review quest-lua-review quest-typescript-review quest-python-project-setup; do
		[[ -f "${tracked_plugin}/skills/${skill}/SKILL.md" ]]
	done
	[[ ! -e "${tracked_plugin}/MCP.md" ]]
}

@test 'tracked plugin:: install replaces a live tree with the declared assets' {
	local tracked_plugin="${GIT_ROOT}/tools/quest-log/plugin"

	mkdir -p "${QUEST_LOG_PLUGIN_DIR}/skills/quest-retired" "${QUEST_LOG_PLUGIN_DIR}/rules"
	echo "stale" >"${QUEST_LOG_PLUGIN_DIR}/skills/quest-retired/SKILL.md"
	echo "stale" >"${QUEST_LOG_PLUGIN_DIR}/rules/extra.mdc"

	run install_quest_plugin "${tracked_plugin}"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/bash.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/zsh.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/quest-author/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/quest-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}/skills/quest-retired" ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/rules/extra.mdc" ]]
}
