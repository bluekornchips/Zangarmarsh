#!/usr/bin/env bash
#
# Install Zangarmarsh and its local Cursor plugin.
#

RC_BLOCK_START="# >>> zangarmarsh >>>"
RC_BLOCK_END="# <<< zangarmarsh <<<"

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

Manage the Zangarmarsh block in ~/.zshrc and the bash rc file, and install the
local Cursor plugin, user rules, Cursor settings, and DejaVu Sans Mono font.

Options:
  -h, --help       Show this help
  -r, --dry-run    Show changes without modifying user files
  -u, --uninstall  Remove the Zangarmarsh block, local Cursor plugin, and managed rules
      --zsh        Update ~/.zshrc only, or both rc files with --bash
      --bash       Update the bash rc file only, or both rc files with --zsh

The bash rc file is ~/.bash_profile on macOS and ~/.bashrc on Linux.
When neither --zsh nor --bash is given, both rc files are updated.
Uninstall leaves Cursor user settings and the installed font in place.
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

# Print the profile family for this host
#
# Outputs:
# - macos or linux on stdout
#
# Returns:
# - 0 on success
# - 1 when platform detection fails
_host_os() {
	local platform_id
	platform_id="$(_detect_platform)" || return 1
	platform_os_from_id "${platform_id}"

	return $?
}

# Resolve the bash rc file for this host
#
# Reads environment:
# - HOME
#
# Outputs:
# - ~/.bash_profile on macOS or ~/.bashrc on Linux, on stdout
#
# Returns:
# - 0 on success
# - 1 when platform detection fails
bash_rc_path() {
	local host_os
	host_os="$(_host_os)" || return 1

	if [[ "${host_os}" == "macos" ]]; then
		printf '%s\n' "${HOME}/.bash_profile"
	else
		printf '%s\n' "${HOME}/.bashrc"
	fi

	return 0
}

# Resolve the user fonts directory for this host
#
# Reads environment:
# - HOME
#
# Outputs:
# - Absolute fonts directory path on stdout
#
# Returns:
# - 0 on success
# - 1 when HOME is empty or platform detection fails
user_fonts_dir() {
	if [[ -z "${HOME:-}" ]]; then
		echo "user_fonts_dir:: HOME is required" >&2
		return 1
	fi

	local host_os
	host_os="$(_host_os)" || return 1

	if [[ "${host_os}" == "macos" ]]; then
		printf '%s\n' "${HOME}/Library/Fonts"
	else
		printf '%s\n' "${HOME}/.local/share/fonts"
	fi

	return 0
}

# Build the marked Zangarmarsh block for this checkout
#
# Reads environment:
# - ZANGARMARSH_ROOT
#
# Outputs:
# - Start marker, source line, and end marker on stdout, with no trailing newline
#
# Returns:
# - 0 always
_rc_block() {
	local quoted
	quoted="$(printf '%q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"
	printf '%s\nsource %s\n%s' "${RC_BLOCK_START}" "${quoted}" "${RC_BLOCK_END}"

	return 0
}

