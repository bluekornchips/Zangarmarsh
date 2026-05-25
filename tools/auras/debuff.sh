#!/usr/bin/env bash
#
# Debuff: remove managed .desktop entries and bin symlinks for AppImage files
#

# Remove a managed bin symlink when it matches the desktop Exec target
#
# Inputs:
# - $1 app_stem, command name without path segments
# - $2 expected_target, AppImage path from the managed desktop Exec=
#
# Side Effects:
# - Removes symlink when it exists and points at expected_target
#
# Returns:
# - 0 on success or when no symlink exists
# - 1 when symlink exists but does not match expected_target
remove_application_bin_link() {
	local app_stem
	local expected_target
	local link_path
	local current_target

	app_stem="$1"
	expected_target="$2"

	if [[ -z "${app_stem}" || -z "${expected_target}" ]]; then
		echo "remove_application_bin_link:: app_stem and expected_target are required" >&2
		return 1
	fi

	if ! link_path="$(bin_link_path "${app_stem}")"; then
		return 1
	fi

	if [[ ! -L "${link_path}" ]]; then
		if [[ ! -e "${link_path}" ]]; then
			return 0
		fi

		echo "remove_application_bin_link:: refusing to remove unmanaged bin path: ${link_path}" >&2
		return 1
	fi

	current_target="$(readlink -f "${link_path}" 2>/dev/null || true)"

	if [[ "${current_target}" != "${expected_target}" ]]; then
		echo "remove_application_bin_link:: refusing to remove bin symlink with unexpected target: ${link_path}" >&2
		return 1
	fi

	if ! rm -f "${link_path}"; then
		echo "remove_application_bin_link:: could not remove ${link_path}" >&2
		return 1
	fi

	echo "remove_application_bin_link:: removed ${link_path}"

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
	local app_stem
	local apps_root
	local desktop_path
	local exec_target

	app_stem="$1"

	if [[ -z "${app_stem}" ]]; then
		echo "debuff_appimage:: app_stem is required" >&2
		return 1
	fi

	if ! validate_app_name_segment "${app_stem}" "debuff_appimage"; then
		return 1
	fi

	if ! desktop_path="$(desktop_path_for_stem "${app_stem}")"; then
		return 1
	fi

	if ! apps_root="$(applications_dir)"; then
		return 1
	fi

	if [[ ! -f "${desktop_path}" ]]; then
		echo "debuff_appimage:: no desktop file: ${desktop_path}" >&2
		return 1
	fi

	if ! desktop_entry_is_auras_managed "${desktop_path}"; then
		echo "debuff_appimage:: refusing to remove unmanaged desktop file: ${desktop_path}" >&2
		return 1
	fi

	if ! exec_target="$(desktop_entry_exec_path "${desktop_path}")"; then
		return 1
	fi

	if ! rm -f "${desktop_path}"; then
		echo "debuff_appimage:: could not remove ${desktop_path}" >&2
		return 1
	fi

	if ! remove_application_bin_link "${app_stem}" "${exec_target}"; then
		return 1
	fi

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
	local app_stem
	local appimage_path

	app_stem="$1"
	appimage_path="$2"

	if [[ -n "${appimage_path}" ]]; then
		echo "main:: --appimage is only valid with --buff" >&2
		return 1
	fi

	if [[ -z "${app_stem}" ]]; then
		echo "main:: --debuff requires NAME" >&2
		return 1
	fi

	debuff_appimage "${app_stem}"

	return $?
}
