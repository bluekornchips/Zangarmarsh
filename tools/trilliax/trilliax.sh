#!/usr/bin/env bash
#
# Trilliax cleanup script
# Removes generated files and directories from development environments
#
set -eo pipefail

ENABLED_TARGETS=""
DEFAULT_MAX_DEPTH=10

# Execute cleanup operation with find pattern
#
# Inputs:
# - $1, function_name, name of calling function (for logging)
# - $2, target_dir, directory to clean
# - $3+, find_args, find command arguments (passed as array elements)
#
# Side Effects:
# - Removes items matching find expression using "rm -rf" (works for both files and directories)
# - Always uses iteration (never find -delete)
# - Uses maxdepth 10 by default
# - In dry-run mode, shows what would be removed
# - Returns 0 on success, 1 on error
execute_clean() {
	local function_name="$1"
	local target_dir="$2"
	shift 2
	local find_args=("$@")
	local max_depth=10

	# Input validation
	if [[ -z "${function_name}" ]]; then
		echo "execute_clean:: function_name is required" >&2
		return 1
	fi

	if [[ -z "${target_dir}" ]]; then
		echo "${function_name}:: target_dir is required" >&2
		return 1
	fi

	if [[ ${#find_args[@]} -eq 0 ]]; then
		echo "${function_name}:: find_args are required" >&2
		return 1
	fi

	# Path validation: ensure target_dir is absolute and exists
	local target_dir_abs
	target_dir_abs="$(cd "${target_dir}" && pwd 2>/dev/null)"
	if [[ -z "${target_dir_abs}" ]] || [[ ! -d "${target_dir_abs}" ]]; then
		echo "${function_name}:: Invalid target_dir: ${target_dir}" >&2
		return 1
	fi

	# Dry-run mode: show what would be removed
	if [[ "${DRY_RUN}" == "true" ]]; then
		while IFS= read -r -d '' item || [[ -n "${item}" ]]; do
			# Explicit path validation: ensure item is within target_dir_abs
			if [[ -n "${item}" ]] && [[ "${item}" == "${target_dir_abs}"* ]]; then
				echo "${function_name}:: Would remove: ${item}"
			fi
		done < <(find "${target_dir_abs}" -maxdepth "${max_depth}" "${find_args[@]}" -print0 2>/dev/null)
		return 0
	fi

	# Actual removal using rm -rf (works for both files and directories)
	while IFS= read -r -d '' item || [[ -n "${item}" ]]; do
		# Explicit path validation: ensure item is within target_dir_abs
		if [[ -n "${item}" ]] && [[ "${item}" == "${target_dir_abs}"* ]]; then
			rm -rf "${item}" 2>/dev/null || true
		fi
	done < <(find "${target_dir_abs}" -maxdepth "${max_depth}" "${find_args[@]}" -print0 2>/dev/null)

	return 0
}

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
  -t, --targets      Comma-separated list of targets to clean (cursor,python,node,fs)
  -a, --all          Clean all targets (overrides --targets)
  -r, --dry-run      Show what would be cleaned without making changes
  -h, --help         Show this help message

ENVIRONMENT VARIABLES:
  DRY_RUN   Enable dry-run mode

CLEANUP OPERATIONS:
  - .cursor directories (recursively)
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

	echo "clean_fs:: Cleaning empty directories."

	execute_clean "clean_fs" "${target_dir}" -depth -type d -empty
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

	echo "clean_cursor:: Cleaning .cursor directories."

	execute_clean "clean_cursor" "${target_dir}" -type d -name ".cursor"
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

	echo "clean_python:: Cleaning Python files."

	execute_clean "clean_python" "${target_dir}" \
		\( \
		-type d -name "venv" \
		-o -type d -name ".venv" \
		-o -type d -name "env" \
		-o -type d -name "__pycache__" \
		-o -name "*.pyc" \
		-o -name "*.pyo" \
		\)
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

	echo "clean_node:: Cleaning Node.js files."

	execute_clean "clean_node" "${target_dir}" \
		\( \
		-type d -name "node_modules" \
		-o -type d -name ".npm" \
		-o -type d -name ".yarn" \
		-o -name ".yarnrc.yml" \
		-o -name "npm-debug.log*" \
		-o -name "yarn-debug.log*" \
		-o -name "yarn-error.log*" \
		\)
}

# Validate and parse target selection
validate_targets() {
	local targets_string="$1"
	local all_flag="${2:-false}"

	if [[ "${all_flag}" == "true" ]]; then
		ENABLED_TARGETS="cursor python node fs"
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
		cursor | python | node | fs)
			if [[ -n "${enabled_targets}" ]]; then
				enabled_targets="${enabled_targets} ${target}"
			else
				enabled_targets="${target}"
			fi
			;;
		*)
			echo "validate_targets:: Invalid target '${target}'. Available targets: cursor,python,node,fs" >&2
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
# - Command line arguments: [OPTIONS] [DIRECTORY]
#
# Side Effects:
# - Parses command line arguments
# - Performs cleanup operations for selected targets in the specified directory
# - Shows progress messages for each cleanup operation
# - Uses global DRY_RUN variable to determine dry-run mode
# - Returns 0 on success, 1 on error
run_trilliax() {
	local target_dir="."
	local targets_string=""
	local all_flag="false"

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-d | --dir)
			if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
				echo "run_trilliax:: --dir requires a directory path" >&2
				echo "run_trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				return 1
			fi
			target_dir="${2}"
			shift 2
			;;
		-t | --targets)
			if [[ -z "${2:-}" ]] || [[ "${2:-}" == -* ]]; then
				echo "run_trilliax:: --targets requires a comma-separated list of targets" >&2
				echo "run_trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				return 1
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
			return 0
			;;
		*)
			if [[ -d "${1}" ]]; then
				target_dir="${1}"
				shift
			else
				echo "run_trilliax:: Unknown option '${1}'" >&2
				echo "run_trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				return 1
			fi
			;;
		esac
	done

	# Validate targets
	if ! validate_targets "${targets_string}" "${all_flag}"; then
		return 1
	fi

	# Set DRY_RUN default if not set
	DRY_RUN="${DRY_RUN:-false}"
	export DRY_RUN

	# Validate target directory
	if [[ -z "${target_dir}" ]]; then
		echo "run_trilliax:: target_dir is required" >&2
		return 1
	fi

	echo "run_trilliax:: Apologies for the mess master, I shall tidy up immediately."

	# Set MAX_DEPTH globally so clean_fs can access it
	MAX_DEPTH="${MAX_DEPTH:-${DEFAULT_MAX_DEPTH}}"

	if [[ ! -d "${target_dir}" ]]; then
		echo "run_trilliax:: Directory '${target_dir}' does not exist" >&2
		return 1
	fi

	pushd "${target_dir}" >/dev/null
	target_dir="$(pwd)"
	popd >/dev/null
	echo "run_trilliax:: Cleaning directory: ${target_dir}"

	if [[ -z "${ENABLED_TARGETS}" ]]; then
		echo "run_trilliax:: No targets selected for cleanup." >&2
		return 1
	fi

	echo "run_trilliax:: Filthy, filthy, FILTHY!"
	local cleanup_count=0
	# Convert space-separated string to array for safe iteration
	local -a targets_array
	IFS=' ' read -ra targets_array <<<"${ENABLED_TARGETS}"
	local target
	for target in "${targets_array[@]}"; do
		case "${target}" in
		cursor)
			clean_cursor "${target_dir}"
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

	echo "run_trilliax:: Please don't say such things! The master is back, and things need to be kept tidy."
}

# Execute main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	run_trilliax "$@"
	exit $?
fi
