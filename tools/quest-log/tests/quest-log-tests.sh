#!/usr/bin/env bats

GIT_ROOT=$(git rev-parse --show-toplevel)
QUEST_LOG_ROOT="$GIT_ROOT/tools/quest-log"
SCRIPT="$QUEST_LOG_ROOT/quest-log.sh"
SCHEMA_FILE="$QUEST_LOG_ROOT/schema.json"

CURSOR_RULES_DIR=".cursor/rules"

# Create a test quest file
# Writes json to the given quest file path. Allows for input of custom info.
# Also validates the json
# Inputs
# $1 - quest_file, local path to the quest file
# $2 - quest_name
# $3 - icon
# $4 - description
# $5 - keywords
# $6 - cursor_always_apply
# Outputs
# $0 - status code
create_test_quest_file() {
	local quest_file="$1"
	local quest_name="$2"
	local icon="$3"
	local description="$4"
	local keywords="$5"
	local cursor_always_apply="$6"

	jq -n \
		--arg name "$quest_name" \
		--arg icon "$icon" \
		--arg description "$description" \
		--arg keywords "$keywords" \
		--arg cursor_always_apply "$cursor_always_apply" \
		'{
			"name": $name,
			"icon": $icon,
			"description": $description,
			"keywords": ($keywords | fromjson),
			"cursor": {"alwaysApply": ($cursor_always_apply == "true")}
		}' >"$quest_file"

	return 0
}

setup_file() {
	# Set up test environment for all tests
	# No external dependencies to check for this test suite

	return 0
}

setup() {
	# Set up test environment and source the script
	TEST_TEMP_DIR=$(mktemp -d)
	# shellcheck disable=SC2164
	cd "$TEST_TEMP_DIR"

	mkdir -p "./$CURSOR_RULES_DIR"

	quest_name="test-quest"
	icon="🧪"
	description="Test Rule Description"
	always_apply="false"
	content="# Test Content\nThis is test content."
	keywords='["test","quest"]'
	always_apply="false"

	# Create test quest file
	TEST_QUEST_FILE=$(mktemp)
	create_test_quest_file "$TEST_QUEST_FILE" "$quest_name" "$icon" "$description" "$keywords" "$always_apply"

	export TEST_TEMP_DIR

	# Temporarily disable errexit and traps to source script safely
	set +e
	trap - EXIT ERR
	source "$SCRIPT"
	# Disable traps again after sourcing (script re-enables them)
	trap - EXIT ERR
	# Keep errexit disabled - bats' run command handles error status
	set +e

	# Reset statistics for test isolation
	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_SKIPPED=0
	STATS_ERRORS=0
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=0

	return 0
}

teardown() {
	# Clean up test directory
	if [[ -n "${TEST_TEMP_DIR}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
		if ! rm -rf "${TEST_TEMP_DIR}"; then
			echo "Failed to cleanup test directory: ${TEST_TEMP_DIR}" >&2
		fi
	fi

	# Reset statistics
	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_SKIPPED=0
	STATS_ERRORS=0
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=0

	return 0
}

########################################################
# Mock Functions
########################################################

# Mock jq command to simulate it not being installed
mock_jq_not_installed() {
	# shellcheck disable=SC2329
	jq() {
		echo "jq is required but not installed"
		return 1
	}
	export -f jq

	return 0
}

# Mock git command to simulate being in a git repository
mock_git_in_repo() {
	# shellcheck disable=SC2329
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

# Mock git command to simulate NOT being in a git repository
mock_git_not_in_repo() {
	# shellcheck disable=SC2329
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
	export TARGET_DIR="/some/other/path"

	determine_target_directory
	[[ "$TARGET_DIR" == "$TEST_TEMP_DIR" ]]

	run determine_target_directory
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Git repository detected"
}

@test 'determine_target_directory:: uses current directory when not in git repo' {
	mock_git_not_in_repo
	TARGET_DIR="$TEST_TEMP_DIR"

	run determine_target_directory
	[[ "$status" -eq 0 ]]
	[[ "$TARGET_DIR" == "$TEST_TEMP_DIR" ]]
	echo "$output" | grep -q "Not in a git repository"
}

@test 'determine_target_directory:: uses PWD when TARGET_DIR not set and not in git repo' {
	mock_git_not_in_repo
	unset TARGET_DIR

	run determine_target_directory
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Not in a git repository"
}

########################################################
# validate_rule
########################################################

@test 'validate_rule:: passes validation for valid rule' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2\nLine 3')
	local test_globs="[]"
	local test_description="This is a valid test description"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_ERRORS" -eq 0 ]]
	[[ "$STATS_WARNINGS" -eq 0 ]]
}

@test 'validate_rule:: errors when rule exceeds 500 lines' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line %d\n' {1..501})
	local test_globs="[]"
	local test_description="This is a valid test description"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 1 ]]
	[[ "$STATS_ERRORS" -eq 1 ]]
	echo "$output" | grep -q "validate_rule:: Error: Rule '${test_name}' exceeds 500 lines"
	echo "$output" | grep -q "validate_rule:: Suggestion: Split into multiple rules"
}

