#!/usr/bin/env bash
#
# Install the quest-log Cursor plugin and overwrite host Cursor user settings
#

_QUEST_LOG_SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
_QUEST_LOG_DIR="$(cd "$(dirname "${_QUEST_LOG_SCRIPT_PATH}")" && pwd)"

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Install the quest-log Cursor plugin from tools/quest-log/plugin under
~/.cursor/plugins/local/quest-log and overwrite host Cursor user settings
from tools/vscode/settings.json.

OPTIONS:
    -h, --help          Show this help message
    -r, --dry-run       Show planned changes without writing files

EXAMPLES:
    $0                  # Install plugin and overwrite Cursor user settings
    $0 --dry-run        # Show planned plugin and settings writes
EOF
}

# Statistics tracking, updated by write_if_changed during Cursor settings sync
STATS_CREATED=0
STATS_UPDATED=0
STATS_UNCHANGED=0
STATS_ERRORS=0
PLUGIN_ACTION=""

# Print summary of quest-log work
#
# Side Effects:
# - Displays summary report to stdout
#
# Returns:
# - 0 when STATS_ERRORS is 0
# - 1 when STATS_ERRORS is greater than 0
print_summary() {
	local total_processed=0
	total_processed=$((STATS_CREATED + STATS_UPDATED + STATS_UNCHANGED))

	printf '\nquest-log summary\n'

	case "${PLUGIN_ACTION:-}" in
	installed)
		printf '  plugin: installed\n'
		;;
	dry-run)
		printf '  plugin: dry-run\n'
		;;
	skipped)
		printf '  plugin: skipped\n'
		;;
	esac

	if ((STATS_ERRORS > 0)); then
		printf '  cursor: %s error(s)\n' "${STATS_ERRORS}"
		((STATS_CREATED > 0)) && printf '  cursor created: %s\n' "${STATS_CREATED}"
		((STATS_UPDATED > 0)) && printf '  cursor updated: %s\n' "${STATS_UPDATED}"
		((STATS_UNCHANGED > 0)) && printf '  cursor unchanged: %s\n' "${STATS_UNCHANGED}"
		printf 'print_summary:: cursor settings sync failed\n' >&2
		return 1
	fi

	if ((total_processed == 0)); then
		printf '  cursor: no files synced\n'
	else
		((STATS_CREATED > 0)) && printf '  cursor created: %s\n' "${STATS_CREATED}"
		((STATS_UPDATED > 0)) && printf '  cursor updated: %s\n' "${STATS_UPDATED}"
		((STATS_UNCHANGED > 0)) && printf '  cursor unchanged: %s\n' "${STATS_UNCHANGED}"
		printf '  cursor total: %s\n' "${total_processed}"
	fi

	return 0
}

# Load quest-log libraries after ZANGARMARSH_ROOT is known
#
# Side Effects:
# - Sources apply.sh and its plugin/settings helpers
#
# Returns:
# - 0 on success
# - 1 when ZANGARMARSH_ROOT is unset or sourcing fails
_quest_log_load_libs() {
	[[ -n "${_QUEST_LOG_LIBS_LOADED:-}" ]] && return 0

	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "_quest_log_load_libs:: ZANGARMARSH_ROOT is required" >&2
		return 1
	fi

	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh" || return 1
	_QUEST_LOG_LIBS_LOADED=1

	return 0
}

# Main entry point for quest-log
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Installs the plugin, overwrites host Cursor user settings, prints summary
#
# Returns:
# - 0 on success
# - 1 on validation or apply failure
run_quest_log() {
	local summary_exit_code

	if [[ -z "${ZANGARMARSH_ROOT:-}" || ! -f "${ZANGARMARSH_ROOT}/zangarmarsh.sh" ]]; then
		source "${_QUEST_LOG_DIR}/../lib/repo.sh" || return 1
		ensure_zangarmarsh_repo "${_QUEST_LOG_DIR}" || return 1
	fi

	_quest_log_load_libs || return 1

	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		usage
		return 0
	fi

	echo "quest-log: running"

	SCRIPT_PATH="${_QUEST_LOG_SCRIPT_PATH}"
	SCRIPT_DIR="${ZANGARMARSH_ROOT}/tools/quest-log"
	QUEST_LOG_ROOT="${SCRIPT_DIR}"
	PLUGIN_SOURCE_DIR="${PLUGIN_SOURCE_DIR:-${QUEST_LOG_ROOT}/plugin}"
	DRY_RUN="${DRY_RUN:-false}"
	PLUGIN_ACTION=""
	export SCRIPT_DIR
	export QUEST_LOG_ROOT
	export PLUGIN_SOURCE_DIR

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		-r | --dry-run)
			DRY_RUN=true
			shift
			;;
		-*)
			echo "run_quest_log:: Unknown option: ${1}" >&2
			usage
			return 1
			;;
		*)
			echo "run_quest_log:: Unexpected argument: ${1}" >&2
			usage
			return 1
			;;
		esac
	done

	export DRY_RUN

	# CLI flags are already consumed; apply reads DRY_RUN and PLUGIN_SOURCE_DIR.
	# shellcheck disable=SC2119
	apply_quest_log || return 1

	print_summary
	summary_exit_code=$?

	if ((summary_exit_code == 0)); then
		echo "quest-log: complete"
	fi

	return "${summary_exit_code}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	source "${_QUEST_LOG_DIR}/../lib/repo.sh"
	ensure_zangarmarsh_repo "${_QUEST_LOG_DIR}"
	run_quest_log "$@"
	exit $?
fi
