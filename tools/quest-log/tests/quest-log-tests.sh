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

setup() {
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

	# shellcheck disable=SC1091
	source "$SCRIPT"
}

########################################################
# mock functions
########################################################
mock_yq_not_installed() {
	#shellcheck disable=SC2329
	yq() {
		echo "yq is required but not installed"
		return 1
	}
	export -f yq
}

mock_jq_not_installed() {
	#shellcheck disable=SC2329
	jq() {
		echo "jq is required but not installed"
		return 1
	}
	export -f jq
}

########################################################
# main
########################################################
@test 'main:: requires target directory' {
	export TARGET_DIR="/tmp/does-not-exist"
	run $SCRIPT
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Target directory is required"
}

@test 'main:: requires readable schema file' {
	export SCHEMA_FILE="/tmp/does-not-exist"
	run $SCRIPT
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
	run $SCRIPT --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules for Cursor and Claude Code"
	echo "$output" | grep -q "backup"
}

@test 'main:: handles unknown options' {
	run $SCRIPT --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}

@test 'create_cursor_rule_file:: creates rule file with correct content' {
	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content"
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-$quest_name.mdc" ]]
	grep -q "description: $description" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
	grep -q "alwaysApply: $always_apply" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
	grep -q "Test Content" "./$CURSOR_RULES_DIR/rules-$quest_name.mdc"
}

########################################################
# update_claude_file
########################################################
@test 'update_claude_file:: updates existing claude file' {
	source "$SCRIPT"

	cat >"./$CLAUDE_FILE" <<EOF
# Initial Content
$QUEST_LOG_MARKER
Old rule content
$QUEST_LOG_MARKER
# More Content
EOF

	local temp_file
	temp_file=$(mktemp)
	echo -e "New Rule Content\nThis is new rule content." >"$temp_file"

	run update_claude_file "$temp_file"
	[[ "$status" -eq 0 ]]

	grep -q "New Rule Content" "./$CLAUDE_FILE"
	grep -q "This is new rule content." "./$CLAUDE_FILE"
	grep -v "Old rule content" "./$CLAUDE_FILE" >/dev/null
}

@test 'update_claude_file:: creates file when none exists' {
	rm -f "$CLAUDE_FILE"

	local temp_file
	temp_file=$(mktemp)
	echo "Test content for new file" >"$temp_file"

	run update_claude_file "$temp_file"
	[[ "$status" -eq 0 ]]

	[[ -f "./$CLAUDE_FILE" ]]
	grep -q "$QUEST_LOG_MARKER" "./$CLAUDE_FILE"
	grep -q "Test content for new file" "./$CLAUDE_FILE"
}

########################################################
# fill_quest_log
########################################################
@test 'fill_quest_log:: generates all rule files' {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-always.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-author.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-python.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-shell.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-lotr.mdc" ]]
	[[ -f "./$CURSOR_RULES_DIR/rules-warcraft.mdc" ]]
}

@test 'fill_quest_log:: generates non-empty files' {
	run $SCRIPT
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if [[ ! -s "$file" ]]; then
			echo "File $file is empty"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with rule headers' {
	run $SCRIPT
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if ! grep -q "RULE APPLIED:" "$file"; then
			echo "File $file does not contain RULE APPLIED header"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with proper formatting' {
	run $SCRIPT
	[[ "$status" -eq 0 ]]

	for file in "./$CURSOR_RULES_DIR"/*.mdc; do
		if ! grep -q "^\*\*RULE APPLIED:" "$file"; then
			echo "File $file does not have proper RULE APPLIED header"
			return 1
		fi
	done
}

@test 'main:: handles help option' {
	run $SCRIPT --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules"
}

@test 'main:: handles invalid options' {
	run $SCRIPT --invalid-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}
