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
  1. trilliax --all       Clean generated files and directories
  2. questlog             Generate agentic tool rules
  3. vscodeoverride       Sync VSCode settings
  4. gdlf --install      Force install Gandalf MCP server

OPTIONS:
  -y, --yes   Skip confirmation prompt
  -h, --help  Show this help message

EOF
}

# Prompt user to confirm proceeding with destructive operations
#
# Side Effects:
# - Prompts user for input if not in non-interactive mode
# - Returns 1 if user does not confirm
confirm_proceed() {
	cat <<EOF

WARNING: This script will perform destructive operations:
  - Clean generated files and directories (trilliax --all)
  - Regenerate agentic tool rules (questlog)
  - Sync VSCode settings (vscodeoverride)
  - Force reinstall Gandalf MCP server (gdlf --install)

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
# Side Effects:
# - Exits with error if directory structure is invalid
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

# Execute the hearthstone operations
#
# Side Effects:
# - Executes trilliax with --all flag
# - Executes questlog
# - Executes vscodeoverride
# - Executes gdlf with --install flag
execute_operations() {
	echo "Running: trilliax --all"
	if ! "$TRILLIAX_SCRIPT" --all; then
		echo "Failed to execute: trilliax --all" >&2
		return 1
	fi

	echo "Running: questlog"
	if ! "$QUESTLOG_SCRIPT"; then
		echo "Failed to execute: questlog" >&2
		return 1
	fi

	echo "Running: vscodeoverride"
	if [[ "$PWD" != "$GIT_ROOT" ]]; then
		mkdir -p "$PWD/.vscode"
		if ! cp -rf "$GIT_ROOT/.vscode/"* "$PWD/.vscode/"; then
			echo "Failed to execute: vscodeoverride" >&2
			return 1
		fi
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
		case $1 in
		-y | --yes)
			skip_confirmation=true
			shift
			;;
		-h | --help) usage && return 0 ;;
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
