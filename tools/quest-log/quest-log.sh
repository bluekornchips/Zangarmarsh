#!/usr/bin/env bash
#
# Generate agentic tool rules for Cursor based on schema.json
#

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Generate agentic tool rules and daily-quests for Cursor based on schema.json. Rules
and daily-quests are installed locally in the project directory.
Baseline quests include always, python, shell, and typescript.

OPTIONS:
    -a, --all           Include all rules (including warcraft and lotr)
    -f, --force         Force operations (replace existing VSCode settings)
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Generate rules and daily-quests in git root (if in git repo) or current directory
    $0 /path/to/dir     # Generate rules and daily-quests in git root (if in git repo) or specified directory
    $0 --all            # Generate all rules including warcraft and lotr
EOF
}

DEFAULT_INCLUDE_ALL=false
DEFAULT_FORCE=false
SKIPPED_RULES=("warcraft" "lotr")

# Statistics tracking
STATS_CREATED=0
STATS_UPDATED=0
STATS_UNCHANGED=0
STATS_SKIPPED=0
STATS_ERRORS=0
STATS_TOTAL_LINES=0
STATS_WARNINGS=0

# Validate rule content
#
# Inputs:
# - $1, name, the name of the rule
# - $2, file_content, the content of the rule file
# - $3, globs, optional array of glob patterns for file matching
# - $4, description, the description of the rule
# - $5, cursor_always_apply, whether the rule should always apply
#
# Returns:
# - 0 if validation passes
# - 1 if validation fails
# - Sets STATS_WARNINGS and STATS_ERRORS accordingly
validate_rule() {
	local name="$1"
	local file_content="$2"
	local globs="$3"
	local description="$4"
	local cursor_always_apply="$5"
	local validation_failed=false

	# Validate rule length (500 line limit per Cursor best practices)
	local line_count
	line_count=$(echo "${file_content}" | wc -l | tr -d ' ')
	if ((line_count > 500)); then
		echo "validate_rule:: Error: Rule '${name}' exceeds 500 lines (${line_count} lines)" >&2
		echo "validate_rule:: Suggestion: Split into multiple rules or use rule composition" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	elif ((line_count > 400)); then
		echo "validate_rule:: Rule '${name}' is approaching the 500 line limit (${line_count} lines)" >&2
		echo "validate_rule:: Consider splitting into multiple rules" >&2
		STATS_WARNINGS=$((STATS_WARNINGS + 1))
	fi

	# Validate description is meaningful when using intelligent application
	if [[ "${cursor_always_apply}" == "false" ]]; then
		local glob_count
		glob_count=$(echo "${globs}" | jq 'length' 2>/dev/null || echo "0")
		if [[ "${glob_count}" == "0" ]]; then
			# Using intelligent application - description should be descriptive
			local desc_length
			desc_length=$(echo -n "${description}" | wc -c | tr -d ' ')
			if ((desc_length < 20)); then
				echo "validate_rule:: Rule '${name}' has a short description (${desc_length} chars) but uses intelligent application" >&2
				echo "validate_rule:: Suggestion: Provide a more descriptive description for better AI matching" >&2
				STATS_WARNINGS=$((STATS_WARNINGS + 1))
			fi
		fi
	fi

	# Validate glob patterns (basic syntax check)
	if [[ -n "${globs}" ]] && [[ "${globs}" != "[]" ]]; then
		local glob_array
		if ! glob_array=$(echo "${globs}" | jq -r '.[]' 2>/dev/null); then
			echo "validate_rule:: Error: Rule '${name}' has invalid globs JSON format" >&2
			STATS_ERRORS=$((STATS_ERRORS + 1))
			validation_failed=true
		else
			# Basic glob pattern validation
			while IFS= read -r glob_pattern; do
				if [[ -z "${glob_pattern}" ]]; then
					continue
				fi
				# Check for common glob pattern issues
				if [[ "${glob_pattern}" =~ ^[[:space:]]+ ]] || [[ "${glob_pattern}" =~ [[:space:]]+$ ]]; then
					echo "validate_rule:: Rule '${name}' has glob pattern with leading/trailing whitespace: '${glob_pattern}'" >&2
					STATS_WARNINGS=$((STATS_WARNINGS + 1))
				fi
			done <<<"${glob_array}"
		fi
	fi

	# Validate description is not empty
	if [[ -z "${description}" ]] || [[ "${description}" == "null" ]]; then
		echo "validate_rule:: Error: Rule '${name}' has empty description" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	fi

	# Track total lines
	STATS_TOTAL_LINES=$((STATS_TOTAL_LINES + line_count))

	if [[ "${validation_failed}" == "true" ]]; then
		return 1
	fi

	return 0
}

