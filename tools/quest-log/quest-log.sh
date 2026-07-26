#!/usr/bin/env bash
#
# Sync .vscode settings from Zangarmarsh into a target project, with diffs
#

_QUEST_LOG_SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
_QUEST_LOG_SCRIPT_DIR="$(cd "$(dirname "${_QUEST_LOG_SCRIPT_PATH}")" && pwd)"
source "${_QUEST_LOG_SCRIPT_DIR}/lib/io.sh"

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Sync .vscode settings from Zangarmarsh into a target project, printing a
diff for every file that changes.

OPTIONS:
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Sync into git root (if in git repo) or current directory
    $0 /path/to/dir     # Sync into git root (if in git repo) or specified directory
EOF
}

# Statistics tracking
STATS_CREATED=0
STATS_UPDATED=0
STATS_UNCHANGED=0
STATS_ERRORS=0

# Determine the target directory for the sync
#
# Side Effects:
# - Sets TARGET_DIR to git root if in git repo, otherwise uses provided/current directory
# - Outputs status messages for testing
determine_target_directory() {
	local git_root
	if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
		TARGET_DIR="${git_root}"
		echo "git_root: ${git_root}"
	else
		TARGET_DIR=${TARGET_DIR:-${PWD}}
		echo "git_root: none"
	fi

	return 0
}

# Print summary statistics
#
# Side Effects:
# - Displays summary report to stdout
print_summary() {
	local total_processed=0
	total_processed=$((STATS_CREATED + STATS_UPDATED + STATS_UNCHANGED))

	cat <<EOF

=============================
Summary
=============================
EOF
	[[ ${STATS_CREATED} -gt 0 ]] && echo "Created: ${STATS_CREATED}"
	[[ ${STATS_UPDATED} -gt 0 ]] && echo "Updated: ${STATS_UPDATED}"
	[[ ${STATS_UNCHANGED} -gt 0 ]] && echo "Unchanged: ${STATS_UNCHANGED}"
	[[ ${STATS_ERRORS} -gt 0 ]] && echo "Errors: ${STATS_ERRORS}"
	echo "Total processed: ${total_processed}"

	echo ""

	if ((STATS_ERRORS > 0)); then
		echo "print_summary:: Some files failed to sync. Please review errors above." >&2
		return 1
	fi

	echo "print_summary:: All files processed successfully."

	return 0
}

# Main entry point for quest-log
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Processes command line options
# - Syncs .vscode settings into the target directory
# - Exits with appropriate status code
run_quest_log() {
	echo "quest-log: running"

	SCRIPT_PATH="${_QUEST_LOG_SCRIPT_PATH}"
	SCRIPT_DIR="${_QUEST_LOG_SCRIPT_DIR}"
	export SCRIPT_DIR

	if [[ ! -f "${SCRIPT_DIR}/../lib/vscodeoverride.sh" ]]; then
		echo "run_quest_log:: vscodeoverride library not found" >&2
		return 1
	fi

	source "${SCRIPT_DIR}/../lib/vscodeoverride.sh"

	TARGET_DIR=${TARGET_DIR:-${PWD}}

	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			usage
			return 0
			;;
		-*)
			echo "run_quest_log:: Unknown option: ${1}" >&2
			usage
			return 1
			;;
		*)
			TARGET_DIR="${1}"
			shift
			;;
		esac
	done

	determine_target_directory

	if [[ ! -d "${TARGET_DIR}" ]]; then
		echo "run_quest_log:: Target directory does not exist: ${TARGET_DIR}" >&2
		return 1
	fi

	GIT_ROOT="${TARGET_DIR}"

	if ! vscodeoverride; then
		return 1
	fi

	print_summary
	local summary_exit_code=$?

	if ((summary_exit_code == 0)); then
		echo "quest-log: complete"
	fi

	return ${summary_exit_code}
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	run_quest_log "$@"
	exit $?
fi
