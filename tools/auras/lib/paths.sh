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
# - 1 when the path is empty or its directory does not exist
resolve_appimage_path() {
	local appimage_path="$1"
	local ctx="${2:-resolve_appimage_path}"

	if [[ -z "${appimage_path}" ]]; then
		echo "${ctx}:: AppImage path is required" >&2
		return 1
	fi

	local appimage_dir="${appimage_path%/*}"
	local appimage_name="${appimage_path##*/}"

	if [[ "${appimage_dir}" == "${appimage_path}" ]]; then
		appimage_dir="."
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

	if [[ "${appimage_path}" == *\"* || "${appimage_path}" == *%* ]]; then
		echo "${ctx}:: AppImage path must not contain a quote or percent sign" >&2
		return 1
	fi

	if [[ "${appimage_path}" == *\$* ]]; then
		echo "${ctx}:: AppImage path must not contain a dollar sign" >&2
		return 1
	fi

	if [[ "${appimage_path}" == *\`* ]]; then
		echo "${ctx}:: AppImage path must not contain a backtick" >&2
		return 1
	fi

	if [[ "${appimage_path}" == *\\* ]]; then
		echo "${ctx}:: AppImage path must not contain a backslash" >&2
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

# Resolve a path under HOME for Auras outputs
#
# Inputs:
# - $1 relative_path, path relative to HOME, for example .local/bin
# - $2 context label for error messages
#
# Outputs:
# - Absolute directory path on stdout
#
# Returns:
# - 0 on success
# - 1 if HOME is unset or empty, or relative_path is empty
_auras_local_user_dir() {
	local relative_path="$1"
	local ctx="${2:-_auras_local_user_dir}"

	if [[ -z "${HOME}" ]]; then
		echo "${ctx}:: HOME is not set" >&2
		return 1
	fi

	if [[ -z "${relative_path}" ]]; then
		echo "${ctx}:: relative_path is required" >&2
		return 1
	fi

	echo "${HOME}/${relative_path}"

	return 0
}

# Resolve ~/.local/share/applications
#
# Outputs:
# - Absolute applications directory path on stdout
#
# Returns:
# - 0 on success
# - 1 if HOME is unset or empty
applications_dir() {
	_auras_local_user_dir ".local/share/applications" "applications_dir"
	return $?
}

# Resolve ~/.local/bin
#
# Outputs:
# - Absolute bin directory path on stdout
#
# Returns:
# - 0 on success
# - 1 if HOME is unset or empty
bin_link_dir() {
	_auras_local_user_dir ".local/bin" "bin_link_dir"
	return $?
}

# Build a desktop or bin path for one application stem
#
# Inputs:
# - $1 app_stem, single path segment name
# - $2 kind, desktop or bin
# - $3 context label for error messages
#
# Outputs:
# - Absolute path on stdout
#
# Returns:
# - 0 on success
# - 1 when stem validation fails, HOME is unset, or kind is unknown
_auras_stem_path() {
	local app_stem="$1"
	local kind="$2"
	local ctx="${3:-_auras_stem_path}"

	validate_app_name_segment "${app_stem}" "${ctx}" || return 1

	local root
	case "${kind}" in
	desktop)
		root="$(applications_dir)" || return 1
		echo "${root}/${app_stem}.desktop"
		;;
	bin)
		root="$(bin_link_dir)" || return 1
		echo "${root}/${app_stem}"
		;;
	*)
		echo "${ctx}:: unknown stem path kind: ${kind}" >&2

		return 1
		;;
	esac

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

	_auras_stem_path "${app_stem}" "bin" "bin_link_path"
	return $?
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

	_auras_stem_path "${app_stem}" "desktop" "desktop_path_for_stem"
	return $?
}
