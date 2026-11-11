#!/usr/bin/env bash
#
# Creates and removes user .desktop entries and bin symlinks for AppImage files
#

_AURAS_SCRIPT="${BASH_SOURCE[0]:-$0}"
_AURAS_DIR="$(cd "$(dirname "${_AURAS_SCRIPT}")" && pwd)"

# Display usage information
#
# Side Effects:
# - Writes usage text to stdout
#
# Returns:
# - 0 always
usage() {
	cat <<EOF
Usage: $(basename "$0") -b|--buff NAME -a|--appimage PATH | --ready-check DIR | -d|--debuff NAME | -h|--help

Creates or refreshes a user .desktop launcher and a ~/.local/bin symlink for one
AppImage. Debuff removes both when they were created by this script.

Buff requires NAME and --appimage PATH. Relative AppImage directories are resolved
from the current working directory. NAME is the desktop file stem, desktop Name=,
and the command name under ~/.local/bin.

Ready-check takes a packages directory, scans each immediate subdirectory for
AppImage files, picks the highest filename version then newest mtime, and buffs
each stem named after its subdirectory.

Existing launchers are overwritten only when they were created by this script
and include the current Auras management marker.

If your launcher cache is stale after buff or debuff, run:
  update-desktop-database "\$HOME/.local/share/applications"

Options:
  -h, --help             Show this help message
  -b, --buff NAME        Install managed launcher and bin symlink for NAME
  -a, --appimage PATH    AppImage path, required with --buff
  --ready-check DIR      Buff latest AppImage in each child of DIR
  -d, --debuff NAME      Remove managed NAME.desktop and matching bin symlink

EOF

	return 0
}

# Load the Auras library from the checkout that holds this script
#
# Side Effects:
# - Exports ZANGARMARSH_ROOT for this checkout
# - Sources tools/auras/lib/auras.sh and its helpers
#
# Returns:
# - 0 on success
# - 1 when repository resolution or sourcing fails
_auras_load_lib() {
	source "${_AURAS_DIR}/../lib/repo.sh" || return 1
	ensure_zangarmarsh_repo "${_AURAS_DIR}" || return 1
	source "${ZANGARMARSH_ROOT}/tools/auras/lib/auras.sh" || return 1

	return 0
}

# Refuse a second mode flag on the same invocation
#
# Inputs:
# - $1 current_mode, already selected mode or empty
#
# Returns:
# - 0 when current_mode is empty
# - 1 when a mode was already selected
_auras_require_single_mode() {
	local current_mode="$1"

	if [[ -n "${current_mode}" ]]; then
		echo "main:: use only one of --buff, --ready-check, or --debuff" >&2
		return 1
	fi

	return 0
}

main() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		usage
		return 0
	fi

	if [[ "$(uname -s)" != "Linux" ]]; then
		echo "main:: auras requires Linux" >&2
		return 1
	fi

	# Auras has no dry-run flag, so an inherited DRY_RUN must not skip its writes.
	DRY_RUN=false

	local mode=""
	local appimage_path=""
	local app_stem=""
	local packages_dir=""

	while (($# > 0)); do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		-b | --buff)
			_auras_require_single_mode "${mode}" || return 1
			if (($# < 2)); then
				echo "main:: --buff requires NAME" >&2
				return 1
			fi

			mode="buff"
			app_stem="$2"
			shift 2
			;;
		--ready-check)
			_auras_require_single_mode "${mode}" || return 1
			if (($# < 2)); then
				echo "main:: --ready-check requires DIR" >&2
				return 1
			fi

			mode="ready-check"
			packages_dir="$2"
			shift 2
			;;
		-d | --debuff)
			_auras_require_single_mode "${mode}" || return 1
			if (($# < 2)); then
				echo "main:: --debuff requires NAME" >&2
				return 1
			fi

			mode="debuff"
			app_stem="$2"
			shift 2
			;;
		-a | --appimage)
			if (($# < 2)); then
				echo "main:: --appimage requires PATH" >&2
				return 1
			fi

			appimage_path="$2"
			shift 2
			;;
		*)
			echo "main:: Unknown option '$1'" >&2
			echo "main:: Use '$(basename "$0") --help' for usage information" >&2
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
	ready-check)
		if [[ -n "${appimage_path}" ]]; then
			echo "main:: --appimage is only valid with --buff" >&2
			return 1
		fi

		ready_check_main "${packages_dir}"
		return $?
		;;
	debuff)
		debuff_main "${app_stem}" "${appimage_path}"
		return $?
		;;
	*)
		echo "main:: unknown mode '${mode}'" >&2
		return 1
		;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	_auras_load_lib || exit 1
	main "$@"
	exit $?
fi

_auras_load_lib || return 1
