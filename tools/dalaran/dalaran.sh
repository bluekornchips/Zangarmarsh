#!/usr/bin/env bash
#
# ZSH Command Dalaran Library Script
# Builds and maintains a collection of the most-used commands over time
# Usage: ./dalaran.sh [OPTIONS]
#
# Options:
#   -h, --help          Show usage information
#   --top=N             Show the top N most used commands
#   --dry-run           Show what would be done without making changes
#
# Set DRY_RUN=true to see what would be done without making changes

set -uo pipefail

# Set locale to handle encoding issues
export LC_ALL=C

show_usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

ZSH Command Dalaran Library Script
Builds and maintains a collection of the most-used commands over time.

OPTIONS:
    -h, --help          Show this help message
    --top=N             Show the top N most used commands (default: 10)
    --dry-run           Show what would be done without making changes

ENVIRONMENT VARIABLES:
    DRY_RUN=true        Enable dry run mode
    TOP_N_COMMANDS=N    Number of top commands to extract (default: 1000)
    HISTFILE=path       Path to zsh history file (default: ~/.zsh_history)

EXAMPLES:
    $(basename "$0")                    # Run with default settings
    $(basename "$0") --top=20          # Show top 20 commands
    $(basename "$0") --dry-run         # Show what would be done
    DRY_RUN=true $(basename "$0")      # Alternative dry run method

The script creates a library of your most frequently used commands
and maintains a working history file that combines your current
history with the historical top commands.
EOF
}

# DRY_RUN mode: set to true to see what would be done without making changes
DRY_RUN=${DRY_RUN:-false}

execute_or_dry_run() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would execute: $*"
		return 0
	else
		"$@"
	fi
}

create_file_or_dry_run() {
	local content="$1"
	local file_path="$2"

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would create file: ${file_path}"
		echo "Content preview (first 3 lines):"
		echo "${content}" | head -3 | sed 's/^/  /'
		return 0
	else
		echo "${content}" >"${file_path}"
	fi
}

validate_input() {
	local current_history="$1"

	if [[ -z "${current_history}" ]]; then
		echo "Empty history file path" >&2
		exit 1
	fi

	if [[ ! -f "${current_history}" ]]; then
		echo "History file not found: ${current_history}" >&2
		exit 1
	fi

	echo "Valid history file: ${current_history}"
}

create_backup() {
	if [[ ! -f "${CURRENT_HISTORY}" ]]; then
		echo "Current history file not found: ${CURRENT_HISTORY}" >&2
		return 1
	fi

	execute_or_dry_run cp "${CURRENT_HISTORY}" "${BACKUP_FILE}"

	if [[ "${DRY_RUN}" == "true" ]]; then
		local backup_count
		backup_count=$(wc -l <"${CURRENT_HISTORY}")
		echo "Would back up ${backup_count} commands to: $(basename "${BACKUP_FILE}")"
	elif [[ ! -f "${BACKUP_FILE}" ]]; then
		echo "Backup file not found: ${BACKUP_FILE}" >&2
		return 1
	else
		local backup_count
		backup_count=$(wc -l <"${BACKUP_FILE}")
		echo "Backed up ${backup_count} commands to: $(basename "${BACKUP_FILE}")"
	fi
}

extract_top_commands() {
	echo "Extracting top ${TOP_N_COMMANDS} commands."

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would extract commands from: ${CURRENT_HISTORY}"
		echo "Would save to: $(basename "${TOP_COMMANDS_FILE}")"
		# Simulate extraction for dry run
		local simulated_count
		simulated_count=$(head -"${TOP_N_COMMANDS}" "${CURRENT_HISTORY}" | wc -l)
		echo "Would extract approximately ${simulated_count} top commands"
	else
		# Extract commands from zsh history using sed, sort, and uniq
		# Handle zsh history format: ': timestamp:duration;command' or plain commands
		{
			# Extract commands after semicolon from timestamped entries
			sed -n 's/^: [0-9]*:[0-9]*;//p' "${CURRENT_HISTORY}"
			# Extract plain commands (lines not starting with ':')
			grep -v '^: ' "${CURRENT_HISTORY}" || true
		} |
			grep -v '^[[:space:]]*$' |
			sort |
			uniq -c |
			sort -rn |
			head -"${TOP_N_COMMANDS}" |
			sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' >"${TOP_COMMANDS_FILE}"

		local top_extracted
		top_extracted=$(wc -l <"${TOP_COMMANDS_FILE}")
		echo "Extracted ${top_extracted} top commands to: $(basename "${TOP_COMMANDS_FILE}")"
	fi
}

