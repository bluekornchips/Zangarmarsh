#!/usr/bin/env bash
#
# Hearthstone setup and sync tool
#
set -eo pipefail

# Global cleanup trap handler
cleanup() {
	local exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		echo "Error in $0 at line $LINENO" >&2
	fi
}
trap cleanup EXIT ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_TRILLIAX_SCRIPT="$GIT_ROOT/tools/trilliax/trilliax.sh"
DEFAULT_QUESTLOG_SCRIPT="$GIT_ROOT/tools/quest-log/quest-log.sh"
DEFAULT_GDLF_SCRIPT="$HOME/bluekornchips/gandalf/gandalf.sh"

# Default values
DEFAULT_FORCE=false

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Hearthstone setup and sync tool. Runs a series of setup and sync commands
to initialize and synchronize the Zangarmarsh development environment.

OPTIONS:
	-y, --yes     Skip confirmation prompt
	-f, --force   Force operations (replace existing VSCode settings, run trilliax, pass force to gdlf)
	-h, --help    Show this help message

EOF
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
	local build_deck_msg
	local questlog_msg
	local trilliax_msg
	local vscodeoverride_msg
	local gdlf_msg
	local msg
	local response

	build_deck_msg="build_deck: Build the deck, install packages, etc."
	questlog_msg="questlog: Generate agentic tool rules"
	trilliax_msg="trilliax --all: Clean generated files and directories"
	vscodeoverride_msg="vscodeoverride: Sync VSCode settings"
	gdlf_msg="gdlf --install: Install Gandalf MCP server"

	if [[ "${FORCE:-}" = "true" ]]; then
		gdlf_msg="${gdlf_msg} (with --force)"
	fi

	cat <<EOF
WARNING: This script performs destructive operations. You will be prompted
to confirm before proceeding unless the -y flag is provided.

OPERATIONS:
EOF

	for msg in "$build_deck_msg" "$questlog_msg" "$vscodeoverride_msg" "$gdlf_msg" "$trilliax_msg"; do
		echo "${msg}"
	done

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

# Sync VSCode settings from Zangarmarsh root to current directory
#
# Outputs:
# - Status messages to stdout
# - Error messages to stderr if copy operation fails
#
# Returns:
# - 0 if sync is successful or already in git root
# - 1 if copy operation fails
vscodeoverride() {
	if [[ -z "${GIT_ROOT:-}" ]]; then
		echo "vscodeoverride:: GIT_ROOT is not set" >&2
		return 1
	fi

	if [[ ! -d "${GIT_ROOT}/.vscode" ]]; then
		echo "vscodeoverride:: VSCode settings directory not found in ${GIT_ROOT}/.vscode" >&2
		return 1
	fi

	mkdir -p "${PWD}/.vscode"

	if [[ "${FORCE:-}" = "true" ]]; then
		if cp -rf "${GIT_ROOT}/.vscode/"* "${PWD}/.vscode/" 2>/dev/null || true; then
			echo "vscodeoverride:: VSCode settings synced (replaced existing)"
		else
			echo "vscodeoverride:: Failed to copy VSCode settings" >&2
			return 1
		fi
	elif [[ ! "$(ls -A "${PWD}/.vscode" 2>/dev/null)" ]]; then
		if cp -rf "${GIT_ROOT}/.vscode/"* "${PWD}/.vscode/" 2>/dev/null || true; then
			echo "vscodeoverride:: VSCode settings synced"
		else
			echo "vscodeoverride:: Failed to copy VSCode settings" >&2
			return 1
		fi
	else
		echo "vscodeoverride:: VSCode settings already exist (use --force to replace)"
	fi

	return 0
}

