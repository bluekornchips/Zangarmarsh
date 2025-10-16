#!/usr/bin/env bash
#
# Generate agentic tool rules for Cursor and Claude Code based on schema.yaml
#
set -euo pipefail

# Display usage information
usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Generate agentic tool rules for Cursor and Claude Code. If run from within a git
repository, files are always written to the git root directory. Otherwise, files
are written to the specified directory or current directory.

OPTIONS:
    -a, --all           Include all rules (including warcraft and lotr)
    -b, --backup        Backup existing rules before overwriting
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Generate rules in git root (if in git repo) or current directory
    $0 /path/to/dir     # Generate rules in git root (if in git repo) or specified directory
    $0 --backup         # Backup existing rules before generating
    $0 --all            # Generate all rules including warcraft and lotr
EOF

	return 1
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
create_cursor_rule_file() {
	local name="$1"
	local description="$2"
	local cursor_always_apply="$3"
	local file_content="$4"

	if [[ -z "$name" ]]; then
		echo "Name is required"
		return 1
	fi

	if [[ -z "$description" ]]; then
		echo "Description is required"
		return 1
	fi

	if [[ -z "$cursor_always_apply" ]]; then
		echo "Cursor always apply is required"
		return 1
	fi

	if [[ -z "$file_content" ]]; then
		echo "File content is required"
		return 1
	fi

	if [[ ! -d "$CURSOR_RULES_DIR" ]]; then
		if ! mkdir -p "$CURSOR_RULES_DIR"; then
			echo "Failed to create directory: $CURSOR_RULES_DIR" >&2
			return 1
		fi
	fi

	local cursor_rule_file="$CURSOR_RULES_DIR/rules-$name.mdc"
	local cursor_rule_file_abs
	cursor_rule_file_abs=$(realpath "$cursor_rule_file" 2>/dev/null || echo "$(pwd)/$cursor_rule_file")

	# Check if file exists and read existing content
	local existing_content=""
	if [[ -f "$cursor_rule_file" ]]; then
		existing_content=$(cat "$cursor_rule_file" 2>/dev/null || true)
	fi

	local new_content
	new_content=$(
		cat <<EOF
---
description: $description
globs:
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

	echo "$new_content" >"$temp_file"

	if ! diff -u --color=always "$file_path" "$temp_file"; then
		echo "Differences found between $file_path and $temp_file"
	fi

	return $?
}

# Update the CLAUDE.md file with new rule content
#
# Inputs:
# - $1, claude_temp_file, path to temporary file containing new rule content
#
# Side Effects:
# - Updates or creates the CLAUDE.md file with new rule content
update_claude_file() {
	local claude_temp_file="$1"

	# If the file does not exist, create it with initial markers and content
	if [[ ! -f "$CLAUDE_FILE" ]]; then
		echo "Creating $CLAUDE_FILE"
		cat <<EOF >"$CLAUDE_FILE"
$QUEST_LOG_MARKER
$(cat "$claude_temp_file")
$QUEST_LOG_MARKER
EOF
		return 0
	fi

	# Find the first index of the $QUEST_LOG_MARKER
	local first_marker_index
	first_marker_index=$(grep -n "$QUEST_LOG_MARKER" "$CLAUDE_FILE" | cut -d: -f1 | head -n1 || true)

	# If the file does not contain the $QUEST_LOG_MARKER, append it to the end of the file
	if ! grep -q "$QUEST_LOG_MARKER" "$CLAUDE_FILE"; then
		echo "Updating $CLAUDE_FILE."
		cat <<EOF >>"$CLAUDE_FILE"
$QUEST_LOG_MARKER
$(cat "$claude_temp_file")
$QUEST_LOG_MARKER
EOF
		return 0
	fi

	# Find the last index of the $QUEST_LOG_MARKER
	local last_marker_index
	last_marker_index=$(grep -n "$QUEST_LOG_MARKER" "$CLAUDE_FILE" | cut -d: -f1 | tail -n1 || true)

	local existing_content
	existing_content=$(sed -n "${first_marker_index},${last_marker_index}p" "$CLAUDE_FILE" | sed '1d;$d')

	local new_content
	new_content=$(cat "$claude_temp_file")

	if [[ "$existing_content" == "$new_content" ]]; then
		echo "No changes: $CLAUDE_FILE"
		return 0
	fi

	echo "Updating $CLAUDE_FILE."
	tmp_file=$(mktemp)
	sed "${first_marker_index},${last_marker_index}d" "$CLAUDE_FILE" >"$tmp_file"
	{
		echo "$QUEST_LOG_MARKER"
		cat "$claude_temp_file"
		echo "$QUEST_LOG_MARKER"
	} >>"$tmp_file"
	mv "$tmp_file" "$CLAUDE_FILE"

	return 0
}

# Create all rule files from the quest schema
#
# Inputs:
# - $1, target_dir, the directory where rules should be generated
#
# Side Effects:
# - Creates cursor rule files in .cursor/rules directory
# - Updates or creates CLAUDE.md file with rule content
# - Creates temporary files during processing
fill_quest_log() {
	cat <<EOF

Filling quest log.

EOF

	# Read the 'SCHEMA_FILE', convert to JSON because I prefer to work with JSON in shell
	SCHEMA_CONTENTS=""
	if ! SCHEMA_CONTENTS=$(yq -o json '.' "$SCHEMA_FILE"); then
		echo "Failed to read schema file with yq: $SCHEMA_FILE" >&2
		return 1
	fi

	if [[ ! -d "$CURSOR_RULES_DIR" ]]; then
		if ! mkdir -p "$CURSOR_RULES_DIR"; then
			echo "Failed to create directory: $CURSOR_RULES_DIR" >&2
			return 1
		fi
	fi

	CLAUDE_TEMP_FILE=$(mktemp)
	if [[ -z "$CLAUDE_TEMP_FILE" ]]; then
		echo "Failed to create temporary file" >&2
		return 1
	fi

	while IFS= read -r quest; do
		if ! name=$(jq -r '.name // ""' <<<"$quest"); then
			echo "Failed to parse quest name from JSON" >&2
			return 1
		fi

		# Skip warcraft and lotr rules unless INCLUDE_ALL is true
		if [[ "$INCLUDE_ALL" != "true" ]] && [[ "${SKIPPED_RULES[*]}" =~ $name ]]; then
			echo "Skipping $name (use --all to include)"
			continue
		fi

		if ! file=$(jq -r '.file // ""' <<<"$quest"); then
			echo "Failed to parse quest file from JSON" >&2
			return 1
		fi

		if ! icon=$(jq -r '.icon // ""' <<<"$quest"); then
			echo "Failed to parse quest icon from JSON" >&2
			return 1
		fi

		if ! description=$(jq -r '.description // ""' <<<"$quest"); then
			echo "Failed to parse quest description from JSON" >&2
			return 1
		fi

		if ! keywords=$(jq -r '.keywords // []' <<<"$quest"); then
			echo "Failed to parse quest keywords from JSON" >&2
			return 1
		fi

		# Cursor Specific
		if ! cursor=$(jq -r '.cursor // {}' <<<"$quest"); then
			echo "Failed to parse quest cursor data from JSON" >&2
			return 1
		fi

		if ! cursor_always_apply=$(jq -r '.cursor.alwaysApply // false' <<<"$quest"); then
			echo "Failed to parse quest cursor alwaysApply from JSON" >&2
			return 1
		fi

		[[ "$name" == "null" || -z "$name" ]] && echo "Quest name is required" >&2 && return 1
		[[ "$file" == "null" || -z "$file" ]] && echo "Quest file is required" >&2 && return 1
		[[ "$icon" == "null" || -z "$icon" ]] && echo "Quest icon is required" >&2 && return 1
		[[ "$description" == "null" || -z "$description" ]] && echo "Quest description is required" >&2 && return 1
		[[ "$keywords" == "null" || "$keywords" == "[]" ]] && echo "Quest keywords are required" >&2 && return 1
		[[ "$cursor" == "null" || "$cursor" == "{}" ]] && echo "Quest cursor is required" >&2 && return 1

		file_content=$(
			cat <<EOF

RULE APPLIED: Start each response with an acknowledgement icon to confirm this rule is being followed: $icon

Keywords that trigger usage of this rule: $(echo "$keywords" | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

$(cat "$QUEST_DIR/$file")
EOF
		)

		create_cursor_rule_file "$name" "$description" "$cursor_always_apply" "$file_content"
		echo -e "$file_content\n---\n" >>"$CLAUDE_TEMP_FILE"

	done \
		<<<"$(jq -c '.[]' <<<"$SCHEMA_CONTENTS")"

	update_claude_file "$CLAUDE_TEMP_FILE"

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

	# Check for yq availability
	if ! command -v yq &>/dev/null; then
		echo "yq is required but not installed." >&2
		exit 1
	fi

	# Check for jq availability
	if ! command -v jq &>/dev/null; then
		echo "jq is required but not installed." >&2
		exit 1
	fi

	SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
	SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
	QUEST_LOG_ROOT="$SCRIPT_DIR"
	QUESTMARKER_FILE="$QUEST_LOG_ROOT/QUEST_MARKER.txt"

	QUEST_LOG_MARKER=$(cat "$QUESTMARKER_FILE")

	readonly QUEST_DIR="$SCRIPT_DIR/quests"

	# Environment variables with defaults
	SCHEMA_FILE=${SCHEMA_FILE:-"$SCRIPT_DIR/schema.yaml"}
	BACKUP_ENABLED=${BACKUP_ENABLED:-false}
	INCLUDE_ALL=${INCLUDE_ALL:-"$DEFAULT_INCLUDE_ALL"}
	TARGET_DIR=${TARGET_DIR:-$PWD}

	while [[ $# -gt 0 ]]; do
		case $1 in
		-a | --all)
			INCLUDE_ALL=true
			shift
			;;
		-b | --backup)
			BACKUP_ENABLED=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			echo "Unknown option: $1" >&2
			usage
			exit 1
			;;
		*)
			TARGET_DIR="$1"
			shift
			;;
		esac
	done

	determine_target_directory

	# Change to target directory for file operations
	if ! cd "$TARGET_DIR"; then
		echo "Failed to change to target directory: $TARGET_DIR" >&2
		exit 1
	fi

	readonly CLAUDE_FILE="$TARGET_DIR/CLAUDE.md"
	readonly CURSOR_RULES_DIR="$TARGET_DIR/.cursor/rules"

	if [[ ! -d "$TARGET_DIR" ]]; then
		echo "Target directory is required" >&2
		exit 1
	fi

	if [[ ! -r "$SCHEMA_FILE" ]]; then
		echo "Schema file not found: $SCHEMA_FILE" >&2
		exit 1
	fi

	fill_quest_log "$TARGET_DIR"

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