@test 'validate_rule:: warns when rule exceeds 400 lines' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line %d\n' {1..401})
	local test_globs="[]"
	local test_description="This is a valid test description"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_ERRORS" -eq 0 ]]
	[[ "$STATS_WARNINGS" -eq 1 ]]
	echo "$output" | grep -q "validate_rule:: Warning: Rule '${test_name}' is approaching the 500 line limit"
}

@test 'validate_rule:: warns for short description with intelligent application' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2')
	local test_globs="[]"
	local test_description="Short"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_WARNINGS" -eq 1 ]]
	echo "$output" | grep -q "validate_rule:: Warning: Rule '${test_name}' has a short description"
}

@test 'validate_rule:: does not warn for short description with globs' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2')
	local test_globs='["**/*.sh"]'
	local test_description="Short"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_WARNINGS" -eq 0 ]]
}

@test 'validate_rule:: errors for empty description' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2')
	local test_globs="[]"
	local test_description=""
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 1 ]]
	[[ "$STATS_ERRORS" -eq 1 ]]
	echo "$output" | grep -q "validate_rule:: Error: Rule '${test_name}' has empty description"
}

@test 'validate_rule:: errors for null description' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2')
	local test_globs="[]"
	local test_description="null"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 1 ]]
	[[ "$STATS_ERRORS" -eq 1 ]]
}

@test 'validate_rule:: errors for invalid globs JSON' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2')
	local test_globs="invalid json"
	local test_description="This is a valid test description"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 1 ]]
	[[ "$STATS_ERRORS" -eq 1 ]]
	echo "$output" | grep -q "validate_rule:: Error: Rule '${test_name}' has invalid globs JSON format"
}

@test 'validate_rule:: warns for glob pattern with whitespace' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line 1\nLine 2')
	local test_globs='["  **/*.sh  "]'
	local test_description="This is a valid test description"
	local test_always_apply="false"

	STATS_ERRORS=0
	STATS_WARNINGS=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_WARNINGS" -eq 1 ]]
	echo "$output" | grep -q "validate_rule:: Warning: Rule '${test_name}' has glob pattern with leading/trailing whitespace"
}

@test 'validate_rule:: tracks total lines' {
	local test_name="test-rule"
	local test_content
	test_content=$(printf 'Line %d\n' {1..10})
	local test_globs="[]"
	local test_description="This is a valid test description"
	local test_always_apply="false"

	STATS_TOTAL_LINES=0

	run validate_rule "${test_name}" "${test_content}" "${test_globs}" "${test_description}" "${test_always_apply}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_TOTAL_LINES" -eq 10 ]]
}

########################################################
# create_cursor_rule_file
########################################################

@test 'create_cursor_rule_file:: creates rule file with correct content' {
	rm -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content" "[]"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	grep -q "description: $description" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
	grep -q "alwaysApply: $always_apply" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
	grep -q "Test Content" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
}

