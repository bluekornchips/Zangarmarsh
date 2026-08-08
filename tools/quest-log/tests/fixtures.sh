#!/usr/bin/env bash
#
# Shared fixtures for quest-log Bats tests
#

GIT_ROOT=$(git rev-parse --show-toplevel)
QUEST_LOG_ROOT="$GIT_ROOT/tools/quest-log"
SCRIPT="$QUEST_LOG_ROOT/quest-log.sh"
ZANGARMARSH_VSCODE_DIR="${GIT_ROOT}/.vscode"

export GIT_ROOT
export QUEST_LOG_ROOT
export SCRIPT
export ZANGARMARSH_VSCODE_DIR

# Write a minimal valid plugin source tree at the given path
#
# Inputs:
# - $1, plugin_dir, directory to populate with a fake plugin tree
create_test_plugin_source() {
	local plugin_dir="$1"

	mkdir -p "${plugin_dir}/.cursor-plugin" "${plugin_dir}/rules" "${plugin_dir}/skills/quest-review"
	echo '{"name":"quest-log"}' >"${plugin_dir}/.cursor-plugin/plugin.json"
	echo "rule body" >"${plugin_dir}/rules/always.mdc"
	echo "skill body" >"${plugin_dir}/skills/quest-review/SKILL.md"

	return 0
}

# Per-test setup: temp dir, source quest-log, reset stats
quest_log_test_setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_TEMP_DIR="$(mktemp -d "${base}/quest-log-test.XXXXXX")"
	cd "$TEST_TEMP_DIR" || return 1

	HOME="${TEST_TEMP_DIR}/home"
	mkdir -p "${HOME}"
	export HOME

	PLUGIN_SOURCE_DIR="${TEST_TEMP_DIR}/plugin"
	create_test_plugin_source "${PLUGIN_SOURCE_DIR}"
	export PLUGIN_SOURCE_DIR

	QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log"
	export QUEST_LOG_PLUGIN_DIR

	export TEST_TEMP_DIR
	export GIT_ROOT

	set +e
	trap - EXIT ERR
	source "$SCRIPT"
	SCRIPT_DIR="${QUEST_LOG_ROOT}"
	export SCRIPT_DIR
	export QUEST_LOG_ROOT
	source "${QUEST_LOG_ROOT}/../lib/vscodeoverride.sh"
	trap - EXIT ERR
	set +e

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0

	return 0
}

# Per-test teardown: remove temp dir and reset stats
quest_log_test_teardown() {
	if [[ -n "${TEST_TEMP_DIR}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
		if ! rm -rf "${TEST_TEMP_DIR}"; then
			echo "Failed to cleanup test directory: ${TEST_TEMP_DIR}" >&2
		fi
	fi

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0

	return 0
}

########################################################
# Mock Functions
########################################################

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
