#!/usr/bin/env bash
#
# Install Zangarmarsh and its local Cursor plugin.
#

# Usage

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

# Validation

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

# Source-line helpers

_canonical_source_command() {
	local quoted
	quoted="$(printf '%q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"
	printf 'source %s' "${quoted}"

	return 0
}

write_source_line() {
	_canonical_source_command
	printf '\n'

	return 0
}

source_line_text() {
	_canonical_source_command

	return 0
}

_zangarmarsh_loader_path() {
	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		printf '_zangarmarsh_loader_path:: ZANGARMARSH_ROOT is required\n' >&2
		return 1
	fi

	printf '%s\n' "${ZANGARMARSH_ROOT}/zangarmarsh.sh"

	return 0
}

_trim_leading_ws() {
	local text="${1:-}"
	printf '%s\n' "${text#"${text%%[![:space:]]*}"}"

	return 0
}

_trim_trailing_ws() {
	local text="${1:-}"
	printf '%s\n' "${text%"${text##*[![:space:]]}"}"

	return 0
}

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

_rc_is_bashrc() {
	local basename_rc
	basename_rc="$(basename "${RC_FILE}")"
	[[ "${basename_rc}" == ".bashrc" || "${basename_rc}" == "bashrc" ]]
}

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

has_source_line() {
	[[ -f "${RC_FILE}" ]] || return 1

	local line
	while IFS= read -r line || [[ -n "${line}" ]]; do
		if _line_sources_this_root "${line}"; then
			return 0
		fi
	done <"${RC_FILE}"

	return 1
}

# RC rewrite

_inspect_rc_install_state() {
	local match_count=0
	local has_canonical=false
	local needs_rewrite=false
	local strip_nvm=false

	_rc_needs_rewrite=false

	if _rc_is_bashrc; then
		strip_nvm=true
	fi

	[[ -f "${RC_FILE}" ]] || {
		_rc_needs_rewrite=true
		return 0
	}

	local canonical
	canonical="$(source_line_text)"

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
	done <"${RC_FILE}"

	if ((match_count == 0)) || ((match_count > 1)) || [[ "${has_canonical}" != true ]]; then
		needs_rewrite=true
	fi

	_rc_needs_rewrite="${needs_rewrite}"

	return 0
}

_rewrite_rc_file() {
	local append_source="${1:-false}"
	local strip_nvm="${2:-false}"
	local caller_name="${3:-_rewrite_rc_file}"

	local temporary_file
	temporary_file="$(mktemp "${TMPDIR:-/tmp}/zangarmarsh-rc.XXXXXX")" || {
		printf '%s:: failed to create temporary file\n' "${caller_name}" >&2
		return 1
	}

	if [[ -f "${RC_FILE}" ]]; then
		local line
		while IFS= read -r line || [[ -n "${line}" ]]; do
			if ! _should_keep_rc_line "${line}" "${strip_nvm}"; then
				continue
			fi

			printf '%s\n' "${line}" >>"${temporary_file}" || {
				rm -f "${temporary_file}"
				printf '%s:: failed to write %s\n' "${caller_name}" "${RC_FILE}" >&2
				return 1
			}
		done <"${RC_FILE}"
	fi

	if [[ "${append_source}" == true ]]; then
		if [[ -s "${temporary_file}" ]] && [[ -n "$(tail -c 1 "${temporary_file}")" ]]; then
			printf '\n' >>"${temporary_file}" || {
				rm -f "${temporary_file}"
				printf '%s:: failed to append newline to %s\n' "${caller_name}" "${RC_FILE}" >&2
				return 1
			}
		fi

		if ! write_source_line >>"${temporary_file}"; then
			rm -f "${temporary_file}"
			printf '%s:: failed to append source line to %s\n' "${caller_name}" "${RC_FILE}" >&2
			return 1
		fi
	fi

	if [[ -e "${RC_FILE}" && ! -f "${RC_FILE}" ]]; then
		rm -f "${temporary_file}"
		printf '%s:: failed to append source line to %s\n' "${caller_name}" "${RC_FILE}" >&2
		return 1
	fi

	if ! cat "${temporary_file}" >"${RC_FILE}"; then
		rm -f "${temporary_file}"
		if [[ ! -e "${RC_FILE}" ]]; then
			printf '%s:: failed to append source line to %s\n' "${caller_name}" "${RC_FILE}" >&2
		else
			printf '%s:: failed to replace %s\n' "${caller_name}" "${RC_FILE}" >&2
		fi

		return 1
	fi

	rm -f "${temporary_file}"

	return 0
}

install_zangarmarsh() {
	validate_install_env || return 1

	if [[ -z "${RC_FILE:-}" ]]; then
		printf 'install_zangarmarsh:: RC_FILE is required\n' >&2
		return 1
	fi

	_inspect_rc_install_state
	if [[ "${_rc_needs_rewrite}" != true ]]; then
		printf 'Already installed in %s\n' "${RC_FILE}"
		return 0
	fi

	printf 'Would install into %s:\n' "${RC_FILE}"
	write_source_line
	[[ "${DRY_RUN}" == true ]] && return 0

	local strip_nvm=false
	if _rc_is_bashrc; then
		strip_nvm=true
	fi

	_rewrite_rc_file true "${strip_nvm}" "install_zangarmarsh" || return 1
	printf 'Installed in %s\n' "${RC_FILE}"

	return 0
}

install_shell_rcs() {
	local errors=0
	local rc_file
	for rc_file in "${INSTALL_RC_FILES[@]}"; do
		RC_FILE="${rc_file}"
		export RC_FILE
		install_zangarmarsh || errors=$((errors + 1))
	done

	if ((errors == 0)); then
		return 0
	fi

	return 1
}

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

	_rewrite_rc_file false false "uninstall_zangarmarsh" || return 1
	printf 'Uninstalled from %s\n' "${RC_FILE}"

	return 0
}

uninstall_shell_rcs() {
	local errors=0
	local rc_file
	for rc_file in "${INSTALL_RC_FILES[@]}"; do
		RC_FILE="${rc_file}"
		export RC_FILE
		uninstall_zangarmarsh || errors=$((errors + 1))
	done

	if ((errors == 0)); then
		return 0
	fi

	return 1
}

# Plugin wrappers

install_cursor_plugin() {
	validate_install_env || return 1
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh"
	apply_quest_log --plugin-only

	return $?
}

uninstall_cursor_plugin() {
	uninstall_quest_plugin

	return $?
}

# Main

main() {
	local uninstall=false
	local errors=0
	local want_zsh=false
	local want_bash=false

	DRY_RUN=false
	unset RC_FILE
	unset INSTALL_RC_FILES

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

	INSTALL_RC_FILES=()
	[[ "${want_zsh}" == true ]] && INSTALL_RC_FILES+=("${HOME}/.zshrc")
	[[ "${want_bash}" == true ]] && INSTALL_RC_FILES+=("${HOME}/.bashrc")
	export DRY_RUN

	if [[ "${uninstall}" == true ]]; then
		uninstall_shell_rcs || errors=$((errors + 1))
		uninstall_cursor_plugin || errors=$((errors + 1))
		if ((errors == 0)); then
			return 0
		fi

		return 1
	fi

	# Plugin first; roll it back if an rc update fails.
	install_cursor_plugin || return 1
	if ! install_shell_rcs; then
		uninstall_cursor_plugin || true
		return 1
	fi

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -euo pipefail
	umask 077

	install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	source "${install_dir}/../tools/lib/repo.sh"
	ensure_zangarmarsh_repo "${install_dir}"
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh"

	main "$@"
fi
