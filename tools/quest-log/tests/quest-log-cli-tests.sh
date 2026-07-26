#!/usr/bin/env bats
#
# Tests for determine_target_directory, print_summary, vscodeoverride, run_quest_log
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

@test 'vscodeoverride:: prints a diff and replaces existing settings' {
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
	echo "$output" | grep -q "Updated:"
	cmp -s "${GIT_ROOT}/.vscode/settings.json" "${ZANGARMARSH_VSCODE_DIR}/settings.json"
}

@test 'vscodeoverride:: reports no changes when settings already match' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	GIT_ROOT="${test_git_root}"
	export GIT_ROOT

	run vscodeoverride
	[[ "$status" -eq 0 ]]

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "No changes:"
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
# run_quest_log
########################################################

@test 'run_quest_log:: fails when target directory does not exist' {
	TARGET_DIR="/tmp/does-not-exist"

	run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Target directory does not exist"
}

@test 'run_quest_log:: displays help message' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Sync .vscode settings"
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

@test 'run_quest_log:: syncs vscode settings into the target directory' {
	run run_quest_log

	[[ "$status" -eq 0 ]]
	[[ -f "$TEST_TEMP_DIR/.vscode/settings.json" ]]
}

@test 'run_quest_log:: displays summary at end of execution' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Total processed:"
}
