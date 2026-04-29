#!/usr/bin/env bash
#
# Creates and removes user .desktop entries for explicitly provided AppImage files
#

AURAS_DESKTOP_VERSION="1"
AURAS_MANAGED_KEY="X-Auras-Managed=true"
AURAS_VERSION_KEY="X-Auras-Version=${AURAS_DESKTOP_VERSION}"

usage() {
	cat <<EOF
Usage: $(basename "$0") -b|--buff APPIMAGE NAME | -d|--debuff NAME | -h|--help

Creates or refreshes a user .desktop launcher for one AppImage path.

Buff requires the full path to an AppImage and an explicit NAME. NAME is used
for both the desktop file stem and the desktop entry Name= value.

Existing launchers are overwritten only when they were created by this script
and include the current Auras management marker.

If your launcher cache is stale after buff or debuff, run:
  update-desktop-database "\$HOME/.local/share/applications"

Options:
  -h, --help             Show this help message
  -b, --buff APPIMAGE NAME
                         Write \$HOME/.local/share/applications/NAME.desktop
  -d, --debuff NAME      Remove managed NAME.desktop

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

# Resolve user applications directory, always under HOME .local share
#
# Outputs:
# - Path to applications directory on stdout
#
# Returns:
# - 0 on success
# - 1 if HOME is unset or empty
applications_dir() {
	if [[ -z "${HOME}" ]]; then
		echo "applications_dir:: HOME is not set" >&2
		return 1
	fi

	echo "${HOME}/.local/share/applications"

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

# Ensure a desktop file may be written without clobbering an unmanaged entry
#
# Inputs:
# - $1 desktop_path, path that will be written
#
# Returns:
# - 0 when no file exists or the file is current Auras-managed
# - 1 when a file exists without current Auras markers
ensure_desktop_entry_writable() {
	local desktop_path

	desktop_path="$1"

	if [[ -z "${desktop_path}" ]]; then
		echo "ensure_desktop_entry_writable:: desktop_path is required" >&2
		return 1
	fi

	if [[ ! -e "${desktop_path}" ]]; then
		return 0
	fi

	if desktop_entry_is_auras_managed "${desktop_path}"; then
		return 0
	fi

	echo "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file: ${desktop_path}" >&2

	return 1
}

# Write or overwrite a managed .desktop file for an AppImage
#
# Inputs:
# - $1 app_stem, basename for the .desktop file without extension
# - $2 appimage_path, absolute path to the AppImage
# - $3 display_name, value for the Name= field
#
# Side Effects:
# - Creates applications directory if needed
# - Writes desktop_path when it is absent or Auras-managed
#
# Returns:
# - 0 on success
# - 1 on validation, safety, or write failure
write_application_desktop() {
	local app_stem
	local appimage_path
	local display_name
	local apps_root
	local desktop_path

	app_stem="$1"
	appimage_path="$2"
	display_name="$3"

	if [[ -z "${app_stem}" || -z "${appimage_path}" || -z "${display_name}" ]]; then
		echo "write_application_desktop:: app_stem, appimage_path, and display_name are required" >&2
		return 1
	fi

	if ! validate_app_name_segment "${app_stem}" "write_application_desktop"; then
		return 1
	fi

	if ! validate_appimage_path "${appimage_path}" "write_application_desktop"; then
		return 1
	fi

	if ! apps_root="$(applications_dir)"; then
		return 1
	fi

	if ! mkdir -p "${apps_root}"; then
		echo "write_application_desktop:: could not create ${apps_root}" >&2
		return 1
	fi

	desktop_path="${apps_root}/${app_stem}.desktop"

	if ! ensure_desktop_entry_writable "${desktop_path}"; then
		return 1
	fi

	if ! cat <<EOF >"${desktop_path}"; then
[Desktop Entry]
Type=Application
Name=${display_name}
Exec="${appimage_path}" %u
Terminal=false
${AURAS_MANAGED_KEY}
${AURAS_VERSION_KEY}
EOF
		echo "write_application_desktop:: failed to write desktop file: ${desktop_path}" >&2
		return 1
	fi

	echo "write_application_desktop:: wrote ${desktop_path}"

	return 0
}

# Remove a managed user .desktop entry by application stem
#
# Inputs:
# - $1 app_stem, name without .desktop extension
#
# Side Effects:
# - Removes desktop file when it is current Auras-managed
#
# Returns:
# - 0 on success
# - 1 if name missing, HOME unset, file missing, or file is unmanaged
debuff_appimage() {
	local app_stem
	local apps_root
	local desktop_path

	app_stem="$1"

	if [[ -z "${app_stem}" ]]; then
		echo "debuff_appimage:: app_stem is required" >&2
		return 1
	fi

	if ! validate_app_name_segment "${app_stem}" "debuff_appimage"; then
		return 1
	fi

	if ! apps_root="$(applications_dir)"; then
		return 1
	fi

	desktop_path="${apps_root}/${app_stem}.desktop"

	if [[ ! -f "${desktop_path}" ]]; then
		echo "debuff_appimage:: no desktop file: ${desktop_path}" >&2
		return 1
	fi

	if ! desktop_entry_is_auras_managed "${desktop_path}"; then
		echo "debuff_appimage:: refusing to remove unmanaged desktop file: ${desktop_path}" >&2
		return 1
	fi

	if ! rm -f "${desktop_path}"; then
		echo "debuff_appimage:: could not remove ${desktop_path}" >&2
		return 1
	fi

	echo "debuff_appimage:: removed ${desktop_path}"

	return 0
}

# Create or refresh a managed launcher for one explicit AppImage path
#
# Inputs:
# - $1 appimage_path, absolute path to AppImage
# - $2 app_stem, desktop stem and display name
#
# Side Effects:
# - Writes or overwrites a managed desktop entry under HOME .local share applications
#
# Returns:
# - 0 on success
# - 1 on validation or desktop write failure
buff_appimage() {
	local appimage_path
	local app_stem

	appimage_path="$1"
	app_stem="$2"

	if ! validate_app_name_segment "${app_stem}" "buff_appimage"; then
		return 1
	fi

	if ! validate_appimage_path "${appimage_path}" "buff_appimage"; then
		return 1
	fi

	if ! write_application_desktop "${app_stem}" "${appimage_path}" "${app_stem}"; then
		echo "buff_appimage:: failed to write desktop for ${appimage_path}" >&2
		return 1
	fi

	return 0
}

main() {
	local mode=""
	local appimage_path=""
	local app_stem=""

	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			usage
			return 0
			;;
		-b | --buff)
			if [[ -n "${mode}" ]]; then
				echo "main:: use only one of --buff or --debuff" >&2
				return 1
			fi

			if [[ $# -lt 3 ]]; then
				echo "main:: --buff requires APPIMAGE and NAME" >&2
				return 1
			fi

			mode="buff"
			appimage_path="$2"
			app_stem="$3"
			shift 3
			;;
		-d | --debuff)
			if [[ -n "${mode}" ]]; then
				echo "main:: use only one of --buff or --debuff" >&2
				return 1
			fi

			if [[ $# -lt 2 ]]; then
				echo "main:: --debuff requires NAME" >&2
				return 1
			fi

			mode="debuff"
			app_stem="$2"
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

	if [[ "${mode}" == "buff" ]]; then
		buff_appimage "${appimage_path}" "${app_stem}"
		return $?
	fi

	debuff_appimage "${app_stem}"

	return $?
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	main "$@"
	exit $?
fi
