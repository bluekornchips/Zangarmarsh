#!/usr/bin/env bash
#
# Trilliax cleanup script
# Removes generated files and directories from development environments
#

_TRILLIAX_SCRIPT="${BASH_SOURCE[0]:-$0}"
_TRILLIAX_DIR="$(cd "$(dirname "${_TRILLIAX_SCRIPT}")" && pwd)"
# Shared helpers. Top-level source so both direct runs and bats sourcing get them.
# shellcheck source=../lib/repo.sh
source "${_TRILLIAX_DIR}/../lib/repo.sh"

ENABLED_TARGETS=()
ALL_TARGETS=(cursor python node fs)
DEFAULT_MAX_DEPTH=10

# Display usage information
#
# Side Effects:
# - Writes usage text to stdout
#
# Returns:
# - 0 always
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
  DRY_RUN     Enable dry-run mode
  MAX_DEPTH   Maximum find depth, default ${DEFAULT_MAX_DEPTH}

CLEANUP OPERATIONS:
  - .cursor directories (recursively)
  - Python files (virtual environments, cache files, compiled files)
  - Node.js files (node_modules, npm cache directories, debug logs)
  - Empty directories (recursively removes all empty directories up to ${DEFAULT_MAX_DEPTH} levels deep)

EXAMPLES:
  $(basename "$0") --all                    # Clean all targets in current directory
  $(basename "$0") --all /path/to/project   # Clean all targets in specific directory
  $(basename "$0") --targets cursor,python  # Clean selected targets
  $(basename "$0") --dry-run --all          # Show what would be cleaned
  $(basename "$0") --help                   # Show this help

EOF

	return 0
}

# Validate and parse target selection
#
# Inputs:
# - $1, targets_string, comma-separated target names
# - $2, all_flag, true when --all was requested
#
# Side Effects:
# - Sets ENABLED_TARGETS
#
# Returns:
# - 0 when targets are valid
# - 1 when no targets are specified or a target name is invalid
validate_targets() {
	local targets_string="$1"
	local all_flag="${2:-false}"
	local available
	available="$(
		IFS=,
		echo "${ALL_TARGETS[*]}"
	)"

	ENABLED_TARGETS=()

	if [[ "${all_flag}" == "true" ]]; then
		ENABLED_TARGETS=("${ALL_TARGETS[@]}")
		return 0
	fi

	if [[ -z "${targets_string}" ]]; then
		echo "validate_targets:: No targets specified. Use --targets to specify targets or --all to clean all." >&2
		return 1
	fi

	local requested_targets
	IFS=',' read -ra requested_targets <<<"${targets_string}"

	local target
	for target in "${requested_targets[@]}"; do
		target="${target#"${target%%[![:space:]]*}"}"
		target="${target%"${target##*[![:space:]]}"}"
		local matched=false
		local known
		for known in "${ALL_TARGETS[@]}"; do
			if [[ "${target}" == "${known}" ]]; then
				ENABLED_TARGETS+=("${target}")
				matched=true
				break
			fi
		done

		if [[ "${matched}" != true ]]; then
			echo "validate_targets:: Invalid target '${target}'. Available targets: ${available}" >&2
			return 1
		fi
	done

	return 0
}

