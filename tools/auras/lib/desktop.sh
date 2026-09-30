#!/usr/bin/env bash
#
# Desktop entry inspection helpers for Auras
#

# Return whether Auras owns the desktop entry for one application stem
#
# Inputs:
# - $1 app_stem, desktop file stem without extension
#
# Returns:
# - 0 when a managed desktop entry exists for the stem
# - 1 otherwise
auras_manages_app_stem() {
	local app_stem="$1"

	local desktop_path
	desktop_path="$(desktop_path_for_stem "${app_stem}")" || return 1

	[[ ! -f "${desktop_path}" ]] && return 1

	desktop_entry_is_auras_managed "${desktop_path}" || return 1

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
	local desktop_path="$1"

	[[ -z "${desktop_path}" || ! -f "${desktop_path}" ]] && return 1

	grep -Fxq "${AURAS_MANAGED_KEY}" "${desktop_path}" || return 1

	grep -Fxq "${AURAS_VERSION_KEY}" "${desktop_path}" || return 1

	return 0
}

# Read Exec= target from a desktop file
#
# Inputs:
# - $1 desktop_path, desktop file to read
#
# Outputs:
# - AppImage path from Exec= on stdout
#
# Returns:
# - 0 on success
# - 1 when Exec= is missing or empty
desktop_entry_exec_path() {
	local desktop_path="$1"

	if [[ -z "${desktop_path}" || ! -f "${desktop_path}" ]]; then
		echo "desktop_entry_exec_path:: desktop_path is required" >&2
		return 1
	fi

	local exec_line
	exec_line="$(grep -E '^Exec=' "${desktop_path}" | head -n1)"

	if [[ -z "${exec_line}" ]]; then
		echo "desktop_entry_exec_path:: Exec= is missing in ${desktop_path}" >&2
		return 1
	fi

	local exec_path
	exec_path="${exec_line#Exec=}"
	exec_path="${exec_path#\"}"
	exec_path="${exec_path%\"}"
	exec_path="${exec_path%% %u}"
	exec_path="${exec_path%% %U}"
	exec_path="${exec_path#\"}"
	exec_path="${exec_path%\"}"

	if [[ -z "${exec_path}" ]]; then
		echo "desktop_entry_exec_path:: Exec= path is empty in ${desktop_path}" >&2
		return 1
	fi

	if [[ "${exec_path}" == *" "* || "${exec_path}" == *$'\t'* ]]; then
		echo "desktop_entry_exec_path:: could not parse Exec= in ${desktop_path}" >&2
		return 1
	fi

	echo "${exec_path}"

	return 0
}
