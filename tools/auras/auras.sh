#!/usr/bin/env bash
#
# Creates and removes user .desktop entries and bin symlinks for AppImage files
#

AURAS_DESKTOP_VERSION="1"
AURAS_MANAGED_KEY="X-Auras-Managed=true"
AURAS_VERSION_KEY="X-Auras-Version=${AURAS_DESKTOP_VERSION}"

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

# Validate one path segment for desktop file stems
#
# Inputs:
# - $1 token, single desktop stem without slashes
# - $2 context label for error messages
#
# Returns:
# - 0 when the token is safe to use as one filesystem segment
# - 1 when empty, includes slashes or control characters, or is . or ..
validate_app_name_segment() {
	local token
	local ctx

	token="$1"
	ctx="${2:-validate_app_name_segment}"

	if [[ -z "${token}" ]]; then
		echo "${ctx}:: name must be non-empty" >&2
		return 1
	fi

	if [[ "${token}" == *"/"* ]]; then
		echo "${ctx}:: name must be one segment without slashes, got: ${token}" >&2
		return 1
	fi

	if [[ "${token}" == "." || "${token}" == ".." ]]; then
		echo "${ctx}:: name must not be . or .." >&2
		return 1
	fi

	if [[ "${token}" =~ [[:cntrl:]] ]]; then
		echo "${ctx}:: name must not contain control characters" >&2
		return 1
	fi

	return 0
}

