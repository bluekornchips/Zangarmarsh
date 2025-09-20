#!/usr/bin/env bash
#
# ZSH Command Dalaran Library Script
# Builds and maintains a collection of the most-used commands over time
#
set -euo pipefail

# Display usage information
usage() {
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

# Constants
readonly DALARAN_DIR="$HOME/.dalaran"
readonly TOP_COMMANDS_DIR="${DALARAN_DIR}/top_commands"
readonly COMBINED_TOP_COMMANDS="${DALARAN_DIR}/top_commands.txt"

# Validate input history file exists and is accessible
#
# Inputs:
# - $1, history_file, the path to the history file to validate
#
# Side Effects:
# - Returns error code if validation fails
validate_input() {
	local history_file="$1"

	if [[ -z "${history_file}" ]]; then
		echo "Empty history file path" >&2
		return 1
	fi

	if [[ ! -f "${history_file}" ]]; then
		echo "History file not found: ${history_file}" >&2
		return 1
	fi

	if [[ ! -r "${history_file}" ]]; then
		echo "History file not readable: ${history_file}" >&2
		return 1
	fi

	return 0
}

# Create backup of current history file
#
# Inputs:
# - $1, source_file, path to the source history file
# - $2, backup_file, path to the backup file to create
#
# Side Effects:
# - Creates a backup file of the current history
# - Returns error code if backup fails
create_backup() {
	local source_file="$1"
	local backup_file="$2"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	if ! cp "$source_file" "$backup_file"; then
		echo "Failed to copy $source_file to $backup_file" >&2
		return 1
	fi

	local backup_count
	backup_count=$(wc -l <"${backup_file}")
	echo "Backed up ${backup_count} commands to: $(basename "${backup_file}")"
}

# Extract top commands from history file
#
# Inputs:
# - $1, input_file, path to the history file to process
# - $2, output_file, path where to save the top commands
# - $3, max_commands, maximum number of top commands to extract
#
# Side Effects:
# - Creates a file with the top commands
# - Shows progress and results
extract_top_commands() {
	local input_file="$1"
	local output_file="$2"
	local max_commands="$3"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	# Extract commands from zsh history using sed, sort, and uniq
	# Handle zsh history format: ': timestamp:duration;command' or plain commands
	{
		# Extract commands after semicolon from timestamped entries
		sed -n 's/^: [0-9]*:[0-9]*;//p' "${input_file}"
		# Extract plain commands (lines not starting with ':')
		grep -v '^: ' "${input_file}" || true
	} |
		grep -v '^[[:space:]]*$' |
		sort |
		uniq -c |
		sort -rn |
		head -"${max_commands}" |
		sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' >"${output_file}"

	if [[ ! -f "${output_file}" ]]; then
		echo "Failed to create top commands file: ${output_file}" >&2
		return 1
	fi

	local top_extracted
	top_extracted=$(wc -l <"${output_file}")
	echo "Extracted ${top_extracted} top commands to: $(basename "${output_file}")"

	return 0
}

# Combine all historical top command files
#
# Inputs:
# - $1, input_directory, directory containing historical command files
# - $2, output_file, path where to save the combined commands
# - $3, max_commands, maximum number of top commands to keep
#
# Side Effects:
# - Creates a combined file with all historical top commands
# - Shows progress and results
combine_historical_files() {
	local input_directory="$1"
	local output_file="$2"
	local max_commands="$3"
	local library_file_pattern="library_*.txt"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local temp_combined
	temp_combined=$(mktemp)
	if [[ -z "${temp_combined}" ]]; then
		echo "Failed to create temporary file" >&2
		return 1
	fi

	local total_files
	total_files=$(find "${input_directory}" -name "${library_file_pattern}" -type f 2>/dev/null | wc -l || echo 0)
	echo "Found ${total_files} historical top command files. Adding to combined file."

	local files_processed=0
	while IFS= read -r -d '' file; do
		if [[ -f "${file}" ]]; then
			local file_count
			file_count=$(wc -l <"${file}")
			echo "Processed $(basename "${file}"): ${file_count} commands"
			cat "${file}" >>"${temp_combined}"
			((files_processed++))
		fi
	done < <(find "${input_directory}" -name "${library_file_pattern}" -type f -print0 2>/dev/null || true)

	# Count frequency of commands and rank them
	sort "${temp_combined}" |
		uniq -c |
		sort -rn |
		head -"${max_commands}" >"${temp_combined}.ranked"

	# Remove frequency counts and save final result
	sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' "${temp_combined}.ranked" >"${output_file}"

	if [[ ! -f "${output_file}" ]]; then
		echo "Failed to create combined top commands file: ${output_file}" >&2
		rm -f "${temp_combined}" "${temp_combined}.ranked"
		return 1
	fi

	local total_commands
	total_commands=$(wc -l <"${temp_combined}")
	local unique_commands
	unique_commands=$(wc -l <"${temp_combined}.ranked")

	echo "Combined ${total_commands} total commands into ${unique_commands} unique top commands"

	rm -f "${temp_combined}" "${temp_combined}.ranked"

	return 0
}

# Create dalaran library history file in zsh format
#
# Inputs:
# - $1, input_file, path to the file containing commands to convert
# - $2, output_file, path where to save the zsh history format
#
# Side Effects:
# - Creates a zsh history format file with the dalaran library commands
# - Shows progress and results
create_dalaran_library_history() {
	local input_file="$1"
	local output_file="$2"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	if [[ ! -f "${input_file}" ]]; then
		echo "Input file not found: ${input_file}" >&2
		return 1
	fi

	local combined_count
	combined_count=$(grep -c -v '^#' "${input_file}" 2>/dev/null || echo 0)
	echo "Created dalaran library: $(basename "${input_file}") with ${combined_count} commands"
	echo "Adding dalaran library to working zsh history."

	local base_timestamp
	local time_increment
	
	base_timestamp=$(($(date +%s) - 365 * 24 * 60 * 60))
	if [[ "${combined_count}" -gt 0 ]]; then
		time_increment=$((365 * 24 * 60 * 60 / combined_count))
	else
		time_increment=$((365 * 24 * 60 * 60))
	fi

	# Create zsh history format with timestamps
	local count=0
	local command
	while IFS= read -r command || [[ -n "${command}" ]]; do
		# Skip comments and empty lines
		[[ -z "${command}" || "${command}" =~ ^[[:space:]]*# ]] && continue

		local timestamp
		timestamp=$((base_timestamp + count * time_increment))
		echo ": ${timestamp}:0;${command}" >>"${output_file}"
		((count++))
	done <"${input_file}"

	if [[ ! -f "${output_file}" ]]; then
		echo "Failed to create dalaran library history file: ${output_file}" >&2
		return 1
	fi

	echo "Created zsh history format: $(basename "${output_file}") with ${count} commands"

	return 0
}

# Create working history file combining library and current history
#
# Inputs:
# - $1, library_file, path to the dalaran library history file
# - $2, current_history_file, path to the current history file
# - $3, output_file, path where to save the working history
#
# Side Effects:
# - Creates a working history file combining library and current history
# - Shows progress and results
create_working_history() {
	local library_file="$1"
	local current_history_file="$2"
	local output_file="$3"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	# Remove existing file to start fresh
	rm -f "${output_file}"

	# Append library history first
	if ! cat "${library_file}" >>"${output_file}"; then
		echo "Failed to append dalaran library to working history" >&2
		return 1
	fi

	# Append current history
	if ! cat "${current_history_file}" >>"${output_file}"; then
		echo "Failed to append current history to working history" >&2
		return 1
	fi

	if [[ ! -f "${output_file}" ]]; then
		echo "Failed to create working history file: ${output_file}" >&2
		return 1
	fi

	local working_count
	working_count=$(wc -l <"${output_file}")
	echo "Created working history: $(basename "${output_file}") with ${working_count} total commands"

	return 0
}

# Display summary of operations performed
#
# Inputs:
# - $1, dalaran_dir, path to the dalaran directory
# - $2, top_commands_dir, path to the top commands directory
# - $3, combined_commands_file, path to the combined commands file
# - $4, working_history_file, path to the working history file
#
# Side Effects:
# - Shows summary of all operations performed
display_summary() {
	local dalaran_dir="$1"
	local top_commands_dir="$2"
	local combined_commands_file="$3"
	local working_history_file="$4"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local backup_files
	backup_files=$(find "${dalaran_dir}" -maxdepth 1 -name "library_*.txt" -type f | wc -l)
	local snapshot_files
	snapshot_files=$(find "${top_commands_dir}" -name "library_*.txt" -type f | wc -l)
	local combined_count
	combined_count=$(grep -c -v '^#' "${combined_commands_file}" 2>/dev/null || echo 0)
	local working_count
	working_count=$(wc -l <"${working_history_file}")

	cat <<EOF

Dalaran Library Summary:
    Backup files: ${backup_files}
    Top command snapshots: ${snapshot_files}
    Library commands: ${combined_count}
    Working history total: ${working_count}

To use your dalaran library-enhanced history:
    export HISTFILE="${working_history_file}"
    fc -R  # Reload history

Run this script periodically to keep your library updated.
EOF
}

# Show top N most used commands from dalaran library
#
# Inputs:
# - $1, top_count, the number of top commands to show
#
# Side Effects:
# - Displays the top commands from the dalaran library
# - Returns error code if library not found
show_top_commands() {
	local top_count="$1"

	if [[ ! -f "${COMBINED_TOP_COMMANDS}" ]]; then
		echo "No dalaran library found. Run the script first to create one."
		return 1
	fi

	cat <<EOF

Top ${top_count} most used commands from dalaran library:
================================================
$(head -"${top_count}" "${COMBINED_TOP_COMMANDS}" | nl)
EOF
}

# Parse command line options
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Sets global variables based on options
# - Returns error code for invalid options
parse_options() {
	local show_top=0
	local top_count=10

	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			usage
			exit 0
			;;
		--top=*)
			show_top=1
			top_count="${1#--top=}"
			if [[ ! "${top_count}" =~ ^[0-9]+$ ]] || [[ "${top_count}" -lt 1 ]]; then
				echo "Error: --top value must be a positive integer" >&2
				return 1
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
			return 1
			;;
		esac
	done

	if [[ "${show_top}" -eq 1 ]]; then
		show_top_commands "${top_count}"
		exit $?
	fi

	return 0
}

# Main entry point for the dalaran library script
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Processes command line options
# - Creates and maintains the dalaran library
# - Exits with appropriate status code
main() {
	echo -e "\n===\Entry: ${BASH_SOURCE[0]:-$0}\n==="

	# Handle environment variables with defaults
	local dry_run
	dry_run=${DRY_RUN:-false}
	DRY_RUN="${dry_run}"

	# Parse command line options
	if ! parse_options "$@"; then
		usage
		return 1
	fi

	# Configuration
	local top_n_commands
	local current_history
	local timestamp
	local backup_file
	local top_commands_file
	local dalaran_library_history
	local working_history

	top_n_commands=${TOP_N_COMMANDS:-1000}
	current_history="${HISTFILE:-$HOME/.zsh_history}"
	timestamp=$(date +"%Y%m%d_%H%M%S")
	backup_file="${DALARAN_DIR}/library_${timestamp}.txt"
	top_commands_file="${TOP_COMMANDS_DIR}/library_${timestamp}.txt"
	dalaran_library_history="${DALARAN_DIR}/library"
	working_history="${DALARAN_DIR}/active_history"

	# Validate input
	if ! validate_input "${current_history}"; then
		echo "Failed to validate input history file" >&2
		return 1
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		cat <<EOF
========================================
ZSH Dalaran Library [DRY RUN MODE]
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
		echo "Would create directories: ${DALARAN_DIR} and ${TOP_COMMANDS_DIR}"
	else
		if ! mkdir -p "${DALARAN_DIR}" "${TOP_COMMANDS_DIR}"; then
			echo "Failed to create directories: ${DALARAN_DIR} and ${TOP_COMMANDS_DIR}" >&2
			return 1
		fi
	fi

	# Backup current history
	if ! create_backup "${current_history}" "${backup_file}"; then
		echo "Failed to create backup" >&2
		return 1
	fi

	if ! extract_top_commands "${current_history}" "${top_commands_file}" "${top_n_commands}"; then
		echo "Failed to extract top commands" >&2
		return 1
	fi

	if ! combine_historical_files "${TOP_COMMANDS_DIR}" "${COMBINED_TOP_COMMANDS}" "${top_n_commands}"; then
		echo "Failed to combine historical files" >&2
		return 1
	fi

	if ! create_dalaran_library_history "${COMBINED_TOP_COMMANDS}" "${dalaran_library_history}"; then
		echo "Failed to create dalaran library history" >&2
		return 1
	fi

	if ! create_working_history "${dalaran_library_history}" "${current_history}" "${working_history}"; then
		echo "Failed to create working history" >&2
		return 1
	fi

	display_summary "${DALARAN_DIR}" "${TOP_COMMANDS_DIR}" "${COMBINED_TOP_COMMANDS}" "${working_history}"

	echo -e "\n===\Exit: ${BASH_SOURCE[0]:-$0}\n==="

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
	exit $?
fi