combine_historical_files() {
	echo "Combining all historical top command files."

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would combine historical files from: ${TOP_COMMANDS_DIR}"
		echo "Would save to: $(basename "${COMBINED_TOP_COMMANDS}")"

		local historical_files
		mapfile -t historical_files < <(find "${TOP_COMMANDS_DIR}" -name ".zsh_history_*.txt" -type f 2>/dev/null || true)
		echo "Found ${#historical_files[@]} historical top command files"
		return 0
	fi

	local temp_combined
	temp_combined=$(mktemp)
	local files_processed=0

	local historical_files
	mapfile -t historical_files < <(find "${TOP_COMMANDS_DIR}" -name ".zsh_history_*.txt" -type f)
	echo "Found ${#historical_files[@]} historical top command files. Adding to combined file."

	local file
	for file in "${historical_files[@]}"; do
		if [[ -f "${file}" ]]; then
			local file_count
			file_count=$(wc -l <"${file}")
			echo "Processed $(basename "${file}"): ${file_count} commands"
			cat "${file}" >>"${temp_combined}"
			((files_processed++))
		fi
	done

	# Count frequency of commands
	sort "${temp_combined}" |
		uniq -c |
		sort -rn |
		head -"${TOP_N_COMMANDS}" >"${temp_combined}.ranked"

	sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' "${temp_combined}.ranked" >"${COMBINED_TOP_COMMANDS}"

	local total_commands
	total_commands=$(wc -l <"${temp_combined}")
	local unique_commands
	unique_commands=$(wc -l <"${temp_combined}.ranked")

	echo "Combined ${total_commands} total commands into ${unique_commands} unique top commands"

	rm -f "${temp_combined}" "${temp_combined}.ranked"
}

create_dalaran_library_history() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would create dalaran library history file: $(basename "${DALARAN_LIBRARY_HISTORY}")"
		if [[ -f "${COMBINED_TOP_COMMANDS}" ]]; then
			local combined_count
			combined_count=$(grep -c -v '^#' "${COMBINED_TOP_COMMANDS}" || echo 0)
			echo "Would add ${combined_count} commands to working zsh history"
		fi
		return 0
	fi

	local combined_count
	combined_count=$(grep -c -v '^#' "${COMBINED_TOP_COMMANDS}" || echo 0)
	echo "Created dalaran library: $(basename "${COMBINED_TOP_COMMANDS}") with ${combined_count} commands"
	echo "Adding dalaran library to working zsh history."

	local base_timestamp
	base_timestamp=$(($(date +%s) - 365 * 24 * 60 * 60))
	local time_increment
	if [[ ${combined_count} -gt 0 ]]; then
		time_increment=$((365 * 24 * 60 * 60 / combined_count))
	else
		time_increment=1
	fi

	rm -f "${DALARAN_LIBRARY_HISTORY}"

	local count=0
	local command
	while IFS= read -r command || [[ -n "${command}" ]]; do
		# Skip comments and empty lines
		[[ -z "${command}" || "${command}" =~ ^[[:space:]]*# ]] && continue

		local timestamp
		timestamp=$((base_timestamp + count * time_increment))
		echo ": ${timestamp}:0;${command}" >>"${DALARAN_LIBRARY_HISTORY}"
		((count++))
	done <"${COMBINED_TOP_COMMANDS}"

	echo "Created zsh history format: $(basename "${DALARAN_LIBRARY_HISTORY}") with ${count} commands"
}

create_working_history() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would create working history file: $(basename "${WORKING_HISTORY}")"
		local current_count
		current_count=$(wc -l <"${CURRENT_HISTORY}")
		echo "Would combine current history (${current_count} commands) with dalaran library"
		return 0
	fi

	rm -f "${WORKING_HISTORY}"

	cat "${DALARAN_LIBRARY_HISTORY}" >>"${WORKING_HISTORY}"
	cat "${CURRENT_HISTORY}" >>"${WORKING_HISTORY}"

	local working_count
	working_count=$(wc -l <"${WORKING_HISTORY}")
	echo "Created working history: $(basename "${WORKING_HISTORY}") with ${working_count} total commands"
}

