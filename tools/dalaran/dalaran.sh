#!/usr/bin/env bash
#
# ZSH Command Dalaran Spellbook Script
# Builds and maintains a collection of the most-used commands over time
#
set -euo pipefail

# Display usage information
usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

ZSH Command Dalaran Spellbook Script
Builds and maintains a collection of the most-used commands over time.

OPTIONS:
    -h, --help          				Show this help message
    --top=N             				Show the top N most used spells (default: 100)
    --silence="spell1,spell2"  	Add spells to silenced exclusion list
		--dry-run              			Show what would be done without making changes
		--archive=true          		Create an archive of the current history

ENVIRONMENT VARIABLES:
    DRY_RUN=true        Enable dry run mode
    TOP_N_SPELLS=N      Number of top spells to extract (default: 1000)
    HISTFILE=path       Path to zsh history file (default: ~/.zsh_history)

EXAMPLES:
    $(basename "$0")                    	# Run with default settings
    $(basename "$0") --top=20          		# Show top 20 spells
    $(basename "$0") --dry-run         		# Show what would be done
		$(basename "$0") --silence="ls,pwd" 	# Add spells to exclusion list
		DRY_RUN=true $(basename "$0")      		# Alternative dry run method

The script creates a spellbook of your most frequently used commands
and maintains archives of your command history with silenced spell
filtering to focus on the spells that matter most.
EOF
}

# Update silenced spells file with new commands to exclude
#
# Inputs:
# - $1, silenced_file, path to the silenced.txt file
# - $2, spells_string, comma-separated list of spells to add
#
# Side Effects:
# - Updates or creates the silenced.txt file
# - Shows progress messages
update_silenced_spells() {
	local silenced_file="$1"
	local spells_string="$2"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local dalaran_dir
	dalaran_dir="$(dirname "${silenced_file}")"
	if ! mkdir -p "${dalaran_dir}"; then
		echo "Failed to create dalaran directory ${dalaran_dir}" >&2
		return 1
	fi

	touch "${silenced_file}"

	# Parse comma-separated spells and add to silenced file
	local IFS=','
	local spell
	local spells_added=0

	for spell in ${spells_string}; do
		[[ -z "${spell}" ]] && continue

		# Check if spell already exists in silenced file
		if ! grep -Fxq "${spell}" "${silenced_file}"; then
			echo "${spell}" >>"${silenced_file}"
			echo "Silenced spell: ${spell}"
			((spells_added++))
		else
			echo "Already silenced: ${spell}"
		fi
	done

	if [[ ${spells_added} -gt 0 ]]; then
		echo "Updated silenced spells with ${spells_added} new spell(s)"
	else
		echo "No new spells added to silence list"
	fi

	return 0
}

# Extract top spells from history file
#
# Inputs:
# - $1, input_file, path to the history file to process
# - $2, output_file, path where to save the top spells
# - $3, max_spells, maximum number of top spells to extract
# - $4, silenced_file, path to silenced spells file (optional)
#
# Side Effects:
# - Creates a file with the top spells
# - Shows progress and results
extract_top_spells() {
	local input_file="$1"
	local output_file="$2"
	local max_spells="$3"
	local silenced_file="${4:-}"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	# Use arcane linguist for spell processing
	local temp_spells
	temp_spells=$(mktemp)

	"${ARCANE_LINGUIST_SCRIPT}" <"$input_file" |
		sort |
		uniq -c |
		sort -rn |
		head -"$max_spells" |
		sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' >"$temp_spells"

	# Apply silenced spells filtering if silenced file exists
	if [[ -f "$silenced_file" ]]; then
		local filtered_spells
		filtered_spells=$(mktemp)
		local spells_silenced=0

		while IFS= read -r spell; do
			if ! grep -Fxq "$spell" "$silenced_file" 2>/dev/null; then
				echo "$spell" >>"$filtered_spells"
			else
				((spells_silenced++))
			fi
		done <"$temp_spells"

		if [[ $spells_silenced -gt 0 ]]; then
			echo "Silenced $spells_silenced spell(s) from spellbook"
		fi

		mv "$filtered_spells" "$output_file"
		rm -f "$temp_spells"
	else
		mv "$temp_spells" "$output_file"
	fi

	local top_extracted
	top_extracted=$(wc -l <"$output_file")
	echo "Extracted $top_extracted top spells to: $(basename "$output_file")"

	return 0
}

