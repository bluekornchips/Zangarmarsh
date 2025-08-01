#!/usr/bin/env bash
set -euo pipefail

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

# POSIX compliant way to get the script directory
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

RULE_MARKER="##_USER_RULES_##"
CLAUDE_FILE="CLAUDE.md"
SCHEMA_FILE="$SCRIPT_DIR/schema.yaml"
SPEC_DIR="$SCRIPT_DIR/spec"
CURSOR_RULES_DIR=".cursor/rules"

BACKUP_ENABLED=${BACKUP_ENABLED:-false}

if ! command -v yq &>/dev/null; then
	echo "yq is required but not installed." >&2
	exit 1
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
	echo "Schema file not found: $SCHEMA_FILE" >&2
	exit 1
fi

# Parse arguments
TARGET_DIR="$PWD"
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

write_file() {
	local target_file="$1"
	local content="$2"

	echo "$content" >"$target_file"
	echo "Created: $target_file"
}

backup_rules() {
	[[ "$BACKUP_ENABLED" != "true" ]] && return

	local dir_path="$1"

	local backup_dir=".agent-rules-backup"
	local timestamp
	timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
	local backup_path="$backup_dir/$timestamp"

	mkdir -p "$backup_path"

	# Backup Claude file if it exists
	if [[ -f "$dir_path/$CLAUDE_FILE" ]]; then
		cp "$dir_path/$CLAUDE_FILE" "$backup_path/"
		echo "Backed up: $dir_path/$CLAUDE_FILE -> $backup_path/$CLAUDE_FILE"
	fi

	# Backup Cursor rules if they exist
	if [[ -d "$dir_path/$CURSOR_RULES_DIR" ]]; then
		cp -r "$dir_path/$CURSOR_RULES_DIR" "$backup_path/"
		echo "Backed up: $dir_path/$CURSOR_RULES_DIR -> $backup_path/$CURSOR_RULES_DIR"
	fi

	echo "Backup created at: $backup_path"
}

restore_rules() {
	local dir_path="$1"

	if [[ ! -d "$dir_path" ]]; then
		echo "Backup directory not found: $dir_path" >&2
		return 1
	fi

	# Restore Claude file if it exists in backup
	if [[ -f "$dir_path/$CLAUDE_FILE" ]]; then
		cp "$dir_path/$CLAUDE_FILE" "./$CLAUDE_FILE"
		echo "Restored: $dir_path/$CLAUDE_FILE -> ./$CLAUDE_FILE"
	fi

	# Restore Cursor rules if they exist in backup
	if [[ -d "$dir_path/$CURSOR_RULES_DIR" ]]; then
		rm -rf "./$CURSOR_RULES_DIR"
		cp -r "$dir_path/$CURSOR_RULES_DIR" "./$CURSOR_RULES_DIR"
		echo "Restored: $dir_path/$CURSOR_RULES_DIR -> ./$CURSOR_RULES_DIR"
	fi

	echo "Rules restored from: $dir_path"
}

set_rules() {
	local dir_path="$1"
	local rules="$2"

	mkdir -p "$(dirname "$dir_path")"
	mkdir -p "$dir_path"

	echo "$rules" >"$dir_path"
	echo "Set rules at: $dir_path"
}

manage_claude() {
	local dir_path="$1"

	if [[ ! -f "$SPEC_DIR/vital.md" ]]; then
		echo "Template file $SPEC_DIR/vital.md not found" >&2
		return 1
	fi

	local content
	content=$(cat "$SPEC_DIR/vital.md")

	# Wrap content in markers
	local wrapped_content
	wrapped_content=$(
		cat <<EOF
$RULE_MARKER
$content
$RULE_MARKER
EOF
	)

	# Update existing CLAUDE.md file preserving non-user-rules content
	if [[ ! -f "$dir_path" ]]; then
		# File doesn't exist, create new one with wrapped content
		echo "$wrapped_content" >"$dir_path"
		echo "Created: $dir_path"
		return
	fi

	# Check if file has user rules markers
	if grep -q "$RULE_MARKER" "$dir_path"; then
		# Replace content between markers
		local temp_file
		local in_user_rules=false
		local found_first_marker=false

		temp_file=$(mktemp)

		while IFS= read -r line; do
			if [[ "$line" == "$RULE_MARKER" ]]; then
				if [[ "$found_first_marker" == "false" ]]; then
					# First marker - write it and our new content
					echo "$line" >>"$temp_file"
					echo "$content" >>"$temp_file"
					found_first_marker=true
					in_user_rules=true
				else
					# Second marker - write it and continue
					echo "$line" >>"$temp_file"
					in_user_rules=false
				fi
			elif [[ "$in_user_rules" == "false" ]]; then
				# Outside user rules section, preserve content
				echo "$line" >>"$temp_file"
			fi
			# Inside user rules section, skip content (it gets replaced)
		done <"$dir_path"

		mv "$temp_file" "$dir_path"
		echo "Updated: $dir_path"
	else
		# No markers found, append our rules to existing content
		echo "" >>"$dir_path"
		echo "$wrapped_content" >>"$dir_path"
		echo "Appended rules to: $dir_path"
	fi
}

install_rules() {
	local dir_path="$1"
	local claude_file="$dir_path/$CLAUDE_FILE"
	local rules_dir="$dir_path/$CURSOR_RULES_DIR"

	backup_rules "$dir_path"

	if [[ -f "$claude_file" ]] && ! grep -q "$RULE_MARKER" "$claude_file"; then
		rm "$claude_file"
		echo "Removed: $claude_file"
	fi

	if [[ -d "$rules_dir" ]]; then
		while IFS= read -r rule_file; do
			if [[ -f "$rules_dir/$rule_file" ]]; then
				rm "$rules_dir/$rule_file"
				echo "Removed: $rules_dir/$rule_file"
			fi
		done < <(get_our_cursor_rules)
	fi

	mkdir -p "$dir_path"
	mkdir -p "$rules_dir"

	manage_claude "$claude_file"

	SOURCE_FILES_YAML=$(yq '.source_files' "$SCHEMA_FILE")
	if [[ -z "$SOURCE_FILES_YAML" || "$SOURCE_FILES_YAML" == "null" ]]; then
		echo "No source files found in schema.yaml" >&2
		return 1
	fi

	local source_files_count
	source_files_count=$(yq '.source_files | length' "$SCHEMA_FILE")

	for i in $(seq 0 $((source_files_count - 1))); do
		local source_name cursor_rule description always_apply
		source_name=$(yq ".source_files[$i].name" "$SCHEMA_FILE" | tr -d '"')
		cursor_rule=$(yq ".source_files[$i].cursor_rule" "$SCHEMA_FILE" | tr -d '"')
		description=$(yq ".source_files[$i].description" "$SCHEMA_FILE" | tr -d '"')
		always_apply=$(yq ".source_files[$i].always_apply" "$SCHEMA_FILE" | tr -d '"')

		if [[ ! -f "$SPEC_DIR/$source_name" ]]; then
			echo "Template file $SPEC_DIR/$source_name not found" >&2
			continue
		fi

		local file_content
		file_content=$(
			cat <<EOF
---
description: $description
globs:
alwaysApply: $always_apply
---

$(cat "$SPEC_DIR/$source_name")
EOF
		)
		write_file "$rules_dir/$cursor_rule" "$file_content"
	done
}

# Get our specific rule files from schema
get_our_cursor_rules() {
	yq '.source_files[].cursor_rule' "$SCHEMA_FILE"
}

install_rules "$TARGET_DIR"
