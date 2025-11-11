#!/usr/bin/env bash
#
# Trilliax cleanup script
# Removes generated files and directories from development environments
#
set -eo pipefail

ENABLED_TARGETS=""
DEFAULT_MAX_DEPTH=10

# Display usage information
usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Trilliax cleanup script
Removes generated files and directories from development environments.

ARGUMENTS:
  DIRECTORY    Directory to clean (default: current directory)

OPTIONS:
  -d, --dir          Directory to clean (default: current directory)
  -t, --targets      Comma-separated list of targets to clean (cursor,claude,python,node,fs)
  -a, --all          Clean all targets (overrides --targets)
  -r, --dry-run      Show what would be cleaned without making changes
  -h, --help         Show this help message

ENVIRONMENT VARIABLES:
  DRY_RUN   Enable dry-run mode

CLEANUP OPERATIONS:
  - .cursor directories (recursively)
  - Claude files (CLAUDE.md)
  - Python files (virtual environments, cache files, compiled files)
  - Node.js files (node_modules, npm/yarn cache directories, log files)
  - Empty directories (recursively removes all empty directories up to $DEFAULT_MAX_DEPTH levels deep)

EXAMPLES:
  $(basename "$0")                    # Clean current directory
  $(basename "$0") /path/to/project   # Clean specific directory
  $(basename "$0") --dry-run          # Show what would be cleaned
  $(basename "$0") --dry-run /path/to/project  # Preview cleanup for specific directory
  $(basename "$0") --help             # Show this help

EOF
}

# Clean filesystem of empty directories
#
# Inputs:
# - $1, target_dir, directory to clean filesystem from
#
# Side Effects:
# - Removes empty directories
# - In dry-run mode (DRY_RUN=true), shows what would be removed without removing
# - Returns 0 on success
clean_fs() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "clean_fs:: target_dir is required" >&2
		return 1
	fi

	echo "clean_fs:: Cleaning empty directories."

	local dirs_to_remove
	dirs_to_remove=$(find "${target_dir}" -maxdepth "${DEFAULT_MAX_DEPTH}" -depth -type d -empty 2>/dev/null)

	if [[ "${DRY_RUN}" == "true" ]]; then
		local dir
		for dir in ${dirs_to_remove}; do
			[[ -n "${dir}" ]] && echo "clean_fs:: Would remove: ${dir}"
		done

		return 0
	fi

	find "${target_dir}" -maxdepth "${DEFAULT_MAX_DEPTH}" -depth -type d -empty -delete 2>/dev/null || true

	return 0
}

# Clean .cursor directories recursively
#
# Inputs:
# - $1, target_dir, directory to clean .cursor directories from
#
# Side Effects:
# - Removes .cursor directories and their contents
# - In dry-run mode (DRY_RUN=true), shows what would be removed without removing
# - Returns 0 on success
clean_cursor() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "clean_cursor:: target_dir is required" >&2
		return 1
	fi

	echo "clean_cursor:: Cleaning .cursor directories."

	local dirs_to_remove=""
	dirs_to_remove="$(find "${target_dir}" -maxdepth 10 -type d -name ".cursor" 2>/dev/null)"

	if [[ "${DRY_RUN}" == "true" ]]; then
		local dir
		for dir in ${dirs_to_remove}; do
			[[ -n "${dir}" ]] && echo "clean_cursor:: Would remove: ${dir}"
		done

		return 0
	fi

	local dir
	for dir in ${dirs_to_remove}; do
		[[ -n "${dir}" ]] && rm -rf "${dir}" 2>/dev/null || true
	done

	return 0
}

# Clean Claude-related files
#
# Inputs:
# - $1, target_dir, directory to clean Claude files from
#
# Side Effects:
# - Removes CLAUDE.md files
# - In dry-run mode (DRY_RUN=true), shows what would be removed without removing
# - Returns 0 on success
clean_claude() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "clean_claude:: target_dir is required" >&2
		return 1
	fi

	echo "clean_claude:: Cleaning Claude files."

	local files_to_remove=""
	files_to_remove="$(find "${target_dir}" -maxdepth 10 -name "CLAUDE.md" -type f 2>/dev/null)"

	if [[ "${DRY_RUN}" == "true" ]]; then
		local file
		for file in ${files_to_remove}; do
			[[ -n "${file}" ]] && echo "clean_claude:: Would remove: ${file}"
		done

		return 0
	fi

	local file
	for file in ${files_to_remove}; do
		[[ -n "${file}" ]] && rm -f "${file}" 2>/dev/null || true
	done

	return 0
}

# Clean Python files and directories
#
# Inputs:
# - $1, target_dir, directory to clean Python files from
#
# Side Effects:
# - Removes Python virtual environments, cache files, and compiled files
# - In dry-run mode (DRY_RUN=true), shows what would be removed without removing
# - Returns 0 on success
clean_python() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "clean_python:: target_dir is required" >&2
		return 1
	fi

	echo "clean_python:: Cleaning Python files."

	local items_to_remove=""
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name "venv" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name ".venv" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name "env" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name "__pycache__" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "*.pyc" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "*.pyo" 2>/dev/null)"

	if [[ "${DRY_RUN}" == "true" ]]; then
		local item
		for item in ${items_to_remove}; do
			[[ -n "${item}" ]] && echo "clean_python:: Would remove: ${item}"
		done

		return 0
	fi

	local item
	for item in ${items_to_remove}; do
		[[ -n "${item}" ]] && rm -rf "${item}" 2>/dev/null || true
	done

	return 0
}

