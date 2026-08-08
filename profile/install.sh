#!/usr/bin/env bash
#
# Install Zangarmarsh and its local Cursor plugin.
#

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Add or remove Zangarmarsh from ~/.zshrc and/or ~/.bashrc and install its
local Cursor plugin.

Options:
  -h, --help       Show this help
  -r, --dry-run    Show changes without modifying user files
  -u, --uninstall  Remove Zangarmarsh and its local Cursor plugin
      --zsh        Target ~/.zshrc only, or with --bash both files
      --bash       Target ~/.bashrc only, or with --zsh both files

When neither --zsh nor --bash is given, both ~/.zshrc and ~/.bashrc are used.
EOF

	return 0
}

# Validate required environment for install or uninstall
#
# Reads environment:
# - HOME, ZANGARMARSH_ROOT
#
# Returns:
# - 0 when required values are present and zangarmarsh.sh exists
# - 1 when any required value is missing
validate_install_env() {
	if [[ -z "${HOME:-}" ]]; then
		printf 'validate_install_env:: HOME is required\n' >&2
		return 1
	fi

	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		printf 'validate_install_env:: ZANGARMARSH_ROOT is required\n' >&2
		return 1
	fi

	if [[ ! -f "${ZANGARMARSH_ROOT}/zangarmarsh.sh" ]]; then
		printf 'validate_install_env:: zangarmarsh.sh not found under %s\n' "${ZANGARMARSH_ROOT}" >&2
		return 1
	fi

	return 0
}

# Print the exact shell rc source line, including its trailing newline
#
# Reads environment:
# - ZANGARMARSH_ROOT
#
# Outputs:
# - The source line, terminated with a newline, to stdout
write_source_line() {
	printf 'source "%s/zangarmarsh.sh"\n' "${ZANGARMARSH_ROOT}"
}

# Exact source-line text without a trailing newline, for matching existing lines
#
# Reads environment:
# - ZANGARMARSH_ROOT
#
# Outputs:
# - The source line without a trailing newline, to stdout
source_line_text() {
	printf 'source "%s/zangarmarsh.sh"' "${ZANGARMARSH_ROOT}"
}

# Check whether RC_FILE already sources zangarmarsh.sh
#
# Reads environment:
# - RC_FILE, ZANGARMARSH_ROOT
#
# Returns:
# - 0 when the source line is present
# - 1 when RC_FILE is missing or the source line is absent
has_source_line() {
	[[ -f "${RC_FILE}" ]] || return 1
	grep -Fqx "$(source_line_text)" "${RC_FILE}"
}

# Append the Zangarmarsh source line to RC_FILE
#
# Reads environment:
# - RC_FILE, ZANGARMARSH_ROOT, DRY_RUN
#
# Side Effects:
# - Creates or appends to RC_FILE, unless DRY_RUN is true
#
# Returns:
# - 0 on success, including when already installed or in dry-run mode
# - 1 when environment validation or a write fails
install_zangarmarsh() {
	validate_install_env || return 1

	if [[ -z "${RC_FILE:-}" ]]; then
		printf 'install_zangarmarsh:: RC_FILE is required\n' >&2
		return 1
	fi

	if has_source_line; then
		printf 'Already installed in %s\n' "${RC_FILE}"
		return 0
	fi

	printf 'Would append to %s:\n' "${RC_FILE}"
	write_source_line
	[[ "${DRY_RUN}" == true ]] && return 0

	if [[ -s "${RC_FILE}" ]] && [[ -n "$(tail -c 1 "${RC_FILE}")" ]]; then
		printf '\n' >>"${RC_FILE}" || {
			printf 'install_zangarmarsh:: failed to append newline to %s\n' "${RC_FILE}" >&2
			return 1
		}
	fi

	if ! write_source_line >>"${RC_FILE}"; then
		printf 'install_zangarmarsh:: failed to append source line to %s\n' "${RC_FILE}" >&2
		return 1
	fi

	printf 'Installed in %s\n' "${RC_FILE}"

	return 0
}

# Install into every path listed in INSTALL_RC_FILES
#
# Reads environment:
# - INSTALL_RC_FILES, plus install_zangarmarsh requirements
#
# Returns:
# - 0 when every target succeeds
# - 1 when any target fails
install_shell_rcs() {
	local rc_file
	local errors=0

	for rc_file in "${INSTALL_RC_FILES[@]}"; do
		RC_FILE="${rc_file}"
		export RC_FILE
		install_zangarmarsh || errors=$((errors + 1))
	done

	[[ "${errors}" -eq 0 ]] && return 0
	return 1
}

# Install the tracked quest-log Cursor plugin
#
# Reads environment:
# - ZANGARMARSH_ROOT, DRY_RUN, HOME, QUEST_LOG_PLUGIN_DIR
#
# Side Effects:
# - Delegates to install_quest_plugin for the tracked plugin tree
#
# Returns:
# - 0 on success
# - Non-zero when validation or plugin install fails
install_cursor_plugin() {
	validate_install_env || return 1
	install_quest_plugin "${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	return $?
}

