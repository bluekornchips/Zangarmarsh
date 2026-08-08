#!/usr/bin/env bash
#
# Install Zangarmarsh and its local Cursor plugin.
#

_INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../tools/quest-log/lib/plugin.sh
source "${_INSTALL_SCRIPT_DIR}/../tools/quest-log/lib/plugin.sh"

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Add or remove Zangarmarsh from ~/.aliases and install its local Cursor plugin.
This setup expects ~/.zshrc and ~/.bashrc to source ~/.aliases.

Options:
  -h, --help       Show this help
  -r, --dry-run    Show changes without modifying user files
  -u, --uninstall  Remove Zangarmarsh and its local Cursor plugin
EOF

	return 0
}

# Validate required environment for install or uninstall
#
# Reads environment:
# - HOME, SCRIPT_ROOT, ALIASES_FILE
#
# Returns:
# - 0 when required values are present and zangarmarsh.sh exists
# - 1 when any required value is missing
validate_install_env() {
	if [[ -z "${HOME:-}" ]]; then
		printf 'validate_install_env:: HOME is required\n' >&2
		return 1
	fi

	if [[ -z "${SCRIPT_ROOT:-}" ]]; then
		printf 'validate_install_env:: SCRIPT_ROOT is required\n' >&2
		return 1
	fi

	if [[ -z "${ALIASES_FILE:-}" ]]; then
		printf 'validate_install_env:: ALIASES_FILE is required\n' >&2
		return 1
	fi

	if [[ ! -f "${SCRIPT_ROOT}/zangarmarsh.sh" ]]; then
		printf 'validate_install_env:: zangarmarsh.sh not found under %s\n' "${SCRIPT_ROOT}" >&2
		return 1
	fi

	return 0
}

# Print the exact ~/.aliases source line, including its trailing newline
#
# Reads environment:
# - SCRIPT_ROOT
#
# Outputs:
# - The source line, terminated with a newline, to stdout
write_source_line() {
	printf 'source "%s/zangarmarsh.sh"\n' "${SCRIPT_ROOT}"
}

# Exact source-line text without a trailing newline, for matching existing lines
#
# Reads environment:
# - SCRIPT_ROOT
#
# Outputs:
# - The source line without a trailing newline, to stdout
source_line_text() {
	printf 'source "%s/zangarmarsh.sh"' "${SCRIPT_ROOT}"
}

# Check whether ALIASES_FILE already sources zangarmarsh.sh
#
# Reads environment:
# - ALIASES_FILE, SCRIPT_ROOT
#
# Returns:
# - 0 when the source line is present
# - 1 when ALIASES_FILE is missing or the source line is absent
has_source_line() {
	[[ -f "${ALIASES_FILE}" ]] || return 1
	grep -Fqx "$(source_line_text)" "${ALIASES_FILE}"
}

# Append the Zangarmarsh source line to ALIASES_FILE
#
# Reads environment:
# - ALIASES_FILE, SCRIPT_ROOT, DRY_RUN
#
# Side Effects:
# - Creates or appends to ALIASES_FILE, unless DRY_RUN is true
#
# Returns:
# - 0 on success, including when already installed or in dry-run mode
# - 1 when environment validation or a write fails
install_zangarmarsh() {
	validate_install_env || return 1

	if has_source_line; then
		printf 'Already installed in %s\n' "${ALIASES_FILE}"
		return 0
	fi

	printf 'Would append to %s:\n' "${ALIASES_FILE}"
	write_source_line
	[[ "${DRY_RUN}" == true ]] && return 0

	if [[ -s "${ALIASES_FILE}" ]] && [[ -n "$(tail -c 1 "${ALIASES_FILE}")" ]]; then
		printf '\n' >>"${ALIASES_FILE}" || {
			printf 'install_zangarmarsh:: failed to append newline to %s\n' "${ALIASES_FILE}" >&2
			return 1
		}
	fi

	if ! write_source_line >>"${ALIASES_FILE}"; then
		printf 'install_zangarmarsh:: failed to append source line to %s\n' "${ALIASES_FILE}" >&2
		return 1
	fi

	printf 'Installed in %s\n' "${ALIASES_FILE}"

	return 0
}

