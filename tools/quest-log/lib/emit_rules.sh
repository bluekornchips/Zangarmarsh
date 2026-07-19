#!/usr/bin/env bash
#
# Cursor and Agent rule emission for quest-log
#

# Format globs JSON array for YAML frontmatter list
#
# Inputs:
# - $1, globs, JSON array string
#
# Outputs:
# - formatted block starting with newline and list items, or space plus [] when empty
format_globs_yaml() {
	local globs="$1"
	local glob_count
	glob_count=$(echo "${globs}" | jq 'length' 2>/dev/null || echo "0")

	if ((glob_count > 0)); then
		local lines
		lines=$(jq -r '.[]' <<<"${globs}" 2>/dev/null | sed 's/^/  - "/' | sed 's/$/"/' || echo "")
		printf '\n%s' "${lines}"
	else
		printf ' []'
	fi

	return 0
}

# Build YAML frontmatter lines for a rule without outer delimiters
#
# Inputs:
# - $1, description
# - $2, globs JSON array
# - $3, cursor_always_apply
build_rule_frontmatter() {
	local description="$1"
	local globs="$2"
	local cursor_always_apply="$3"
	local globs_formatted

	globs_formatted=$(format_globs_yaml "${globs}") || return 1

	cat <<EOF
description: ${description}
globs:${globs_formatted}
alwaysApply: ${cursor_always_apply}
EOF

	return 0
}

# Create Cursor and Agent rule files with the provided content
#
# Inputs:
# - $1, name, the name of the rule
# - $2, description, the description of the rule
# - $3, cursor_always_apply, whether the rule should always apply
# - $4, file_content, the body after frontmatter
# - $5, globs, JSON array for Cursor globs
create_cursor_rule_file() {
	local name="$1"
	local description="$2"
	local cursor_always_apply="$3"
	local file_content="$4"
	local globs="$5"

	if [[ -z "${name}" ]]; then
		echo "create_cursor_rule_file:: Name is required" >&2
		return 1
	fi

	if [[ -z "${description}" ]]; then
		echo "create_cursor_rule_file:: Description is required" >&2
		return 1
	fi

	if [[ -z "${cursor_always_apply}" ]]; then
		echo "create_cursor_rule_file:: Cursor always apply is required" >&2
		return 1
	fi

	if [[ -z "${file_content}" ]]; then
		echo "create_cursor_rule_file:: File content is required" >&2
		return 1
	fi

	if ! validate_rule "${name}" "${file_content}" "${globs}" "${description}" "${cursor_always_apply}"; then
		echo "create_cursor_rule_file:: Validation failed for rule '${name}'" >&2
		return 1
	fi

	if ! ensure_dir "${CURSOR_RULES_DIR}" "create_cursor_rule_file"; then
		return 1
	fi

	if ! ensure_dir "${AGENT_RULES_DIR}" "create_cursor_rule_file"; then
		return 1
	fi

	local frontmatter
	if ! frontmatter=$(build_rule_frontmatter "${description}" "${globs}" "${cursor_always_apply}"); then
		echo "create_cursor_rule_file:: Failed to build frontmatter for rule '${name}'" >&2
		return 1
	fi

	local new_content
	new_content=$(
		cat <<EOF
---
${frontmatter}
---

${file_content}
EOF
	)

	local cursor_rule_file="${CURSOR_RULES_DIR}/rules-${name}.mdc"
	if ! write_if_changed "${cursor_rule_file}" "${new_content}" "rule" "create_cursor_rule_file"; then
		return 1
	fi

	local agent_rule_file="${AGENT_RULES_DIR}/rules-${name}.md"
	if ! write_if_changed "${agent_rule_file}" "${new_content}" "none" "create_cursor_rule_file"; then
		return 1
	fi

	return 0
}

# Create all rule files from the quest schema
#
# Inputs:
# - $1, target_dir, the directory where rules should be generated
#
# Side Effects:
# - Creates cursor rule files in .cursor/rules/user directory
fill_quest_log() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "fill_quest_log:: target_dir is required" >&2
		return 1
	fi

	echo "fill_quest_log: running"

	local schema_contents
	if ! schema_contents=$(cat "${SCHEMA_FILE}"); then
		echo "fill_quest_log:: Failed to read schema file: ${SCHEMA_FILE}" >&2
		return 1
	fi

	if ! ensure_dir "${CURSOR_RULES_DIR}" "fill_quest_log"; then
		return 1
	fi

	local quest
	while IFS= read -r quest; do
		local name
		local file
		local icon
		local description
		local keywords
		local cursor_always_apply
		local cursor_globs
		local file_content
		name=$(jq -r '.name // ""' <<<"${quest}")
		file=$(jq -r '.file // ""' <<<"${quest}")
		icon=$(jq -r '.icon // ""' <<<"${quest}")
		description=$(jq -r '.description // ""' <<<"${quest}")
		keywords=$(jq -c '.keywords // []' <<<"${quest}")
		cursor_always_apply=$(jq -r '.cursor.alwaysApply // false' <<<"${quest}")
		cursor_globs=$(jq -c '.cursor.globs // []' <<<"${quest}")

		[[ "${name}" == "null" || -z "${name}" ]] && echo "fill_quest_log:: Quest name is required" >&2 && return 1
		[[ "${file}" == "null" || -z "${file}" ]] && echo "fill_quest_log:: Quest file is required" >&2 && return 1
		[[ "${icon}" == "null" || -z "${icon}" ]] && echo "fill_quest_log:: Quest icon is required" >&2 && return 1
		[[ "${description}" == "null" || -z "${description}" ]] && echo "fill_quest_log:: Quest description is required" >&2 && return 1
		[[ "${keywords}" == "null" || "${keywords}" == "[]" ]] && echo "fill_quest_log:: Quest keywords are required" >&2 && return 1

		if [[ "$(jq -r '.cursor | type' <<<"${quest}")" != "object" ]]; then
			echo "fill_quest_log:: Quest cursor is required" >&2
			return 1
		fi

		if [[ ! -r "${QUEST_DIR}/${file}" ]]; then
			echo "fill_quest_log:: Quest template not found: ${QUEST_DIR}/${file}" >&2
			return 1
		fi

		file_content=$(
			cat <<EOF

RULE APPLIED: Start each response with an acknowledgement icon to confirm this rule is being followed: ${icon}

Keywords that trigger usage of this rule: $(echo "${keywords}" | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

$(cat "${QUEST_DIR}/${file}")
EOF
		)

		if ! create_cursor_rule_file "${name}" "${description}" "${cursor_always_apply}" "${file_content}" "${cursor_globs}"; then
			return 1
		fi

	done <<<"$(jq -c '.[]' <<<"${schema_contents}")"

	echo "fill_quest_log: complete"

	return 0
}
