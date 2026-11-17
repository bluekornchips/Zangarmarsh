#!/usr/bin/env bash
#
# Quest-log Cursor plugin install and uninstall helpers
#

source "${ZANGARMARSH_ROOT}/tools/lib/fs.sh"

# Skills installed when QUEST_LOG_SKILLS is unset
QUEST_LOG_DEFAULT_SKILLS=(blue-author blue-optical blue-review blueberry)

# Print skill names from one --skill value
#
# Inputs:
# - $1, raw, a skill directory name or comma-separated names
#
# Outputs:
# - One skill name per line
#
# Returns:
# - 0 always
quest_log_expand_skill_arg() {
	local raw="$1"
	local normalized="${raw//,/ }"
	local part
	# Word-split on spaces left after comma replacement.
	# shellcheck disable=SC2086
	for part in ${normalized}; do
		printf '%s\n' "${part}"
	done

	return 0
}

# Export QUEST_LOG_SKILLS from --all and --skill CLI choices
#
# Inputs:
# - $1, want_all, true or false
# - remaining args, each a raw --skill value
#
# Side Effects:
# - Exports QUEST_LOG_SKILLS when want_all is true or skill args are present
# - Leaves QUEST_LOG_SKILLS unchanged when both are absent
#
# Returns:
# - 0 on success
# - 1 when --all and --skill are combined, or a skill value is empty
quest_log_apply_skill_flags() {
	local want_all="$1"
	shift

	if [[ "${want_all}" == true ]] && (($# > 0)); then
		echo "quest_log_apply_skill_flags:: use --all or --skill, not both" >&2
		return 1
	fi

	if [[ "${want_all}" == true ]]; then
		export QUEST_LOG_SKILLS=all
		return 0
	fi

	(($# == 0)) && return 0

	local names=()
	local raw
	local expanded
	local name
	for raw in "$@"; do
		if [[ -z "${raw}" ]]; then
			echo "quest_log_apply_skill_flags:: --skill needs a skill name" >&2
			return 1
		fi

		expanded="$(quest_log_expand_skill_arg "${raw}")"
		while IFS= read -r name; do
			[[ -n "${name}" ]] || continue
			names+=("${name}")
		done <<<"${expanded}"
	done

	if ((${#names[@]} == 0)); then
		echo "quest_log_apply_skill_flags:: --skill needs a skill name" >&2
		return 1
	fi

	export QUEST_LOG_SKILLS="${names[*]}"

	return 0
}

# Print the local Cursor plugin install directory after owned_path accepts it
#
# Reads environment:
# - HOME, used to resolve ~/.cursor/plugins/local/quest-log
#
# Outputs:
# - Absolute plugin install path, to stdout
#
# Returns:
# - 0 when the path is owned
# - 1 when HOME is empty or the path fails owned_path
quest_log_plugin_dir() {
	local plugins_root="${HOME:-}/.cursor/plugins/local"
	local install_dir="${plugins_root}/quest-log"
	owned_path "${install_dir}" "${plugins_root}" "quest_log_plugin_dir" || return 1
	printf '%s\n' "${install_dir}"

	return 0
}

# Print skill directory names to copy into the live plugin
#
# Inputs:
# - $1, plugin_source_dir, the tracked plugin tree under tools/quest-log/plugin
#
# Reads environment:
# - QUEST_LOG_SKILLS, unset for defaults, "all" for every skill under skills/,
#   or a space-separated skill list
#
# Outputs:
# - One skill directory name per line
#
# Returns:
# - 0 on success
# - 1 when an explicit skill name is missing from the source tree
quest_log_skills_to_install() {
	local plugin_source_dir="$1"
	local mode="${QUEST_LOG_SKILLS:-}"
	local skills=()
	local require_present=false
	local name

	if [[ "${mode}" == "all" ]]; then
		for name in "${plugin_source_dir}"/skills/*; do
			[[ -d "${name}" ]] || continue
			printf '%s\n' "${name##*/}"
		done

		return 0
	fi

	if [[ -z "${mode}" ]]; then
		skills=("${QUEST_LOG_DEFAULT_SKILLS[@]}")
	else
		require_present=true
		# Word-split the explicit install list from QUEST_LOG_SKILLS.
		# shellcheck disable=SC2206
		skills=(${mode})
	fi

	local has_blueberry=false
	local skill
	for skill in "${skills[@]}"; do
		if [[ "${skill}" == "blueberry" ]]; then
			has_blueberry=true
			break
		fi
	done

	if [[ "${has_blueberry}" == true ]]; then
		local has_penmanship=false
		for skill in "${skills[@]}"; do
			if [[ "${skill}" == "blue-penmanship" ]]; then
				has_penmanship=true
				break
			fi
		done

		if [[ "${has_penmanship}" == false ]]; then
			skills+=("blue-penmanship")
		fi
	fi

	for skill in "${skills[@]}"; do
		if [[ ! -d "${plugin_source_dir}/skills/${skill}" ]]; then
			if [[ "${require_present}" == true ]]; then
				echo "quest_log_skills_to_install:: skill not found: ${skill}" >&2
				return 1
			fi

			continue
		fi

		printf '%s\n' "${skill}"
	done

	return 0
}

# Return whether a skill name appears in a list of selected skills
#
# Inputs:
# - $1, needle, skill directory name
# - remaining args, selected skill names
#
# Returns:
# - 0 when needle is present
# - 1 when absent
_quest_log_skill_selected() {
	local needle="$1"
	shift

	local skill
	for skill in "$@"; do
		[[ "${skill}" == "${needle}" ]] && return 0
	done

	return 1
}

# Drop skills and agents from a staged plugin tree that are outside the install set
#
# Inputs:
# - $1, staging_dir, staged copy of the plugin
# - remaining args, selected skill directory names
#
# Side Effects:
# - Deletes skill directories not in the selected set
# - Deletes agents/ when blueberry is not selected
#
# Returns:
# - 0 on success
# - 1 when removal fails
_quest_log_prune_staged_plugin() {
	local staging_dir="$1"
	shift

	local skill_path
	for skill_path in "${staging_dir}/skills"/*; do
		[[ -e "${skill_path}" || -L "${skill_path}" ]] || continue
		local base="${skill_path##*/}"
		if ! _quest_log_skill_selected "${base}" "$@"; then
			rm -rf -- "${skill_path}" || return 1
		fi
	done

	if [[ -e "${staging_dir}/agents" ]] && ! _quest_log_skill_selected "blueberry" "$@"; then
		rm -rf -- "${staging_dir}/agents" || return 1
	fi

	return 0
}

# Replace the local Cursor plugin with a fresh copy of the tracked plugin tree
#
# Inputs:
# - $1, plugin_source_dir, the tracked plugin tree under tools/quest-log/plugin
#
# Reads environment:
# - DRY_RUN, when true report without writing
# - HOME, used to resolve the install path
# - QUEST_LOG_SKILLS, skill install set; see quest_log_skills_to_install
#
# Side Effects:
# - Copies plugin_source_dir to quest-log.staging beside the install path
# - Keeps only the selected skills, and agents when blueberry is selected
# - Moves the live install to quest-log.removing, moves the staged copy into place,
#   then deletes quest-log.removing
# - Deletes leftover staging and removing paths first, so an interrupted run is
#   repaired by the next run
#
# Returns:
# - 0 on success, including dry-run
# - 1 when the source is invalid, the path is unsafe, or a step fails
install_quest_plugin() {
	local plugin_source_dir="$1"

	[[ -f "${plugin_source_dir}/.cursor-plugin/plugin.json" ]] || {
		echo "install_quest_plugin:: plugin manifest not found: ${plugin_source_dir}/.cursor-plugin/plugin.json" >&2
		return 1
	}

	local skill_list
	skill_list="$(quest_log_skills_to_install "${plugin_source_dir}")" || return 1
	local selected=()
	local skill
	while IFS= read -r skill; do
		[[ -n "${skill}" ]] || continue
		selected+=("${skill}")
	done <<<"${skill_list}"

	local install_dir
	install_dir="$(quest_log_plugin_dir)" || return 1
	local install_parent
	install_parent="$(dirname "${install_dir}")"
	local staging_dir="${install_parent}/quest-log.staging"
	local removing_dir="${install_parent}/quest-log.removing"

	owned_path "${staging_dir}" "${install_parent}" "install_quest_plugin" || return 1
	owned_path "${removing_dir}" "${install_parent}" "install_quest_plugin" || return 1

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "install_quest_plugin: would replace ${install_dir}"
		if ((${#selected[@]} == 0)); then
			echo "install_quest_plugin: skills none"
		else
			echo "install_quest_plugin: skills ${selected[*]}"
		fi

		return 0
	fi

	ensure_dir "${install_parent}" "install_quest_plugin" || return 1

	# A partial copy from an interrupted run must never reach the install path,
	# so the staged copy is always rebuilt from source.
	rm -rf -- "${staging_dir}" "${removing_dir}" || return 1
	cp -R "${plugin_source_dir}" "${staging_dir}" || return 1

	if [[ "${QUEST_LOG_SKILLS:-}" != "all" ]]; then
		_quest_log_prune_staged_plugin "${staging_dir}" "${selected[@]}" || return 1
	fi

	if [[ -e "${install_dir}" ]]; then
		mv "${install_dir}" "${removing_dir}" || {
			echo "install_quest_plugin:: failed to move ${install_dir} aside" >&2
			return 1
		}
	fi

	mv "${staging_dir}" "${install_dir}" || {
		echo "install_quest_plugin:: failed to move ${staging_dir} into place" >&2
		return 1
	}

	rm -rf -- "${removing_dir}" || {
		echo "install_quest_plugin:: failed to remove ${removing_dir}" >&2
		return 1
	}

	echo "install_quest_plugin: complete"
	if ((${#selected[@]} == 0)); then
		echo "install_quest_plugin: skills none"
	else
		echo "install_quest_plugin: skills ${selected[*]}"
	fi

	return 0
}

# Remove the locally installed quest-log Cursor plugin directory
#
# Reads environment:
# - DRY_RUN, when true report without deleting
# - HOME, used to resolve the install path
#
# Side Effects:
# - Deletes the install directory unless DRY_RUN is true
#
# Returns:
# - 0 on success, including when absent or in dry-run mode
# - 1 when the path is unsafe or removal fails
uninstall_quest_plugin() {
	local install_dir
	install_dir="$(quest_log_plugin_dir)" || return 1

	if [[ ! -e "${install_dir}" ]]; then
		echo "uninstall_quest_plugin: not installed in ${install_dir}"
		return 0
	fi

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "uninstall_quest_plugin: would remove ${install_dir}"
		return 0
	fi

	rm -rf -- "${install_dir}" || {
		echo "uninstall_quest_plugin:: failed to remove ${install_dir}" >&2
		return 1
	}

	echo "uninstall_quest_plugin: removed ${install_dir}"

	return 0
}
