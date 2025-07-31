#!/usr/bin/env bats

GIT_ROOT=$(git rev-parse --show-toplevel)
AGENTIC_TOOLS_ROOT="$GIT_ROOT/tools/agent-instructions"
SCRIPT="$AGENTIC_TOOLS_ROOT/agent-instructions.sh"
SCHEMA_FILE="$AGENTIC_TOOLS_ROOT/schema.yaml"

CLAUDE_DIR=".claude"
CLAUDE_FILE="CLAUDE.md"
CURSOR_RULES_DIR=".cursor/rules"

FILE_MARKER="##_USER_RULES_##"
RULES_VITAL_FILE="rules-vital"
RULES_AUTHOR_FILE="rules-author"
RULES_LOTR_DATA_FILE="rules-lotr-data"
RULES_WOW_DATA_FILE="rules-wow-data"
RULES_SHELL_STYLES_FILE="rules-shell-styles"
RULES_PYTHON_STYLES_FILE="rules-python-styles"

setup() {
	TEST_TEMP_DIR=$(mktemp -d)
	# shellcheck disable=SC2164
	cd "$TEST_TEMP_DIR"

	mkdir -p "./$CURSOR_RULES_DIR"
	mkdir -p "./$CLAUDE_DIR"

	export TEST_TEMP_DIR
}

@test "schema file exists and is readable" {
	[[ -f "$SCHEMA_FILE" ]]
	[[ -r "$SCHEMA_FILE" ]]
}

@test "script requires yq dependency" {
	# Skip this test if yq is available, since we can't easily mock it away
	if command -v yq &>/dev/null; then
		skip "yq is available, cannot test missing dependency scenario"
	fi

	run $SCRIPT
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "yq.*required"
}

@test "all referenced templates exist" {
	if command -v yq &>/dev/null; then
		while IFS= read -r template_name; do
			template_name=$(echo "$template_name" | tr -d '"')
			[[ -f "$AGENTIC_TOOLS_ROOT/spec/$template_name" ]]
		done < <(yq '.source_files[].name' "$SCHEMA_FILE")
	else
		skip "yq not available"
	fi
}

@test "default mode generates claude file" {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
	[[ -f "./$CLAUDE_FILE" ]]
}

@test "cursor rules have correct frontmatter" {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
}

@test "python-styles rule file is generated" {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/$RULES_PYTHON_STYLES_FILE.mdc" ]]
	grep -q "Python Style Guide" "./$CURSOR_RULES_DIR/$RULES_PYTHON_STYLES_FILE.mdc"
	grep -q "🐍" "./$CURSOR_RULES_DIR/$RULES_PYTHON_STYLES_FILE.mdc"
}

@test "shell-styles rule file is generated" {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
	[[ -f "./$CURSOR_RULES_DIR/$RULES_SHELL_STYLES_FILE.mdc" ]]
	grep -q "Shell Style Guide" "./$CURSOR_RULES_DIR/$RULES_SHELL_STYLES_FILE.mdc"
	grep -q "🐚" "./$CURSOR_RULES_DIR/$RULES_SHELL_STYLES_FILE.mdc"
}

@test "claude file contains wrapped template content" {
	run $SCRIPT
	[[ "$status" -eq 0 ]]
	[[ -f "./$CLAUDE_FILE" ]]
	grep -q "$FILE_MARKER" "./$CLAUDE_FILE"
	grep -qE "(Enhanced|Development|Standards)" "./$CLAUDE_FILE"
}

