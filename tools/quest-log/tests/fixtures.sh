#!/usr/bin/env bash
#
# Shared fixtures for quest-log Bats tests
#

GIT_ROOT=$(git rev-parse --show-toplevel)
QUEST_LOG_ROOT="$GIT_ROOT/tools/quest-log"
SCRIPT="$QUEST_LOG_ROOT/quest-log.sh"
SCHEMA_FILE="$QUEST_LOG_ROOT/schema.json"
ZANGARMARSH_VSCODE_DIR="${GIT_ROOT}/.vscode"

CURSOR_RULES_DIR=".cursor/rules/user"

export GIT_ROOT
export QUEST_LOG_ROOT
export SCRIPT
export SCHEMA_FILE
export ZANGARMARSH_VSCODE_DIR
export CURSOR_RULES_DIR

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

# Per-test setup: temp dir, source quest-log, reset stats
quest_log_test_setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	# Set up test environment and source the script
	TEST_TEMP_DIR="$(mktemp -d "${base}/quest-log-test.XXXXXX")"
	cd "$TEST_TEMP_DIR"

	mkdir -p "${TEST_TEMP_DIR}/.cursor/rules/user" "${TEST_TEMP_DIR}/.agent/rules"

	CURSOR_RULES_DIR="${TEST_TEMP_DIR}/.cursor/rules/user"
	export CURSOR_RULES_DIR
	AGENT_RULES_DIR="${TEST_TEMP_DIR}/.agent/rules"
	export AGENT_RULES_DIR
	QUEST_DIR="${QUEST_LOG_ROOT}/quests"
	export QUEST_DIR
	SCHEMA_FILE="$SCHEMA_FILE"
	export SCHEMA_FILE

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
	export GIT_ROOT

	# Temporarily disable errexit and traps to source script safely
	set +e
	trap - EXIT ERR
	source "$SCRIPT"
	SCRIPT_DIR="${QUEST_LOG_ROOT}"
	export SCRIPT_DIR
	source "${QUEST_LOG_ROOT}/../lib/vscodeoverride.sh"
	# Disable traps again after sourcing (script re-enables them)
	trap - EXIT ERR
	# Keep errexit disabled - bats' run command handles error status
	set +e

	# Reset statistics for test isolation
	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0
	STATS_WARNINGS=0
	STATS_TOTAL_LINES=0

	return 0
}

# Per-test teardown: remove temp dir and reset stats
quest_log_test_teardown() {
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
	jq() {
		echo "jq is required but not installed"
		return 1
	}
	export -f jq

	return 0
}

# Mock git command to simulate being in a git repository
mock_git_in_repo() {
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
