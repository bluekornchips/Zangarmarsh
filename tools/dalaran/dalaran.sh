#!/usr/bin/env bash
#
# ZSH Command Dalaran Library Script
# Builds and maintains a collection of the most-used commands over time
#
set -eo pipefail

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

# Update library by combining all archive top_commands.txt files
#
# Inputs:
# - $1, archives_directory, directory containing archive directories
# - $2, output_file, path where to save the combined library
#
# Side Effects:
# - Creates library file with all top commands from archives
# - Shows progress and results
update_library() {
	local archives_directory="$1"
	local output_file="$2"
	local top_commands_pattern="*/top_commands.txt"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local total_files
	total_files=$(find "${archives_directory}" -path "${archives_directory}/${top_commands_pattern}" -type f 2>/dev/null | wc -l || echo 0)
	echo "Found ${total_files} archive top commands files. Updating library."

	# Clear the output file
	: >"${output_file}"

	local files_processed=0
	while IFS= read -r -d '' file; do
		if [[ -f "${file}" ]]; then
			local file_count
			file_count=$(wc -l <"${file}")
			echo "Added $(basename "$(dirname "${file}")"): ${file_count} commands"
			cat "${file}" >>"${output_file}"
			((files_processed++))
		fi
	done < <(find "${archives_directory}" -path "${archives_directory}/${top_commands_pattern}" -type f -print0 2>/dev/null || true)

	if [[ ! -f "${output_file}" ]]; then
		echo "Failed to create library file: ${output_file}" >&2
		return 1
	fi

	local total_commands
	total_commands=$(wc -l <"${output_file}")
	echo "Updated library with ${total_commands} total commands from ${files_processed} archives"

	return 0
}

# Create archive with paired top commands file
#
# Inputs:
# - $1, archive_file, path where to save the archive
# - $2, top_commands_file, path where to save the top commands
# - $3, max_commands, maximum number of top commands to extract
#
# Side Effects:
# - Creates archive file (backup of current HISTFILE)
# - Creates top commands file from the archive
# - Shows progress and results
create_archive() {
	local archive_file="$1"
	local top_commands_file="$2"
	local max_commands="$3"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	# Create archive directory
	local archive_dir
	archive_dir="$(dirname "${archive_file}")"
	if ! mkdir -p "${archive_dir}"; then
		echo "Failed to create archive directory ${archive_dir}" >&2
		return 1
	fi

	# Create archive (backup of current HISTFILE)
	if ! cp "${HISTFILE}" "${archive_file}"; then
		echo "Failed to create archive ${archive_file}" >&2
		return 1
	fi

	local archive_count
	archive_count=$(wc -l <"${archive_file}")
	echo "Created archive: $(basename "${archive_dir}") with ${archive_count} commands"

	# Extract top commands from the archive
	if ! extract_top_commands "${archive_file}" "${top_commands_file}" "${max_commands}"; then
		echo "Failed to extract top commands from archive" >&2
		return 1
	fi

	return 0
}

# Display summary of operations performed
#
# Inputs:
# - $1, dalaran_dir, path to the dalaran directory
# - $2, archives_dir, path to the archives directory
# - $3, top_commands_file, path to the top commands file
#
# Side Effects:
# - Shows summary of all operations performed
display_summary() {
	local dalaran_dir="$1"
	local archives_dir="$2"
	local top_commands_file="$3"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local archive_dirs
	archive_dirs=$(find "${archives_dir}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo 0)
	local top_commands_count
	top_commands_count=$(grep -c -v '^#' "${top_commands_file}" 2>/dev/null || echo 0)

	cat <<EOF

Dalaran Summary:
    Archive directories: ${archive_dirs}
    Combined top commands: ${top_commands_count}

Your dalaran top commands are available at:
    ${top_commands_file}

Run this script periodically to keep your archives updated.
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
	local dalaran_dir="$HOME/.dalaran"
	local top_commands_file="${dalaran_dir}/top_commands.txt"

	if [[ ! -f "${top_commands_file}" ]]; then
		echo "No dalaran top commands found. Run the script first to create them."
		return 1
	fi

	cat <<EOF

Top ${top_count} most used commands from dalaran:
===============================================
$(head -"${top_count}" "${top_commands_file}" | nl)
EOF
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

	# Handle environment variables with defaults
	[[ -z "${DRY_RUN:-}" ]] && DRY_RUN="false"

	# Ensure HISTFILE is set to default if not already set
	HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

	# Validate that history file exists
	[[ ! -f "${HISTFILE}" ]] && echo "History file not found: ${HISTFILE}" >&2

	# Configuration
	local dalaran_dir
	local timestamp

	local top_commands_file
	local archives_dir
	local archive_dir
	local archive_file
	local archive_top_commands_file

	dalaran_dir="$HOME/.dalaran"
	timestamp=$(date +"%Y%m%d_%H%M%S")

	top_n_commands=${TOP_N_COMMANDS:-1000}

	top_commands_file="${dalaran_dir}/top_commands.txt"
	archives_dir="${dalaran_dir}/archives"
	archive_dir="${archives_dir}/${timestamp}"
	archive_file="${archive_dir}/.zsh_history"
	archive_top_commands_file="${archive_dir}/top_commands.txt"

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
		echo "Would create directories: ${dalaran_dir} and ${archives_dir}"
	else
		if ! mkdir -p "${dalaran_dir}" "${archives_dir}"; then
			echo "Failed to create directories: ${dalaran_dir} and ${archives_dir}" >&2
			return 1
		fi
	fi

	# Create archive with paired top commands file
	if ! create_archive "${archive_file}" "${archive_top_commands_file}" "${top_n_commands}"; then
		echo "Failed to create archive" >&2
		return 1
	fi

	# Update library from all archive top commands files
	if ! update_library "${archives_dir}" "${top_commands_file}"; then
		echo "Failed to update library" >&2
		return 1
	fi

	display_summary "${dalaran_dir}" "${archives_dir}" "${top_commands_file}"

	echo -e "\n===\Exit: ${BASH_SOURCE[0]:-$0}\n==="

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
	exit $?
fi