# Validate MDC frontmatter syntax
#
# Inputs:
# - $1, name, the name of the rule
# - $2, frontmatter_content, the frontmatter YAML content (without --- delimiters)
#
# Returns:
# - 0 if validation passes
# - 1 if validation fails
# - Sets STATS_WARNINGS and STATS_ERRORS accordingly
validate_mdc_frontmatter() {
	local name="$1"
	local frontmatter_content="$2"
	local validation_failed=false

	# Check for required fields
	if ! echo "${frontmatter_content}" | grep -q "^description:"; then
		echo "validate_mdc_frontmatter:: Error: Rule '${name}' frontmatter missing required field 'description'" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	fi

	if ! echo "${frontmatter_content}" | grep -q "^globs:"; then
		echo "validate_mdc_frontmatter:: Error: Rule '${name}' frontmatter missing required field 'globs'" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	fi

	if ! echo "${frontmatter_content}" | grep -q "^alwaysApply:"; then
		echo "validate_mdc_frontmatter:: Error: Rule '${name}' frontmatter missing required field 'alwaysApply'" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	fi

	# Validate YAML-like structure (basic check for colon-separated key-value pairs)
	local line_count
	line_count=$(echo "${frontmatter_content}" | wc -l | tr -d ' ')
	if ((line_count == 0)); then
		echo "validate_mdc_frontmatter:: Error: Rule '${name}' has empty frontmatter" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	fi

	if [[ "${validation_failed}" == "true" ]]; then
		return 1
	fi

	return 0
}

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

	# Validate rule before creating
	if ! validate_rule "${name}" "${file_content}" "${globs}" "${description}" "${cursor_always_apply}"; then
		echo "create_cursor_rule_file:: Validation failed for rule '${name}'" >&2
		return 1
	fi

	if [[ ! -d "${CURSOR_RULES_DIR}" ]]; then
		if ! mkdir -p "${CURSOR_RULES_DIR}"; then
			echo "create_cursor_rule_file:: Failed to create directory: ${CURSOR_RULES_DIR}" >&2
			return 1
		fi
	fi

	if [[ ! -d "${AGENT_RULES_DIR}" ]]; then
		if ! mkdir -p "${AGENT_RULES_DIR}"; then
			echo "create_cursor_rule_file:: Failed to create directory: ${AGENT_RULES_DIR}" >&2
			return 1
		fi
	fi

	local cursor_rule_file="${CURSOR_RULES_DIR}/rules-${name}.mdc"
	local cursor_rule_file_abs
	cursor_rule_file_abs=$(realpath "${cursor_rule_file}" 2>/dev/null || echo "${cursor_rule_file}")

	local agent_rule_file="${AGENT_RULES_DIR}/rules-${name}.md"
	local agent_rule_file_abs
	agent_rule_file_abs=$(realpath "${agent_rule_file}" 2>/dev/null || echo "${agent_rule_file}")

	# Check if files exist and read existing content
	local cursor_existing_content=""
	if [[ -f "${cursor_rule_file}" ]]; then
		cursor_existing_content=$(cat "${cursor_rule_file}" 2>/dev/null || true)
	fi

	local agent_existing_content=""
	if [[ -f "${agent_rule_file}" ]]; then
		agent_existing_content=$(cat "${agent_rule_file}" 2>/dev/null || true)
	fi

	# Format globs for MDC frontmatter
	local globs_formatted
	local glob_count
	glob_count=$(echo "${globs}" | jq 'length' 2>/dev/null || echo "0")
	if ((glob_count > 0)); then
		globs_formatted=$(jq -r '.[]' <<<"${globs}" 2>/dev/null | sed 's/^/  - "/' | sed 's/$/"/' || echo "")
		globs_formatted="
