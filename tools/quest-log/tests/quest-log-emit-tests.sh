#!/usr/bin/env bats
#
# Tests for create_cursor_rule_file and fill_quest_log
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
# create_cursor_rule_file
########################################################

@test 'create_cursor_rule_file:: creates rule files with correct content' {
	rm -f "${CURSOR_RULES_DIR}/rules-$quest_name.mdc"
	rm -f "./.agent/rules/rules-$quest_name.md"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content" "[]"
	[[ "$status" -eq 0 ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-$quest_name.mdc" ]]
	[[ -f "./.agent/rules/rules-$quest_name.md" ]]
	grep -q "description: $description" "${CURSOR_RULES_DIR}/rules-$quest_name.mdc"
	grep -q "description: $description" "./.agent/rules/rules-$quest_name.md"
	grep -q "alwaysApply: $always_apply" "${CURSOR_RULES_DIR}/rules-$quest_name.mdc"
	grep -q "alwaysApply: $always_apply" "./.agent/rules/rules-$quest_name.md"
	grep -q "Test Content" "${CURSOR_RULES_DIR}/rules-$quest_name.mdc"
	grep -q "Test Content" "./.agent/rules/rules-$quest_name.md"
}

@test 'create_cursor_rule_file:: updates existing rule file with different content' {
	echo "initial content" >"${CURSOR_RULES_DIR}/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content" "[]"
	[[ "$status" -eq 0 ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-$quest_name.mdc" ]]
	grep -q "description: $description" "${CURSOR_RULES_DIR}/rules-$quest_name.mdc"
}

@test 'create_cursor_rule_file:: shows no changes when content is identical' {
	local test_content
	test_content=$(
		cat <<EOF
---
description: $description
globs: []
alwaysApply: $always_apply
---

$content
EOF
	)
	echo "${test_content}" >"${CURSOR_RULES_DIR}/rules-$quest_name.mdc"

	run create_cursor_rule_file "$quest_name" "$description" "$always_apply" "$content" "[]"
	[[ "$status" -eq 0 ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-$quest_name.mdc" ]]
	echo "$output" | grep -q "No changes:"
}

@test 'create_cursor_rule_file:: tracks created statistics' {
	rm -f "${CURSOR_RULES_DIR}/rules-test-stats.mdc"

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
	echo "old content" >"${CURSOR_RULES_DIR}/rules-test-stats.mdc"

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
globs: []
alwaysApply: false
---

Test content
EOF
	)
	echo "${test_content}" >"${CURSOR_RULES_DIR}/rules-test-stats.mdc"

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
# fill_quest_log
########################################################

@test 'fill_quest_log:: generates core rule files by default' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-always.mdc" ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-typescript.mdc" ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-python.mdc" ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-shell.mdc" ]]
	[[ -f "${CURSOR_RULES_DIR}/rules-lua.mdc" ]]
}

@test 'fill_quest_log:: generates non-empty files' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	for file in "${CURSOR_RULES_DIR}"/*.mdc; do
		if [[ ! -s "$file" ]]; then
			echo "File $file is empty"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with rule headers' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	for file in "${CURSOR_RULES_DIR}"/*.mdc; do
		if ! grep -q "RULE APPLIED:" "$file"; then
			echo "File $file does not contain RULE APPLIED header"
			return 1
		fi
	done
}

@test 'fill_quest_log:: generates files with proper formatting' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	for file in "${CURSOR_RULES_DIR}"/*.mdc; do
		if ! grep -q "^RULE APPLIED:" "$file"; then
			echo "File $file does not have proper RULE APPLIED header"
			return 1
		fi
	done
}
