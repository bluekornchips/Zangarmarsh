#!/usr/bin/env bash
#
# Install Zangarmarsh and its local Cursor plugin.
#

# Display usage information
#
# Side Effects:
# - Writes usage text to stdout
#
# Returns:
# - 0 always
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

# Validate HOME and ZANGARMARSH_ROOT before install or uninstall work
#
# Returns:
# - 0 when the environment is usable
# - 1 when HOME, ZANGARMARSH_ROOT, or zangarmarsh.sh is missing
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

# Build the canonical source command for this checkout
#
# Outputs:
# - source line without a trailing newline
#
# Returns:
# - 0 always
_canonical_source_command() {
	local quoted
	quoted="$(printf '%q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"
	printf 'source %s' "${quoted}"

	return 0
}

# Resolve the absolute path of zangarmarsh.sh for this checkout
#
# Outputs:
# - Absolute loader path on stdout
#
# Returns:
# - 0 on success
# - 1 when ZANGARMARSH_ROOT is unset
_zangarmarsh_loader_path() {
	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		printf '_zangarmarsh_loader_path:: ZANGARMARSH_ROOT is required\n' >&2
		return 1
	fi

	printf '%s\n' "${ZANGARMARSH_ROOT}/zangarmarsh.sh"

	return 0
}

# Strip leading whitespace from one string
#
# Inputs:
# - $1 text, input string
#
# Outputs:
# - Trimmed string on stdout
#
# Returns:
# - 0 always
_trim_leading_ws() {
	local text="${1:-}"
	printf '%s\n' "${text#"${text%%[![:space:]]*}"}"

	return 0
}