${globs_formatted}"
	else
		globs_formatted=" []"
	fi

	local frontmatter_content
	frontmatter_content=$(
		cat <<EOF
description: $description
globs:${globs_formatted}
alwaysApply: $cursor_always_apply
EOF
	)

	# Validate MDC frontmatter syntax
	if ! validate_mdc_frontmatter "${name}" "${frontmatter_content}"; then
		echo "create_cursor_rule_file:: MDC frontmatter validation failed for rule '${name}'" >&2
		return 1
	fi

	local new_content
	new_content=$(
		cat <<EOF
---
${frontmatter_content}
---

$file_content
EOF
	)

	# Check and update Cursor rule file
	if [[ "${cursor_existing_content}" == "${new_content}" ]]; then
		echo "No changes: ${cursor_rule_file_abs}"
		STATS_UNCHANGED=$((STATS_UNCHANGED + 1))
	else
		show_diff "${cursor_rule_file}" "${new_content}"
		echo "${new_content}" >"${cursor_rule_file}"
		if [[ -f "${cursor_rule_file}" ]]; then
			if [[ -n "${cursor_existing_content}" ]]; then
				echo "Updated: ${cursor_rule_file_abs}"
				STATS_UPDATED=$((STATS_UPDATED + 1))
			else
				echo "Created: ${cursor_rule_file_abs}"
				STATS_CREATED=$((STATS_CREATED + 1))
			fi
		else
			echo "create_cursor_rule_file:: Error: Failed to write rule file: ${cursor_rule_file_abs}" >&2
			STATS_ERRORS=$((STATS_ERRORS + 1))
			return 1
		fi
	fi

	# Check and update Agent rule file
	if [[ "${agent_existing_content}" == "${new_content}" ]]; then
		echo "No changes: ${agent_rule_file_abs}"
	else
		show_diff "${agent_rule_file}" "${new_content}"
		echo "${new_content}" >"${agent_rule_file}"
		if [[ -f "${agent_rule_file}" ]]; then
			if [[ -n "${agent_existing_content}" ]]; then
				echo "Updated: ${agent_rule_file_abs}"
			else
				echo "Created: ${agent_rule_file_abs}"
			fi
		else
			echo "create_cursor_rule_file:: Error: Failed to write rule file: ${agent_rule_file_abs}" >&2
			STATS_ERRORS=$((STATS_ERRORS + 1))
			return 1
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
	temp_file=$(mktemp) || {
		echo "show_diff:: Failed to create temporary file" >&2
		return 1
	}

	trap 'rm -f "${temp_file}"' EXIT ERR
	chmod 0600 "${temp_file}"

	echo "${new_content}" >"${temp_file}"

	if [[ -f "${file_path}" ]]; then
		if ! diff -u --color=always "${file_path}" "${temp_file}"; then
			echo "show_diff:: Differences found between ${file_path} and ${temp_file}"
		fi
	fi

	rm -f "${temp_file}"
	trap - EXIT ERR

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
			STATS_SKIPPED=$((STATS_SKIPPED + 1))
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

	echo "fill_quest_log: complete"
	return 0
}

# Generate Cursor daily-quests (commands) from markdown files
#
# Inputs:
# - $1, target_dir, the directory where daily-quests should be generated
#
# Side Effects:
# - Creates daily-quest files in .cursor/commands/user directory
generate_commands() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "generate_commands:: target_dir is required" >&2
		return 1
	fi

	local commands_dir="${QUEST_LOG_ROOT}/commands"
	local cursor_commands_dir="${target_dir}/.cursor/commands/user"

	if [[ ! -d "${commands_dir}" ]]; then
		return 0
	fi

	echo "generate_commands: running"

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

	echo "generate_commands: complete"
	return 0
}

