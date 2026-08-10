#!/usr/bin/env bash
#
# Install the quest-log Cursor plugin and overwrite host Cursor user settings
#

_QUEST_LOG_SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Install the quest-log Cursor plugin from tools/quest-log/plugin under
~/.cursor/plugins/local/quest-log and overwrite host Cursor user settings
from tools/vscode/settings.json.

OPTIONS:
    -h, --help          Show this help message
    -r, --dry-run       Show planned changes without writing files

EXAMPLES:
    $0                  # Install plugin and overwrite Cursor user settings
    $0 /path/to/dir     # Same, using the given directory as the working tree
EOF
}

# Statistics tracking, updated by write_if_changed during Cursor settings sync
STATS_CREATED=0
STATS_UPDATED=0
STATS_UNCHANGED=0
STATS_ERRORS=0

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

# Determine the working directory for this quest-log run
#
# Side Effects:
# - Sets TARGET_DIR to git root when no explicit target was supplied
# - Preserves an explicit target directory
# - Outputs status messages for testing
determine_target_directory() {
	local git_root
	if [[ "${TARGET_DIR_IS_EXPLICIT:-false}" == true ]]; then
		echo "target_dir: ${TARGET_DIR}"
		return 0
	fi

	if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
		TARGET_DIR="${git_root}"
		echo "git_root: ${git_root}"
	else
		TARGET_DIR=${TARGET_DIR:-${PWD}}
		echo "git_root: none"
	fi

	return 0
}

# Overwrite host Cursor user settings from tools/vscode/settings.json
#
# Reads environment:
# - ZANGARMARSH_ROOT, HOME, DRY_RUN
#
# Side Effects:
# - Replaces ${HOME}/.config/Cursor/User/settings.json with the template
#
# Returns:
# - 0 on success
# - 1 when the template cannot be read or settings cannot be written
sync_cursor_user_settings() {
	local template="${ZANGARMARSH_ROOT}/tools/vscode/settings.json"
	local settings_file="${HOME}/.config/Cursor/User/settings.json"
	local new_content
	local theme

	if [[ -z "${HOME:-}" ]]; then
		echo "sync_cursor_user_settings:: HOME is required" >&2
		return 1
	fi

	if [[ ! -f "${template}" ]]; then
		echo "sync_cursor_user_settings:: template not found: ${template}" >&2
		return 1
	fi

	if ! command -v jq >/dev/null 2>&1; then
		echo "sync_cursor_user_settings:: jq is required" >&2
		return 1
	fi

	if ! jq -e 'type == "object"' "${template}" >/dev/null 2>&1; then
		echo "sync_cursor_user_settings:: template is not a JSON object: ${template}" >&2
		return 1
	fi

	theme="$(jq -r '.["workbench.colorTheme"] // empty' "${template}")"
	if [[ -z "${theme}" ]]; then
		echo "sync_cursor_user_settings:: workbench.colorTheme not found in ${template}" >&2
		return 1
	fi

	if [[ "${DRY_RUN:-}" == true ]]; then
		echo "sync_cursor_user_settings: would overwrite ${settings_file} from ${template}"
		return 0
	fi

	ensure_dir "$(dirname "${settings_file}")" "sync_cursor_user_settings" || return 1

	new_content="$(jq --indent 4 -n --slurpfile template "${template}" --arg theme "${theme}" '
		$template[0]
		| .["workbench.preferredDarkColorTheme"] = $theme
		| .["workbench.colorTheme"] = $theme
	')" || return 1

	write_if_changed "${settings_file}" "${new_content}"$'\n' "rule" "sync_cursor_user_settings" || return 1

	return 0
}

# Main entry point for quest-log
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Installs the plugin, overwrites host Cursor user settings, prints summary
# - Exits with appropriate status code
run_quest_log() {
	local summary_exit_code

	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "quest-log:: ZANGARMARSH_ROOT is required" >&2
		return 1
	fi

	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"

	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		usage
		return 0
	fi

	echo "quest-log: running"

	SCRIPT_PATH="${_QUEST_LOG_SCRIPT_PATH}"
	SCRIPT_DIR="${ZANGARMARSH_ROOT}/tools/quest-log"
	QUEST_LOG_ROOT="${SCRIPT_DIR}"
	PLUGIN_SOURCE_DIR="${PLUGIN_SOURCE_DIR:-${QUEST_LOG_ROOT}/plugin}"
	TARGET_DIR_IS_EXPLICIT=false
	DRY_RUN=false
	export SCRIPT_DIR
	export QUEST_LOG_ROOT
	export PLUGIN_SOURCE_DIR

	[[ -d "${PLUGIN_SOURCE_DIR}" ]] || {
		echo "run_quest_log:: plugin source not found: ${PLUGIN_SOURCE_DIR}" >&2
		return 1
	}

	while [[ $# -gt 0 ]]; do
		case $1 in
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
			TARGET_DIR="${1}"
			TARGET_DIR_IS_EXPLICIT=true
			shift
			;;
		esac
	done

	TARGET_DIR=${TARGET_DIR:-${PWD}}
	determine_target_directory
	export TARGET_DIR
	export DRY_RUN

	cd "${TARGET_DIR}" || {
		echo "run_quest_log:: Failed to change to target directory: ${TARGET_DIR}" >&2
		return 1
	}

	[[ -d "${TARGET_DIR}" ]] || {
		echo "run_quest_log:: Target directory is required" >&2
		return 1
	}

	install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1
	sync_cursor_user_settings || return 1

	print_summary
	summary_exit_code=$?

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
