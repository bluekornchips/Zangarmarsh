#!/usr/bin/env bash
#
# Creates and removes user .desktop entries and bin symlinks for AppImage files
#

_AURAS_SCRIPT="${BASH_SOURCE[0]:-$0}"
_AURAS_DIR="$(cd "$(dirname "${_AURAS_SCRIPT}")" && pwd)"

usage() {
	cat <<EOF
Usage: $(basename "$0") -b|--buff NAME -a|--appimage PATH | -d|--debuff NAME | -h|--help

Creates or refreshes a user .desktop launcher and a ~/.local/bin symlink for one
AppImage. Debuff removes both when they were created by this script.

Buff requires NAME and --appimage PATH. Relative AppImage directories are resolved
from the current working directory. NAME is the desktop file stem, desktop Name=,
and the command name under ~/.local/bin.

Existing launchers are overwritten only when they were created by this script
and include the current Auras management marker.

If your launcher cache is stale after buff or debuff, run:
  update-desktop-database "\$HOME/.local/share/applications"

Options:
  -h, --help             Show this help message
  -b, --buff NAME        Install managed launcher and bin symlink for NAME
  -a, --appimage PATH    AppImage path, required with --buff
  -d, --debuff NAME      Remove managed NAME.desktop and matching bin symlink

EOF

	return 0
}

# Load shared Auras helpers after the repository root is known
#
# Side Effects:
# - Sources tools/auras/lib/auras.sh once per shell
#
# Returns:
# - 0 on success
# - 1 when ZANGARMARSH_ROOT is unset or sourcing fails
_auras_load_lib() {
	[[ -n "${_AURAS_LIBS_LOADED:-}" ]] && return 0

	if [[ -z "${ZANGARMARSH_ROOT:-}" || ! -f "${ZANGARMARSH_ROOT}/zangarmarsh.sh" ]]; then
		source "${_AURAS_DIR}/../lib/repo.sh" || return 1
		ensure_zangarmarsh_repo "${_AURAS_DIR}" || return 1
	fi

	source "${ZANGARMARSH_ROOT}/tools/auras/lib/auras.sh" || return 1
	_AURAS_LIBS_LOADED=1

	return 0
}

main() {
	local mode=""
	local appimage_path=""
	local app_stem=""

	_auras_load_lib || return 1

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		-b | --buff | -d | --debuff)
			if [[ -n "${mode}" ]]; then
				echo "main:: use only one of --buff or --debuff" >&2
				return 1
			fi

			if [[ $# -lt 2 ]]; then
				if [[ "$1" == "-b" || "$1" == "--buff" ]]; then
					echo "main:: --buff requires NAME" >&2
				else
					echo "main:: --debuff requires NAME" >&2
				fi
				return 1
			fi

			if [[ "$1" == "-b" || "$1" == "--buff" ]]; then
				mode="buff"
			else
				mode="debuff"
			fi

			app_stem="$2"
			shift 2
			;;
		-a | --appimage)
			if [[ $# -lt 2 ]]; then
				echo "main:: --appimage requires PATH" >&2
				return 1
			fi

			appimage_path="$2"
			shift 2
			;;
		*)
			echo "main:: unknown option or argument '$1'" >&2
			echo "Use '$(basename "$0") --help' for usage information" >&2
			return 1
			;;
		esac
	done

	if [[ -z "${mode}" ]]; then
		usage >&2
		return 1
	fi

	case "${mode}" in
	buff)
		buff_main "${app_stem}" "${appimage_path}"
		return $?
		;;
	debuff)
		debuff_main "${app_stem}" "${appimage_path}"
		return $?
		;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	main "$@"
	exit $?
elif [[ -n "${ZANGARMARSH_ROOT:-}" ]]; then
	_auras_load_lib || return 1
fi