# Walk find matches once for dry-run or live removal
#
# Inputs:
# - $1, function_name, name of calling function for logging
# - $2, target_dir, directory to clean
# - $3+, find_args, find command arguments
#
# Reads environment:
# - DRY_RUN, MAX_DEPTH
#
# Side Effects:
# - Removes matching items, or prints them in dry-run mode
#
# Returns:
# - 0 on success
# - 1 when arguments are invalid, find fails, or a removal fails
execute_clean() {
	local function_name="$1"
	local target_dir="$2"
	shift 2
	local find_args=("$@")

	if [[ -z "${function_name}" ]]; then
		echo "execute_clean:: function_name is required" >&2
		return 1
	fi

	if [[ -z "${target_dir}" ]]; then
		echo "${function_name}:: target_dir is required" >&2
		return 1
	fi

	if ((${#find_args[@]} == 0)); then
		echo "${function_name}:: find_args are required" >&2
		return 1
	fi

	local target_dir_abs
	if ! target_dir_abs="$(absolute_dir_of "${target_dir}" 2>/dev/null)"; then
		echo "${function_name}:: Invalid target_dir: ${target_dir}" >&2
		return 1
	fi

	local max_depth="${MAX_DEPTH:-${DEFAULT_MAX_DEPTH}}"
	if [[ ! "${max_depth}" =~ ^[0-9]+$ ]]; then
		echo "${function_name}:: MAX_DEPTH must be an integer" >&2
		return 1
	fi

	local list_file
	list_file="$(mktemp "${TMPDIR:-/tmp}/trilliax-find.XXXXXX")" || {
		echo "${function_name}:: Failed to create find listing file" >&2
		return 1
	}

	if ! find "${target_dir_abs}" -maxdepth "${max_depth}" "${find_args[@]}" -print0 >"${list_file}"; then
		rm -f "${list_file}"
		echo "${function_name}:: find failed in ${target_dir_abs}" >&2
		return 1
	fi

	local errors=0
	local item
	while IFS= read -r -d '' item; do
		# find also reports the root itself when it matches the expression
		if [[ "${item}" == "${target_dir_abs}" ]]; then
			continue
		fi

		# Never remove anything outside the target tree
		if [[ "${item}" != "${target_dir_abs}/"* ]]; then
			continue
		fi

		if [[ "${DRY_RUN:-}" == "true" ]]; then
			echo "${function_name}:: Would remove: ${item}"
			continue
		fi

		if ! rm -rf "${item}"; then
			echo "${function_name}:: Failed to remove: ${item}" >&2
			errors=$((errors + 1))
		fi
	done <"${list_file}"

	rm -f "${list_file}"
	((errors == 0)) || return 1

	return 0
}

# Return whether a directory would be empty after listed child removals
#
# Inputs:
# - $1 dir, directory to inspect
# - $2 removed_list, newline-separated absolute paths already marked for removal
#
# Returns:
# - 0 when every direct child is listed in removed_list or the directory has none
# - 1 when at least one child would remain
_trilliax_dir_empty_after_removals() {
	local dir="$1"
	local removed_list="$2"
	local child
	while IFS= read -r -d '' child; do
		if ! grep -Fxq "${child}" "${removed_list}"; then
			return 1
		fi
	done < <(find "${dir}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

	return 0
}

# Clean filesystem of empty directories
#
# Inputs:
# - $1, target_dir, directory to clean filesystem from
#
# Side Effects:
# - Removes empty directories
# - In dry-run mode, shows what would be removed without removing
#
# Returns:
# - 0 on success
# - 1 when find or rmdir fails
clean_fs() {
	local target_dir="$1"

	echo "clean_fs:: Cleaning empty directories."

	local max_depth="${MAX_DEPTH:-${DEFAULT_MAX_DEPTH}}"
	if [[ ! "${max_depth}" =~ ^[0-9]+$ ]]; then
		echo "clean_fs:: MAX_DEPTH must be an integer" >&2
		return 1
	fi

	if [[ "${DRY_RUN:-}" == "true" ]]; then
		local dir_list
		dir_list="$(mktemp "${TMPDIR:-/tmp}/trilliax-fs-dirs.XXXXXX")" || {
			echo "clean_fs:: Failed to create directory listing file" >&2
			return 1
		}

		local removed_list
		removed_list="$(mktemp "${TMPDIR:-/tmp}/trilliax-fs-removed.XXXXXX")" || {
			rm -f "${dir_list}"
			echo "clean_fs:: Failed to create removal listing file" >&2
			return 1
		}

		if ! find "${target_dir}" -mindepth 1 -maxdepth "${max_depth}" -depth -type d -print0 >"${dir_list}"; then
			rm -f "${dir_list}" "${removed_list}"
			echo "clean_fs:: find failed in ${target_dir}" >&2
			return 1
		fi

		local dir
		while IFS= read -r -d '' dir; do
			if _trilliax_dir_empty_after_removals "${dir}" "${removed_list}"; then
				echo "clean_fs:: Would remove: ${dir}"
				printf '%s\n' "${dir}" >>"${removed_list}"
			fi
		done <"${dir_list}"

		rm -f "${dir_list}" "${removed_list}"
		return 0
	fi

	find "${target_dir}" -mindepth 1 -maxdepth "${max_depth}" -depth -type d -empty -exec rmdir {} \; || return 1

	return 0
}

# Clean .cursor directories recursively
#
# Inputs:
# - $1, target_dir, directory to clean .cursor directories from
#
# Side Effects:
# - Removes .cursor directories and their contents
#
# Returns:
# - 0 on success
# - 1 when execute_clean fails
clean_cursor() {
	local target_dir="$1"

	echo "clean_cursor:: Cleaning .cursor directories."

	execute_clean "clean_cursor" "${target_dir}" -type d -name ".cursor" || return 1

	return 0
}

# Clean Python files and directories
#
# Inputs:
# - $1, target_dir, directory to clean Python files from
#
# Side Effects:
# - Removes venv and .venv directories, cache files, and compiled files
#
# Returns:
# - 0 on success
# - 1 when execute_clean fails
clean_python() {
	local target_dir="$1"

	echo "clean_python:: Cleaning Python files."

	execute_clean "clean_python" "${target_dir}" \
		\( \
		-type d -name "venv" \
		-o -type d -name ".venv" \
		-o -type d -name "__pycache__" \
		-o -name "*.pyc" \
		-o -name "*.pyo" \
		\) || return 1

	return 0
}

# Clean Node.js files and directories
#
# Inputs:
# - $1, target_dir, directory to clean Node.js files from
#
# Side Effects:
# - Removes node_modules directories, npm cache directories, and debug logs
#
# Returns:
# - 0 on success
# - 1 when execute_clean fails
clean_node() {
	local target_dir="$1"

	echo "clean_node:: Cleaning Node.js files."

	execute_clean "clean_node" "${target_dir}" \
		\( \
		-type d -name "node_modules" \
		-o -type d -name ".npm" \
		-o -name "npm-debug.log*" \
		-o -name "yarn-debug.log*" \
		-o -name "yarn-error.log*" \
		\) || return 1

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
#
# Returns:
# - 0 on success
# - 1 on error
run_trilliax() {
	local target_dir="."
	local targets_string=""
	local all_flag="false"
	while (($# > 0)); do
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
			if [[ "${1}" == -* ]]; then
				echo "run_trilliax:: Unknown option '${1}'" >&2
				echo "run_trilliax:: Use '$(basename "$0") --help' for usage information" >&2
				return 1
			fi

			target_dir="${1}"
			shift
			;;
		esac
	done

	if [[ ! -d "${target_dir}" ]]; then
		echo "run_trilliax:: Directory '${target_dir}' does not exist" >&2
		return 1
	fi

	validate_targets "${targets_string}" "${all_flag}" || return 1

	DRY_RUN="${DRY_RUN:-false}"
	export DRY_RUN

	echo "run_trilliax:: Apologies for the mess master, I shall tidy up immediately."

	MAX_DEPTH="${MAX_DEPTH:-${DEFAULT_MAX_DEPTH}}"
	export MAX_DEPTH

	target_dir="$(absolute_dir_of "${target_dir}")" || return 1
	echo "run_trilliax:: Cleaning directory: ${target_dir}"

	echo "run_trilliax:: Filthy, filthy, FILTHY!"
	# ENABLED_TARGETS is validated against ALL_TARGETS, which maps 1:1 to clean_*.
	local errors=0
	local target
	for target in "${ENABLED_TARGETS[@]}"; do
		"clean_${target}" "${target_dir}" || errors=$((errors + 1))
	done

	echo "run_trilliax:: Please don't say such things! The master is back, and things need to be kept tidy."
	((errors == 0)) || return 1

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	run_trilliax "$@"
	exit $?
fi
