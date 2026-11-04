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

# Return 0 when left dotted version is greater than right
#
# Inputs:
# - $1 left version
# - $2 right version
#
# Returns:
# - 0 when left > right
# - 1 when left <= right
_version_gt() {
	local left_rest="${1}."
	local right_rest="${2}."
	local left_part
	local right_part

	while [[ -n "${left_rest}" || -n "${right_rest}" ]]; do
		left_part="${left_rest%%.*}"
		right_part="${right_rest%%.*}"
		if [[ "${left_rest}" == *.* ]]; then
			left_rest="${left_rest#*.}"
		else
			left_rest=""
		fi

		if [[ "${right_rest}" == *.* ]]; then
			right_rest="${right_rest#*.}"
		else
			right_rest=""
		fi

		left_part="${left_part:-0}"
		right_part="${right_part:-0}"
		if ((10#${left_part} > 10#${right_part})); then
			return 0
		fi

		if ((10#${left_part} < 10#${right_part})); then
			return 1
		fi
	done

	return 1
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
# - 1 when app_dir is empty, missing, or has no AppImage files
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

	local paths=()
	local path
	local base
	local has_versioned=0
	local ver
	# One walk so case-insensitive filesystems do not double-count via
	# separate *.AppImage and *.appimage globs.
	for path in "${app_dir}"/*; do
		[[ -f "${path}" ]] || continue
		base="${path##*/}"
		case "${base}" in
		*.AppImage | *.appimage) ;;
		*) continue ;;
		esac

		paths+=("${path}")
		ver="$(appimage_version_from_name "${base}")"
		if [[ -n "${ver}" ]]; then
			has_versioned=1
		fi
	done

	if ((${#paths[@]} == 0)); then
		echo "pick_latest_appimage:: no AppImage files in ${app_dir}" >&2
		return 1
	fi

	local winner_path=""
	local winner_ver=""
	for path in "${paths[@]}"; do
		ver="$(appimage_version_from_name "${path##*/}")"
		if ((has_versioned)) && [[ -z "${ver}" ]]; then
			continue
		fi

		if [[ -z "${winner_path}" ]]; then
			winner_path="${path}"
			winner_ver="${ver}"
			continue
		fi

		if [[ -n "${ver}" && -n "${winner_ver}" ]]; then
			if _version_gt "${ver}" "${winner_ver}"; then
				winner_path="${path}"
				winner_ver="${ver}"
				continue
			fi

			if _version_gt "${winner_ver}" "${ver}"; then
				continue
			fi
		fi

		# Same version, or both unversioned: bash -nt is portable, no stat.
		if [[ "${path}" -nt "${winner_path}" ]]; then
			winner_path="${path}"
			winner_ver="${ver}"
		fi
	done

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