# Strip trailing whitespace from one string
#
# Inputs:
# - $1 text, input string
#
# Outputs:
# - Trimmed string on stdout
#
# Returns:
# - 0 always
_trim_trailing_ws() {
	local text="${1:-}"
	printf '%s\n' "${text%"${text##*[![:space:]]}"}"

	return 0
}

# Normalize a source target path from an rc line
#
# Inputs:
# - $1 target, raw path token after source
#
# Outputs:
# - Normalized absolute or expanded path on stdout
#
# Returns:
# - 0 always
_normalize_source_target() {
	local target="${1:-}"

	if [[ "${target}" == \"*\" ]]; then
		target="${target#\"}"
		target="${target%\"}"
	elif [[ "${target}" == \'*\' ]]; then
		target="${target#\'}"
		target="${target%\'}"
	fi

	if [[ "${target}" == \$HOME/* ]]; then
		target="${HOME}/${target#\$HOME/}"
	fi

	printf '%s\n' "${target}"

	return 0
}

# Return whether an rc line sources this checkout's zangarmarsh.sh
#
# Inputs:
# - $1 line, one rc file line
#
# Returns:
# - 0 when the line sources this root
# - 1 otherwise
_line_sources_this_root() {
	local line="${1:-}"
	local trimmed
	trimmed="$(_trim_leading_ws "${line}")"
	[[ "${trimmed}" == source[[:space:]]* ]] || return 1

	local target="${trimmed#source}"
	target="$(_trim_leading_ws "${target}")"
	target="${target%%#*}"
	target="$(_trim_trailing_ws "${target}")"
	[[ -n "${target}" ]] || return 1

	local expected
	expected="$(_zangarmarsh_loader_path)" || return 1
	target="$(_normalize_source_target "${target}")"

	if [[ "${target}" == "${expected}" ]]; then
		return 0
	fi

	return 1
}

# Return whether an rc line is an eager NVM install snippet
#
# Inputs:
# - $1 line, one rc file line
#
# Returns:
# - 0 when the line matches a known eager NVM form
# - 1 otherwise
_line_is_eager_nvm() {
	local line="${1:-}"
	local trimmed
	trimmed="$(_trim_leading_ws "${line}")"
	[[ -n "${trimmed}" ]] || return 1

	local body="${trimmed%%#*}"
	body="$(_trim_trailing_ws "${body}")"
	body="${body//\\./.}"

	# shellcheck disable=SC2016
	case "${body}" in
	'export NVM_DIR="$HOME/.nvm"' | "export NVM_DIR='$HOME/.nvm'" | 'export NVM_DIR=$HOME/.nvm')
		return 0
		;;
	'[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"')
		return 0
		;;
	'[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"')
		return 0
		;;
	esac

	return 1
}

# Return whether an rc path is a bashrc path
#
# Inputs:
# - $1 rc_file, path under inspection
#
# Returns:
# - 0 when the basename is .bashrc or bashrc
# - 1 otherwise
_rc_is_bashrc() {
	local rc_file="$1"
	local basename_rc
	basename_rc="$(basename "${rc_file}")"
	[[ "${basename_rc}" == ".bashrc" || "${basename_rc}" == "bashrc" ]] && return 0

	return 1
}

# Return whether an rc line should be kept during rewrite
#
# Inputs:
# - $1 line, one rc file line
# - $2 strip_nvm, true to drop eager NVM lines
#
# Returns:
# - 0 when the line should be kept
# - 1 when the line should be removed
_should_keep_rc_line() {
	local line="${1:-}"
	local strip_nvm="${2:-false}"

	if _line_sources_this_root "${line}"; then
		return 1
	fi

	if [[ "${strip_nvm}" == true ]] && _line_is_eager_nvm "${line}"; then
		return 1
	fi

	return 0
}

# Return whether an rc file already sources this checkout
#
# Inputs:
# - $1 rc_file, path under inspection
#
# Returns:
# - 0 when a matching source line is present
# - 1 when the file is missing or has no matching line
has_source_line() {
	local rc_file="$1"

	[[ -f "${rc_file}" ]] || return 1

	local line
	while IFS= read -r line || [[ -n "${line}" ]]; do
		if _line_sources_this_root "${line}"; then
			return 0
		fi
	done <"${rc_file}"

	return 1
}

# Return whether an rc file needs rewrite for install
#
# Inputs:
# - $1 rc_file, path under inspection
#
# Returns:
# - 0 when the file needs rewrite
# - 1 when the canonical source line is already present alone
_rc_install_needs_rewrite() {
	local rc_file="$1"
	local match_count=0
	local has_canonical=false
	local needs_rewrite=false
	local strip_nvm=false

	if _rc_is_bashrc "${rc_file}"; then
		strip_nvm=true
	fi

	[[ -f "${rc_file}" ]] || return 0

	local canonical
	canonical="$(_canonical_source_command)"

	local line
	while IFS= read -r line || [[ -n "${line}" ]]; do
		if _line_sources_this_root "${line}"; then
			match_count=$((match_count + 1))
			if [[ "${line}" == "${canonical}" ]]; then
				has_canonical=true
			else
				needs_rewrite=true
			fi
		elif [[ "${strip_nvm}" == true ]] && _line_is_eager_nvm "${line}"; then
			needs_rewrite=true
		fi
	done <"${rc_file}"

	if ((match_count == 0)) || ((match_count > 1)) || [[ "${has_canonical}" != true ]]; then
		needs_rewrite=true
	fi

	[[ "${needs_rewrite}" == true ]]

	return $?
}

# Rewrite an rc file, optionally appending the canonical source line
#
# Inputs:
# - $1 rc_file, path to rewrite
# - $2 append_source, true to append the source line
# - $3 strip_nvm, true to drop eager NVM lines
# - $4 caller_name, prefix for error messages
#
# Side Effects:
# - Replaces rc_file contents via a temporary file
#
# Returns:
# - 0 on success
# - 1 on write failure
_rewrite_rc_file() {
	local rc_file="$1"
	local append_source="${2:-false}"
	local strip_nvm="${3:-false}"
	local caller_name="${4:-_rewrite_rc_file}"

	local temporary_file
	temporary_file="$(mktemp "${TMPDIR:-/tmp}/zangarmarsh-rc.XXXXXX")" || {
		printf '%s:: failed to create temporary file\n' "${caller_name}" >&2
		return 1
	}

	chmod 0600 "${temporary_file}" || {
		rm -f "${temporary_file}"
		printf '%s:: failed to harden temporary file permissions\n' "${caller_name}" >&2
		return 1
	}

	trap 'rm -f -- "${temporary_file}"; trap - RETURN' RETURN

	if [[ -f "${rc_file}" ]]; then
		local line
		while IFS= read -r line || [[ -n "${line}" ]]; do
			if ! _should_keep_rc_line "${line}" "${strip_nvm}"; then
				continue
			fi

			printf '%s\n' "${line}" >>"${temporary_file}" || {
				printf '%s:: failed to write %s\n' "${caller_name}" "${rc_file}" >&2
				return 1
			}
		done <"${rc_file}"
	fi

	if [[ "${append_source}" == true ]]; then
		if ! printf '%s\n' "$(_canonical_source_command)" >>"${temporary_file}"; then
			printf '%s:: failed to append source line to %s\n' "${caller_name}" "${rc_file}" >&2
			return 1
		fi
	fi

	if [[ -e "${rc_file}" && ! -f "${rc_file}" ]]; then
		printf '%s:: failed to append source line to %s\n' "${caller_name}" "${rc_file}" >&2
		return 1
	fi

	if ! cat "${temporary_file}" >"${rc_file}"; then
		if [[ ! -e "${rc_file}" ]]; then
			printf '%s:: failed to append source line to %s\n' "${caller_name}" "${rc_file}" >&2
		else
			printf '%s:: failed to replace %s\n' "${caller_name}" "${rc_file}" >&2
		fi
		return 1
	fi

	rm -f "${temporary_file}"
	trap - RETURN

	return 0
}

# Install the Zangarmarsh source line into one rc file
#
# Inputs:
# - $1 rc_file, destination shell rc path
#
# Reads environment:
# - DRY_RUN, ZANGARMARSH_ROOT, HOME
#
# Side Effects:
# - May rewrite rc_file and strip eager NVM lines from bashrc
#
# Returns:
# - 0 on success or when already installed
# - 1 on validation or write failure
install_zangarmarsh() {
	local rc_file="$1"

	validate_install_env || return 1

	if [[ -z "${rc_file}" ]]; then
		printf 'install_zangarmarsh:: rc_file is required\n' >&2
		return 1
	fi

	if ! _rc_install_needs_rewrite "${rc_file}"; then
		printf 'Already installed in %s\n' "${rc_file}"
		return 0
	fi

	printf 'Would install into %s:\n' "${rc_file}"
	printf '%s\n' "$(_canonical_source_command)"
	[[ "${DRY_RUN}" == true ]] && return 0

	local strip_nvm=false
	if _rc_is_bashrc "${rc_file}"; then
		strip_nvm=true
	fi

	_rewrite_rc_file "${rc_file}" true "${strip_nvm}" "install_zangarmarsh" || return 1
	printf 'Installed in %s\n' "${rc_file}"

	return 0
}

# Remove the Zangarmarsh source line from one rc file
#
# Inputs:
# - $1 rc_file, shell rc path to clean
#
# Reads environment:
# - DRY_RUN, ZANGARMARSH_ROOT, HOME
#
# Side Effects:
# - May rewrite rc_file
#
# Returns:
# - 0 on success or when not installed
# - 1 on validation or write failure
uninstall_zangarmarsh() {
	local rc_file="$1"

	validate_install_env || return 1

	if [[ -z "${rc_file}" ]]; then
		printf 'uninstall_zangarmarsh:: rc_file is required\n' >&2
		return 1
	fi

	if ! has_source_line "${rc_file}"; then
		printf 'Not installed in %s\n' "${rc_file}"
		return 0
	fi

	printf 'Would remove from %s:\n' "${rc_file}"
	printf '%s\n' "$(_canonical_source_command)"
	[[ "${DRY_RUN}" == true ]] && return 0

	_rewrite_rc_file "${rc_file}" false false "uninstall_zangarmarsh" || return 1
	printf 'Uninstalled from %s\n' "${rc_file}"

	return 0
}

# Install the local Cursor quest-log plugin only
#
# Returns:
# - apply_quest_log exit status
# - 1 when validation fails
install_cursor_plugin() {
	validate_install_env || return 1
	apply_quest_log --plugin-only

	return $?
}

main() {
	local uninstall=false
	local errors=0
	local want_zsh=false
	local want_bash=false

	DRY_RUN=false

	while (($# > 0)); do
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

	local rc_files=()
	[[ "${want_zsh}" == true ]] && rc_files+=("${HOME}/.zshrc")
	[[ "${want_bash}" == true ]] && rc_files+=("${HOME}/.bashrc")
	export DRY_RUN

	local rc_file
	if [[ "${uninstall}" == true ]]; then
		for rc_file in "${rc_files[@]}"; do
			uninstall_zangarmarsh "${rc_file}" || errors=$((errors + 1))
		done

		uninstall_quest_plugin || errors=$((errors + 1))
		if ((errors == 0)); then
			return 0
		fi

		return 1
	fi

	# Plugin first; roll it back if an rc update fails.
	install_cursor_plugin || return 1
	for rc_file in "${rc_files[@]}"; do
		if ! install_zangarmarsh "${rc_file}"; then
			uninstall_quest_plugin || true
			return 1
		fi
	done

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -euo pipefail
	umask 077

	install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	source "${install_dir}/../tools/lib/repo.sh"
	# Always bind to this checkout. An inherited ZANGARMARSH_ROOT from another
	# tree would make make install write the wrong source line.
	unset ZANGARMARSH_ROOT
	ensure_zangarmarsh_repo "${install_dir}"
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh"

	main "$@"
fi
