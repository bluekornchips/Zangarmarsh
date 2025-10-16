#!/usr/bin/env bash
#
# Hearthstone setup and sync tool
#
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_TRILLIAX_SCRIPT="$GIT_ROOT/tools/trilliax/trilliax.sh"
DEFAULT_QUESTLOG_SCRIPT="$GIT_ROOT/tools/quest-log/quest-log.sh"
DEFAULT_GDLF_SCRIPT="$HOME/bluekornchips/gandalf/gandalf.sh"

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Hearthstone setup and sync tool. Runs a series of setup and sync commands
to initialize and synchronize the Zangarmarsh development environment.

WARNING: This script performs destructive operations. You will be prompted
to confirm before proceeding unless the -y flag is provided.

OPERATIONS:
	build_deck           Build the deck, install packages, etc.
	questlog             Generate agentic tool rules
	vscodeoverride       Sync VSCode settings
	trilliax --all       Clean generated files and directories
	gdlf --install       Install Gandalf MCP server

OPTIONS:
	-y, --yes   Skip confirmation prompt
	-h, --help  Show this help message

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
	cat <<EOF

WARNING: This script will perform destructive operations:
	- Clean generated files and directories (trilliax --all)
	- Regenerate agentic tool rules (questlog)
	- Sync VSCode settings (vscodeoverride)
	- Install Gandalf MCP server (gdlf --install)

EOF

	read -r -p "Do you want to proceed? [y/N] " response
	case "$response" in
	[yY][eE][sS] | [yY])
		return 0
		;;
	*)
		echo "Operation cancelled by user"
		return 1
		;;
	esac
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
	if [[ ! -d "$GIT_ROOT" ]]; then
		echo "Zangarmarsh root directory not found: $GIT_ROOT" >&2
		return 1
	fi

	if [[ ! -d "$GIT_ROOT/tools" ]]; then
		echo "Invalid Zangarmarsh structure: tools directory not found" >&2
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
	# Ensure VSCode settings directory exists in current working directory
	mkdir -p "$PWD/.vscode"

	# Copy VSCode settings from Zangarmarsh root to current directory, if they
	# don't already exist in the current directory.
	if [[ ! -d "$PWD/.vscode" ]]; then
		if ! cp -rf "$GIT_ROOT/.vscode/"* "$PWD/.vscode/"; then
			echo "Failed to sync VSCode settings" >&2
			return 1
		fi
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
		echo "jq installed"
		return 0
	fi

	echo "jq not found, attempting to install."

	# Select package manager and install based on available tools
	if command -v brew &>/dev/null; then
		echo "Using Homebrew to install jq."
		if brew install jq; then
			return 0
		else
			echo "Failed to install jq with brew. Please install manually: brew install jq" >&2
			return 1
		fi
	elif command -v apt-get &>/dev/null; then
		echo "Using apt-get to install jq."
		if sudo apt-get install -y jq 2>/dev/null; then
			echo "jq installed successfully"
			return 0
		else
			echo "Failed to install jq with apt-get. Please install manually: sudo apt-get install jq" >&2
			return 1
		fi
	elif command -v pacman &>/dev/null; then
		echo "Using pacman to install jq."
		if sudo pacman -S jq; then
			echo "jq installed successfully"
			return 0
		else
			echo "Failed to install jq with pacman. Please install manually: sudo pacman -S jq" >&2
			return 1
		fi
	else
		echo "No supported package manager found. Please install jq manually for your system." >&2
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
	echo "Running: build_deck"
	if ! build_deck; then
		echo "Failed to execute: build_deck" >&2
		return 1
	fi

	echo "Running: questlog"
	if ! "$QUESTLOG_SCRIPT"; then
		echo "Failed to execute: questlog" >&2
		return 1
	fi

	echo "Running: vscodeoverride"
	if ! vscodeoverride; then
		echo "Failed to execute: vscodeoverride" >&2
		return 1
	fi

	echo "Running: trilliax --all"
	if ! "$TRILLIAX_SCRIPT" --all; then
		echo "Failed to execute: trilliax --all" >&2
		return 1
	fi

	echo "Running: gdlf --install"
	if ! "$GDLF_SCRIPT" --install; then
		echo "Failed to execute: gdlf --install" >&2
		return 1
	fi

	return 0
}

main() {
	TRILLIAX_SCRIPT="${TRILLIAX_SCRIPT:-$DEFAULT_TRILLIAX_SCRIPT}"
	QUESTLOG_SCRIPT="${QUESTLOG_SCRIPT:-$DEFAULT_QUESTLOG_SCRIPT}"
	GDLF_SCRIPT="${GDLF_SCRIPT:-$DEFAULT_GDLF_SCRIPT}"

	local skip_confirmation=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-y | --yes)
			skip_confirmation=true
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		*)
			echo "Unknown option '$1'" >&2
			echo "Use '$(basename "$0") --help' for usage information" >&2
			return 1
			;;
		esac
	done

	if ! verify_git_repository; then
		return 1
	fi

	if [[ "$skip_confirmation" != "true" ]]; then
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
		echo "Hearthstone operations failed" >&2
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
fi
