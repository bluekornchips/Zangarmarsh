#!/usr/bin/env bash
#
# Debuff: remove managed .desktop entries and bin symlinks for AppImage files
#

# Validate that a managed bin symlink may be removed
#
# Inputs:
# - $1 app_stem, command name without path segments
# - $2 expected_target, AppImage path from the managed desktop Exec=
#
# Returns:
# - 0 when no symlink exists or it points at expected_target
# - 1 when an unmanaged path exists or the symlink target does not match
ensure_bin_link_removable() {
	local app_stem="$1"
	local expected_target="$2"

	if [[ -z "${app_stem}" || -z "${expected_target}" ]]; then
		echo "ensure_bin_link_removable:: app_stem and expected_target are required" >&2
		return 1
	fi

	local link_path
	link_path="$(bin_link_path "${app_stem}")" || return 1

	if [[ ! -L "${link_path}" ]]; then
		[[ ! -e "${link_path}" ]] && return 0

		echo "ensure_bin_link_removable:: refusing to remove unmanaged bin path: ${link_path}" >&2
		return 1
	fi

	local current_target
	current_target="$(readlink "${link_path}")" || return 1

	if [[ "${current_target}" != "${expected_target}" ]]; then
		echo "ensure_bin_link_removable:: refusing to remove bin symlink with unexpected target: ${link_path}" >&2
		return 1
	fi

	return 0
}

# Remove a bin symlink without ownership checks
#
# Inputs:
# - $1 app_stem, command name without path segments
#
# Side Effects:
# - Removes the symlink when it exists
#
# Returns:
# - 0 on success or when no symlink exists
# - 1 when path resolution or removal fails
_auras_unlink_bin_link() {
	local app_stem="$1"

	if [[ -z "${app_stem}" ]]; then
		echo "_auras_unlink_bin_link:: app_stem is required" >&2
		return 1
	fi

	local link_path
	link_path="$(bin_link_path "${app_stem}")" || return 1

	[[ ! -L "${link_path}" ]] && return 0

	if ! rm -f "${link_path}"; then
		echo "_auras_unlink_bin_link:: could not remove ${link_path}" >&2
		return 1
	fi

	echo "_auras_unlink_bin_link:: removed ${link_path}"

	return 0
}

# Remove a managed user .desktop entry and matching bin symlink
#
# Inputs:
# - $1 app_stem, name without .desktop extension
#
# Side Effects:
# - Removes desktop file and bin symlink when current Auras-managed
#
# Returns:
# - 0 on success
# - 1 if name missing, HOME unset, file missing, or file is unmanaged
debuff_appimage() {
	local app_stem="$1"

	if [[ -z "${app_stem}" ]]; then
		echo "debuff_appimage:: app_stem is required" >&2
		return 1
	fi

	local desktop_path
	desktop_path="$(desktop_path_for_stem "${app_stem}")" || return 1

	local apps_root
	apps_root="$(dirname "${desktop_path}")"

	if [[ ! -f "${desktop_path}" ]]; then
		echo "debuff_appimage:: no desktop file: ${desktop_path}" >&2
		return 1
	fi

	if ! desktop_entry_is_auras_managed "${desktop_path}"; then
		echo "debuff_appimage:: refusing to remove unmanaged desktop file: ${desktop_path}" >&2
		return 1
	fi

	local exec_target
	exec_target="$(desktop_entry_exec_path "${desktop_path}")" || return 1

	# Validate bin link before removing the desktop so a mismatch cannot leave a
	# half-removed managed launcher.
	ensure_bin_link_removable "${app_stem}" "${exec_target}" || return 1

	if ! rm -f "${desktop_path}"; then
		echo "debuff_appimage:: could not remove ${desktop_path}" >&2
		return 1
	fi

	_auras_unlink_bin_link "${app_stem}" || return 1

	echo "debuff_appimage:: removed ${apps_root}/${app_stem}.desktop"

	return 0
}

# Run debuff mode from parsed CLI arguments
#
# Inputs:
# - $1 app_stem, desktop stem without extension
# - $2 appimage_path, optional raw AppImage path from CLI, rejected when non-empty
#
# Returns:
# - 0 on success
# - 1 on validation or removal failure
debuff_main() {
	local app_stem="$1"
	local appimage_path="$2"

	if [[ -n "${appimage_path}" ]]; then
		echo "debuff_main:: --appimage is only valid with --buff" >&2
		return 1
	fi

	if [[ -z "${app_stem}" ]]; then
		echo "debuff_main:: --debuff requires NAME" >&2
		return 1
	fi

	validate_app_name_segment "${app_stem}" "debuff_main" || return 1

	debuff_appimage "${app_stem}"

	return $?
}