# Resolve an rc path to the file that holds its content
#
# Inputs:
# - $1 rc_file, rc path that may be a symlink chain
#
# Outputs:
# - Target file path on stdout, which may not exist yet
#
# Returns:
# - 0 on success
# - 1 when the path is a directory or the symlink chain is too deep
_rc_target_file() {
	local rc_file="$1"
	local path="${rc_file}"
	local hops=0

	while [[ -L "${path}" ]]; do
		if ((hops == 32)); then
			echo "_rc_target_file:: symlink chain is too deep: ${rc_file}" >&2
			return 1
		fi

		local link
		link="$(readlink "${path}")" || return 1
		[[ "${link}" == /* ]] || link="$(dirname "${path}")/${link}"
		path="${link}"
		hops=$((hops + 1))
	done

	if [[ -d "${path}" ]]; then
		echo "_rc_target_file:: rc path is a directory: ${rc_file}" >&2
		return 1
	fi

	printf '%s\n' "${path}"

	return 0
}

# Rewrite rc content with the marked block set to block, or without it when block is empty
#
# Inputs:
# - $1 rc_file, rc path to read, may be missing
# - $2 block, marked block text, or empty to remove every marked block
#
# Outputs:
# - Rewritten content on stdout, with each line ending in a newline
#
# Returns:
# - 0 on success
# - 1 when a start marker has no matching end marker
_rc_with_block() {
	local rc_file="$1"
	local block="$2"

	local source_file="${rc_file}"
	[[ -f "${rc_file}" ]] || source_file=/dev/null

	ZANGARMARSH_BLOCK="${block}" awk -v open_mark="${RC_BLOCK_START}" -v close_mark="${RC_BLOCK_END}" '
		BEGIN { block = ENVIRON["ZANGARMARSH_BLOCK"]; placed = 0; inside = 0 }
		$0 == open_mark {
			if (inside) exit 1
			if (!placed && block != "") print block
			placed = 1
			inside = 1
			next
		}
		inside {
			if ($0 == close_mark) inside = 0
			next
		}
		{ print }
		END {
			if (inside) exit 1
			if (!placed && block != "") print block
		}
	' "${source_file}" || {
		echo "_rc_with_block:: unmatched Zangarmarsh markers in ${rc_file}" >&2
		return 1
	}

	return 0
}

# Install the marked Zangarmarsh block into one rc file
#
# Inputs:
# - $1 rc_file, shell rc path to update
#
# Reads environment:
# - DRY_RUN, ZANGARMARSH_ROOT, HOME
#
# Side Effects:
# - Replaces an existing marked block in place, or appends one, through write_atomic
#
# Returns:
# - 0 on success, when already installed, or in dry run
# - 1 on validation, rc resolution, or write failure
install_zangarmarsh() {
	local rc_file="$1"

	validate_install_env || return 1

	local target
	target="$(_rc_target_file "${rc_file}")" || return 1

	local block
	block="$(_rc_block)"

	local content
	content="$(_rc_with_block "${target}" "${block}" && printf x)" || return 1
	content="${content%x}"

	if [[ -f "${target}" ]] && cmp -s "${target}" <(printf '%s' "${content}"); then
		printf 'Already installed in %s\n' "${rc_file}"
		return 0
	fi

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		printf 'Would install into %s:\n%s\n' "${rc_file}" "${block}"
		return 0
	fi

	printf 'Installing into %s\n' "${rc_file}"
	local parent stage
	parent="$(dirname "${target}")"
	ensure_dir "${parent}" "install_zangarmarsh" || return 1
	stage="$(mktemp "${parent}/.zangarmarsh.XXXXXX")" || return 1
	if ! printf '%s' "${content}" >"${stage}"; then
		rm -f -- "${stage}"
		return 1
	fi

	write_atomic "${target}" "${stage}" "install_zangarmarsh" || {
		rm -f -- "${stage}"
		return 1
	}
	rm -f -- "${stage}"

	return 0
}

# Remove every marked Zangarmarsh block from one rc file
#
# Inputs:
# - $1 rc_file, shell rc path to clean
#
# Reads environment:
# - DRY_RUN, ZANGARMARSH_ROOT, HOME
#
# Side Effects:
# - Rewrites the rc file without the marked block, through write_atomic
#
# Returns:
# - 0 on success, when not installed, or in dry run
# - 1 on validation, rc resolution, or write failure
uninstall_zangarmarsh() {
	local rc_file="$1"

	validate_install_env || return 1

	local target
	target="$(_rc_target_file "${rc_file}")" || return 1

	if ! grep -qsxF "${RC_BLOCK_START}" "${target}"; then
		printf 'Not installed in %s\n' "${rc_file}"
		return 0
	fi

	local content
	content="$(_rc_with_block "${target}" "" && printf x)" || return 1
	content="${content%x}"

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		printf 'Would remove from %s\n' "${rc_file}"
		return 0
	fi

	printf 'Removing from %s\n' "${rc_file}"
	local parent stage
	parent="$(dirname "${target}")"
	ensure_dir "${parent}" "uninstall_zangarmarsh" || return 1
	stage="$(mktemp "${parent}/.zangarmarsh.XXXXXX")" || return 1
	if ! printf '%s' "${content}" >"${stage}"; then
		rm -f -- "${stage}"
		return 1
	fi

	write_atomic "${target}" "${stage}" "uninstall_zangarmarsh" || {
		rm -f -- "${stage}"
		return 1
	}
	rm -f -- "${stage}"

	return 0
}

# Install DejaVu Sans Mono from the bundled profile font
#
# Reads environment:
# - ZANGARMARSH_ROOT, HOME, DRY_RUN
#
# Side Effects:
# - Writes DejaVuSansMono.ttf into the user fonts directory through write_atomic
# - Refreshes the font cache on Linux when the font was created or updated
#
# Returns:
# - 0 on success, when unchanged, or in dry run
# - 1 on validation or write failure
install_dejavu_font() {
	validate_install_env || return 1

	local src="${ZANGARMARSH_ROOT}/profile/fonts/dejavu-fonts-ttf-2.37/ttf/DejaVuSansMono.ttf"
	if [[ ! -f "${src}" ]]; then
		echo "install_dejavu_font:: font not found: ${src}" >&2
		return 1
	fi

	local fonts_dir
	fonts_dir="$(user_fonts_dir)" || return 1

	write_atomic "${fonts_dir}/DejaVuSansMono.ttf" "${src}" "install_dejavu_font" || return 1
	[[ "${WRITE_ATOMIC_OUTCOME}" == unchanged || "${WRITE_ATOMIC_OUTCOME}" == dry-run ]] && return 0

	# Plain fc-cache, since -f forces a slow full rescan.
	if command -v fc-cache >/dev/null 2>&1; then
		fc-cache "${fonts_dir}" >/dev/null 2>&1 || {
			echo "install_dejavu_font:: fc-cache failed for ${fonts_dir}; font is installed" >&2
		}
	fi

	return 0
}

# Install the local Cursor quest-log plugin, user rules, and Cursor settings
#
# Returns:
# - 0 on success
# - 1 when validation or apply_quest_log fails
install_quest_log() {
	validate_install_env || return 1
	# shellcheck disable=SC2119
	apply_quest_log || return 1

	return 0
}

main() {
	local uninstall=false
	local want_zsh=false
	local want_bash=false
	local errors=0

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
	if [[ "${want_bash}" == true ]]; then
		local bash_rc
		bash_rc="$(bash_rc_path)" || return 1
		rc_files+=("${bash_rc}")
	fi

	local rc_file
	if [[ "${uninstall}" == true ]]; then
		for rc_file in "${rc_files[@]}"; do
			uninstall_zangarmarsh "${rc_file}" || errors=$((errors + 1))
		done

		uninstall_quest_plugin || errors=$((errors + 1))
		uninstall_quest_rules || errors=$((errors + 1))

		((errors == 0)) && return 0
		return 1
	fi

	install_dejavu_font || return 1
	install_quest_log || return 1
	for rc_file in "${rc_files[@]}"; do
		install_zangarmarsh "${rc_file}" || return 1
	done

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -euo pipefail
	umask 077

	install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	source "${install_dir}/../tools/lib/repo.sh"
	ensure_zangarmarsh_repo "${install_dir}"
	source "${ZANGARMARSH_ROOT}/tools/lib/fs.sh"
	source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh"

	main "$@"
fi
