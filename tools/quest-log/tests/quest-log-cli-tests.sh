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
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=100

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Created: 2"
	echo "$output" | grep -q "Updated: 3"
	echo "$output" | grep -q "Unchanged: 1"
	echo "$output" | grep -q "Errors: 0"
	echo "$output" | grep -q "Warnings: 0"
	echo "$output" | grep -q "Total processed: 6"
	echo "$output" | grep -q "Total lines: 100"
	echo "$output" | grep -q "print_summary:: All rules processed successfully"
}

@test 'print_summary:: returns error status when errors exist' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=1
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=50

	run print_summary
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Errors: 1"
	echo "$output" | grep -q "print_summary:: Some rules failed validation"
}

@test 'print_summary:: returns success status with warnings' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0
	STATS_WARNINGS=1
	STATS_TOTAL_LINES=50

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Warnings: 1"
	echo "$output" | grep -q "print_summary:: Some warnings were generated"
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
	FORCE=false
	export FORCE

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscodeoverride: complete"
	[[ -d "${GIT_ROOT}/.vscode" ]]
	[[ -f "${GIT_ROOT}/.vscode/settings.json" ]]
	cmp -s "${GIT_ROOT}/.vscode/settings.json" "${ZANGARMARSH_VSCODE_DIR}/settings.json"
}

@test 'vscodeoverride:: skips when directory exists and FORCE is false' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	mkdir -p "${test_git_root}/.vscode"
	echo "existing" >"${test_git_root}/.vscode/settings.json"

	GIT_ROOT="${test_git_root}"
	export GIT_ROOT
	FORCE=false
	export FORCE

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscodeoverride: existing settings kept, use FORCE=true to replace"
	echo "$output" | grep -q "vscodeoverride: complete"
	[[ "$(cat "${GIT_ROOT}/.vscode/settings.json")" == "existing" ]]
}

@test 'vscodeoverride:: replaces when FORCE is true' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	mkdir -p "${test_git_root}/.vscode"
	echo "existing" >"${test_git_root}/.vscode/settings.json"

	GIT_ROOT="${test_git_root}"
	export GIT_ROOT
	FORCE=true
	export FORCE

	run vscodeoverride
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "vscodeoverride: complete"
	cmp -s "${GIT_ROOT}/.vscode/settings.json" "${ZANGARMARSH_VSCODE_DIR}/settings.json"
}

@test 'vscodeoverride:: fails when GIT_ROOT is not set' {
	unset GIT_ROOT
	FORCE=false
	export FORCE

	run vscodeoverride
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "vscodeoverride:: GIT_ROOT is not set"
}

@test 'vscodeoverride:: fails when Zangarmarsh template is missing' {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local test_git_root
	test_git_root="$(mktemp -d "${base}/vscodeoverride-dest.XXXXXX")"
	local fake_script_dir
	fake_script_dir="$(mktemp -d "${base}/vscodeoverride-no-template.XXXXXX")"

	GIT_ROOT="${test_git_root}"
	export GIT_ROOT
	FORCE=false
	export FORCE
	SCRIPT_DIR="${fake_script_dir}"
	export SCRIPT_DIR

	run vscodeoverride
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "vscodeoverride:: VSCode settings directory not found"

	SCRIPT_DIR="${QUEST_LOG_ROOT}"
	export SCRIPT_DIR
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

@test 'run_quest_log:: requires readable schema file' {
	SCHEMA_FILE="/tmp/does-not-exist"
	export SCHEMA_FILE

	run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Schema file not found"
}

@test 'run_quest_log:: validates schema file exists and is readable' {
	[[ -f "$SCHEMA_FILE" ]]
	[[ -r "$SCHEMA_FILE" ]]
}

@test 'run_quest_log:: displays help message' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules for Cursor"
	echo "$output" | grep -q "lua"
	echo "$output" | grep -q "git"
	echo "$output" | grep -q "force"
}

@test 'run_quest_log:: handles unknown options' {
	run run_quest_log --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'run_quest_log:: handles help option' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules"
}

@test 'run_quest_log:: handles invalid options' {
	run run_quest_log --invalid-option
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

@test 'run_quest_log:: creates files in git root directory when in git repo' {
	mock_git_in_repo

	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/rules/user/rules-always.mdc" ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/rules/user/rules-typescript.mdc" ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/rules/user/rules-lua.mdc" ]]
	[[ -f "$TEST_TEMP_DIR/.agent/rules/rules-always.md" ]]
	[[ -f "$TEST_TEMP_DIR/.agent/rules/rules-typescript.md" ]]
	[[ -f "$TEST_TEMP_DIR/.agent/rules/rules-lua.md" ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/commands/user/author.md" ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/commands/user/lua-review.md" ]]
	[[ -f "$TEST_TEMP_DIR/.agent/workflows/author.md" ]]
	[[ -f "$TEST_TEMP_DIR/.agent/workflows/lua-review.md" ]]
}

@test 'run_quest_log:: displays summary at end of execution' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Total processed:"
	echo "$output" | grep -q "Total lines:"
}

@test 'run_quest_log:: validation prevents creation of invalid rules' {
	local invalid_schema
	invalid_schema=$(
		cat <<EOF
[
  {
    "name": "invalid-rule",
    "file": "always.md",
    "icon": "💡",
    "description": "",
    "keywords": ["test"],
    "cursor": {
      "alwaysApply": false,
      "globs": []
    }
  }
]
EOF
	)
	local invalid_schema_file
	invalid_schema_file=$(mktemp)
	echo "${invalid_schema}" >"${invalid_schema_file}"

	SCHEMA_FILE="${invalid_schema_file}"
	QUEST_DIR="${QUEST_LOG_ROOT}/quests"

	STATS_ERRORS=0

	run run_quest_log
	[[ "$STATS_ERRORS" -gt 0 ]]
	echo "$output" | grep -q "validate_rule:: Error"
}

@test 'run_quest_log:: tracks statistics correctly across multiple rules' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Created:"
	echo "$output" | grep -q "Total processed:"
	[[ -f "${CURSOR_RULES_DIR}/rules-always.mdc" ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-python.mdc" ]]
}

@test 'run_quest_log:: handles force flag' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "\-f, \-\-force"
	echo "$output" | grep -q "Force operations"
}

@test 'run_quest_log:: accepts force flag' {
	run run_quest_log --force
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "quest-log: running"
}

@test 'run_quest_log:: accepts short force flag' {
	run run_quest_log -f
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "quest-log: running"
}