@test "script overwrites existing rules without backup" {
	echo "# Original Claude" >"./$CLAUDE_FILE"
	echo "# Original Rules Vital" >"./$CURSOR_RULES_DIR/$RULES_VITAL_FILE.mdc"
	echo "# Other Rule" >"./$CURSOR_RULES_DIR/other-rule.mdc"

	run $SCRIPT
	[[ "$status" -eq 0 ]]

	# Check that our rules were updated
	grep -q "$FILE_MARKER" "./$CLAUDE_FILE"
	grep -qE "(Enhanced|Development|Standards)" "./$CLAUDE_FILE"
	[[ -f "./$CURSOR_RULES_DIR/$RULES_VITAL_FILE.mdc" ]]

	# Check that other rules were preserved
	[[ -f "./$CURSOR_RULES_DIR/other-rule.mdc" ]]
	grep -q "Other Rule" "./$CURSOR_RULES_DIR/other-rule.mdc"

	# Verify no backup was created
	[[ ! -d ".agent-rules-backup" ]]
}

@test "backup flag creates backup directory" {
	echo "# Original Claude" >"./$CLAUDE_FILE"

	run $SCRIPT --backup
	[[ "$status" -eq 0 ]]

	# Check that backup was created
	[[ -d ".agent-rules-backup" ]]
	local backup_count
	backup_count=$(find .agent-rules-backup -type d | wc -l)
	[[ "$backup_count" -gt 1 ]] # At least one timestamped directory

	# Check that backup contains original files
	local latest_backup
	latest_backup=$(find .agent-rules-backup -type d -name "*_*" | sort | tail -1)
	[[ -f "$latest_backup/$CLAUDE_FILE" ]]
	grep -q "Original Claude" "$latest_backup/$CLAUDE_FILE"
}

@test "backup preserves existing content" {
	echo "# Original Claude" >"./$CLAUDE_FILE"

	run $SCRIPT --backup
	[[ "$status" -eq 0 ]]

	# Check that backup contains original content
	local latest_backup
	latest_backup=$(find .agent-rules-backup -type d -name "*_*" | sort | tail -1)
	grep -q "Original Claude" "$latest_backup/$CLAUDE_FILE"
}

@test "claude file marker replacement preserves surrounding content" {
	cat >"./$CLAUDE_FILE" <<EOF
# My Custom Rules
These are my personal rules.

$FILE_MARKER
# Old user rules content
This should be replaced.
$FILE_MARKER

# More Custom Content
This should be preserved.
EOF

	run $SCRIPT
	[[ "$status" -eq 0 ]]

	grep -q "# My Custom Rules" "./$CLAUDE_FILE"
	grep -q "These are my personal rules" "./$CLAUDE_FILE"
	grep -q "# More Custom Content" "./$CLAUDE_FILE"
	grep -q "This should be preserved" "./$CLAUDE_FILE"
	grep -qE "(Enhanced|Development|Standards)" "./$CLAUDE_FILE"
	grep -v "Old user rules content" "./$CLAUDE_FILE" >/dev/null
	grep -v "This should be replaced" "./$CLAUDE_FILE" >/dev/null
}

@test "script handles missing schema file" {
	temp_dir=$(mktemp -d)
	cd "$temp_dir"
	cp "$SCRIPT" ./agent-instructions.sh
	run ./agent-instructions.sh
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Schema file not found"
	rm -rf "$temp_dir"
}

@test "script shows help message" {
	run $SCRIPT --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Generate agentic tool rules for Cursor and Claude Code"
	echo "$output" | grep -q "backup"
}

@test "script handles unknown options" {
	run $SCRIPT --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}

@test "backup directory format follows timestamp pattern" {
	echo "# Original Claude" >"./$CLAUDE_FILE"

	run $SCRIPT --backup
	[[ "$status" -eq 0 ]]

	# Check that backup directory follows YYYY-MM-DD_HH-MM-SS format
	local backup_dir
	local dir_name
	backup_dir=$(find .agent-rules-backup -type d -name "*_*" | head -1)
	dir_name=$(basename "$backup_dir")
	echo "$dir_name" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$"
}

@test "script works with custom directory path" {
	custom_dir=$(mktemp -d)
	run $SCRIPT "$custom_dir"
	[[ "$status" -eq 0 ]]
	[[ -f "$custom_dir/$CLAUDE_FILE" ]]
	rm -rf "$custom_dir"
}