# Clean Node.js files and directories
#
# Inputs:
# - $1, target_dir, directory to clean Node.js files from
#
# Side Effects:
# - Removes node_modules directories, npm/yarn cache directories, and log files
# - In dry-run mode (DRY_RUN=true), shows what would be removed without removing
# - Returns 0 on success
clean_node() {
	local target_dir="$1"

	if [[ -z "${target_dir}" ]]; then
		echo "clean_node:: target_dir is required" >&2
		return 1
	fi

	echo "clean_node:: Cleaning Node.js files."

	local items_to_remove=""
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name "node_modules" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name ".npm" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -type d -name ".yarn" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "package-lock.json" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "yarn.lock" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name ".yarnrc.yml" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "npm-debug.log*" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "yarn-debug.log*" 2>/dev/null)"
	items_to_remove="${items_to_remove} $(find "${target_dir}" -maxdepth 10 -name "yarn-error.log*" 2>/dev/null)"

	if [[ "${DRY_RUN}" == "true" ]]; then
		local item
		for item in ${items_to_remove}; do
			[[ -n "${item}" ]] && echo "clean_node:: Would remove: ${item}"
		done

		return 0
	fi

	local item
	for item in ${items_to_remove}; do
		[[ -n "${item}" ]] && rm -rf "${item}" 2>/dev/null || true
	done

	return 0
}

# Validate and parse target selection
validate_targets() {
	local targets_string="$1"
	local all_flag="${2:-false}"

	if [[ "${all_flag}" == "true" ]]; then
		ENABLED_TARGETS="cursor claude python node fs"
		return 0
	fi

	if [[ -z "${targets_string}" ]]; then
		echo "validate_targets:: No targets specified. Use --targets to specify targets or --all to clean all." >&2
		return 1
	fi

	local enabled_targets=""
	local target

	IFS=',' read -ra REQUESTED_TARGETS <<<"${targets_string}"
	for target in "${REQUESTED_TARGETS[@]}"; do
		target=$(echo "${target}" | xargs)
		case "${target}" in
		cursor | claude | python | node | fs)
			if [[ -n "${enabled_targets}" ]]; then
				enabled_targets="${enabled_targets} ${target}"
			else
				enabled_targets="${target}"
			fi
			;;
		*)
			echo "validate_targets:: Invalid target '${target}'. Available targets: cursor,claude,python,node,fs" >&2
			return 1
			;;
		esac
	done

	ENABLED_TARGETS="${enabled_targets}"
	return 0
}

# Main entry point for the trilliax cleanup script
#
# Inputs:
# - $1, target_dir, optional directory to clean (default: current directory)
#
# Side Effects:
# - Performs cleanup operations for selected targets in the specified directory
# - Shows progress messages for each cleanup operation
# - Uses global DRY_RUN variable to determine dry-run mode
# - Returns 0 on success, 1 on error
main() {
	local target_dir="${1:-.}"

	if [[ -z "${target_dir}" ]]; then
		echo "main:: target_dir is required" >&2
		return 1
	fi

	echo "main:: Apologies for the mess master, I shall tidy up immediately."

	# Set MAX_DEPTH globally so clean_fs can access it
	MAX_DEPTH="${MAX_DEPTH:-${DEFAULT_MAX_DEPTH}}"

	if [[ ! -d "${target_dir}" ]]; then
		echo "main:: Directory '${target_dir}' does not exist" >&2
		return 1
	fi

	pushd "${target_dir}" >/dev/null
	target_dir="$(pwd)"
	popd >/dev/null
	echo "main:: Cleaning directory: ${target_dir}"

	if [[ -z "${ENABLED_TARGETS}" ]]; then
		echo "main:: No targets selected for cleanup." >&2
		return 1
	fi

	echo "main:: Filthy, filthy, FILTHY!"
	local cleanup_count=0
	local target
	for target in ${ENABLED_TARGETS}; do
		case "${target}" in
		cursor)
			clean_cursor "${target_dir}"
			cleanup_count=$((cleanup_count + 1))
			;;
		claude)
			clean_claude "${target_dir}"
			cleanup_count=$((cleanup_count + 1))
			;;
		python)
			clean_python "${target_dir}"
			cleanup_count=$((cleanup_count + 1))
			;;
		node)
			clean_node "${target_dir}"
			cleanup_count=$((cleanup_count + 1))
			;;
		fs)
			clean_fs "${target_dir}"
			cleanup_count=$((cleanup_count + 1))
			;;
		esac
	done

	echo "main:: Please don't say such things! The master is back, and things need to be kept tidy."
}

# Execute main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	target_dir="."
	DRY_RUN="${DRY_RUN}"
	targets_string=""
	all_flag="false"

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-d | --dir)
			if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
				echo "trilliax:: --dir requires a directory path" >&2
				echo "trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				exit 1
			fi
			target_dir="${2}"
			shift 2
			;;
		-t | --targets)
			if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
				echo "trilliax:: --targets requires a comma-separated list of targets" >&2
				echo "trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				exit 1
			fi
			targets_string="${2}"
			shift 2
			;;
		-a | --all)
			all_flag="true"
			shift
			;;
		-r | --dry-run)
			DRY_RUN="true"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			if [[ -d "${1}" ]]; then
				target_dir="${1}"
				shift
			else
				echo "trilliax:: Unknown option '${1}'" >&2
				echo "trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				exit 1
			fi
			;;
		esac
	done

	# Validate targets
	if ! validate_targets "${targets_string}" "${all_flag}"; then
		exit 1
	fi

	DRY_RUN="${DRY_RUN-false}"

	export DRY_RUN

	main "${target_dir}"
fi