# Generate Agent workflows from markdown files
#
# Inputs:
# - $1, target_dir, the directory where workflows should be generated
#
# Side Effects:
# - Creates workflow files in .agent/workflows directory
generate_workflows() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "generate_workflows:: target_dir is required" >&2
		return 1
	fi

	local commands_dir="${QUEST_LOG_ROOT}/commands"
	local agent_workflows_dir="${target_dir}/.agent/workflows"

	if [[ ! -d "${commands_dir}" ]]; then
		return 0
	fi

	echo "generate_workflows: running"

	if [[ ! -d "${agent_workflows_dir}" ]]; then
		if ! mkdir -p "${agent_workflows_dir}"; then
			echo "generate_workflows:: Failed to create workflows directory: ${agent_workflows_dir}" >&2
			return 1
		fi
	fi

	local command_file
	while IFS= read -r -d '' command_file; do
		local command_name
		command_name=$(basename "${command_file}" .md)

		local command_content
		command_content=$(cat "${command_file}")

		# Workflows need a description frontmatter for Antigravity
		local description
		description=$(head -n 1 "${command_file}" | sed 's/^# //')
		local workflow_content
		workflow_content=$(
			cat <<EOF
---
description: ${description}
---

${command_content}
EOF
		)

		local agent_workflow_file="${agent_workflows_dir}/${command_name}.md"

		# Check if content changed
		local existing_content=""
		if [[ -f "${agent_workflow_file}" ]]; then
			existing_content=$(cat "${agent_workflow_file}" 2>/dev/null || true)
		fi

		if [[ "$existing_content" == "$workflow_content" ]]; then
			echo "No changes: ${agent_workflow_file}"
		else
			show_diff "${agent_workflow_file}" "${workflow_content}"
			echo "${workflow_content}" >"${agent_workflow_file}"
			if [[ -f "${agent_workflow_file}" ]]; then
				echo "Updated: ${agent_workflow_file}"
			else
				echo "Created: ${agent_workflow_file}"
			fi
		fi
	done < <(find "${commands_dir}" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)

	echo "generate_workflows: complete"

	return 0
}

# Install quest-log rules for Cursor
#
# Side Effects:
# - Creates local Cursor rules directory at TARGET_DIR/.cursor/rules/user/
# - Installs rules from quest-log schema
install_rules() {
	echo "install_rules: running"

	# Define directories
	local cursor_rules_dir="${TARGET_DIR}/.cursor/rules/user"

	# Create local Cursor rules directory
	if ! mkdir -p "${cursor_rules_dir}"; then
		echo "install_rules:: Failed to create Cursor rules directory: ${cursor_rules_dir}" >&2
		return 1
	fi

	# Create local Agent rules directory
	local agent_rules_dir="${TARGET_DIR}/.agent/rules"
	if ! mkdir -p "${agent_rules_dir}"; then
		echo "install_rules:: Failed to create Agent rules directory: ${agent_rules_dir}" >&2
		return 1
	fi

	# Set target directory
	readonly CURSOR_RULES_DIR="${cursor_rules_dir}"
	readonly AGENT_RULES_DIR="${agent_rules_dir}"

	# Generate rules
	fill_quest_log "${TARGET_DIR}"

	echo "install_rules: complete"

	return 0
}

# Sync VSCode settings from Zangarmarsh root to git root
#
# Outputs:
# - Status messages to stdout
# - Error messages to stderr if copy operation fails
#
# Returns:
# - 0 if sync is successful
# - 1 if copy operation fails
vscodeoverride() {
	if [[ -z "${GIT_ROOT:-}" ]]; then
		echo "vscodeoverride:: GIT_ROOT is not set" >&2
		return 1
	fi

	echo "vscodeoverride: running"

	local zangarmarsh_root
	zangarmarsh_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"

	if [[ ! -d "${zangarmarsh_root}/.vscode" ]]; then
		echo "vscodeoverride:: VSCode settings directory not found in ${zangarmarsh_root}/.vscode" >&2
		return 1
	fi

	if [[ "${GIT_ROOT}" == "${zangarmarsh_root}" ]]; then
		echo "vscodeoverride: complete"
		return 0
	fi

	mkdir -p "${GIT_ROOT}/.vscode"

	if [[ "${FORCE:-}" = "true" ]]; then
		if cp -rf "${zangarmarsh_root}/.vscode/"* "${GIT_ROOT}/.vscode/" 2>/dev/null; then
			:
		else
			echo "vscodeoverride:: Failed to copy VSCode settings" >&2
			return 1
		fi
	elif [[ ! "$(ls -A "${GIT_ROOT}/.vscode" 2>/dev/null)" ]]; then
		if cp -rf "${zangarmarsh_root}/.vscode/"* "${GIT_ROOT}/.vscode/" 2>/dev/null; then
			:
		else
			echo "vscodeoverride:: Failed to copy VSCode settings" >&2
			return 1
		fi
	fi

	echo "vscodeoverride: complete"
	return 0
}

