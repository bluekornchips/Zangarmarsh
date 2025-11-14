#!/usr/bin/env bash
#
# Generate agentic tool rules for Cursor based on schema.json
#
set -eo pipefail

# Global cleanup trap handler
cleanup() {
	local exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		echo "Error in $0 at line $LINENO" >&2
	fi
}
trap cleanup EXIT ERR

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Generate agentic tool rules and daily-quests for Cursor based on schema.json. Rules
and daily-quests are installed locally in the project directory.

OPTIONS:
    -a, --all           Include all rules (including warcraft and lotr)
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Generate rules and daily-quests in git root (if in git repo) or current directory
    $0 /path/to/dir     # Generate rules and daily-quests in git root (if in git repo) or specified directory
    $0 --all            # Generate all rules including warcraft and lotr
EOF
}

DEFAULT_INCLUDE_ALL=false
SKIPPED_RULES=("warcraft" "lotr")

# Create a cursor rule file with the provided content
#
# Inputs:
# - $1, name, the name of the rule
# - $2, description, the description of the rule
# - $3, cursor_always_apply, whether the rule should always apply
# - $4, file_content, the content of the rule file
# - $5, globs, optional array of glob patterns for file matching
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

	if [[ ! -d "$CURSOR_RULES_DIR" ]]; then
		if ! mkdir -p "$CURSOR_RULES_DIR"; then
			echo "Failed to create directory: $CURSOR_RULES_DIR" >&2
			return 1
		fi
	fi

	local cursor_rule_file="${CURSOR_RULES_DIR}/rules-${name}.mdc"
	local cursor_rule_file_abs
	cursor_rule_file_abs=$(realpath "${cursor_rule_file}" 2>/dev/null || echo "${cursor_rule_file}")

	# Check if file exists and read existing content
	local existing_content=""
	if [[ -f "${cursor_rule_file}" ]]; then
		existing_content=$(cat "${cursor_rule_file}" 2>/dev/null || true)
	fi

	# Format globs for MDC frontmatter
	local globs_formatted
	globs_formatted=$(jq -r '.[]' <<<"${globs}" 2>/dev/null | sed 's/^/  - "/' | sed 's/$/"/' || echo "")

	local new_content
	new_content=$(
		cat <<EOF
---
description: $description
globs:
${globs_formatted}
alwaysApply: $cursor_always_apply
---

$file_content
EOF
	)

	# Check if content actually changed
	if [[ "$existing_content" == "$new_content" ]]; then
		echo "No changes: $cursor_rule_file_abs"
	else
		show_diff "$cursor_rule_file" "$new_content"
		echo "$new_content" >"$cursor_rule_file"
		if [[ -f "$cursor_rule_file" ]]; then
			echo "Updated: $cursor_rule_file_abs"
		else
			echo "Created: $cursor_rule_file_abs"
		fi
	fi

	return 0
}

# Show diff between current file and incoming changes
#
# Inputs:
# - $1, file_path, path to the file to compare
# - $2, new_content, the new content to compare against
#
# Side Effects:
# - Displays color-coded diff to terminal
show_diff() {
	local file_path="$1"
	local new_content="$2"
	local temp_file
	temp_file=$(mktemp)
	chmod 0600 "$temp_file"

	# Cleanup trap handler
	trap 'rm -f "$temp_file"' EXIT

	echo "$new_content" >"$temp_file"

	if [[ -f "$file_path" ]]; then
		if ! diff -u --color=always "$file_path" "$temp_file"; then
			echo "Differences found between $file_path and $temp_file"
		fi
	else
		echo "File does not exist: $file_path"
	fi

	# Remove trap and cleanup
	trap - EXIT
	rm -f "$temp_file"
	return $?
}

# Create all rule files from the quest schema
#
# Inputs:
# - $1, target_dir, the directory where rules should be generated
#
# Side Effects:
# - Creates cursor rule files in .cursor/rules directory
fill_quest_log() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "fill_quest_log:: target_dir is required" >&2
		return 1
	fi

	cat <<EOF

Filling quest log.

