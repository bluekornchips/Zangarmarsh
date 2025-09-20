#!/usr/bin/env bats

GIT_ROOT=$(git rev-parse --show-toplevel)
QUEST_LOG_ROOT="$GIT_ROOT/tools/quest-log"
SCRIPT="$QUEST_LOG_ROOT/quest-log.sh"
SCHEMA_FILE="$QUEST_LOG_ROOT/schema.yaml"

CLAUDE_DIR=".claude"
CLAUDE_FILE="CLAUDE.md"
CURSOR_RULES_DIR=".cursor/rules"

QUESTMARKER_FILE="$QUEST_LOG_ROOT/QUEST_MARKER.txt"
QUEST_LOG_MARKER=$(cat "$QUESTMARKER_FILE")

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
	mkdir -p "./$CLAUDE_DIR"

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

	# shellcheck disable=SC1090
	source "$SCRIPT"

	return 0
}

########################################################
# Mock Functions
########################################################

# Mock yq command to simulate it not being installed
mock_yq_not_installed() {
	# shellcheck disable=SC2329
	yq() {
		echo "yq is required but not installed"
		return 1
	}
	export -f yq

	return 0
}

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

########################################################
# Main Function Tests
########################################################
@test 'main:: requires target directory' {
	export TARGET_DIR="/tmp/does-not-exist"

	run main
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Target directory is required"
}

@test 'main:: requires readable schema file' {
	export SCHEMA_FILE="/tmp/does-not-exist"

	run main
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Schema file not found"
}

@test 'main:: validates schema file exists and is readable' {
	#shellcheck disable=SC2031
	[[ -f "$SCHEMA_FILE" ]]
	#shellcheck disable=SC2031
	[[ -r "$SCHEMA_FILE" ]]
}

@test 'main:: displays help message' {

	run main --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules for Cursor and Claude Code"
	echo "$output" | grep -q "backup"
}

@test 'main:: handles unknown options' {

	run main --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}

@test 'create_cursor_rule_file:: creates rule file with correct content' {
	# Ensure file doesn't exist first
	rm -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	grep -q "description: $description" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
	grep -q "alwaysApply: $always_apply" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
	grep -q "Test Content" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
}

@test 'create_cursor_rule_file:: updates existing rule file with different content' {
	# Create initial file with different content
	echo "initial content" >"./$CURSOR_RULES_DIR/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	grep -q "description: $description" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
}

@test 'create_cursor_rule_file:: shows no changes when content is identical' {
	# Create file with same content that would be generated
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
	echo "$test_content" >"./$CURSOR_RULES_DIR/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	echo "$output" | grep -q "No changes:"
}

########################################################
# show_diff Function Tests
########################################################

@test 'show_diff:: shows diff for new file' {
	local test_file="./test-new-file.txt"
	local new_content="This is new content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	grep -qF "No such file or directory" <<<"$output"
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

	# Should be no output for identical content
	[[ -z "$output" ]]
}

@test 'show_diff:: handles multi-line content' {

	local test_file="./test-multiline-file.txt"
	local new_content="Line 1
Line 2
Line 3"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	# Check for diff error message for non-existent file
	grep -qF "No such file or directory" <<<"$output"
}

@test 'show_diff:: cleans up temporary files' {

	local test_file="./test-cleanup-file.txt"
	local new_content="Test content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	# Verify temp files are cleaned up by checking no temp files exist
	[[ -z "$(find /tmp -name "tmp.*" -user "$(whoami)" 2>/dev/null | head -1)" ]] || true
}

########################################################
# update_claude_file Function Tests
########################################################

@test 'update_claude_file:: updates existing claude file' {

	# Create existing CLAUDE.md file with markers and old content
	cat >"./$CLAUDE_FILE" <<EOF
# Initial Content
$QUEST_LOG_MARKER
Old rule content
$QUEST_LOG_MARKER
# More Content
EOF

	local temp_file
	temp_file=$(mktemp)
	echo "New Rule Content" >"$temp_file"
	echo "This is new rule content." >>"$temp_file"

	run update_claude_file "$temp_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Updating"

	grep -q "New Rule Content" "./$CLAUDE_FILE"
	grep -q "This is new rule content." "./$CLAUDE_FILE"
	grep -v "Old rule content" "./$CLAUDE_FILE" >/dev/null
}

@test 'update_claude_file:: creates file when none exists' {
	# Remove existing CLAUDE.md file to test creation
	rm -f "$CLAUDE_FILE"

	local temp_file
	temp_file=$(mktemp)
	echo "Test content for new file" >"$temp_file"

	run update_claude_file "$temp_file"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CLAUDE_FILE" ]]
	echo "$output" | grep -q "Creating"
	grep -q "$QUEST_LOG_MARKER" "./$CLAUDE_FILE"
	grep -q "Test content for new file" "./$CLAUDE_FILE"
}

@test 'update_claude_file:: shows no changes when content is identical' {
	# Create existing CLAUDE.md file with markers and content
	cat >"./$CLAUDE_FILE" <<EOF
# Initial Content
$QUEST_LOG_MARKER
Test content for new file
$QUEST_LOG_MARKER
# More Content
EOF

	local temp_file
	temp_file=$(mktemp)
	echo "Test content for new file" >"$temp_file"

	run update_claude_file "$temp_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "No changes:"
}

########################################################
# fill_quest_log Function Tests
########################################################
@test 'fill_quest_log:: generates all rule files' {

	run main
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-always.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-author.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-python.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-shell.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
}

@test 'fill_quest_log:: generates non-empty files' {

	run main
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if [[ ! -s "$file" ]]; then
			echo "File $file is empty"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with rule headers' {

	run main
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if ! grep -q "RULE APPLIED:" "$file"; then
			echo "File $file does not contain RULE APPLIED header"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with proper formatting' {

	run main
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if ! grep -q "^RULE APPLIED:" "$file"; then
			echo "File $file does not have proper RULE APPLIED header"
			return 1
		fi
	done
}

@test 'main:: handles help option' {

	run main --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules"
}

@test 'main:: handles invalid options' {

	run main --invalid-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}