# Update spellbook by combining all archive spellbook.txt files
#
# Inputs:
# - $1, archives_directory, directory containing archive directories
# - $2, output_file, path where to save the combined spellbook
#
# Side Effects:
# - Creates spellbook file with all top spells from archives
# - Shows progress and results
update_spellbook() {
	local archives_directory="$1"
	local output_file="$2"
	local spellbook_pattern="*/spellbook.txt"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local total_files
	total_files=$(find "${archives_directory}" -path "${archives_directory}/${spellbook_pattern}" \
		-type f 2>/dev/null | wc -l || echo 0)
	echo "Found ${total_files} archive spellbook files. Updating spellbook."

	: >"${output_file}"

	local files_processed=0
	while IFS= read -r -d '' file; do
		if [[ -f "${file}" ]]; then
			local file_count
			file_count=$(wc -l <"${file}")
			echo "Added $(basename "$(dirname "${file}")"): ${file_count} spells"
			cat "${file}" >>"${output_file}"
			((files_processed++))
		fi
	done < <(find "${archives_directory}" -path "${archives_directory}/${spellbook_pattern}" \
		-type f -print0 2>/dev/null || true)

	if [[ ! -f "${output_file}" ]]; then
		echo "Failed to create spellbook file: ${output_file}" >&2
		return 1
	fi

	local total_spells
	total_spells=$(wc -l <"${output_file}")
	local summary
	summary="Updated spellbook with ${total_spells} total spells from ${files_processed} archives"
	echo "${summary}"

	return 0
}

# Create archive with paired spellbook file
#
# Inputs:
# - $1, archive_file, path where to save the archive
# - $2, spellbook_file, path where to save the spellbook
# - $3, max_spells, maximum number of top spells to extract
# - $4, silenced_file, path to silenced spells file (optional)
#
# Side Effects:
# - Creates archive file (backup of current HISTFILE)
# - Creates spellbook file from the archive
# - Shows progress and results
create_archive() {
	local archive_file="$1"
	local spellbook_file="$2"
	local max_spells="$3"
	local silenced_file="${4:-}"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local archive_dir
	archive_dir="$(dirname "${archive_file}")"
	if ! mkdir -p "${archive_dir}"; then
		echo "Failed to create archive directory ${archive_dir}" >&2
		return 1
	fi

	# Creat backup of current HISTFILE
	if ! cp "${HISTFILE}" "${archive_file}"; then
		echo "Failed to create archive ${archive_file}" >&2
		return 1
	fi

	local archive_count
	archive_count=$(wc -l <"${archive_file}")
	echo "Created archive: $(basename "${archive_dir}") (${archive_count} commands)"

	if ! extract_top_spells "${archive_file}" "${spellbook_file}" "${max_spells}" "${silenced_file}"; then
		echo "Failed to extract top spells from archive" >&2
		return 1
	fi

	return 0
}

