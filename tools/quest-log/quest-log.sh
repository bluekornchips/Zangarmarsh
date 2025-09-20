#!/usr/bin/env bash
set -euo pipefail

#
# Generate agentic tool rules for Cursor and Claude Code based on schema.yaml
#

usage() {
	cat <<EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Generate agentic tool rules for Cursor and Claude Code in the specified directory.

OPTIONS:
    -b, --backup        Backup existing rules before overwriting
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Generate rules in current directory
    $0 /path/to/dir     # Generate rules in specified directory
    $0 --backup         # Backup existing rules before generating
EOF
}

# Create rules for cursor
create_cursor_rule_file() {
	local name="$1"
	local description="$2"
	local cursor_always_apply="$3"
	local file_content="$4"

	local cursor_rule_file="$CURSOR_RULES_DIR/rules-$name.mdc"
	cat <<EOF >"$cursor_rule_file"
---
description: $description
globs:
alwaysApply: $cursor_always_apply
---

$file_content
EOF

	echo "Created: $cursor_rule_file"
}

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

	echo "Updating $CLAUDE_FILE."
	tmp_file=$(mktemp)
	sed "${first_marker_index},${last_marker_index}d" "$CLAUDE_FILE" >"$tmp_file"
	{
		echo "$QUEST_LOG_MARKER"
		cat "$claude_temp_file"
		echo "$QUEST_LOG_MARKER"
	} >>"$tmp_file"
	mv "$tmp_file" "$CLAUDE_FILE"
}

# Create rules
fill_quest_log() {
	echo -e "\nFilling quest log."

	# Read the 'SCHEMA_FILE', convert to JSON because I prefer to work with JSON in shell
	SCHEMA_CONTENTS=""
	if yq '.' "$SCHEMA_FILE" >/dev/null 2>&1; then
		SCHEMA_CONTENTS=$(yq '.' "$SCHEMA_FILE")
	else
		SCHEMA_CONTENTS=$(yq -o json '.' "$SCHEMA_FILE")
	fi

	if [[ ! -d "$CURSOR_RULES_DIR" ]]; then
		mkdir -p "$CURSOR_RULES_DIR"
	fi

	CLAUDE_TEMP_FILE=$(mktemp)

	while IFS= read -r quest; do
		name=$(jq -r '.name // ""' <<<"$quest")
		file=$(jq -r '.file // ""' <<<"$quest")
		icon=$(jq -r '.icon // ""' <<<"$quest")
		description=$(jq -r '.description // ""' <<<"$quest")
		keywords=$(jq -r '.keywords // []' <<<"$quest")

		# Cursor Specific
		cursor=$(jq -r '.cursor // {} // null' <<<"$quest") # Cursor has children keys
		cursor_always_apply=$(jq -r '.cursor.alwaysApply // false' <<<"$quest")

		[[ -z "$name" ]] && echo "Quest name is required" >&2 && return 1
		[[ -z "$file" ]] && echo "Quest file is required" >&2 && return 1
		[[ -z "$icon" ]] && echo "Quest icon is required" >&2 && return 1
		[[ -z "$description" ]] && echo "Quest description is required" >&2 && return 1
		[[ -z "$keywords" ]] && echo "Quest keywords are required" >&2 && return 1
		[[ -z "$cursor" ]] && echo "Quest cursor is required" >&2 && return 1

		file_content=$(
			cat <<EOF

**RULE APPLIED: Start each response with an acknowledgement icon to confirm this rule is being followed: $icon**

Keywords that trigger usage of this rule: $(jq -r '.[]' <<<"$keywords" | tr '\n' ',')

$(cat "$QUEST_DIR/$file")
EOF
		)

		create_cursor_rule_file "$name" "$description" "$cursor_always_apply" "$file_content"
		echo -e "$file_content\n---\n" >>"$CLAUDE_TEMP_FILE"

	done \
		<<<"$(jq -c '.[]' <<<"$SCHEMA_CONTENTS")"

	update_claude_file "$CLAUDE_TEMP_FILE"
}

main() {
	echo -e "\n=====\nRunning ${BASH_SOURCE[0]:-$0}\n====="

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

	readonly CLAUDE_FILE="CLAUDE.md"
	readonly QUEST_DIR="$SCRIPT_DIR/quests"
	readonly CURSOR_RULES_DIR=".cursor/rules"

	# Environment variables with defaults
	SCHEMA_FILE=${SCHEMA_FILE:-"$SCRIPT_DIR/schema.yaml"}
	BACKUP_ENABLED=${BACKUP_ENABLED:-false}
	TARGET_DIR=${TARGET_DIR:-$PWD}

	if [[ ! -d "$TARGET_DIR" ]]; then
		echo "Target directory is required" >&2
		exit 1
	fi

	if [[ ! -r "$SCHEMA_FILE" ]]; then
		echo "Schema file not found: $SCHEMA_FILE" >&2
		exit 1
	fi

	while [[ $# -gt 0 ]]; do
		case $1 in
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

	fill_quest_log "$TARGET_DIR"

	echo -e "=====\nFinished ${BASH_SOURCE[0]:-$0}\n====="

}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
	exit $?
fi