# Resolve an AppImage path to an absolute path
#
# Inputs:
# - $1 appimage_path, path to an AppImage
# - $2 context label for error messages
#
# Outputs:
# - Absolute AppImage path on stdout
#
# Returns:
# - 0 when the directory can be resolved
# - 1 when the path is empty, unsafe, or has an unavailable directory
resolve_appimage_path() {
	local appimage_path
	local ctx
	local appimage_dir
	local appimage_name
	local resolved_dir

	appimage_path="$1"
	ctx="${2:-resolve_appimage_path}"

	if [[ -z "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage path is required" >&2
		return 1
	fi

	if [[ "${appimage_path}" =~ [[:cntrl:]] ]]; then
		echo "${ctx}:: AppImage path must not contain control characters" >&2
		return 1
	fi

	appimage_dir="${appimage_path%/*}"
	appimage_name="${appimage_path##*/}"

	if [[ "${appimage_dir}" == "${appimage_path}" ]]; then
		appimage_dir="."
	fi

	if [[ -z "${appimage_name}" || "${appimage_name}" == "." || "${appimage_name}" == ".." ]]; then
		echo "${ctx}:: AppImage file name is required" >&2
		return 1
	fi

	if ! resolved_dir="$(cd "${appimage_dir}" && pwd -P)"; then
		echo "${ctx}:: AppImage directory does not exist: ${appimage_dir}" >&2
		return 1
	fi

	echo "${resolved_dir}/${appimage_name}"

	return 0
}

# Validate the AppImage path supplied to --buff
#
# Inputs:
# - $1 appimage_path, expected absolute path to an AppImage
# - $2 context label for error messages
#
# Returns:
# - 0 when the path is an absolute, executable AppImage file
# - 1 when the path is invalid or not usable
validate_appimage_path() {
	local appimage_path
	local ctx

	appimage_path="$1"
	ctx="${2:-validate_appimage_path}"

	if [[ -z "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage path is required" >&2
		return 1
	fi

	if [[ "${appimage_path}" != /* ]]; then
		echo "${ctx}:: AppImage path must be absolute: ${appimage_path}" >&2
		return 1
	fi

	if [[ "${appimage_path}" =~ [[:cntrl:]] ]]; then
		echo "${ctx}:: AppImage path must not contain control characters" >&2
		return 1
	fi

	if [[ "${appimage_path}" != *.AppImage && "${appimage_path}" != *.appimage ]]; then
		echo "${ctx}:: AppImage path must end with .AppImage or .appimage: ${appimage_path}" >&2
		return 1
	fi

	if [[ ! -f "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage file does not exist: ${appimage_path}" >&2
		return 1
	fi

	if [[ ! -r "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage file is not readable: ${appimage_path}" >&2
		return 1
	fi

	if [[ ! -x "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage file is not executable: ${appimage_path}" >&2
		return 1
	fi

	return 0
}

# Resolve and validate one AppImage path
#
# Inputs:
# - $1 raw_appimage_path, user-supplied AppImage path
# - $2 context label for error messages
#
# Outputs:
# - Absolute validated AppImage path on stdout
#
# Returns:
# - 0 on success
# - 1 on resolve or validation failure
prepare_appimage_path() {
	local raw_appimage_path
	local ctx
	local resolved_appimage_path

	raw_appimage_path="$1"
	ctx="${2:-prepare_appimage_path}"

	if ! resolved_appimage_path="$(resolve_appimage_path "${raw_appimage_path}" "${ctx}")"; then
		return 1
	fi

	if ! validate_appimage_path "${resolved_appimage_path}" "${ctx}"; then
		return 1
	fi

	echo "${resolved_appimage_path}"

	return 0
}

# Resolve a path under ~/.local for one suffix
#
# Inputs:
# - $1 suffix, path segment under ~/.local
# - $2 context label for error messages
#
# Outputs:
# - Absolute directory path on stdout
#
# Returns:
# - 0 on success
# - 1 if HOME is unset or empty
local_user_dir() {
	local suffix
	local ctx

	suffix="$1"
	ctx="$2"

	if [[ -z "${HOME}" ]]; then
		echo "${ctx}:: HOME is not set" >&2
		return 1
	fi

	echo "${HOME}/.local/${suffix}"

	return 0
}

applications_dir() {
	local_user_dir "share/applications" "applications_dir"
}

bin_link_dir() {
	local_user_dir "bin" "bin_link_dir"
}

# Build the bin symlink path for one application stem
#
# Inputs:
# - $1 app_stem, command name without path segments
#
# Outputs:
# - Absolute bin symlink path on stdout
#
# Returns:
# - 0 on success
# - 1 if HOME is unset or stem validation fails
bin_link_path() {
	local app_stem
	local bin_root

	app_stem="$1"

	if ! validate_app_name_segment "${app_stem}" "bin_link_path"; then
		return 1
	fi

	if ! bin_root="$(bin_link_dir)"; then
		return 1
	fi

	echo "${bin_root}/${app_stem}"

	return 0
}

# Resolve the desktop file path for one application stem
#
# Inputs:
# - $1 app_stem, desktop file stem without extension
#
# Outputs:
# - Absolute desktop file path on stdout
#
# Returns:
# - 0 on success
# - 1 when HOME is unset or stem validation fails
desktop_path_for_stem() {
	local app_stem="$1"
	local apps_root

	if ! validate_app_name_segment "${app_stem}" "desktop_path_for_stem"; then
		return 1
	fi

	if ! apps_root="$(applications_dir)"; then
		return 1
	fi

	echo "${apps_root}/${app_stem}.desktop"

	return 0
}

# Return whether Auras owns the desktop entry for one application stem
#
# Inputs:
# - $1 app_stem, desktop file stem without extension
#
# Returns:
# - 0 when a managed desktop entry exists for the stem
# - 1 otherwise
auras_manages_app_stem() {
	local app_stem="$1"
	local desktop_path

	if ! desktop_path="$(desktop_path_for_stem "${app_stem}")"; then
		return 1
	fi

	if [[ ! -f "${desktop_path}" ]]; then
		return 1
	fi

	if ! desktop_entry_is_auras_managed "${desktop_path}"; then
		return 1
	fi

	return 0
}

# Check whether a desktop entry is managed by this version of Auras
#
# Inputs:
# - $1 desktop_path, desktop file to inspect
#
# Returns:
# - 0 when the file has current Auras management markers
# - 1 otherwise
desktop_entry_is_auras_managed() {
	local desktop_path

	desktop_path="$1"

	if [[ -z "${desktop_path}" || ! -f "${desktop_path}" ]]; then
		return 1
	fi

	if ! grep -Fxq "${AURAS_MANAGED_KEY}" "${desktop_path}"; then
		return 1
	fi

	if ! grep -Fxq "${AURAS_VERSION_KEY}" "${desktop_path}"; then
		return 1
	fi

	return 0
}

# Read Exec= target from a desktop file
#
# Inputs:
# - $1 desktop_path, desktop file to read
#
# Outputs:
# - AppImage path from Exec= on stdout
#
# Returns:
# - 0 on success
# - 1 when Exec= is missing or empty
desktop_entry_exec_path() {
	local desktop_path
	local exec_line
	local exec_path

	desktop_path="$1"

	if [[ -z "${desktop_path}" || ! -f "${desktop_path}" ]]; then
		echo "desktop_entry_exec_path:: desktop_path is required" >&2
		return 1
	fi

	exec_line="$(grep -E '^Exec=' "${desktop_path}" | head -n1)"

	if [[ -z "${exec_line}" ]]; then
		echo "desktop_entry_exec_path:: Exec= is missing in ${desktop_path}" >&2
		return 1
	fi

	exec_path="${exec_line#Exec=}"
	exec_path="${exec_path#\"}"
	exec_path="${exec_path%\"}"
	exec_path="${exec_path%% %u}"
	exec_path="${exec_path%% %U}"
	exec_path="${exec_path#\"}"
	exec_path="${exec_path%\"}"

	if [[ -z "${exec_path}" ]]; then
		echo "desktop_entry_exec_path:: Exec= path is empty in ${desktop_path}" >&2
		return 1
	fi

	if [[ "${exec_path}" == *" "* || "${exec_path}" == *$'\t'* ]]; then
		echo "desktop_entry_exec_path:: could not parse Exec= in ${desktop_path}" >&2
		return 1
	fi

	echo "${exec_path}"

	return 0
}

AURAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${AURAS_DIR}/buff.sh"
source "${AURAS_DIR}/debuff.sh"

main() {
	local mode=""
	local appimage_path=""
	local app_stem=""

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
fi