# Display summary of operations performed
#
# Inputs:
# - $1, dalaran_dir, path to the dalaran directory
# - $2, archives_dir, path to the archives directory
# - $3, spellbook_file, path to the spellbook file
#
# Side Effects:
# - Shows summary of all operations performed
display_summary() {
	local dalaran_dir="$1"
	local archives_dir="$2"
	local spellbook_file="$3"

	[[ "${DRY_RUN}" == "true" ]] && return 0

	local archive_dirs
	archive_dirs=$(find "${archives_dir}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo 0)
	local spellbook_count
	spellbook_count=$(grep -c -v '^#' "${spellbook_file}" 2>/dev/null || echo 0)

	cat <<EOF

Dalaran Summary:
    Archive directories: ${archive_dirs}
    Combined spellbook entries: ${spellbook_count}

Your dalaran spellbook is available at:
    ${spellbook_file}

Run this script periodically to keep your archives updated.
EOF
}

# Show top N most used spells from dalaran spellbook
#
# Inputs:
# - $1, top_count, the number of top spells to show
#
# Side Effects:
# - Displays the top spells from the dalaran spellbook
# - Returns error code if spellbook not found
show_top_spells() {
	local top_count="$1"
	local dalaran_dir="$HOME/.dalaran"
	local spellbook_file="${dalaran_dir}/spellbook.txt"

	if [[ ! -f "${spellbook_file}" ]]; then
		echo "No dalaran spellbook found. Run the script first to create it."
		return 1
	fi

	cat <<EOF

Top ${top_count} most used spells from dalaran spellbook:
========================================================
$(head -"${top_count}" "${spellbook_file}" | nl)
EOF
}

# Main entry point for the dalaran spellbook script
#
# Inputs:
# - All command line arguments
#
# Side Effects:
# - Processes command line options
# - Creates and maintains the dalaran spellbook
# - Exits with appropriate status code
main() {
	local show_top=0

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
				echo "--top value must be a positive integer" >&2
				return 1
			fi
			shift
			;;
		--silence=*)
			silenced_spells="${1#--silence=}"
			if [[ -z "${silenced_spells}" ]]; then
				echo "--silence requires a comma-separated list of spells" >&2
				return 1
			fi
			shift
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		*)
			echo "Unknown option '$1'" >&2
			echo "Use --help for usage information" >&2
			return 1
			;;
		esac
	done

	if [[ "${show_top}" -eq 1 ]]; then
		show_top_spells "${top_count}"
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

	local spellbook_file
	local archives_dir
	local archive_dir
	local archive_file
	local archive_spellbook_file
	local silenced_file

	dalaran_dir="$HOME/.dalaran"
	timestamp=$(date +"%Y%m%d_%H%M%S")

	top_n_spells=${TOP_N_SPELLS:-1000}

	spellbook_file="${dalaran_dir}/spellbook.txt"
	archives_dir="${dalaran_dir}/archives"
	archive_dir="${archives_dir}/${timestamp}"
	archive_file="${archive_dir}/.zsh_history"
	archive_spellbook_file="${archive_dir}/spellbook.txt"
	silenced_file="${dalaran_dir}/silenced.txt"

	if [[ -n "${silenced_spells:-}" ]]; then
		if ! update_silenced_spells "${silenced_file}" "${silenced_spells}"; then
			echo "Failed to update silenced spells" >&2
			return 1
		fi
		echo "Silenced spells updated. Run script again to apply filtering."
		return 0
	fi

	cat <<EOF
========================================
ZSH Dalaran Spellbook
========================================
EOF

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Would create directories: ${dalaran_dir} and ${archives_dir}"
	else
		if ! mkdir -p "${dalaran_dir}" "${archives_dir}"; then
			local dir_error
			dir_error="Failed to create directories: ${dalaran_dir} and ${archives_dir}"
			echo "${dir_error}" >&2
			return 1
		fi
	fi

	if ! create_archive "${archive_file}" "${archive_spellbook_file}" "${top_n_spells}" "${silenced_file}"; then
		echo "Failed to create archive" >&2
		return 1
	fi

	if ! update_spellbook "${archives_dir}" "${spellbook_file}"; then
		echo "Failed to update spellbook" >&2
		return 1
	fi

	display_summary "${dalaran_dir}" "${archives_dir}" "${spellbook_file}"

	return 0
}

ARCANE_LINGUIST_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/arcane-linguist.sh"
if [[ ! -f "${ARCANE_LINGUIST_SCRIPT}" ]]; then
	echo "Could not find arcane-linguist.sh script" >&2
	return 1
fi

export ARCANE_LINGUIST_SCRIPT

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

	main "$@"
	exit $?
fi