display_summary() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would display summary of operations"
		echo "Would show backup files, snapshots, and command counts"
		return 0
	fi

	local backup_files
	backup_files=$(find "${DALARAN_LIBRARY_DIR}" -maxdepth 1 -name ".zsh_history_*.txt" -type f | wc -l)
	local snapshot_files
	snapshot_files=$(find "${TOP_COMMANDS_DIR}" -name ".zsh_history_*.txt" -type f | wc -l)
	local combined_count
	combined_count=$(grep -c -v '^#' "${COMBINED_TOP_COMMANDS}" || echo 0)
	local working_count
	working_count=$(wc -l <"${WORKING_HISTORY}")

	cat <<EOF

Dalaran Library Summary:
    Backup files: ${backup_files}
    Top command snapshots: ${snapshot_files}
    Library commands: ${combined_count}
    Working history total: ${working_count}

To use your dalaran library-enhanced history:
    export HISTFILE="${WORKING_HISTORY}"
    fc -R  # Reload history

Run this script periodically to keep your library updated.
EOF
}

show_top_commands() {
	local top_count="$1"
	local combined_file="${DALARAN_LIBRARY_DIR}/top_commands.txt"

	if [[ ! -f "${combined_file}" ]]; then
		echo "No dalaran library found. Run the script first to create one."
		return 1
	fi

	cat <<EOF
	
Top ${top_count} most used commands from dalaran library:
================================================
$(head -"${top_count}" "${combined_file}" | nl)
EOF
}

parse_options() {
	local show_top=0
	local top_count=10

	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			show_usage
			exit 0
			;;
		--top=*)
			show_top=1
			top_count="${1#--top=}"
			if [[ ! "${top_count}" =~ ^[0-9]+$ ]] || [[ "${top_count}" -lt 1 ]]; then
				echo "Error: --top value must be a positive integer" >&2
				exit 1
			fi
			shift
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		*)
			echo "Error: Unknown option '$1'" >&2
			echo "Use --help for usage information" >&2
			exit 1
			;;
		esac
	done

	if [[ "${show_top}" -eq 1 ]]; then
		# Configuration for top commands display
		DALARAN_LIBRARY_DIR="$HOME/.zsh_dalaran_library"
		show_top_commands "${top_count}"
		exit $?
	fi
}

main() {
	parse_options "$@"

	# Configuration
	readonly DALARAN_LIBRARY_DIR="$HOME/.zsh_dalaran_library"
	readonly TOP_COMMANDS_DIR="${DALARAN_LIBRARY_DIR}/top_commands"
	readonly TOP_N_COMMANDS=${TOP_N_COMMANDS:-1000}
	readonly CURRENT_HISTORY="${HISTFILE:-$HOME/.zsh_history}"
	TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
	readonly TIMESTAMP
	readonly BACKUP_FILE="${DALARAN_LIBRARY_DIR}/.zsh_history_${TIMESTAMP}.txt"
	readonly TOP_COMMANDS_FILE="${TOP_COMMANDS_DIR}/.zsh_history_${TIMESTAMP}.txt"
	readonly COMBINED_TOP_COMMANDS="${DALARAN_LIBRARY_DIR}/top_commands.txt"
	readonly DALARAN_LIBRARY_HISTORY="${DALARAN_LIBRARY_DIR}/.zsh_history_dalaran_library"
	readonly WORKING_HISTORY="${DALARAN_LIBRARY_DIR}/.zsh_history_working"

	validate_input "${CURRENT_HISTORY}"

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would create directories: ${DALARAN_LIBRARY_DIR} and ${TOP_COMMANDS_DIR}"
	else
		mkdir -p "${DALARAN_LIBRARY_DIR}" "${TOP_COMMANDS_DIR}"
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		cat <<EOF
========================================
ZSH Dalaran Library [DRY RUN]
========================================
EOF
	else
		cat <<EOF
========================================
ZSH Dalaran Library
========================================
EOF
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		cat <<EOF
Would back up current history.
Source: ${CURRENT_HISTORY}
Target: ${BACKUP_FILE}

EOF
	else
		cat <<EOF
Backing up current history.
Source: ${CURRENT_HISTORY}
Target: ${BACKUP_FILE}

EOF
	fi

	create_backup
	extract_top_commands
	combine_historical_files
	create_dalaran_library_history
	create_working_history
	display_summary
}

main "$@"