EOF

	local schema_contents
	if ! schema_contents=$(cat "${SCHEMA_FILE}"); then
		echo "fill_quest_log:: Failed to read schema file: ${SCHEMA_FILE}" >&2
		return 1
	fi

	if [[ ! -d "${CURSOR_RULES_DIR}" ]]; then
		if ! mkdir -p "${CURSOR_RULES_DIR}"; then
			echo "fill_quest_log:: Failed to create directory: ${CURSOR_RULES_DIR}" >&2
			return 1
		fi
	fi

	while IFS= read -r quest; do
		if ! name=$(jq -r '.name // ""' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest name from JSON" >&2
			return 1
		fi

		# Skip warcraft and lotr rules unless INCLUDE_ALL is true
		if [[ "${INCLUDE_ALL}" != "true" ]] && [[ "${SKIPPED_RULES[*]}" =~ ${name} ]]; then
			echo "fill_quest_log:: Skipping ${name} (use --all to include)"
			continue
		fi

		if ! file=$(jq -r '.file // ""' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest file from JSON" >&2
			return 1
		fi

		if ! icon=$(jq -r '.icon // ""' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest icon from JSON" >&2
			return 1
		fi

		if ! description=$(jq -r '.description // ""' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest description from JSON" >&2
			return 1
		fi

		if ! keywords=$(jq -r '.keywords // []' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest keywords from JSON" >&2
			return 1
		fi

		# Cursor Specific
		if ! cursor=$(jq -r '.cursor // {}' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest cursor data from JSON" >&2
			return 1
		fi

		if ! cursor_always_apply=$(jq -r '.cursor.alwaysApply // false' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest cursor alwaysApply from JSON" >&2
			return 1
		fi

		if ! cursor_globs=$(jq -r '.cursor.globs // []' <<<"${quest}"); then
			echo "fill_quest_log:: Failed to parse quest cursor globs from JSON" >&2
			return 1
		fi

		[[ "${name}" == "null" || -z "${name}" ]] && echo "fill_quest_log:: Quest name is required" >&2 && return 1
		[[ "${file}" == "null" || -z "${file}" ]] && echo "fill_quest_log:: Quest file is required" >&2 && return 1
		[[ "${icon}" == "null" || -z "${icon}" ]] && echo "fill_quest_log:: Quest icon is required" >&2 && return 1
		[[ "${description}" == "null" || -z "${description}" ]] && echo "fill_quest_log:: Quest description is required" >&2 && return 1
		[[ "${keywords}" == "null" || "${keywords}" == "[]" ]] && echo "fill_quest_log:: Quest keywords are required" >&2 && return 1
		[[ "${cursor}" == "null" || "${cursor}" == "{}" ]] && echo "fill_quest_log:: Quest cursor is required" >&2 && return 1

		file_content=$(
			cat <<EOF

RULE APPLIED: Start each response with an acknowledgement icon to confirm this rule is being followed: ${icon}

Keywords that trigger usage of this rule: $(echo "${keywords}" | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

$(cat "${QUEST_DIR}/${file}")
EOF
		)

		create_cursor_rule_file "${name}" "${description}" "${cursor_always_apply}" "${file_content}" "${cursor_globs}"

	done \
		<<<"$(jq -c '.[]' <<<"${schema_contents}")"

	return 0
}

# Generate Cursor daily-quests (commands) from markdown files
#
# Inputs:
# - $1, target_dir, the directory where daily-quests should be generated
#
# Side Effects:
# - Creates daily-quest files in .cursor/commands directory
generate_commands() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "generate_commands:: target_dir is required" >&2
		return 1
	fi

	local commands_dir="${QUEST_LOG_ROOT}/commands"
	local cursor_commands_dir="${target_dir}/.cursor/commands"

	if [[ ! -d "${commands_dir}" ]]; then
		return 0
	fi

	cat <<EOF

Generating daily-quests (Cursor commands).

EOF

		if [[ ! -d "${cursor_commands_dir}" ]]; then
		if ! mkdir -p "${cursor_commands_dir}"; then
			echo "generate_commands:: Failed to create daily-quests directory: ${cursor_commands_dir}" >&2
			return 1
		fi
	fi

	local command_file
	while IFS= read -r -d '' command_file; do
		local command_name
		command_name=$(basename "${command_file}" .md)

		local command_content
		command_content=$(cat "${command_file}")

		local cursor_command_file="${cursor_commands_dir}/${command_name}.md"

		# Check if content changed
		local existing_content=""
		if [[ -f "${cursor_command_file}" ]]; then
			existing_content=$(cat "${cursor_command_file}" 2>/dev/null || true)
		fi

		if [[ "$existing_content" == "$command_content" ]]; then
			echo "No changes: ${cursor_command_file}"
		else
			show_diff "${cursor_command_file}" "${command_content}"
			echo "${command_content}" >"${cursor_command_file}"
			if [[ -f "${cursor_command_file}" ]]; then
				echo "Updated: ${cursor_command_file}"
			else
				echo "Created: ${cursor_command_file}"
			fi
		fi
	done < <(find "${commands_dir}" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)

	return 0
}

# Install quest-log rules for Cursor
#
# Side Effects:
# - Creates local Cursor rules directory at TARGET_DIR/.cursor/rules/
# - Installs rules from quest-log schema
install_rules() {
	cat <<EOF

Installing quest-log rules for Cursor.

EOF

	# Define directories
	local cursor_rules_dir="${TARGET_DIR}/.cursor/rules"

	# Create local Cursor rules directory
	if ! mkdir -p "${cursor_rules_dir}"; then
		echo "install_rules:: Failed to create Cursor rules directory: ${cursor_rules_dir}" >&2
		return 1
	fi

	# Set target directory
	readonly CURSOR_RULES_DIR="${cursor_rules_dir}"

	echo "install_rules:: Cursor rules directory: ${cursor_rules_dir}"

	# Generate rules
	fill_quest_log "${TARGET_DIR}"

	cat <<EOF

Installation complete.
Cursor rules are available locally in this project.

EOF

	return 0
}

# Determine the target directory for rule generation
#
# Side Effects:
# - Sets TARGET_DIR to git root if in git repo, otherwise uses provided/current directory
# - Outputs status messages for testing
determine_target_directory() {
	local git_root
	if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
		TARGET_DIR="$git_root"
		echo "Git repository detected"
		echo "using git root: $git_root"
	else
		TARGET_DIR=${TARGET_DIR:-$PWD}
		echo "Not in a git repository"
	fi

	return 0
}

# Main entry point for the quest log generator
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Processes command line options
# - Generates rule files
# - Exits with appropriate status code
main() {
	cat <<EOF
=====
Running ${BASH_SOURCE[0]:-$0}
=====
EOF

	# Check for jq availability
	if ! command -v jq &>/dev/null; then
		echo "main:: jq is required but not installed." >&2
		exit 1
	fi

	SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
	SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
	QUEST_LOG_ROOT="${SCRIPT_DIR}"

	readonly QUEST_DIR="${SCRIPT_DIR}/quests"

	# Environment variables with defaults
	SCHEMA_FILE=${SCHEMA_FILE:-"${SCRIPT_DIR}/schema.json"}
	INCLUDE_ALL=${INCLUDE_ALL:-"${DEFAULT_INCLUDE_ALL}"}
	TARGET_DIR=${TARGET_DIR:-${PWD}}

	while [[ $# -gt 0 ]]; do
		case $1 in
		-a | --all)
			INCLUDE_ALL=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			echo "main:: Unknown option: ${1}" >&2
			usage
			exit 1
			;;
		*)
			TARGET_DIR="${1}"
			shift
			;;
		esac
	done

	determine_target_directory

	# Change to target directory for file operations
	if ! cd "${TARGET_DIR}"; then
		echo "main:: Failed to change to target directory: ${TARGET_DIR}" >&2
		exit 1
	fi

	if [[ ! -d "${TARGET_DIR}" ]]; then
		echo "main:: Target directory is required" >&2
		exit 1
	fi

	if [[ ! -r "${SCHEMA_FILE}" ]]; then
		echo "main:: Schema file not found: ${SCHEMA_FILE}" >&2
		exit 1
	fi

	# Install rules
	install_rules

	# Generate daily-quests if commands directory exists
	if [[ -d "${QUEST_LOG_ROOT}/commands" ]]; then
		generate_commands "${TARGET_DIR}"
	fi

	cat <<EOF
=====
Finished ${BASH_SOURCE[0]:-$0}
=====

EOF

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
	exit $?
fi
