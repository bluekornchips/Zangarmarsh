#!/usr/bin/env bash
#
# Install the quest-log Cursor plugin and overwrite host Cursor user settings
#

_QUEST_LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Display usage information
#
# Side Effects:
# - Writes usage text to stdout
#
# Returns:
# - 0 always
usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Install the quest-log Cursor plugin from tools/quest-log/plugin under
~/.cursor/plugins/local/quest-log, sync rules into ~/.cursor/rules, and
overwrite host Cursor user settings from tools/vscode/settings.json.

By default only blue-author, blue-optical, blue-review, and blueberry are
installed. blueberry also pulls blue-penmanship.
Pass --all for every skill, or --skill for a custom set.

OPTIONS:
    -h, --help          Show this help message
    -r, --dry-run       Show planned changes without writing files
    -a, --all           Install every skill from the plugin tree
        --skill NAME    Install NAME; repeat the flag or pass comma-separated names

EXAMPLES:
    $0                  # Default skills, rules, and Cursor settings
    $0 --all            # Every skill
    $0 --skill blue-diagnose
    $0 --skill blue-review --skill blue-optical
    $0 --skill blue-review,blue-diagnose
    $0 --dry-run        # Show planned plugin, rules, and settings writes
EOF

	return 0
}

# Main entry point for quest-log
#
# Inputs:
# - All command line arguments
#
# Reads environment:
# - DRY_RUN, must be exactly true or false when set
# - QUEST_LOG_SKILLS, used when neither --all nor --skill is given
#
# Side Effects:
# - Installs the plugin and user rules, overwrites host Cursor settings
#
# Returns:
# - 0 on success
# - 1 on validation or apply failure
run_quest_log() {
	local DRY_RUN="${DRY_RUN:-false}"
	if [[ "${DRY_RUN}" != "true" && "${DRY_RUN}" != "false" ]]; then
		echo "run_quest_log:: DRY_RUN must be true or false" >&2
		return 1
	fi

	local want_all=false
	local skill_args=()

	while (($# > 0)); do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		-r | --dry-run)
			DRY_RUN=true
			shift
			;;
		-a | --all)
			want_all=true
			shift
			;;
		--skill)
			shift
			if [[ $# -eq 0 || "$1" == -* ]]; then
				echo "run_quest_log:: --skill needs a skill name" >&2
				return 1
			fi

			skill_args+=("$1")
			shift
			;;
		-*)
			echo "run_quest_log:: Unknown option '${1}'" >&2
			echo "run_quest_log:: Use '$(basename "$0") --help' for usage information" >&2
			usage >&2
			return 1
			;;
		*)
			echo "run_quest_log:: Unexpected argument: ${1}" >&2
			usage >&2
			return 1
			;;
		esac
	done

	quest_log_apply_skill_flags "${want_all}" "${skill_args[@]}" || return 1

	echo "quest-log: running"

	apply_quest_log || return 1

	echo "quest-log: complete"

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	source "${_QUEST_LOG_DIR}/../lib/repo.sh"
	ensure_zangarmarsh_repo "${_QUEST_LOG_DIR}" || exit 1
	source "${_QUEST_LOG_DIR}/lib/apply.sh"
	run_quest_log "$@"
	exit $?
fi