# Remove the Zangarmarsh source line from RC_FILE
#
# Reads environment:
# - RC_FILE, ZANGARMARSH_ROOT, DRY_RUN
#
# Side Effects:
# - Rewrites RC_FILE without the source line, unless DRY_RUN is true
# - Preserves a symlinked RC_FILE by writing through the link
#
# Returns:
# - 0 on success, including when not installed or in dry-run mode
# - 1 when RC_FILE cannot be rewritten
uninstall_zangarmarsh() {
	validate_install_env || return 1

	if [[ -z "${RC_FILE:-}" ]]; then
		printf 'uninstall_zangarmarsh:: RC_FILE is required\n' >&2
		return 1
	fi

	if ! has_source_line; then
		printf 'Not installed in %s\n' "${RC_FILE}"
		return 0
	fi

	printf 'Would remove from %s:\n' "${RC_FILE}"
	write_source_line
	[[ "${DRY_RUN}" == true ]] && return 0

	local temporary_file
	temporary_file="$(mktemp "${TMPDIR:-/tmp}/zangarmarsh-rc.XXXXXX")" || {
		printf 'uninstall_zangarmarsh:: failed to create temporary file\n' >&2
		return 1
	}

	local line
	line="$(source_line_text)"
	if ! awk -v line="${line}" '$0 != line' "${RC_FILE}" >"${temporary_file}"; then
		rm -f "${temporary_file}"
		printf 'uninstall_zangarmarsh:: failed to update %s\n' "${RC_FILE}" >&2
		return 1
	fi

	if ! cat "${temporary_file}" >"${RC_FILE}"; then
		rm -f "${temporary_file}"
		printf 'uninstall_zangarmarsh:: failed to replace %s\n' "${RC_FILE}" >&2
		return 1
	fi
	rm -f "${temporary_file}"

	printf 'Uninstalled from %s\n' "${RC_FILE}"

	return 0
}

# Remove from every path listed in INSTALL_RC_FILES
#
# Reads environment:
# - INSTALL_RC_FILES, plus uninstall_zangarmarsh requirements
#
# Returns:
# - 0 when every target succeeds
# - 1 when any target fails
uninstall_shell_rcs() {
	local rc_file
	local errors=0

	for rc_file in "${INSTALL_RC_FILES[@]}"; do
		RC_FILE="${rc_file}"
		export RC_FILE
		uninstall_zangarmarsh || errors=$((errors + 1))
	done

	[[ "${errors}" -eq 0 ]] && return 0
	return 1
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
# - HOME, ZANGARMARSH_ROOT
#
# Side Effects:
# - Sets INSTALL_RC_FILES, DRY_RUN
# - Installs or uninstalls Zangarmarsh and the quest-log Cursor plugin
#
# Returns:
# - 0 when every step succeeds
# - 1 when an option is invalid or any step fails
main() {
	local uninstall=false
	local errors=0
	local want_zsh=false
	local want_bash=false

	DRY_RUN=false
	# Ignore inherited values from the caller shell or prior test runs.
	unset RC_FILE
	unset INSTALL_RC_FILES

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
		--zsh)
			want_zsh=true
			;;
		--bash)
			want_bash=true
			;;
		*)
			printf 'main:: unknown option: %s\n' "$1" >&2
			printf 'main:: use "%s --help" for usage\n' "$(basename "$0")" >&2
			return 1
			;;
		esac
		shift
	done

	if [[ "${want_zsh}" == false && "${want_bash}" == false ]]; then
		want_zsh=true
		want_bash=true
	fi

	INSTALL_RC_FILES=()
	[[ "${want_zsh}" == true ]] && INSTALL_RC_FILES+=("${HOME}/.zshrc")
	[[ "${want_bash}" == true ]] && INSTALL_RC_FILES+=("${HOME}/.bashrc")
	export DRY_RUN

	if [[ "${uninstall}" == true ]]; then
		uninstall_shell_rcs || errors=$((errors + 1))
		uninstall_cursor_plugin || errors=$((errors + 1))
		[[ "${errors}" -eq 0 ]] && return 0
		return 1
	fi

	# Plugin first, then shell rc lines. Roll the plugin back when an rc
	# update fails so a failed install does not leave a partial setup.
	install_cursor_plugin || return 1
	if ! install_shell_rcs; then
		uninstall_cursor_plugin || true
		return 1
	fi

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -euo pipefail

	# Cold bootstrap: profile load has not run yet, so find the install tree once.
	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		_install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
		ZANGARMARSH_ROOT="$(git -C "${_install_dir}" rev-parse --show-toplevel 2>/dev/null)" || true
		if [[ -z "${ZANGARMARSH_ROOT}" ]]; then
			ZANGARMARSH_ROOT="$(cd "${_install_dir}/.." && pwd)"
		fi
		unset _install_dir
	fi
	export ZANGARMARSH_ROOT

	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"

	main "$@"
fi
