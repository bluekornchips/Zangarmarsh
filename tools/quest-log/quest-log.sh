#!/usr/bin/env bash
#
# Install the quest-log Cursor plugin and sync .vscode settings
#

_QUEST_LOG_SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
_QUEST_LOG_SCRIPT_DIR="$(cd "$(dirname "${_QUEST_LOG_SCRIPT_PATH}")" && pwd)"
source "${_QUEST_LOG_SCRIPT_DIR}/lib/io.sh"

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Install the quest-log Cursor plugin from tools/quest-log/plugin under
~/.cursor/plugins/local/quest-log, and sync .vscode settings into the
target project directory.

OPTIONS:
    -h, --help          Show this help message
    -r, --dry-run       Show planned changes without writing files

EXAMPLES:
    $0                  # Install plugin, sync .vscode in git root
    $0 /path/to/dir     # Same, syncing .vscode into the given directory tree
EOF
}

# Statistics tracking, updated by write_if_changed during .vscode sync
STATS_CREATED=0
STATS_UPDATED=0
STATS_UNCHANGED=0
STATS_ERRORS=0

DEFAULT_QUEST_LOG_PLUGIN_DIR="${HOME}/.cursor/plugins/local/quest-log"

# Validate the plugin installation path before any deletion.
#
# Inputs:
# - $1, install_dir, requested plugin installation directory
#
# Returns:
# - 0 when install_dir is an absolute child of ~/.cursor/plugins/local
# - 1 when the path is unsafe or invalid
validate_plugin_install_dir() {
	local install_dir="$1"
	local allowed_root="${HOME}/.cursor/plugins/local"

	if [[ -z "${HOME:-}" || -z "${install_dir}" || "${install_dir}" != /* ]]; then
		echo "validate_plugin_install_dir:: absolute install path is required" >&2
		return 1
	fi

	case "${install_dir}" in
	*"/../"* | *"/./"* | */.. | */.)
		echo "validate_plugin_install_dir:: path traversal is not allowed" >&2
		return 1
		;;
	esac

	case "${install_dir}" in
	"${allowed_root}"/*)
		;;
	*)
		echo "validate_plugin_install_dir:: install path must be below ${allowed_root}" >&2
		return 1
		;;
	esac

	if [[ "${install_dir}" == "${allowed_root}" || "${install_dir}" == */. || "${install_dir}" == */.. ]]; then
		echo "validate_plugin_install_dir:: refusing unsafe install path: ${install_dir}" >&2
		return 1
	fi

	return 0
}

# Copy the tracked quest-log plugin tree into the local Cursor plugins path
#
# Inputs:
# - $1, plugin_source_dir, the tracked plugin tree under tools/quest-log/plugin
#
# Reads environment:
# - QUEST_LOG_PLUGIN_DIR, optional install destination
#
# Side Effects:
# - Replaces the install directory from a staged copy of plugin_source_dir,
#   so stale files never survive a run
#
# Returns:
# - 0 on success
# - 1 when plugin_source_dir is missing its manifest, or the copy fails
install_quest_plugin() {
	local plugin_source_dir="$1"
	local install_dir="${QUEST_LOG_PLUGIN_DIR:-${DEFAULT_QUEST_LOG_PLUGIN_DIR}}"
	local install_parent
	local staging_dir
	local backup_dir

	[[ -f "${plugin_source_dir}/.cursor-plugin/plugin.json" ]] || {
		echo "install_quest_plugin:: plugin manifest not found: ${plugin_source_dir}/.cursor-plugin/plugin.json" >&2
		return 1
	}
	validate_plugin_install_dir "${install_dir}" || return 1

	install_parent="$(dirname "${install_dir}")"
	ensure_dir "${install_parent}" "install_quest_plugin" || return 1

	echo "install_quest_plugin: running"

	if [[ "${DRY_RUN:-false}" == true ]]; then
		echo "install_quest_plugin: would replace ${install_dir}"
		return 0
	fi

	staging_dir="$(mktemp -d "${install_parent}/.quest-log-staging.XXXXXX")" || {
		echo "install_quest_plugin:: Failed to create staging directory" >&2
		return 1
	}

	if ! cp -R "${plugin_source_dir}/." "${staging_dir}/"; then
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: copy failed" >&2
		return 1
	fi

	backup_dir="$(mktemp -d "${install_parent}/.quest-log-backup.XXXXXX")" || {
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: Failed to create backup directory" >&2
		return 1
	}
	rmdir "${backup_dir}" || {
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: Failed to prepare backup directory" >&2
		return 1
	}

	if [[ -e "${install_dir}" || -L "${install_dir}" ]]; then
		if ! mv "${install_dir}" "${backup_dir}"; then
			rm -rf "${staging_dir}"
			echo "install_quest_plugin:: Failed to stage existing installation" >&2
			return 1
		fi
	fi

	if ! mv "${staging_dir}" "${install_dir}"; then
		if [[ -e "${backup_dir}" || -L "${backup_dir}" ]]; then
			mv "${backup_dir}" "${install_dir}" || true
		fi
		rm -rf "${staging_dir}"
		echo "install_quest_plugin:: Failed to activate staged installation" >&2
		return 1
	fi

	rm -rf "${backup_dir}"

	echo "install_quest_plugin: complete"

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

# Determine the target directory for .vscode sync
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

# Main entry point for quest-log
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Installs the plugin, syncs .vscode, prints summary
# - Exits with appropriate status code
run_quest_log() {
	echo "quest-log: running"

	SCRIPT_PATH="${_QUEST_LOG_SCRIPT_PATH}"
	SCRIPT_DIR="${_QUEST_LOG_SCRIPT_DIR}"
	QUEST_LOG_ROOT="${SCRIPT_DIR}"
	PLUGIN_SOURCE_DIR="${PLUGIN_SOURCE_DIR:-${QUEST_LOG_ROOT}/plugin}"
	TARGET_DIR_IS_EXPLICIT=false
	DRY_RUN=false
	export SCRIPT_DIR
	export QUEST_LOG_ROOT
	export PLUGIN_SOURCE_DIR

	[[ -f "${SCRIPT_DIR}/../lib/vscodeoverride.sh" ]] || {
		echo "run_quest_log:: vscodeoverride library not found" >&2
		return 1
	}
	source "${SCRIPT_DIR}/../lib/vscodeoverride.sh"

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

	GIT_ROOT="${TARGET_DIR}"

	cd "${TARGET_DIR}" || {
		echo "run_quest_log:: Failed to change to target directory: ${TARGET_DIR}" >&2
		return 1
	}

	[[ -d "${TARGET_DIR}" ]] || {
		echo "run_quest_log:: Target directory is required" >&2
		return 1
	}

	export DRY_RUN
	install_quest_plugin "${PLUGIN_SOURCE_DIR}" || return 1

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
