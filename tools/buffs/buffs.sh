#!/usr/bin/env bash
#
# Scans packages subdirectories for AppImage files and syncs user .desktop entries
#

usage() {
	cat <<EOF
Usage: $(basename "$0") -a|--add -p|--packages-dir DIR [NAME ...] | -r|--remove NAME | -h|--help

Scans immediate subdirectories of DIR, picks the newest AppImage in each by
modification time, and writes or refreshes
\$HOME/.local/share/applications/<dirname>.desktop

With -a and no NAME arguments, every immediate subdirectory of DIR is
considered. Empty subdirectories are skipped. With one or more NAME arguments,
only DIR/NAME for each name is synced, each must exist and contain an AppImage.

Remove deletes only that desktop file by application name, stem without .desktop.

If your launcher cache is stale after add, run:
  update-desktop-database "\$HOME/.local/share/applications"

Options:
  -h, --help              Show this help message
  -a, --add [NAME ...]    Sync subdirs under the packages directory
  -p, --packages-dir DIR  Directory containing app subdirectories, required with -a
  -r, --remove NAME       Remove \$HOME/.local/share/applications/NAME.desktop

EOF
}

# Consume and validate the directory argument for --packages-dir
#
# Inputs:
# - $@ remaining argv after the -p or --packages-dir token, first token is the path
#
# Side Effects:
# - Sets packages_dir in the caller scope when that local exists in the caller
#
# Returns:
# - 0 on success
# - 1 if the path is missing, looks like another option, or is not a readable directory
_handle_input_packages_dir() {
	local candidate

	if [[ $# -eq 0 ]]; then
		echo "main:: -p requires a directory path" >&2
		return 1
	fi

	if [[ "$1" == -* ]]; then
		echo "main:: -p requires a directory path" >&2
		return 1
	fi

	candidate="$1"

	if [[ ! -d "${candidate}" ]]; then
		echo "main:: packages directory does not exist: ${candidate}" >&2
		return 1
	fi

	if [[ ! -r "${candidate}" ]]; then
		echo "main:: packages directory is not readable: ${candidate}" >&2
		return 1
	fi

	packages_dir="${candidate}"

	return 0
}

# Consume and validate the application stem argument for --remove
#
# Inputs:
# - $@ remaining argv after the -r or --remove token, first token is the desktop stem
#
# Side Effects:
# - Sets remove_name in the caller scope when that local exists in the caller
#
# Returns:
# - 0 on success
# - 1 if the name is missing, looks like another option, or is not a valid stem
_handle_input_remove_name() {
	if [[ $# -eq 0 ]]; then
		echo "main:: -r requires NAME, the desktop stem without .desktop" >&2
		return 1
	fi

	if [[ "$1" == -* ]]; then
		echo "main:: -r requires NAME, the desktop stem without .desktop" >&2
		return 1
	fi

	if [[ "$1" == *"/"* ]]; then
		echo "main:: -r NAME must be one path segment, not a path with slashes" >&2
		return 1
	fi

	if [[ "$1" == "." || "$1" == ".." ]]; then
		echo "main:: -r NAME must not be . or .." >&2
		return 1
	fi

	remove_name="$1"

	return 0
}

# Validate one subdirectory NAME token after --add and append it to add_targets
#
# Inputs:
# - $1 single NAME token taken from argv after -a
#
# Side Effects:
# - Appends to add_targets in the caller scope when that local exists in the caller
#
# Returns:
# - 0 on success
# - 1 if the token is empty or only whitespace
_handle_input_add_name() {
	local portion

	portion="$1"

	if [[ "${portion}" =~ ^[[:space:]]*$ ]]; then
		echo "main:: each NAME after -a must be non-empty" >&2
		return 1
	fi

	add_targets+=("${portion}")

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

# Find the newest AppImage in a directory by mtime
#
# Inputs:
# - $1 dir_path, path to directory to search
#
# Outputs:
# - Absolute path to newest AppImage by mtime, or empty if none
#
# Returns:
# - 0 on success
# - 1 if directory does not exist or is not readable
find_latest_appimage() {
	local dir_path
	local latest_line
	local appimage_path

	dir_path="$1"

	if [[ -z "${dir_path}" ]]; then
		echo "find_latest_appimage:: dir_path is required" >&2
		return 1
	fi

	if [[ ! -d "${dir_path}" ]]; then
		echo "find_latest_appimage:: directory does not exist: ${dir_path}" >&2
		return 1
	fi

	if [[ ! -r "${dir_path}" ]]; then
		echo "find_latest_appimage:: directory is not readable: ${dir_path}" >&2
		return 1
	fi

	latest_line="$(
		find "${dir_path}" -maxdepth 1 -type f \( -iname "*.AppImage" -o -iname "*.appimage" \) -printf '%T@\t%p\n' |
			sort -nr |
			head -n 1
	)"

	if [[ -z "${latest_line}" ]]; then
		return 0
	fi

	appimage_path="$(printf '%s\n' "${latest_line}" | cut -f2-)"

	if [[ -n "${appimage_path}" ]]; then
		echo "${appimage_path}"
	fi

	return 0
}

# Write or overwrite a .desktop file for an AppImage
#
# Inputs:
# - $1 app_stem, basename for the .desktop file without extension
# - $2 appimage_path, absolute path to the AppImage
# - $3 display_name, value for the Name= field
#
# Side Effects:
# - Creates applications directory if needed
# - Writes desktop_path
#
# Returns:
# - 0 on success
# - 1 on failure
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

	if [[ ! -f "${appimage_path}" ]]; then
		echo "write_application_desktop:: AppImage file does not exist: ${appimage_path}" >&2
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

	cat <<EOF >"${desktop_path}"
[Desktop Entry]
Type=Application
Name=${display_name}
Exec="${appimage_path}" %u
Terminal=false
EOF

	echo "write_application_desktop:: wrote ${desktop_path}"

	return 0
}

# Remove a user .desktop entry by application stem
#
# Inputs:
# - $1 app_stem, name without .desktop extension
#
# Side Effects:
# - Removes desktop file if present
#
# Returns:
# - 0 on success
# - 1 if name missing, HOME unset, or file missing
remove_desktop_entry() {
	local app_stem
	local apps_root
	local desktop_path

	app_stem="$1"

	if [[ -z "${app_stem}" ]]; then
		echo "remove_desktop_entry:: app_stem is required" >&2
		return 1
	fi

	if ! apps_root="$(applications_dir)"; then
		return 1
	fi

	desktop_path="${apps_root}/${app_stem}.desktop"

	if [[ ! -f "${desktop_path}" ]]; then
		echo "remove_desktop_entry:: no desktop file: ${desktop_path}" >&2
		return 1
	fi

	if ! rm -f "${desktop_path}"; then
		echo "remove_desktop_entry:: could not remove ${desktop_path}" >&2
		return 1
	fi

	echo "remove_desktop_entry:: removed ${desktop_path}"

	return 0
}

# Scan subdirectories and sync .desktop files for each AppImage
#
# Inputs:
# - $1 packages_dir, directory containing app subdirectories
# - $@ optional subdirectory names to restrict the scan
#
# Side Effects:
# - Writes or overwrites .desktop files under HOME .local share applications
#
# Returns:
# - 0 on success
# - 1 if packages_dir is invalid, a named directory is missing, no AppImages found, or a named dir has no AppImage
scan_and_sync_desktops() {
	local packages_dir
	local dir
	local appimage_path
	local app_stem
	local found_count
	local name
	local full
	local dirs_to_scan_array
	local named_mode=0

	packages_dir="$1"
	shift

	found_count=0
	dirs_to_scan_array=()

	if [[ -z "${packages_dir}" ]]; then
		echo "scan_and_sync_desktops:: packages_dir is required" >&2
		return 1
	fi

	if [[ ! -d "${packages_dir}" ]]; then
		echo "scan_and_sync_desktops:: not a directory: ${packages_dir}" >&2
		return 1
	fi

	if [[ ! -r "${packages_dir}" ]]; then
		echo "scan_and_sync_desktops:: packages directory is not readable: ${packages_dir}" >&2
		return 1
	fi

	if [[ $# -gt 0 ]]; then
		named_mode=1
	fi

	if [[ $# -eq 0 ]]; then
		for dir in "${packages_dir}"/*; do
			if [[ -d "${dir}" ]]; then
				dirs_to_scan_array+=("${dir}")
			fi
		done
	else
		for name in "$@"; do
			full="${packages_dir}/${name}"
			if [[ ! -d "${full}" ]]; then
				echo "scan_and_sync_desktops:: not a directory: ${full}" >&2
				return 1
			fi

			dirs_to_scan_array+=("${full}")
		done
	fi

	for dir in "${dirs_to_scan_array[@]}"; do
		if ! appimage_path="$(find_latest_appimage "${dir}")"; then
			echo "scan_and_sync_desktops:: failed to scan ${dir}" >&2
			continue
		fi

		if [[ -z "${appimage_path}" ]]; then
			if ((named_mode)); then
				echo "scan_and_sync_desktops:: no AppImage in ${dir}" >&2
				return 1
			fi

			continue
		fi

		app_stem="$(basename "${dir}")"

		if ! write_application_desktop "${app_stem}" "${appimage_path}" "${app_stem}"; then
			echo "scan_and_sync_desktops:: failed to write desktop for ${appimage_path}" >&2
			continue
		fi

		found_count=$((found_count + 1))
	done

	if [[ ${found_count} -eq 0 ]]; then
		echo "scan_and_sync_desktops:: no AppImages found in subdirectories" >&2
		return 1
	fi

	echo "scan_and_sync_desktops:: synced ${found_count} AppImage(s)"

	return 0
}

main() {
	local mode=""
	local remove_name=""
	local add_targets=()
	local packages_dir=""

	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			usage
			return 0
			;;
		-p | --packages-dir)
			shift
			if ! _handle_input_packages_dir "$@"; then
				return 1
			fi
			shift
			;;
		-a | --add)
			if [[ "${mode}" == "remove" ]]; then
				echo "main:: use only one of -a or -r" >&2
				return 1
			fi
			mode="add"
			shift

			while [[ $# -gt 0 && $1 != -* ]]; do
				if ! _handle_input_add_name "$1"; then
					return 1
				fi
				shift
			done
			;;
		-r | --remove)
			if [[ "${mode}" == "add" ]]; then
				echo "main:: use only one of -a or -r" >&2
				return 1
			fi

			if [[ "${mode}" == "remove" ]]; then
				echo "main:: -r expects a single application name" >&2
				return 1
			fi

			mode="remove"
			shift

			if ! _handle_input_remove_name "$@"; then
				return 1
			fi

			shift
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

	if [[ -n "${packages_dir}" && "${mode}" == "remove" ]]; then
		echo "main:: -p is only valid with -a" >&2
		return 1
	fi

	if [[ "${mode}" == "add" ]]; then
		if [[ -z "${packages_dir}" ]]; then
			echo "main:: -a requires -p DIR, the packages directory containing app subdirectories" >&2
			return 1
		fi

		scan_and_sync_desktops "${packages_dir}" "${add_targets[@]}"

		return $?
	fi

	remove_desktop_entry "${remove_name}"

	return $?
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	main "$@"
	exit $?
fi