@test 'create_cursor_rule_file:: updates existing rule file with different content' {
	echo "initial content" >"./$CURSOR_RULES_DIR/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content" "[]"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	grep -q "description: $description" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
}

@test 'create_cursor_rule_file:: shows no changes when content is identical' {
	local test_content
	test_content=$(
		cat <<EOF
---
description: $description
globs:
alwaysApply: $always_apply
---

$content
EOF
	)
	echo "${test_content}" >"./$CURSOR_RULES_DIR/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content" "[]"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	echo "$output" | grep -q "No changes:"
}

@test 'create_cursor_rule_file:: tracks created statistics' {
	rm -f "./$CURSOR_RULES_DIR/rules-test-stats.mdc"

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0

	run create_cursor_rule_file "test-stats" "Test Description" "false" "Test content" "[]"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_CREATED" -eq 1 ]]
	[[ "$STATS_UPDATED" -eq 0 ]]
	[[ "$STATS_UNCHANGED" -eq 0 ]]
}

@test 'create_cursor_rule_file:: tracks updated statistics' {
	echo "old content" >"./$CURSOR_RULES_DIR/rules-test-stats.mdc"

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0

	run create_cursor_rule_file "test-stats" "Test Description" "false" "New content" "[]"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_CREATED" -eq 0 ]]
	[[ "$STATS_UPDATED" -eq 1 ]]
	[[ "$STATS_UNCHANGED" -eq 0 ]]
}

@test 'create_cursor_rule_file:: tracks unchanged statistics' {
	local test_content
	test_content=$(
		cat <<EOF
---
description: Test Description
globs:
alwaysApply: false
---

Test content
EOF
	)
	echo "${test_content}" >"./$CURSOR_RULES_DIR/rules-test-stats.mdc"

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0

	run create_cursor_rule_file "test-stats" "Test Description" "false" "Test content" "[]"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_CREATED" -eq 0 ]]
	[[ "$STATS_UPDATED" -eq 0 ]]
	[[ "$STATS_UNCHANGED" -eq 1 ]]
}

@test 'create_cursor_rule_file:: tracks errors when validation fails' {
	STATS_ERRORS=0

	run create_cursor_rule_file "test-error" "" "false" "Test content" "[]"
	[[ "$status" -eq 1 ]]
	[[ "$STATS_ERRORS" -eq 1 ]]
}

########################################################
# show_diff
########################################################

@test 'show_diff:: shows diff for new file' {
	local test_file="./test-new-file.txt"
	local new_content="This is new content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	grep -qF "File does not exist" <<<"$output"
}

@test 'show_diff:: shows diff for existing file with changes' {
	local test_file="./test-existing-file.txt"
	echo "Original content" >"$test_file"
	local new_content="Modified content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	echo "$output" | grep -qF -- "--- $test_file"
	echo "$output" | grep -qF -- "-Original content"
	echo "$output" | grep -qF -- "+Modified content"
}

@test 'show_diff:: shows no diff for identical content' {
	local test_file="./test-identical-file.txt"
	local content="Same content"
	echo "$content" >"$test_file"

	run show_diff "$test_file" "$content"
	[[ "$status" -eq 0 ]]

	[[ -z "$output" ]]
}

@test 'show_diff:: handles multi-line content' {
	local test_file="./test-multiline-file.txt"
	local new_content="Line 1
Line 2
Line 3"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	grep -qF "File does not exist" <<<"$output"
}

@test 'show_diff:: cleans up temporary files' {
	local test_file="./test-cleanup-file.txt"
	local new_content="Test content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	[[ -z "$(find /tmp -name "tmp.*" -user "$(whoami)" 2>/dev/null | head -1)" ]] || true
}

########################################################
# fill_quest_log
########################################################

@test 'fill_quest_log:: generates core rule files by default' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-always.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-author.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-python.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-shell.mdc" ]]
}

