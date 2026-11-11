#!/usr/bin/env bash
#
# Buff: install managed .desktop entries and bin symlinks for AppImage files
#

source "${ZANGARMARSH_ROOT}/tools/lib/fs.sh" || return 1

# Ensure a desktop file may be written without clobbering an unmanaged entry
#
# Inputs:
# - $1 desktop_path, path that will be written
#
# Returns:
# - 0 when no file exists or the file is current Auras-managed
# - 1 when a file exists without current Auras markers
ensure_desktop_entry_writable() {
	local desktop_path="$1"

	if [[ -z "${desktop_path}" ]]; then
		echo "ensure_desktop_entry_writable:: desktop_path is required" >&2
		return 1
	fi

	[[ ! -e "${desktop_path}" ]] && return 0

	desktop_entry_is_auras_managed "${desktop_path}" && return 0

	echo "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file: ${desktop_path}" >&2

	return 1
}

# Ensure a bin symlink may be written without clobbering an unmanaged path
#
# Inputs:
# - $1 link_path, path that will be written
# - $2 expected_target, resolved AppImage path for the new link
# - $3 app_stem, desktop and symlink stem
#
# Returns:
# - 0 when the path may be written or refreshed
# - 1 when an unmanaged path would be overwritten
ensure_bin_link_writable() {
	local link_path="$1"
	local expected_target="$2"
	local app_stem="$3"

	if [[ -z "${link_path}" || -z "${expected_target}" || -z "${app_stem}" ]]; then
		echo "ensure_bin_link_writable:: link_path, expected_target, and app_stem are required" >&2
		return 1
	fi

	[[ ! -e "${link_path}" ]] && return 0
	[[ -L "${link_path}" && "$(readlink "${link_path}")" == "${expected_target}" ]] && return 0

	auras_manages_app_stem "${app_stem}" && return 0

	if [[ -L "${link_path}" ]]; then
		echo "ensure_bin_link_writable:: refusing to overwrite unmanaged bin symlink: ${link_path}" >&2
	else
		echo "ensure_bin_link_writable:: refusing to overwrite unmanaged bin path: ${link_path}" >&2
	fi

	return 1
}

# Write or overwrite a managed .desktop file for an AppImage
#
# Inputs:
# - $1 app_stem, desktop file stem without extension, also used as Name=
# - $2 resolved_appimage_path, absolute validated AppImage path
#
# Side Effects:
# - Writes desktop_path through write_atomic when it is absent or Auras-managed
#
# Returns:
# - 0 on success
# - 1 on validation, safety, or write failure
write_application_desktop() {
	local app_stem="$1"
	local resolved_appimage_path="$2"

	if [[ -z "${app_stem}" || -z "${resolved_appimage_path}" ]]; then
		echo "write_application_desktop:: app_stem and resolved_appimage_path are required" >&2
		return 1
	fi

	validate_appimage_path "${resolved_appimage_path}" "write_application_desktop" || return 1

	local desktop_path
	desktop_path="$(desktop_path_for_stem "${app_stem}")" || return 1

	ensure_desktop_entry_writable "${desktop_path}" || return 1

	local parent stage
	parent="$(dirname "${desktop_path}")"
	ensure_dir "${parent}" "write_application_desktop" || return 1
	stage="$(mktemp "${parent}/.zangarmarsh.XXXXXX")" || return 1
	if ! cat >"${stage}" <<EOF
[Desktop Entry]
Type=Application
Name=${app_stem}
Exec="${resolved_appimage_path}" %u
Terminal=false
${AURAS_MANAGED_KEY}
${AURAS_VERSION_KEY}
EOF
	then
		rm -f -- "${stage}"
		return 1
	fi

	write_atomic "${desktop_path}" "${stage}" "write_application_desktop" || {
		rm -f -- "${stage}"
		return 1
	}
	rm -f -- "${stage}"

	return 0
}

# Create or refresh a managed launcher and bin symlink for one AppImage
#
# Inputs:
# - $1 app_stem, desktop file stem, Name=, and command name
# - $2 resolved_appimage_path, absolute validated AppImage path
#
# Side Effects:
# - Writes the managed desktop entry, then the bin symlink through link_atomic
# - A failed bin link leaves the desktop entry in place, and a rerun repairs the link
#
# Returns:
# - 0 on success
# - 1 on validation, ownership, or write failure
buff_launcher() {
	local app_stem="$1"
	local resolved_appimage_path="$2"

	if [[ -z "${app_stem}" || -z "${resolved_appimage_path}" ]]; then
		echo "buff_launcher:: app_stem and resolved_appimage_path are required" >&2
		return 1
	fi

	local link_path
	link_path="$(bin_link_path "${app_stem}")" || return 1

	# Check the bin path before writing the desktop. Writing first would make
	# auras_manages_app_stem pass and allow overwriting an unmanaged bin file.
	ensure_bin_link_writable "${link_path}" "${resolved_appimage_path}" "${app_stem}" || return 1

	write_application_desktop "${app_stem}" "${resolved_appimage_path}" || return 1

	link_atomic "${link_path}" "${resolved_appimage_path}" "buff_launcher" || {
		echo "buff_launcher:: failed to write bin link for ${resolved_appimage_path}" >&2
		return 1
	}

	return 0
}

# Run buff mode from parsed CLI arguments
#
# Inputs:
# - $1 app_stem, desktop file stem and command name
# - $2 raw_appimage_path, user-supplied AppImage path
#
# Returns:
# - 0 on success
# - 1 on validation or write failure
buff_main() {
	local app_stem="$1"
	local raw_appimage_path="$2"

	if [[ -z "${app_stem}" ]]; then
		echo "buff_main:: --buff requires NAME" >&2
		return 1
	fi

	if [[ -z "${raw_appimage_path}" ]]; then
		echo "buff_main:: --buff requires --appimage PATH" >&2
		return 1
	fi

	validate_app_name_segment "${app_stem}" "buff_main" || return 1

	local resolved_appimage_path
	resolved_appimage_path="$(prepare_appimage_path "${raw_appimage_path}" "buff_main")" || return 1

	buff_launcher "${app_stem}" "${resolved_appimage_path}"

	return $?
}
