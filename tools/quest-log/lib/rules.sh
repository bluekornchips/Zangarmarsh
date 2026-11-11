#!/usr/bin/env bash
#
# Quest-log Cursor user-rules install and uninstall helpers
#

source "${ZANGARMARSH_ROOT}/tools/lib/fs.sh"

# Print the Cursor user-rules directory after owned_path accepts it
#
# Reads environment:
# - HOME, used to resolve ~/.cursor/rules
#
# Outputs:
# - Absolute rules directory path, to stdout
#
# Returns:
# - 0 when the path is owned
# - 1 when HOME is empty or the path fails owned_path
quest_log_rules_dir() {
	local rules_dir="${HOME:-}/.cursor/rules"
	owned_path "${rules_dir}" "${HOME:-}/.cursor" "quest_log_rules_dir" || return 1
	printf '%s\n' "${rules_dir}"
	return 0
}

# Delete one managed rule file after owned_path accepts its path
#
# Inputs:
# - $1, rule_path, zangarmarsh-*.mdc file to delete
# - $2, rules_dir, rules directory that must own rule_path
#
# Reads environment:
# - DRY_RUN, when true report without deleting
#
# Side Effects:
# - Deletes rule_path unless DRY_RUN is true
#
# Returns:
# - 0 on success, including dry-run
# - 1 when the path is unsafe or removal fails
_quest_log_remove_rule() {
	local rule_path="$1"
	local rules_dir="$2"

	owned_path "${rule_path}" "${rules_dir}" "_quest_log_remove_rule" || return 1

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "Would remove: ${rule_path}"
		return 0
	fi

	rm -f -- "${rule_path}" || {
		echo "_quest_log_remove_rule:: Failed to remove ${rule_path}" >&2
		return 1
	}

	echo "Removed: ${rule_path}"

	return 0
}

# Sync tracked rules into ~/.cursor/rules as zangarmarsh-<name>.mdc files
#
# Inputs:
# - $1, rules_source_dir, the tracked rules tree under tools/quest-log/plugin/rules
#
# Reads environment:
# - DRY_RUN, when true report without writing or deleting
# - HOME, used to resolve the rules directory
#
# Side Effects:
# - Writes each source rule as zangarmarsh-<name>.mdc through write_atomic
# - Deletes zangarmarsh-*.mdc files whose source rule is gone
# - Leaves files without the zangarmarsh- prefix untouched
#
# Returns:
# - 0 on success, including dry-run
# - 1 when the source has no rules, the path is unsafe, or a write or delete fails
install_quest_rules() {
	local rules_source_dir="$1"

	local rules_dir
	rules_dir="$(quest_log_rules_dir)" || return 1

	local sources=("${rules_source_dir}"/*.mdc)
	if [[ ! -f "${sources[0]}" ]]; then
		echo "install_quest_rules:: no .mdc rules in ${rules_source_dir}" >&2
		return 1
	fi

	local source_path
	for source_path in "${sources[@]}"; do
		write_atomic "${rules_dir}/zangarmarsh-${source_path##*/}" "${source_path}" "install_quest_rules" || return 1
	done

	local installed=("${rules_dir}"/zangarmarsh-*.mdc)
	local installed_path
	for installed_path in "${installed[@]}"; do
		[[ -e "${installed_path}" || -L "${installed_path}" ]] || continue

		local source_name="${installed_path##*/zangarmarsh-}"
		[[ -f "${rules_source_dir}/${source_name}" ]] && continue

		_quest_log_remove_rule "${installed_path}" "${rules_dir}" || return 1
	done

	return 0
}

# Delete every zangarmarsh-*.mdc rule from ~/.cursor/rules
#
# Reads environment:
# - DRY_RUN, when true report without deleting
# - HOME, used to resolve the rules directory
#
# Side Effects:
# - Deletes zangarmarsh-*.mdc files unless DRY_RUN is true
# - Leaves files without the zangarmarsh- prefix untouched
#
# Returns:
# - 0 on success, including when none are installed and in dry-run mode
# - 1 when the path is unsafe or removal fails
uninstall_quest_rules() {
	local rules_dir
	rules_dir="$(quest_log_rules_dir)" || return 1

	local installed=("${rules_dir}"/zangarmarsh-*.mdc)
	if [[ ! -e "${installed[0]}" && ! -L "${installed[0]}" ]]; then
		echo "uninstall_quest_rules: not installed in ${rules_dir}"
		return 0
	fi

	local installed_path
	for installed_path in "${installed[@]}"; do
		_quest_log_remove_rule "${installed_path}" "${rules_dir}" || return 1
	done

	return 0
}