@test 'fill_quest_log:: skips warcraft and lotr by default' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ ! -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
	[[ ! -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
	echo "$output" | grep -q "fill_quest_log:: Skipping warcraft"
	echo "$output" | grep -q "fill_quest_log:: Skipping lotr"
}

@test 'fill_quest_log:: generates all rule files with --all flag' {
	run run_quest_log --all
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-always.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-author.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-python.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-shell.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
}

@test 'fill_quest_log:: generates non-empty files' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if [[ ! -s "$file" ]]; then
			echo "File $file is empty"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with rule headers' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if ! grep -q "RULE APPLIED:" "$file"; then
			echo "File $file does not contain RULE APPLIED header"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with proper formatting' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if ! grep -q "^RULE APPLIED:" "$file"; then
			echo "File $file does not have proper RULE APPLIED header"
			return 1
		fi
	done
}

@test 'fill_quest_log:: tracks skipped statistics' {
	STATS_SKIPPED=0

	run fill_quest_log "${TEST_TEMP_DIR}"
	[[ "$status" -eq 0 ]]
	[[ "$STATS_SKIPPED" -eq 2 ]]
	echo "$output" | grep -q "fill_quest_log:: Skipping warcraft"
	echo "$output" | grep -q "fill_quest_log:: Skipping lotr"
}

########################################################
# print_summary
########################################################

@test 'print_summary:: displays summary with all statistics' {
	STATS_CREATED=2
	STATS_UPDATED=3
	STATS_UNCHANGED=1
	STATS_SKIPPED=2
	STATS_ERRORS=0
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=100

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Summary"
	echo "$output" | grep -q "Created: 2"
	echo "$output" | grep -q "Updated: 3"
	echo "$output" | grep -q "Unchanged: 1"
	echo "$output" | grep -q "Skipped: 2"
	echo "$output" | grep -q "Errors: 0"
	echo "$output" | grep -q "Warnings: 0"
	echo "$output" | grep -q "Total processed: 8"
	echo "$output" | grep -q "Total lines: 100"
	echo "$output" | grep -q "print_summary:: All rules processed successfully"
}

@test 'print_summary:: returns error status when errors exist' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_SKIPPED=0
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
	STATS_SKIPPED=0
	STATS_ERRORS=0
	STATS_WARNINGS=1
	STATS_TOTAL_LINES=50

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Warnings: 1"
	echo "$output" | grep -q "print_summary:: Some warnings were generated"
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
	export SCHEMA_FILE="/tmp/does-not-exist"

	run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Schema file not found"
}

@test 'run_quest_log:: validates schema file exists and is readable' {
	#shellcheck disable=SC2031
	[[ -f "$SCHEMA_FILE" ]]
	#shellcheck disable=SC2031
	[[ -r "$SCHEMA_FILE" ]]
}

@test 'run_quest_log:: displays help message' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules for Cursor"
	echo "$output" | grep -q "git"
	echo "$output" | grep -q "all"
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
	echo "$output" | grep -q "Git repository detected"
	echo "$output" | grep -q "using git root: $TEST_TEMP_DIR"
}

@test 'run_quest_log:: uses specified directory when not in git repository' {
	mock_git_not_in_repo

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Not in a git repository"
}

@test 'run_quest_log:: creates files in git root directory when in git repo' {
	mock_git_in_repo

	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/rules/rules-always.mdc" ]]
	[[ -f "$TEST_TEMP_DIR/.cursor/rules/rules-author.mdc" ]]
}

@test 'run_quest_log:: handles --all flag' {
	run run_quest_log --all
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -v "fill_quest_log:: Skipping warcraft"
	echo "$output" | grep -v "fill_quest_log:: Skipping lotr"
	[[ -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
}

@test 'run_quest_log:: handles -a short flag' {
	run run_quest_log -a
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
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
	echo "$output" | grep -q "Skipped: 2"
	[[ -f "./$CURSOR_RULES_DIR/rules-always.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-python.mdc" ]]
}
