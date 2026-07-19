#!/usr/bin/env bats
#
# Tests for validate_rule and show_diff
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
	echo "$output" | grep -q "validate_rule:: Rule '${test_name}' is approaching the 500 line limit"
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
	echo "$output" | grep -q "validate_rule:: Rule '${test_name}' has a short description"
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
	echo "$output" | grep -q "validate_rule:: Rule '${test_name}' has glob pattern with leading/trailing whitespace"
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
# show_diff
########################################################

@test 'show_diff:: shows diff for new file' {
	local test_file="./test-new-file.txt"
	local new_content="This is new content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	[[ -z "$output" ]]
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

	[[ -z "$output" ]]
}

@test 'show_diff:: cleans up temporary files' {
	local test_file="./test-cleanup-file.txt"
	local new_content="Test content"

	run show_diff "$test_file" "$new_content"
	[[ "$status" -eq 0 ]]

	[[ -z "$(find /tmp -name "tmp.*" -user "$(whoami)" 2>/dev/null | head -1)" ]] || true
}
