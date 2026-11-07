#!/usr/bin/env bash
#
# Quest-log Cursor user-rules install and uninstall helpers
#
# Requires plugin.sh to be sourced first for _plugin_resolve_under_home.
#

QUEST_LOG_RULES_MANIFEST=".quest-log.manifest"

# Resolve the Cursor user-rules install directory
#
# Reads environment:
# - QUEST_LOG_RULES_DIR, optional override
# - HOME, used when QUEST_LOG_RULES_DIR is unset
#
# Outputs:
# - Absolute rules install path, to stdout
#
# Returns:
# - 0 on success
# - 1 when HOME is empty and no override is set
quest_log_rules_dir() {
	if [[ -n "${QUEST_LOG_RULES_DIR:-}" ]]; then
		printf '%s\n' "${QUEST_LOG_RULES_DIR}"
		return 0
	fi

	if [[ -z "${HOME:-}" ]]; then
		printf 'quest_log_rules_dir:: HOME is required\n' >&2
		return 1
	fi

	printf '%s/.cursor/rules\n' "${HOME}"

	return 0
}

# Validate the user-rules installation path before any deletion
#
# Inputs:
# - $1, install_dir, requested rules installation directory
#
# Returns:
# - 0 when install_dir is exactly ~/.cursor/rules
# - 1 when the path is unsafe or invalid
validate_rules_install_dir() {
	local install_dir="$1"
	local allowed_root="${HOME}/.cursor/rules"

	if [[ -z "${HOME:-}" || -z "${install_dir}" || "${install_dir}" != /* ]]; then
		echo "validate_rules_install_dir:: absolute install path is required" >&2
		return 1
	fi

	if [[ "${install_dir}" == */ ]]; then
		echo "validate_rules_install_dir:: trailing slash is not allowed" >&2
		return 1
	fi

	case "${install_dir}" in
	*"/../"* | *"/./"* | */.. | */.)
		echo "validate_rules_install_dir:: path traversal is not allowed" >&2
		return 1
		;;
	esac

	if [[ "${install_dir}" != "${allowed_root}" ]]; then
		echo "validate_rules_install_dir:: install path must be ${allowed_root}" >&2
		return 1
	fi

	_plugin_resolve_under_home "${install_dir}" >/dev/null || return 1

	return 0
}

