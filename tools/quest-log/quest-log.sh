#!/usr/bin/env bash
#
# Generate agentic tool rules for Cursor based on schema.json
#

_QUEST_LOG_SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
_QUEST_LOG_SCRIPT_DIR="$(cd "$(dirname "${_QUEST_LOG_SCRIPT_PATH}")" && pwd)"
source "${_QUEST_LOG_SCRIPT_DIR}/lib/io.sh"
source "${_QUEST_LOG_SCRIPT_DIR}/lib/validate.sh"
source "${_QUEST_LOG_SCRIPT_DIR}/lib/emit_rules.sh"
source "${_QUEST_LOG_SCRIPT_DIR}/lib/emit_docs.sh"

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Generate agentic tool rules and daily-quests for Cursor based on schema.json. Rules
and daily-quests are installed locally in the project directory.
Baseline quests include always, python, shell, lua, and typescript.

OPTIONS:
    -f, --force         Force operations (replace existing VSCode settings)
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Generate rules and daily-quests in git root (if in git repo) or current directory
    $0 /path/to/dir     # Generate rules and daily-quests in git root (if in git repo) or specified directory
EOF
}

DEFAULT_FORCE=false

# Statistics tracking
STATS_CREATED=0
STATS_UPDATED=0
STATS_UNCHANGED=0
STATS_ERRORS=0
STATS_TOTAL_LINES=0
STATS_WARNINGS=0

# Install quest-log rules for Cursor
#
# Side Effects:
# - Creates local Cursor rules directory at TARGET_DIR/.cursor/rules/user/
# - Installs rules from quest-log schema
install_rules() {
	echo "install_rules: running"

	local cursor_rules_dir="${TARGET_DIR}/.cursor/rules/user"

	if ! mkdir -p "${cursor_rules_dir}"; then
		echo "install_rules:: Failed to create Cursor rules directory: ${cursor_rules_dir}" >&2
		return 1
	fi

	local agent_rules_dir="${TARGET_DIR}/.agent/rules"
	if ! mkdir -p "${agent_rules_dir}"; then
		echo "install_rules:: Failed to create Agent rules directory: ${agent_rules_dir}" >&2
		return 1
	fi

	CURSOR_RULES_DIR="${cursor_rules_dir}"
	AGENT_RULES_DIR="${agent_rules_dir}"
	export CURSOR_RULES_DIR AGENT_RULES_DIR

	fill_quest_log "${TARGET_DIR}"

	echo "install_rules: complete"

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
	[[ ${STATS_WARNINGS} -gt 0 ]] && echo "Warnings: ${STATS_WARNINGS}"
	[[ ${STATS_TOTAL_LINES} -gt 0 ]] && echo "Total lines: ${STATS_TOTAL_LINES}"
	echo "Total processed: ${total_processed}"

	echo ""

	if ((STATS_ERRORS > 0)); then
		echo "print_summary:: Some rules failed validation. Please review errors above." >&2
		return 1
	fi

	if ((STATS_WARNINGS > 0)); then
		echo "print_summary:: Some warnings were generated. Please review warnings above."
		return 0
	fi

	echo "print_summary:: All rules processed successfully."

	return 0
}

# Determine the target directory for rule generation
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

# Main entry point for the quest log generator
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Processes command line options
# - Generates rule files
# - Exits with appropriate status code
run_quest_log() {
	echo "quest-log: running"

	if ! command -v jq &>/dev/null; then
		echo "run_quest_log:: jq is required but not installed." >&2
		return 1
	fi

	SCRIPT_PATH="${_QUEST_LOG_SCRIPT_PATH}"
	SCRIPT_DIR="${_QUEST_LOG_SCRIPT_DIR}"
	QUEST_LOG_ROOT="${SCRIPT_DIR}"
	export SCRIPT_DIR

	if [[ ! -f "${SCRIPT_DIR}/../lib/vscodeoverride.sh" ]]; then
		echo "run_quest_log:: vscodeoverride library not found" >&2
		return 1
	fi

	source "${SCRIPT_DIR}/../lib/vscodeoverride.sh"

	QUEST_DIR="${SCRIPT_DIR}/quests"
	export QUEST_DIR

	SCHEMA_FILE=${SCHEMA_FILE:-"${SCRIPT_DIR}/schema.json"}
	FORCE=${FORCE:-${DEFAULT_FORCE}}
	TARGET_DIR=${TARGET_DIR:-${PWD}}

	while [[ $# -gt 0 ]]; do
		case $1 in
		-f | --force)
			FORCE=true
			shift
			;;
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

	GIT_ROOT="${TARGET_DIR}"

	if ! cd "${TARGET_DIR}"; then
		echo "run_quest_log:: Failed to change to target directory: ${TARGET_DIR}" >&2
		return 1
	fi

	if [[ ! -d "${TARGET_DIR}" ]]; then
		echo "run_quest_log:: Target directory is required" >&2
		return 1
	fi

	if [[ ! -r "${SCHEMA_FILE}" ]]; then
		echo "run_quest_log:: Schema file not found: ${SCHEMA_FILE}" >&2
		return 1
	fi

	install_rules

	if [[ -d "${QUEST_LOG_ROOT}/commands" ]]; then
		generate_commands "${TARGET_DIR}"
		generate_workflows "${TARGET_DIR}"
	fi

	vscodeoverride

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