# Print summary statistics
#
# Side Effects:
# - Displays summary report to stdout
print_summary() {
	if ((STATS_ERRORS > 0 || STATS_WARNINGS > 0)); then
		return 1
	fi

	cat <<EOF

=============================
Summary
=============================
EOF
	[[ ${STATS_CREATED} -gt 0 ]] && echo "Created: ${STATS_CREATED}"
	[[ ${STATS_UPDATED} -gt 0 ]] && echo "Updated: ${STATS_UPDATED}"
	[[ ${STATS_UNCHANGED} -gt 0 ]] && echo "Unchanged: ${STATS_UNCHANGED}"
	[[ ${STATS_SKIPPED} -gt 0 ]] && echo "Skipped: ${STATS_SKIPPED}"
	[[ ${STATS_ERRORS} -gt 0 ]] && echo "Errors: ${STATS_ERRORS}"
	[[ ${STATS_WARNINGS} -gt 0 ]] && echo "Warnings: ${STATS_WARNINGS}"
	[[ ${STATS_TOTAL_LINES} -gt 0 ]] && echo "Total lines: ${STATS_TOTAL_LINES}"

	echo ""

	if ((STATS_ERRORS > 0)); then
		echo "print_summary:: Some rules failed validation. Please review errors above." >&2
		return 1
	elif ((STATS_WARNINGS > 0)); then
		echo "print_summary:: Some warnings were generated. Please review warnings above."
		return 0
	else
		echo "print_summary:: All rules processed successfully."
		return 0
	fi
}

# Determine the target directory for rule generation
#
# Side Effects:
# - Sets TARGET_DIR to git root if in git repo, otherwise uses provided/current directory
# - Outputs status messages for testing
determine_target_directory() {
	local git_root
	if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
		TARGET_DIR="${git_root}"
		echo "git_root: ${git_root}"
	else
		TARGET_DIR=${TARGET_DIR:-${PWD}}
		echo "git_root: none"
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
run_quest_log() {
	echo "quest-log: running"

	# Check for jq availability
	if ! command -v jq &>/dev/null; then
		echo "run_quest_log:: jq is required but not installed." >&2
		return 1
	fi

	SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
	SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
	QUEST_LOG_ROOT="${SCRIPT_DIR}"
	export SCRIPT_DIR

	readonly QUEST_DIR="${SCRIPT_DIR}/quests"

	# Environment variables with defaults
	SCHEMA_FILE=${SCHEMA_FILE:-"${SCRIPT_DIR}/schema.json"}
	INCLUDE_ALL=${INCLUDE_ALL:-"${DEFAULT_INCLUDE_ALL}"}
	FORCE=${FORCE:-${DEFAULT_FORCE}}
	TARGET_DIR=${TARGET_DIR:-${PWD}}

	while [[ $# -gt 0 ]]; do
		case $1 in
		-a | --all)
			INCLUDE_ALL=true
			shift
			;;
		-f | --force)
			FORCE=true
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		-*)
			echo "run_quest_log:: Unknown option: ${1}" >&2
			usage
			return 1
			;;
		*)
			TARGET_DIR="${1}"
			shift
			;;
		esac
	done

	determine_target_directory

	# Set GIT_ROOT to TARGET_DIR (which is the git root if in a git repo, or current directory)
	GIT_ROOT="${TARGET_DIR}"

	# Change to target directory for file operations
	if ! cd "${TARGET_DIR}"; then
		echo "run_quest_log:: Failed to change to target directory: ${TARGET_DIR}" >&2
		return 1
	fi

	if [[ ! -d "${TARGET_DIR}" ]]; then
		echo "run_quest_log:: Target directory is required" >&2
		return 1
	fi

	if [[ ! -r "${SCHEMA_FILE}" ]]; then
		echo "run_quest_log:: Schema file not found: ${SCHEMA_FILE}" >&2
		return 1
	fi

	# Install rules
	install_rules

	# Generate daily-quests if commands directory exists
	if [[ -d "${QUEST_LOG_ROOT}/commands" ]]; then
		generate_commands "${TARGET_DIR}"
		generate_workflows "${TARGET_DIR}"
	fi

	# Sync VSCode settings
	vscodeoverride

	print_summary
	local summary_exit_code=$?

	if ((summary_exit_code == 0)); then
		echo "quest-log: complete"
	fi

	return ${summary_exit_code}
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail

	cleanup() {
		local exit_code=$?
		if ((exit_code != 0)); then
			echo "Error in ${0} at line ${LINENO}" >&2
		fi
	}
	trap cleanup EXIT ERR

	run_quest_log "$@"
	exit $?
fi
