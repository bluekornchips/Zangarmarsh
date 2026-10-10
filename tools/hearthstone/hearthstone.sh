#!/usr/bin/env bash
#
# Hearthstone setup and sync tool
#

_HEARTHSTONE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Load shared repo helpers and export ZANGARMARSH_ROOT when needed
#
# Side Effects:
# - Sources tools/lib/repo.sh
# - Exports ZANGARMARSH_ROOT
#
# Returns:
# - 0 on success
# - 1 when bootstrap fails
_hearthstone_bootstrap() {
	[[ -n "${ZANGARMARSH_ROOT:-}" && -f "${ZANGARMARSH_ROOT}/zangarmarsh.sh" ]] && return 0

	source "${_HEARTHSTONE_DIR}/../lib/repo.sh" || return 1
	ensure_zangarmarsh_repo "${_HEARTHSTONE_DIR}" || return 1

	return 0
}

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

	return 0
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
		"${TRILLIAX_SCRIPT}" \
		"${QUESTLOG_SCRIPT}"; do
		if [[ ! -f "${script_path}" ]]; then
			echo "health_check:: script not found: ${script_path}" >&2
			errors=$((errors + 1))
		fi
	done

	if ! command -v jq >/dev/null 2>&1; then
		echo "health_check:: jq is not installed" >&2
		errors=$((errors + 1))
	fi

	if ((errors == 0)); then
		echo "health_check:: passed"
		return 0
	fi

	echo "health_check:: failed with ${errors} error(s)" >&2

	return 1
}

# Prompt user to confirm the operations this run will perform
#
# Inputs:
# - $1 force, true when trilliax cleanup will run
#
# Outputs:
# - Planned operations and confirmation prompt to stdout
# - Cancellation message to stderr if user declines
#
# Returns:
# - 0 if user confirms with y or yes
# - 1 if user declines or provides invalid input
confirm_proceed() {
	local force="${1:-false}"
	local operations=()
	operations+=("ensure_jq: Ensure jq is available on PATH")
	operations+=("questlog: Install the local quest-log plugin and overwrite Cursor user settings")
	if [[ "${force}" == true ]]; then
		operations+=("trilliax --all: Clean generated files and directories")
	fi

	if [[ "${force}" == true ]]; then
		cat <<EOF
This script performs destructive operations, including trilliax cleanup.
You will be prompted to confirm before proceeding unless the -y flag is provided.

OPERATIONS:
EOF
	else
		cat <<EOF
This script checks jq, installs the quest-log plugin, and overwrites Cursor user settings.
You will be prompted to confirm before proceeding unless the -y flag is provided.

OPERATIONS:
EOF
	fi

	local operation
	for operation in "${operations[@]}"; do
		echo "${operation}"
	done

	local response
	read -r -p "Do you want to proceed? [y/N] " response
	if [[ "${response}" != [yY][eE][sS] && "${response}" != [yY] ]]; then
		echo "confirm_proceed:: Operation cancelled by user" >&2
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
	if [[ ! -d "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "verify_git_repository:: Zangarmarsh root directory not found: ${ZANGARMARSH_ROOT:-}" >&2
		return 1
	fi

	if [[ ! -d "${ZANGARMARSH_ROOT}/tools" ]]; then
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

# Execute the hearthstone operations in sequence
#
# Inputs:
# - $1 force, true when trilliax cleanup should run
#
# Outputs:
# - Progress messages to stdout
# - Error messages to stderr if any operation fails
#
# Returns:
# - 0 if all operations complete successfully
# - 1 if any operation fails
execute_operations() {
	local force="${1:-false}"

	if [[ -z "${TRILLIAX_SCRIPT:-}" ]] || [[ -z "${QUESTLOG_SCRIPT:-}" ]]; then
		echo "execute_operations:: Required script variables are not set" >&2
		return 1
	fi

	echo "execute_operations:: Running: ensure_jq"
	ensure_jq || {
		echo "execute_operations:: Failed to execute: ensure_jq" >&2
		return 1
	}

	if [[ "${force}" == true ]]; then
		echo "execute_operations:: Running: trilliax --all ${ZANGARMARSH_ROOT}"
		"${TRILLIAX_SCRIPT}" --all "${ZANGARMARSH_ROOT}" || {
			echo "execute_operations:: Failed to execute: trilliax --all" >&2
			return 1
		}
	fi

	echo "execute_operations:: Running: questlog"
	"${QUESTLOG_SCRIPT}" || {
		echo "execute_operations:: Failed to execute: questlog" >&2
		return 1
	}

	return 0
}

run_hearthstone() {
	local do_health_check=false
	local force=false
	SKIP_CONFIRMATION=false

	_hearthstone_bootstrap || return 1

	while (($# > 0)); do
		case "$1" in
		-y | --yes)
			SKIP_CONFIRMATION=true
			shift
			;;
		-f | --force)
			force=true
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		--health-check)
			do_health_check=true
			shift
			;;
		*)
			echo "run_hearthstone:: Unknown option '${1}'" >&2
			echo "run_hearthstone:: Use '$(basename "$0") --help' for usage information" >&2
			return 1
			;;
		esac
	done

	TRILLIAX_SCRIPT="${TRILLIAX_SCRIPT:-${ZANGARMARSH_ROOT}/tools/trilliax/trilliax.sh}"
	QUESTLOG_SCRIPT="${QUESTLOG_SCRIPT:-${ZANGARMARSH_ROOT}/tools/quest-log/quest-log.sh}"

	export SKIP_CONFIRMATION
	export TRILLIAX_SCRIPT
	export QUESTLOG_SCRIPT

	if [[ "${do_health_check}" == true ]]; then
		health_check
		return $?
	fi

	verify_git_repository || return 1

	if [[ "${SKIP_CONFIRMATION}" != "true" ]]; then
		confirm_proceed "${force}" || return 1
	fi

	cat <<EOF
=====
Running Hearthstone
=====

EOF

	if ! execute_operations "${force}"; then
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
	_hearthstone_bootstrap || exit 1
	run_hearthstone "$@"
	exit $?
fi