# List managed rule basenames from a source rules directory
#
# Inputs:
# - $1, rules_source_dir, directory containing tracked *.mdc files
#
# Outputs:
# - One basename per line on stdout, sorted
#
# Returns:
# - 0 on success
# - 1 when the source directory is missing
_quest_log_list_rule_basenames() {
	local rules_source_dir="$1"

	if [[ ! -d "${rules_source_dir}" ]]; then
		echo "_quest_log_list_rule_basenames:: rules source not found: ${rules_source_dir}" >&2
		return 1
	fi

	local basenames=()
	local rule_path
	for rule_path in "${rules_source_dir}"/*.mdc; do
		[[ -f "${rule_path}" ]] || continue
		basenames+=("$(basename "${rule_path}")")
	done

	if ((${#basenames[@]} == 0)); then
		echo "_quest_log_list_rule_basenames:: no .mdc rules in ${rules_source_dir}" >&2
		return 1
	fi

	printf '%s\n' "${basenames[@]}" | LC_ALL=C sort

	return 0
}

# Read previously managed rule basenames from the install manifest
#
# Inputs:
# - $1, manifest_path, path to .quest-log.manifest
#
# Outputs:
# - One basename per line on stdout when the manifest exists
#
# Returns:
# - 0 always
_quest_log_read_rules_manifest() {
	local manifest_path="$1"

	if [[ -f "${manifest_path}" ]]; then
		grep -v '^[[:space:]]*$' "${manifest_path}" || true
	fi

	return 0
}

# Sync tracked *.mdc rules into ~/.cursor/rules for agent injection without reload
#
# Inputs:
# - $1, rules_source_dir, the tracked rules tree under tools/quest-log/plugin/rules
#
# Reads environment:
# - QUEST_LOG_RULES_DIR, optional install destination
# - DRY_RUN, when true report without writing
# - HOME, used to resolve the default install path
#
# Side Effects:
# - Writes tracked *.mdc files into the rules directory
# - Writes .quest-log.manifest listing managed basenames
# - Removes previously managed .mdc files that are no longer in source
# - Leaves non-managed files in the rules directory untouched
#
# Returns:
# - 0 on success, including dry-run
# - 1 when the source is invalid, the path is unsafe, or a write fails
install_quest_rules() {
	local rules_source_dir="$1"

	local install_dir
	install_dir="$(quest_log_rules_dir)" || return 1
	validate_rules_install_dir "${install_dir}" || return 1

	local new_basenames
	new_basenames="$(_quest_log_list_rule_basenames "${rules_source_dir}")" || return 1

	echo "install_quest_rules: running"

	if [[ "${DRY_RUN:-}" == "true" ]]; then
		echo "install_quest_rules: would sync rules into ${install_dir}"
		return 0
	fi

	ensure_dir "${install_dir}" "install_quest_rules" || return 1

	local manifest_path="${install_dir}/${QUEST_LOG_RULES_MANIFEST}"
	local old_basenames
	old_basenames="$(_quest_log_read_rules_manifest "${manifest_path}")"

	local rule_basename
	while IFS= read -r rule_basename; do
		[[ -n "${rule_basename}" ]] || continue

		if ! cp "${rules_source_dir}/${rule_basename}" "${install_dir}/${rule_basename}"; then
			echo "install_quest_rules:: failed to copy ${rule_basename}" >&2
			return 1
		fi
	done <<<"${new_basenames}"

	# Prune before replacing the manifest so a failed prune still leaves the
	# previous managed set listed for the next run.
	while IFS= read -r rule_basename; do
		[[ -n "${rule_basename}" ]] || continue

		if printf '%s\n' "${new_basenames}" | grep -Fxq -- "${rule_basename}"; then
			continue
		fi

		if [[ -e "${install_dir}/${rule_basename}" || -L "${install_dir}/${rule_basename}" ]]; then
			if ! rm -f -- "${install_dir}/${rule_basename}"; then
				echo "install_quest_rules:: failed to prune ${rule_basename}" >&2
				return 1
			fi
		fi
	done <<<"${old_basenames}"

	local staging_manifest
	staging_manifest="$(mktemp "${install_dir}/.quest-log.manifest.XXXXXX")" || {
		echo "install_quest_rules:: Failed to create staging manifest" >&2
		return 1
	}

	if ! printf '%s\n' "${new_basenames}" >"${staging_manifest}"; then
		rm -f -- "${staging_manifest}"
		echo "install_quest_rules:: Failed to write staging manifest" >&2
		return 1
	fi

	if ! mv "${staging_manifest}" "${manifest_path}"; then
		rm -f -- "${staging_manifest}"
		echo "install_quest_rules:: Failed to activate rules manifest" >&2
		return 1
	fi

	echo "install_quest_rules: complete"

	return 0
}

# Remove quest-log-managed Cursor user rules listed in the install manifest
#
# Reads environment:
# - QUEST_LOG_RULES_DIR, optional install destination
# - DRY_RUN, when true report without deleting
# - HOME, used to resolve the default install path
#
# Side Effects:
# - Deletes managed *.mdc files and .quest-log.manifest when present
# - Leaves non-managed files in the rules directory untouched
#
# Returns:
# - 0 on success, including when absent or in dry-run mode
# - 1 when the path is unsafe or removal fails
uninstall_quest_rules() {
	local install_dir
	install_dir="$(quest_log_rules_dir)" || return 1
	validate_rules_install_dir "${install_dir}" || return 1

	local manifest_path="${install_dir}/${QUEST_LOG_RULES_MANIFEST}"

	if [[ ! -f "${manifest_path}" ]]; then
		echo "uninstall_quest_rules: not installed in ${install_dir}"
		return 0
	fi

	local managed
	managed="$(_quest_log_read_rules_manifest "${manifest_path}")"

	if [[ "${DRY_RUN:-}" == "true" ]]; then
		echo "uninstall_quest_rules: would remove managed rules from ${install_dir}"
		return 0
	fi

	local rule_basename
	while IFS= read -r rule_basename; do
		[[ -n "${rule_basename}" ]] || continue

		if [[ -e "${install_dir}/${rule_basename}" || -L "${install_dir}/${rule_basename}" ]]; then
			if ! rm -f -- "${install_dir}/${rule_basename}"; then
				echo "uninstall_quest_rules:: failed to remove ${rule_basename}" >&2
				return 1
			fi
		fi
	done <<<"${managed}"

	if ! rm -f -- "${manifest_path}"; then
		echo "uninstall_quest_rules:: failed to remove ${manifest_path}" >&2
		return 1
	fi

	if [[ -e "${manifest_path}" || -L "${manifest_path}" ]]; then
		echo "uninstall_quest_rules:: failed to remove ${manifest_path}" >&2
		return 1
	fi

	echo "uninstall_quest_rules: removed managed rules from ${install_dir}"

	return 0
}
