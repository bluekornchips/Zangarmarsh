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

# Per-test setup: temp dir, source quest-log, reset stats
quest_log_test_setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_TEMP_DIR="$(mktemp -d "${base}/quest-log-test.XXXXXX")"
	cd "$TEST_TEMP_DIR"

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
