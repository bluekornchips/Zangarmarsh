#!/usr/bin/env bash
#
# Path and AppImage validation helpers for Auras
#

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
	local token="$1"
	local ctx="${2:-validate_app_name_segment}"

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
	local appimage_path="$1"
	local ctx="${2:-resolve_appimage_path}"

	if [[ -z "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage path is required" >&2
		return 1
	fi

	if [[ "${appimage_path}" =~ [[:cntrl:]] ]]; then
		echo "${ctx}:: AppImage path must not contain control characters" >&2
		return 1
	fi

	local appimage_dir="${appimage_path%/*}"
	local appimage_name="${appimage_path##*/}"

	if [[ "${appimage_dir}" == "${appimage_path}" ]]; then
		appimage_dir="."
	fi

	if [[ -z "${appimage_name}" || "${appimage_name}" == "." || "${appimage_name}" == ".." ]]; then
		echo "${ctx}:: AppImage file name is required" >&2
		return 1
	fi

	local resolved_dir
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
	local appimage_path="$1"
	local ctx="${2:-validate_appimage_path}"

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
	local raw_appimage_path="$1"
	local ctx="${2:-prepare_appimage_path}"

	local resolved_appimage_path
	resolved_appimage_path="$(resolve_appimage_path "${raw_appimage_path}" "${ctx}")" || return 1

	validate_appimage_path "${resolved_appimage_path}" "${ctx}" || return 1

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
	local suffix="$1"
	local ctx="$2"

	if [[ -z "${HOME}" ]]; then
		echo "${ctx}:: HOME is not set" >&2
		return 1
	fi

	echo "${HOME}/.local/${suffix}"

	return 0
}

applications_dir() {
	local_user_dir "share/applications" "applications_dir" || return 1

	return 0
}

bin_link_dir() {
	local_user_dir "bin" "bin_link_dir" || return 1

	return 0
}

# Resolve a symlink or path to a canonical absolute path
#
# Works on Bash 3.2 with BSD and GNU userland. Avoids GNU-only readlink -f.
#
# Inputs:
# - $1 path, symlink or ordinary path to resolve
# - $2 context label for error messages
#
# Outputs:
# - Canonical absolute path on stdout
#
# Returns:
# - 0 on success
# - 1 when the path is empty, unreadable, or cannot be canonicalized
resolve_symlink_path() {
	local path="$1"
	local ctx="${2:-resolve_symlink_path}"

	if [[ -z "${path}" ]]; then
		echo "${ctx}:: path is required" >&2
		return 1
	fi

	local depth=0
	local max_depth=32
	local link_target
	local link_dir
	while [[ -L "${path}" && "${depth}" -lt "${max_depth}" ]]; do
		link_target="$(readlink "${path}")" || {
			echo "${ctx}:: failed to read symlink: ${path}" >&2
			return 1
		}

		if [[ "${link_target}" != /* ]]; then
			link_dir="$(cd "$(dirname "${path}")" && pwd)" || {
				echo "${ctx}:: failed to resolve symlink directory: ${path}" >&2
				return 1
			}
			link_target="${link_dir}/${link_target}"
		fi

		path="${link_target}"
		depth=$((depth + 1))
	done

	if [[ -L "${path}" ]]; then
		echo "${ctx}:: symlink loop or depth exceeded: ${path}" >&2
		return 1
	fi

	local parent
	local base
	parent="$(dirname "${path}")"
	base="$(basename "${path}")"

	if [[ ! -d "${parent}" ]]; then
		if [[ "${path}" == /* ]]; then
			echo "${path}"
			return 0
		fi

		echo "${ctx}:: directory does not exist: ${parent}" >&2
		return 1
	fi

	local parent_abs
	parent_abs="$(cd "${parent}" && pwd -P)" || {
		echo "${ctx}:: failed to canonicalize directory: ${parent}" >&2
		return 1
	}
	echo "${parent_abs}/${base}"

	return 0
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
	local app_stem="$1"

	validate_app_name_segment "${app_stem}" "bin_link_path" || return 1

	local bin_root
	bin_root="$(bin_link_dir)" || return 1

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

	validate_app_name_segment "${app_stem}" "desktop_path_for_stem" || return 1

	local apps_root
	apps_root="$(applications_dir)" || return 1

	echo "${apps_root}/${app_stem}.desktop"

	return 0
}
