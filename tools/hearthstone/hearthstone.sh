#!/usr/bin/env bash
#
# Hearthstone setup and sync tool
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEFAULT_TRILLIAX_SCRIPT="$GIT_ROOT/tools/trilliax/trilliax.sh"
DEFAULT_QUESTLOG_SCRIPT="$GIT_ROOT/tools/quest-log/quest-log.sh"

# Default values
DEFAULT_FORCE=false

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Hearthstone setup and sync tool. Runs a series of setup and sync commands
to initialize and synchronize the Zangarmarsh development environment.

OPTIONS:
	-y, --yes           Skip confirmation prompt
	-f, --force         Force operations, run trilliax
	-h, --help          Show this help message
	--health-check      Validate local dependencies and script paths

EOF
}

# Check required external commands and scripts
#
# Side Effects:
# - Writes missing dependency messages to stderr
#
# Returns:
# - 0 when checks pass
# - 1 when any check fails
health_check() {
	local errors=0
	local script_path

	for script_path in \
		"${TRILLIAX_SCRIPT:-${DEFAULT_TRILLIAX_SCRIPT}}" \
		"${QUESTLOG_SCRIPT:-${DEFAULT_QUESTLOG_SCRIPT}}"; do
		if [[ ! -f "${script_path}" ]]; then
			echo "health_check:: script not found: ${script_path}" >&2
			errors=$((errors + 1))
		fi
	done

	if ! command -v jq >/dev/null 2>&1; then
		echo "health_check:: jq is not installed" >&2
		errors=$((errors + 1))
	fi

	if [[ "${errors}" -eq 0 ]]; then
		echo "health_check:: passed"
		return 0
	fi

	echo "health_check:: failed with ${errors} error(s)" >&2

	return 1
}

# Prompt user to confirm proceeding with destructive operations
#
# Outputs:
# - Warning message and confirmation prompt to stdout
# - Cancellation message to stdout if user declines
#
# Returns:
# - 0 if user confirms with y/yes/Y
# - 1 if user declines or provides invalid input
confirm_proceed() {
	local build_deck_msg="build_deck: Build the deck, install packages, etc."
	local questlog_msg="questlog: Install the local quest-log plugin, sync VSCode settings"
	local trilliax_msg="trilliax --all: Clean generated files and directories"

	cat <<EOF
This script performs destructive operations. You will be prompted
to confirm before proceeding unless the -y flag is provided.

OPERATIONS:
EOF

	local msg
	for msg in "$build_deck_msg" "$questlog_msg" "$trilliax_msg"; do
		echo "${msg}"
	done

	local response
	read -r -p "Do you want to proceed? [y/N] " response
	if [[ "${response}" != [yY][eE][sS] && "${response}" != [yY] ]]; then
		echo "confirm_proceed:: Operation cancelled by user"
		return 1
	fi

	return 0
}

# Verify that the Zangarmarsh directory structure is valid
#
# Outputs:
# - Error messages to stderr if validation fails
#
# Returns:
# - 0 if directory structure is valid
# - 1 if git root directory is missing
# - 1 if tools directory is missing
verify_git_repository() {
	if [[ ! -d "${GIT_ROOT:-}" ]]; then
		echo "verify_git_repository:: Zangarmarsh root directory not found: ${GIT_ROOT:-}" >&2
		return 1
	fi

	if [[ ! -d "${GIT_ROOT}/tools" ]]; then
		echo "verify_git_repository:: Invalid Zangarmarsh structure: tools directory not found" >&2
		return 1
	fi

	return 0
}

# Ensure jq is available on PATH
#
# Outputs:
# - Status messages to stdout when jq is present
# - Guidance to stderr when jq is missing
#
# Returns:
# - 0 if jq is already installed
# - 1 if jq is missing
ensure_jq() {
	if command -v jq &>/dev/null; then
		echo "ensure_jq:: jq installed"
		return 0
	fi

	echo "ensure_jq:: jq not found" >&2

	if command -v apt-get &>/dev/null; then
		echo "ensure_jq:: Install with: apt-get install jq" >&2
	elif command -v pacman &>/dev/null; then
		echo "ensure_jq:: Install with: pacman -S jq" >&2
	else
		echo "ensure_jq:: Install jq with your OS package manager, then re-run" >&2
	fi

	return 1
}

# Build the deck by ensuring required dependencies are installed
#
# Outputs:
# - Status messages to stdout
# - Error messages to stderr if installation fails
#
# Returns:
# - 0 if all dependencies are successfully installed
# - 1 if jq is missing
build_deck() {
	ensure_jq || {
		echo "build_deck:: Failed to ensure jq" >&2
		return 1
	}

	return 0
}

# Execute the hearthstone operations in sequence
#
# Outputs:
# - Progress messages to stdout
# - Error messages to stderr if any operation fails
#
# Returns:
# - 0 if all operations complete successfully
# - 1 if any operation fails
execute_operations() {
	if [[ -z "${TRILLIAX_SCRIPT:-}" ]] || [[ -z "${QUESTLOG_SCRIPT:-}" ]]; then
		echo "execute_operations:: Required script variables are not set" >&2
		return 1
	fi

	if [[ -z "${GIT_ROOT:-}" ]]; then
		echo "execute_operations:: GIT_ROOT is not set" >&2
		return 1
	fi

	echo "execute_operations:: Running: build_deck"
	build_deck || {
		echo "execute_operations:: Failed to execute: build_deck" >&2
		return 1
	}

	if [[ "${FORCE:-}" = "true" ]]; then
		echo "execute_operations:: Running: trilliax --all ${GIT_ROOT}"
		"${TRILLIAX_SCRIPT}" --all "${GIT_ROOT}" || {
			echo "execute_operations:: Failed to execute: trilliax --all" >&2
			return 1
		}
	fi

	echo "execute_operations:: Running: questlog ${GIT_ROOT}"
	"${QUESTLOG_SCRIPT}" "${GIT_ROOT}" || {
		echo "execute_operations:: Failed to execute: questlog" >&2
		return 1
	}

	return 0
}

run_hearthstone() {
	local trilliax_script="${TRILLIAX_SCRIPT:-${DEFAULT_TRILLIAX_SCRIPT}}"
	local questlog_script="${QUESTLOG_SCRIPT:-${DEFAULT_QUESTLOG_SCRIPT}}"
	FORCE="${FORCE:-${DEFAULT_FORCE}}"

	SKIP_CONFIRMATION=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-y | --yes)
			SKIP_CONFIRMATION=true
			shift
			;;
		-f | --force)
			FORCE=true
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		--health-check)
			health_check
			return $?
			;;
		*)
			echo "run_hearthstone:: Unknown option '${1}'" >&2
			echo "run_hearthstone:: Use '$(basename "$0") --help' for usage information" >&2
			return 1
			;;
		esac
	done

	TRILLIAX_SCRIPT="${trilliax_script}"
	QUESTLOG_SCRIPT="${questlog_script}"

	export FORCE
	export SKIP_CONFIRMATION
	export TRILLIAX_SCRIPT
	export QUESTLOG_SCRIPT

	if ! verify_git_repository; then
		return 1
	fi

	if [[ "${SKIP_CONFIRMATION}" != "true" ]]; then
		if ! confirm_proceed; then
			return 1
		fi
	fi

	cat <<EOF
=====
Running Hearthstone
=====

EOF

	if ! execute_operations; then
		echo "run_hearthstone:: Hearthstone operations failed" >&2
		return 1
	fi

	cat <<EOF

=====
Hearthstone Complete
=====

EOF
	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	run_hearthstone "$@"
	exit $?
fi
