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

setup() {
	TEST_TEMP_DIR=$(mktemp -d)
	# shellcheck disable=SC2164
	cd "$TEST_TEMP_DIR"

	mkdir -p "./$CURSOR_RULES_DIR"
	mkdir -p "./$CLAUDE_DIR"

	# Create test quest file
	TEST_QUEST_FILE=$(mktemp)
	cat >"$TEST_QUEST_FILE" <<EOF
# Test Quest
This is a test quest.
EOF

	TEST_QUEST_JSON='{"name":"test-quest","file":"test-quest.md","icon":"🧪","description":"Test Quest","keywords":["test","quest"],"cursor":{"alwaysApply":false}}'

	export TEST_TEMP_DIR
}

@test 'target_dir is required' {
	export TARGET_DIR="/tmp/does-not-exist"
	run $SCRIPT
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Target directory is required"
}

@test 'yq is required' {
	skip "yq is required but not installed."
	run $SCRIPT
	echo "$output" >&0
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "yq is required but not installed."
}

@test 'jq is required' {
	skip "jq is required but not installed."
	run $SCRIPT
	echo "$output" >&0
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "jq is required but not installed."
}

@test 'schema file is required' {
	export SCHEMA_FILE="/tmp/does-not-exist"
	run $SCRIPT
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Schema file not found"
}

@test 'schema file exists and is readable' {
	[[ -f "$SCHEMA_FILE" ]]
	[[ -r "$SCHEMA_FILE" ]]
}

@test 'Help message is displayed' {
	run $SCRIPT --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules for Cursor and Claude Code"
	echo "$output" | grep -q "backup"
}

@test 'Unknown option shows error' {
	run $SCRIPT --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}

@test 'create_cursor_rule_file:: creates rule file with correct content' {
	source "$SCRIPT"

	local test_name="test-rule"
	local test_description="Test Rule Description"
	local test_always_apply="false"
	local test_content="# Test Content\nThis is test content."

	run create_cursor_rule_file "$test_name" "$test_description" "$test_always_apply" "$test_content"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$test_name.mdc" ]]

	grep -q "description: $test_description" "./$CURSOR_RULES_DIR/rules-$test_name.mdc"
	grep -q "alwaysApply: $test_always_apply" "./$CURSOR_RULES_DIR/rules-$test_name.mdc"
	grep -q "Test Content" "./$CURSOR_RULES_DIR/rules-$test_name.mdc"
}

@test 'update_claude_file:: updates existing claude file' {
	source "$SCRIPT"

	cat >"./$CLAUDE_FILE" <<EOF
# Initial Content
$QUEST_LOG_MARKER
Old rule content
$QUEST_LOG_MARKER
# More Content
EOF

	local test_temp_file=$(mktemp)
	echo "New Rule Content\nThis is new rule content." >"$test_temp_file"

	run update_claude_file "$test_temp_file"
	[[ "$status" -eq 0 ]]

	grep -q "New Rule Content" "./$CLAUDE_FILE"
	grep -q "This is new rule content." "./$CLAUDE_FILE"
	grep -v "Old rule content" "./$CLAUDE_FILE" >/dev/null

	rm -f "$test_temp_file"
}

@test 'update_claude_file:: creates file when none exists' {
	source "$SCRIPT"

	# Remove CLAUDE_FILE if it exists
	rm -f "$CLAUDE_FILE"

	local test_temp_file=$(mktemp)
	echo "Test content for new file" >"$test_temp_file"

	run update_claude_file "$test_temp_file"
	[[ "$status" -eq 0 ]]

	[[ -f "./$CLAUDE_FILE" ]]
	grep -q "$QUEST_LOG_MARKER" "./$CLAUDE_FILE"
	grep -q "Test content for new file" "./$CLAUDE_FILE"

	rm -f "$test_temp_file"
}

@test 'accept_quest:: files are created' {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-always.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-author.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-python.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-shell.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
}
