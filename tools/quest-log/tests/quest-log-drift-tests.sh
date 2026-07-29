#!/usr/bin/env bats
#
# Drift tests: quest and command sources must generate expected artifacts
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
# Generator drift
########################################################

@test 'quest_log_drift:: quests and commands emit matching cursor and agent artifacts' {
	QUEST_LOG_ROOT="${QUEST_LOG_ROOT}"
	export QUEST_LOG_ROOT
	QUEST_DIR="${QUEST_LOG_ROOT}/quests"
	export QUEST_DIR
	SCHEMA_FILE="${SCHEMA_FILE}"
	export SCHEMA_FILE
	CURSOR_RULES_DIR="${TEST_TEMP_DIR}/.cursor/rules/user"
	export CURSOR_RULES_DIR
	AGENT_RULES_DIR="${TEST_TEMP_DIR}/.agent/rules"
	export AGENT_RULES_DIR

	run fill_quest_log "${TEST_TEMP_DIR}"
	[[ "${status}" -eq 0 ]]

	run generate_commands "${TEST_TEMP_DIR}"
	[[ "${status}" -eq 0 ]]

	run generate_workflows "${TEST_TEMP_DIR}"
	[[ "${status}" -eq 0 ]]

	local quest_file
	local quest_name
	for quest_file in "${QUEST_LOG_ROOT}"/quests/*.md; do
		quest_name=$(basename "${quest_file}" .md)
		[[ -f "${TEST_TEMP_DIR}/.cursor/rules/user/rules-${quest_name}.mdc" ]]
		[[ -f "${TEST_TEMP_DIR}/.agent/rules/rules-${quest_name}.md" ]]
	done

	local command_file
	local command_name
	for command_file in "${QUEST_LOG_ROOT}"/commands/*.md; do
		command_name=$(basename "${command_file}" .md)
		[[ -f "${TEST_TEMP_DIR}/.cursor/commands/user/${command_name}.md" ]]
		[[ -f "${TEST_TEMP_DIR}/.agent/workflows/${command_name}.md" ]]
	done

	local workflow_file
	for workflow_file in "${TEST_TEMP_DIR}"/.agent/workflows/*.md; do
		head -n 3 "${workflow_file}" | grep -q '^---$'
		head -n 5 "${workflow_file}" | grep -q '^description:'
	done

	local sample_cursor
	sample_cursor="${TEST_TEMP_DIR}/.cursor/rules/user/rules-always.mdc"
	[[ -f "${sample_cursor}" ]]
	local first_hash
	first_hash=$(cksum <"${sample_cursor}")

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0

	run fill_quest_log "${TEST_TEMP_DIR}"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "No changes:"

	local second_hash
	second_hash=$(cksum <"${sample_cursor}")
	[[ "${first_hash}" == "${second_hash}" ]]
}