# Install jq package using available package manager
#
# Outputs:
# - Status messages to stdout
# - Error messages to stderr if installation fails
#
# Returns:
# - 0 if jq is already installed or installation succeeds
# - 1 if no supported package manager is found or installation fails
install_jq() {
	if command -v jq &>/dev/null; then
		echo "install_jq:: jq installed"
		return 0
	fi

	echo "install_jq:: jq not found, attempting to install."

	if command -v brew &>/dev/null; then
		echo "install_jq:: Using Homebrew to install jq."
		if brew install jq; then
			echo "install_jq:: jq installed successfully"
			return 0
		else
			echo "install_jq:: Failed to install jq with brew. Please install manually: brew install jq" >&2
			return 1
		fi
	elif command -v apt-get &>/dev/null; then
		echo "install_jq:: Using apt-get to install jq."
		echo "install_jq:: Please install jq manually: apt-get install jq" >&2
		return 1
	elif command -v pacman &>/dev/null; then
		echo "install_jq:: Using pacman to install jq."
		echo "install_jq:: Please install jq manually: pacman -S jq" >&2
		return 1
	else
		echo "install_jq:: No supported package manager found. Please install jq manually for your system." >&2
		return 1
	fi
}

# Build the deck by ensuring required dependencies are installed
#
# Outputs:
# - Status messages to stdout
# - Error messages to stderr if installation fails
#
# Returns:
# - 0 if all dependencies are successfully installed
# - 1 if jq installation fails
build_deck() {
	if ! install_jq; then
		echo "build_deck:: Failed to install jq" >&2
		return 1
	fi

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
	if [[ -z "${TRILLIAX_SCRIPT:-}" ]] || [[ -z "${QUESTLOG_SCRIPT:-}" ]] || [[ -z "${GDLF_SCRIPT:-}" ]]; then
		echo "execute_operations:: Required script variables are not set" >&2
		return 1
	fi

	echo "execute_operations:: Running: build_deck"
	if ! build_deck; then
		echo "execute_operations:: Failed to execute: build_deck" >&2
		return 1
	fi

	if [[ "${FORCE:-}" = "true" ]]; then
		echo "execute_operations:: Running: trilliax --all"
		if ! "${TRILLIAX_SCRIPT}" --all; then
			echo "execute_operations:: Failed to execute: trilliax --all" >&2
			return 1
		fi
	fi

	echo "execute_operations:: Running: questlog"
	if ! "${QUESTLOG_SCRIPT}"; then
		echo "execute_operations:: Failed to execute: questlog" >&2
		return 1
	fi

	echo "execute_operations:: Running: vscodeoverride"
	if ! vscodeoverride; then
		echo "execute_operations:: Failed to execute: vscodeoverride" >&2
		return 1
	fi

	echo "execute_operations:: Running: gdlf --install"
	if [[ "${FORCE:-}" = "true" ]]; then
		if ! "${GDLF_SCRIPT}" -i -f; then
			echo "execute_operations:: Failed to execute: gdlf -i -f" >&2
			return 1
		fi
	else
		if ! "${GDLF_SCRIPT}" -i; then
			echo "execute_operations:: Failed to execute: gdlf -i" >&2
			return 1
		fi
	fi

	return 0
}

main() {
	local skip_confirmation
	local trilliax_script
	local questlog_script
	local gdlf_script

	trilliax_script="${TRILLIAX_SCRIPT:-${DEFAULT_TRILLIAX_SCRIPT}}"
	questlog_script="${QUESTLOG_SCRIPT:-${DEFAULT_QUESTLOG_SCRIPT}}"
	gdlf_script="${GDLF_SCRIPT:-${DEFAULT_GDLF_SCRIPT}}"
	FORCE="${FORCE:-${DEFAULT_FORCE}}"

	skip_confirmation=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-y | --yes)
			skip_confirmation=true
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
		*)
			echo "main:: Unknown option '${1}'" >&2
			echo "main:: Use '$(basename "$0") --help' for usage information" >&2
			return 1
			;;
		esac
	done

	TRILLIAX_SCRIPT="${trilliax_script}"
	QUESTLOG_SCRIPT="${questlog_script}"
	GDLF_SCRIPT="${gdlf_script}"

	export FORCE
	export TRILLIAX_SCRIPT
	export QUESTLOG_SCRIPT
	export GDLF_SCRIPT

	if ! verify_git_repository; then
		return 1
	fi

	if [[ "${skip_confirmation}" != "true" ]]; then
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
		echo "main:: Hearthstone operations failed" >&2
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
	main "$@"
	exit $?
fi