# Install the tracked quest-log Cursor plugin
#
# Reads environment:
# - SCRIPT_ROOT, DRY_RUN, HOME, QUEST_LOG_PLUGIN_DIR
#
# Side Effects:
# - Delegates to install_quest_plugin for the tracked plugin tree
#
# Returns:
# - 0 on success
# - Non-zero when validation or plugin install fails
install_cursor_plugin() {
	validate_install_env || return 1
	install_quest_plugin "${SCRIPT_ROOT}/tools/quest-log/plugin"

	return $?
}

# Remove the Zangarmarsh source line from ALIASES_FILE
#
# Reads environment:
# - ALIASES_FILE, SCRIPT_ROOT, DRY_RUN
#
# Side Effects:
# - Rewrites ALIASES_FILE without the source line, unless DRY_RUN is true
# - Preserves a symlinked ALIASES_FILE by writing through the link
#
# Returns:
# - 0 on success, including when not installed or in dry-run mode
# - 1 when ALIASES_FILE cannot be rewritten
uninstall_zangarmarsh() {
	validate_install_env || return 1

	if ! has_source_line; then
		printf 'Not installed in %s\n' "${ALIASES_FILE}"
		return 0
	fi

	printf 'Would remove from %s:\n' "${ALIASES_FILE}"
	write_source_line
	[[ "${DRY_RUN}" == true ]] && return 0

	local temporary_file
	temporary_file="$(mktemp "${TMPDIR:-/tmp}/zangarmarsh-aliases.XXXXXX")" || {
		printf 'uninstall_zangarmarsh:: failed to create temporary file\n' >&2
		return 1
	}

	local line
	line="$(source_line_text)"
	if ! awk -v line="${line}" '$0 != line' "${ALIASES_FILE}" >"${temporary_file}"; then
		rm -f "${temporary_file}"
		printf 'uninstall_zangarmarsh:: failed to update %s\n' "${ALIASES_FILE}" >&2
		return 1
	fi

	if ! cat "${temporary_file}" >"${ALIASES_FILE}"; then
		rm -f "${temporary_file}"
		printf 'uninstall_zangarmarsh:: failed to replace %s\n' "${ALIASES_FILE}" >&2
		return 1
	fi
	rm -f "${temporary_file}"

	printf 'Uninstalled from %s\n' "${ALIASES_FILE}"

	return 0
}

# Remove the locally installed quest-log Cursor plugin
#
# Reads environment:
# - HOME, DRY_RUN, QUEST_LOG_PLUGIN_DIR
#
# Side Effects:
# - Delegates to uninstall_quest_plugin
#
# Returns:
# - 0 on success
# - Non-zero when uninstall_quest_plugin fails
uninstall_cursor_plugin() {
	uninstall_quest_plugin

	return $?
}

# Parse options and run install or uninstall
#
# Inputs:
# - All command line arguments
#
# Reads environment:
# - SCRIPT_ROOT, ALIASES_FILE, HOME
#
# Side Effects:
# - Sets DRY_RUN
# - Installs or uninstalls Zangarmarsh and the quest-log Cursor plugin
#
# Returns:
# - 0 when every step succeeds
# - 1 when an option is invalid or any step fails
main() {
	local uninstall=false
	local errors=0

	DRY_RUN=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		-r | --dry-run)
			DRY_RUN=true
			;;
		-u | --uninstall)
			uninstall=true
			;;
		*)
			printf 'main:: unknown option: %s\n' "$1" >&2
			printf 'main:: use "%s --help" for usage\n' "$(basename "$0")" >&2
			return 1
			;;
		esac
		shift
	done

	export DRY_RUN

	if [[ "${uninstall}" == true ]]; then
		uninstall_zangarmarsh || errors=$((errors + 1))
		uninstall_cursor_plugin || errors=$((errors + 1))
		[[ "${errors}" -eq 0 ]] && return 0
		return 1
	fi

	# Plugin first, then the shell source line. Roll the plugin back when the
	# aliases update fails so a failed install does not leave a partial setup.
	install_cursor_plugin || return 1
	if ! install_zangarmarsh; then
		uninstall_cursor_plugin || true
		return 1
	fi

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -euo pipefail
	SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	ALIASES_FILE="${HOME}/.aliases"
	export SCRIPT_ROOT
	export ALIASES_FILE
	main "$@"
fi
