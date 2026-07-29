#!/usr/bin/env bash
#
# Command and workflow doc emission for quest-log
#

# Emit command docs for Cursor or Agent
#
# Inputs:
# - $1, target_dir, the directory where docs should be generated
# - $2, format, cursor copies markdown as-is; agent wraps with description frontmatter
#
# Side Effects:
# - Creates files in .cursor/commands/user or .agent/workflows
emit_command_docs() {
	local target_dir="$1"
	local format="$2"
	local label
	local out_dir

	case "${format}" in
	cursor)
		label="generate_commands"
		out_dir="${target_dir}/.cursor/commands/user"
		;;
	agent)
		label="generate_workflows"
		out_dir="${target_dir}/.agent/workflows"
		;;
	*)
		echo "emit_command_docs:: Unknown format: ${format}" >&2
		return 1
		;;
	esac

	if [[ -z "${target_dir}" ]]; then
		echo "${label}:: target_dir is required" >&2
		return 1
	fi

	echo "${label}: running"

	local commands_dir="${QUEST_LOG_ROOT}/commands"

	if [[ ! -d "${commands_dir}" ]]; then
		return 0
	fi

	if ! ensure_dir "${out_dir}" "${label}"; then
		return 1
	fi

	local command_file
	while IFS= read -r -d '' command_file; do
		local command_name
		command_name=$(basename "${command_file}" .md)

		local command_content
		command_content=$(cat "${command_file}")

		local output_content
		if [[ "${format}" == "cursor" ]]; then
			output_content="${command_content}"
		else
			local description
			description=$(head -n 1 "${command_file}" | sed 's/^# //')
			output_content=$(
				cat <<EOF
---
description: ${description}
---

${command_content}
EOF
			)
		fi

		local dest_file="${out_dir}/${command_name}.md"

		if ! write_if_changed "${dest_file}" "${output_content}" "none" "${label}"; then
			return 1
		fi
	done < <(find "${commands_dir}" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)

	echo "${label}: complete"

	return 0
}

# Generate Cursor daily-quests (commands) from markdown files
#
# Inputs:
# - $1, target_dir, the directory where daily-quests should be generated
generate_commands() {
	emit_command_docs "$1" "cursor"
}

# Generate Agent workflows from markdown files
#
# Inputs:
# - $1, target_dir, the directory where workflows should be generated
generate_workflows() {
	emit_command_docs "$1" "agent"
}
