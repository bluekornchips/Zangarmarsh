#!/usr/bin/env bash
#
# Buff: install managed .desktop entries and bin symlinks for AppImage files
#

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

	if [[ -L "${link_path}" ]]; then
		local current_target
		current_target="$(resolve_symlink_path "${link_path}" "ensure_bin_link_writable" 2>/dev/null || true)"

		[[ -n "${current_target}" && "${current_target}" == "${expected_target}" ]] && return 0
	fi

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
# - $1 app_stem, basename for the .desktop file without extension
# - $2 resolved_appimage_path, absolute validated AppImage path
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
	local app_stem="$1"
	local resolved_appimage_path="$2"
	local display_name="$3"

	if [[ -z "${app_stem}" || -z "${resolved_appimage_path}" || -z "${display_name}" ]]; then
		echo "write_application_desktop:: app_stem, resolved_appimage_path, and display_name are required" >&2
		return 1
	fi

	validate_appimage_path "${resolved_appimage_path}" "write_application_desktop" || return 1

	local desktop_path
	desktop_path="$(desktop_path_for_stem "${app_stem}")" || return 1

	local apps_root
	apps_root="$(dirname "${desktop_path}")"

	if ! mkdir -p "${apps_root}"; then
		echo "write_application_desktop:: could not create ${apps_root}" >&2
		return 1
	fi

	ensure_desktop_entry_writable "${desktop_path}" || return 1

	if ! cat <<EOF >"${desktop_path}"
[Desktop Entry]
Type=Application
Name=${display_name}
Exec="${resolved_appimage_path}" %u
Terminal=false
${AURAS_MANAGED_KEY}
${AURAS_VERSION_KEY}
EOF
	then
		echo "write_application_desktop:: failed to write desktop file: ${desktop_path}" >&2
		return 1
	fi

	echo "write_application_desktop:: wrote ${desktop_path}"

	return 0
}

# Create or refresh a bin symlink without ownership checks
#
# Inputs:
# - $1 app_stem, command name without path segments
# - $2 resolved_appimage_path, absolute AppImage path
#
# Side Effects:
# - Creates bin directory if needed
# - Writes or replaces the symlink at the bin path for app_stem
#
# Returns:
# - 0 on success
# - 1 on path resolution, mkdir, or link failure
_auras_write_bin_link() {
	local app_stem="$1"
	local resolved_appimage_path="$2"

	if [[ -z "${app_stem}" || -z "${resolved_appimage_path}" ]]; then
		echo "_auras_write_bin_link:: app_stem and resolved_appimage_path are required" >&2
		return 1
	fi

	local link_path
	link_path="$(bin_link_path "${app_stem}")" || return 1

	local bin_root
	bin_root="$(dirname "${link_path}")"

	if ! mkdir -p "${bin_root}"; then
		echo "_auras_write_bin_link:: could not create ${bin_root}" >&2
		return 1
	fi

	if ! ln -sf "${resolved_appimage_path}" "${link_path}"; then
		echo "_auras_write_bin_link:: failed to link ${link_path}" >&2
		return 1
	fi

	echo "_auras_write_bin_link:: linked ${link_path} -> ${resolved_appimage_path}"

	return 0
}

# Remove a desktop file created during a failed buff operation
#
# Inputs:
# - $1 desktop_path, desktop file to remove
#
# Side Effects:
# - Removes desktop_path when it exists
#
# Returns:
# - 0 on success
# - 1 when desktop_path is empty or removal fails
auras_rollback_desktop() {
	local desktop_path="$1"

	if [[ -z "${desktop_path}" ]]; then
		echo "auras_rollback_desktop:: desktop_path is required" >&2
		return 1
	fi

	if [[ -e "${desktop_path}" ]] && ! rm -f "${desktop_path}"; then
		echo "auras_rollback_desktop:: could not remove ${desktop_path}" >&2
		return 1
	fi

	return 0
}

# Create or refresh a managed launcher and bin symlink for one AppImage
#
# Inputs:
# - $1 app_stem, desktop stem, display name, and command name
# - $2 resolved_appimage_path, absolute validated AppImage path
#
# Side Effects:
# - Writes managed desktop entry and bin symlink under HOME
# - Backs up an existing desktop before rewrite and restores it if the bin link fails
#
# Returns:
# - 0 on success
# - 1 on write failure
buff_launcher() {
	local app_stem="$1"
	local resolved_appimage_path="$2"

	if [[ -z "${app_stem}" || -z "${resolved_appimage_path}" ]]; then
		echo "buff_launcher:: app_stem and resolved_appimage_path are required" >&2
		return 1
	fi

	local desktop_path
	desktop_path="$(desktop_path_for_stem "${app_stem}")" || return 1

	local link_path
	link_path="$(bin_link_path "${app_stem}")" || return 1

	# Check the bin path before writing the desktop. Writing first would make
	# auras_manages_app_stem pass and allow overwriting an unmanaged bin file.
	ensure_bin_link_writable "${link_path}" "${resolved_appimage_path}" "${app_stem}" || return 1

	local desktop_existed=0
	local desktop_backup=""
	if [[ -e "${desktop_path}" ]]; then
		desktop_existed=1
		desktop_backup="$(mktemp "${TMPDIR:-/tmp}/auras-desktop.XXXXXX")" || {
			echo "buff_launcher:: could not create desktop backup" >&2
			return 1
		}
		trap 'rm -f "${desktop_backup}"' RETURN
		if ! cp "${desktop_path}" "${desktop_backup}"; then
			echo "buff_launcher:: could not back up desktop: ${desktop_path}" >&2
			return 1
		fi
	fi

	if ! write_application_desktop "${app_stem}" "${resolved_appimage_path}" "${app_stem}"; then
		echo "buff_launcher:: failed to write desktop for ${resolved_appimage_path}" >&2
		return 1
	fi

	if ! _auras_write_bin_link "${app_stem}" "${resolved_appimage_path}"; then
		if [[ "${desktop_existed}" -eq 1 ]]; then
			if ! cp "${desktop_backup}" "${desktop_path}"; then
				echo "buff_launcher:: could not restore desktop backup: ${desktop_path}" >&2
			fi
		else
			auras_rollback_desktop "${desktop_path}"
		fi

		echo "buff_launcher:: failed to write bin link for ${resolved_appimage_path}" >&2
		return 1
	fi

	return 0
}

# Run buff mode from parsed CLI arguments
#
# Inputs:
# - $1 app_stem, desktop stem, display name, and command name
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
