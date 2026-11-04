#!/usr/bin/env bash
#
# Ready-check: pick the newest AppImage under each app directory and install it
#

# Extract a semver-like version token from an AppImage basename
#
# Inputs:
# - $1 filename, AppImage basename such as DemoApp-1.2.3.AppImage
#
# Outputs:
# - Version string without a leading v on stdout, or empty when none matches
#
# Returns:
# - 0 always
appimage_version_from_name() {
	local filename="$1"

	if [[ -z "${filename}" ]]; then
		echo ""
		return 0
	fi

	local base="${filename}"
	if [[ "${base}" == *.AppImage ]]; then
		base="${base%.AppImage}"
	elif [[ "${base}" == *.appimage ]]; then
		base="${base%.appimage}"
	fi

	if [[ "${base}" =~ [Vv]?([0-9]+(\.[0-9]+)+) ]]; then
		echo "${BASH_REMATCH[1]}"
		return 0
	fi

	echo ""

	return 0
}

# Choose the newest AppImage in one directory by version, then mtime
#
# Inputs:
# - $1 app_dir, directory that may contain AppImage files
#
# Outputs:
# - Absolute path to the winning AppImage on stdout
#
# Returns:
# - 0 when a winner is found
# - 1 when app_dir is empty, missing, has no AppImage files, or GNU stat/sort is unavailable
pick_latest_appimage() {
	local app_dir="$1"

	if [[ -z "${app_dir}" ]]; then
		echo "pick_latest_appimage:: app_dir is required" >&2
		return 1
	fi

	if [[ ! -d "${app_dir}" ]]; then
		echo "pick_latest_appimage:: app_dir does not exist: ${app_dir}" >&2
		return 1
	fi

	if ! command -v stat >/dev/null 2>&1 || ! command -v sort >/dev/null 2>&1; then
		echo "pick_latest_appimage:: stat and sort are required" >&2
		return 1
	fi

	if ! stat -c %Y / >/dev/null 2>&1; then
		echo "pick_latest_appimage:: GNU stat -c %Y is required" >&2
		return 1
	fi

	local records=()
	local has_versioned=0
	local path
	local ver
	local mtime
	for path in "${app_dir}"/*.AppImage "${app_dir}"/*.appimage; do
		[[ -f "${path}" ]] || continue

		ver="$(appimage_version_from_name "${path##*/}")"
		if ! mtime="$(stat -c %Y "${path}")"; then
			echo "pick_latest_appimage:: could not read mtime: ${path}" >&2
			return 1
		fi

		if [[ -n "${ver}" ]]; then
			has_versioned=1
			records+=("v	${ver}	${mtime}	${path}")
		else
			records+=("u		${mtime}	${path}")
		fi
	done

	if ((${#records[@]} == 0)); then
		echo "pick_latest_appimage:: no AppImage files in ${app_dir}" >&2
		return 1
	fi

	local winner_line
	if ((has_versioned)); then
		winner_line="$(printf '%s\n' "${records[@]}" | grep '^v' | sort -t $'\t' -k2,2V -k3,3n | tail -n1)"
	else
		winner_line="$(printf '%s\n' "${records[@]}" | sort -t $'\t' -k3,3n | tail -n1)"
	fi

	local winner_path="${winner_line##*$'\t'}"
	echo "${winner_path}"

	return 0
}

# Buff every immediate app subdirectory under a packages root
#
# Inputs:
# - $1 packages_dir, directory whose children each hold AppImage files
#
# Side Effects:
# - Writes managed desktop entries and bin symlinks for each successful stem
#
# Returns:
# - 0 when every child succeeds, or when packages_dir has no child directories
# - 1 when packages_dir is missing or any child fails to buff
ready_check_main() {
	local packages_dir="$1"

	if [[ -z "${packages_dir}" ]]; then
		echo "ready_check_main:: --ready-check requires DIR" >&2
		return 1
	fi

	local resolved_root
	if ! resolved_root="$(cd "${packages_dir}" && pwd -P)"; then
		echo "ready_check_main:: packages directory does not exist: ${packages_dir}" >&2
		return 1
	fi

	local child_count=0
	local fail_count=0
	local stem
	local winner
	local child
	for child in "${resolved_root}"/*; do
		[[ -d "${child}" ]] || continue
		child_count=$((child_count + 1))
		stem="${child##*/}"

		if ! winner="$(pick_latest_appimage "${child}")"; then
			echo "ready_check_main:: no AppImage found for ${stem} in ${child}" >&2
			fail_count=$((fail_count + 1))
			continue
		fi

		if ! buff_launcher "${stem}" "${winner}"; then
			echo "ready_check_main:: failed to buff ${stem}" >&2
			fail_count=$((fail_count + 1))
			continue
		fi
	done

	if ((child_count == 0)); then
		echo "ready_check_main:: no application directories under ${resolved_root}" >&2
		return 0
	fi

	if ((fail_count > 0)); then
		return 1
	fi

	return 0
}
