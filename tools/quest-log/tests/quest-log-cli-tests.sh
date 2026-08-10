#!/usr/bin/env bats
#
# Tests for determine_target_directory, print_summary, vscodeoverride,
# and run_quest_log
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
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"
	source "${ZANGARMARSH_ROOT}/tools/lib/vscodeoverride.sh"
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

	return 0
}

mock_git_in_repo() {
	git() {
		case "$1" in
		"rev-parse")
			if [[ "$2" == "--show-toplevel" ]]; then
				echo "$TEST_TEMP_DIR"
				return 0
			fi
			;;
		esac
		command git "$@"
	}
	export -f git

	return 0
}

mock_git_not_in_repo() {
	git() {
		case "$1" in
		"rev-parse")
			if [[ "$2" == "--show-toplevel" ]]; then
				echo "fatal: not a git repository" >&2
				return 128
			fi
			;;
		esac
		command git "$@"
	}
	export -f git

	return 0
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
	echo "$output" | grep -q "quest-log summary"
	echo "$output" | grep -q "vscode created: 2"
	echo "$output" | grep -q "vscode updated: 3"
	echo "$output" | grep -q "vscode unchanged: 1"
	echo "$output" | grep -q "vscode total: 6"
}

@test 'print_summary:: returns error status when errors exist' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=1

	run print_summary
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "vscode: 1 error(s)"
	echo "$output" | grep -q "print_summary:: vscode sync failed"
}

@test 'print_summary:: reports no vscode file sync when counters are zero' {
	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscode: no files synced"
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
	echo "$output" | grep -q "vscodeoverride:: VSCode template directory not found"
}

@test 'run_quest_log:: sets Cursor preferredDarkColorTheme from template' {
	mock_git_in_repo

	mkdir -p "${HOME}/.config/Cursor/User"
	printf '%s\n' '{
    "window.autoDetectColorScheme": true,
    "workbench.preferredDarkColorTheme": "Visual Studio Dark"
}' >"${HOME}/.config/Cursor/User/settings.json"

	run run_quest_log
	[[ "$status" -eq 0 ]]
	jq -e '.["workbench.preferredDarkColorTheme"] == "Default Dark+"' "${HOME}/.config/Cursor/User/settings.json"
	jq -e '.["workbench.colorTheme"] == "Default Dark+"' "${HOME}/.config/Cursor/User/settings.json"
	jq -e '.["window.autoDetectColorScheme"] == true' "${HOME}/.config/Cursor/User/settings.json"
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
	echo "$output" | grep -q "quest-log summary"
	echo "$output" | grep -Eq 'vscode: no files synced|vscode total:'
}

@test 'vscodeoverride:: syncs when GIT_ROOT is the Zangarmarsh root' {
	GIT_ROOT="${ZANGARMARSH_ROOT}"
	export GIT_ROOT

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscodeoverride: running"
	echo "$output" | grep -q "vscodeoverride: complete"
	! echo "$output" | grep -q "skipped, target is the Zangarmarsh root"
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
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	[[ -f "${tracked_plugin}/.cursor-plugin/plugin.json" ]]
	local rule
	for rule in always never shell bash zsh python lua javascript typescript; do
		[[ -f "${tracked_plugin}/rules/${rule}.mdc" ]]
	done
	local skill
	for skill in quest-author quest-review quest-bash-review quest-lua-review quest-typescript-review quest-python-project-setup; do
		[[ -f "${tracked_plugin}/skills/${skill}/SKILL.md" ]]
	done
	[[ ! -e "${tracked_plugin}/MCP.md" ]]
}

@test 'tracked plugin:: install replaces a live tree with the declared assets' {
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

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
