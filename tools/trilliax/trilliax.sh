#!/usr/bin/env bash
#
# Trilliax cleanup script
# Removes generated files and directories from development environments
#
set -eo pipefail

AVAILABLE_TARGETS=("cursor" "claude" "python" "node")

# Display usage information
usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Trilliax cleanup script
Removes generated files and directories from development environments.

ARGUMENTS:
    DIRECTORY    Directory to clean (default: current directory)

OPTIONS:
    -a, --all          Clean all targets (overrides --targets)
    -d, --dir          Directory to clean (default: current directory)
    -t, --targets      Comma-separated list of targets to clean (${AVAILABLE_TARGETS[*]})
    -r, --dry-run      Show what would be cleaned without making changes
    -h, --help         Show this help message

ENVIRONMENT VARIABLES:
    DRY_RUN   Enable dry-run mode

CLEANUP OPERATIONS:
    - .cursor directories (recursively)
    - Claude files (CLAUDE.md and files starting with 'claude')
    - Python files (virtual environments, cache files, compiled files)
    - Node.js files (node_modules, package locks, npm cache)

EXAMPLES:
    $(basename "$0") --all              # Clean all targets in current directory
    $(basename "$0") --targets cursor,python  # Clean specific targets
    $(basename "$0") /path/to/project   # Clean specific directory
    $(basename "$0") --dry-run --all    # Preview cleanup for all targets
    $(basename "$0") --help             # Show this help

EOF
}

# Validate and parse target selection
#
# Inputs:
# - $1, targets_string, comma-separated list of targets to clean
# - $2, all_flag, boolean flag for --all option
#
# Side Effects:
# - Sets global array ENABLED_TARGETS with selected targets
# - Returns 0 on success, 1 on invalid target
validate_targets() {
	local targets_string="$1"
	local all_flag="${2:-false}"

	# If --all flag is set, enable all targets
	if [[ "$all_flag" == "true" ]]; then
		ENABLED_TARGETS=("${AVAILABLE_TARGETS[@]}")
		return 0
	fi

	# If no targets specified, fail
	if [[ -z "$targets_string" ]]; then
		echo "No targets specified. Use --targets to specify targets or --all for all targets" >&2
		return 1
	fi

	IFS=',' read -ra REQUESTED_TARGETS <<<"$targets_string"

	local enabled_targets=()
	for target in "${REQUESTED_TARGETS[@]}"; do
		target=$(echo "$target" | xargs)
		local valid=false
		for available in "${AVAILABLE_TARGETS[@]}"; do
			if [[ "$target" == "$available" ]]; then
				valid=true
				break
			fi
		done
		if [[ "$valid" != "true" ]]; then
			echo "Invalid target '$target'. Available targets: ${AVAILABLE_TARGETS[*]}" >&2
			return 1
		fi
		enabled_targets+=("$target")
	done

	ENABLED_TARGETS=("${enabled_targets[@]}")
	return 0
}

# Clean .cursor directories recursively
#
# Inputs:
# - $1, target_dir, directory to clean .cursor directories from
# - $2, dry_run, boolean flag for dry-run mode
#
# Side Effects:
# - Removes .cursor directories and their contents
# - In dry-run mode, shows what would be removed without removing
# - Returns 0 on success
clean_cursor() {
	local target_dir="$1"
	local dry_run="${2:-false}"

	local TARGET_DIRS=(".cursor")

	echo "Cleaning .cursor directories."
	if [[ "$dry_run" == "true" ]]; then
		for dir_pattern in "${TARGET_DIRS[@]}"; do
			find "$target_dir" -type d -name "$dir_pattern" -exec echo "Would remove: {}" \; 2>/dev/null || true
		done
	else
		for dir_pattern in "${TARGET_DIRS[@]}"; do
			find "$target_dir" -type d -name "$dir_pattern" -exec rm -rf {} + 2>/dev/null || true
		done
	fi

	return 0
}

# Clean Claude-related files
#
# Inputs:
# - $1, target_dir, directory to clean Claude files from
# - $2, dry_run, boolean flag for dry-run mode
#
# Side Effects:
# - Removes CLAUDE.md files and files starting with 'claude'
# - In dry-run mode, shows what would be removed without removing
# - Returns 0 on success
clean_claude() {
	local target_dir="$1"
	local dry_run="${2:-false}"

	local TARGET_FILES=("CLAUDE.md" "claude*")

	echo "Cleaning Claude files."
	if [[ "$dry_run" == "true" ]]; then
		for file_pattern in "${TARGET_FILES[@]}"; do
			if [[ "$file_pattern" == "claude*" ]]; then
				find "$target_dir" -name "$file_pattern" -type f -exec echo "Would remove: {}" \; 2>/dev/null || true
			else
				find "$target_dir" -name "$file_pattern" -exec echo "Would remove: {}" \; 2>/dev/null || true
			fi
		done
	else
		for file_pattern in "${TARGET_FILES[@]}"; do
			if [[ "$file_pattern" == "claude*" ]]; then
				find "$target_dir" -name "$file_pattern" -type f -exec rm -f {} + 2>/dev/null || true
			else
				find "$target_dir" -name "$file_pattern" -exec rm -f {} + 2>/dev/null || true
			fi
		done
	fi

	return 0
}

# Clean Python files and directories
#
# Inputs:
# - $1, target_dir, directory to clean Python files from
# - $2, dry_run, boolean flag for dry-run mode
#
# Side Effects:
# - Removes Python virtual environments, cache files, and compiled files
# - In dry-run mode, shows what would be removed without removing
# - Returns 0 on success
clean_python() {
	local target_dir="$1"
	local dry_run="${2:-false}"

	local TARGET_DIRS=("venv" ".venv" "env" "__pycache__")
	local TARGET_FILES=("*.pyc" "*.pyo")

	echo "Cleaning Python files."
	if [[ "$dry_run" == "true" ]]; then
		# Show directories that would be removed
		for dir_pattern in "${TARGET_DIRS[@]}"; do
			find "$target_dir" -type d -name "$dir_pattern" -exec echo "Would remove: {}" \; 2>/dev/null || true
		done
		# Show files that would be removed
		for file_pattern in "${TARGET_FILES[@]}"; do
			find "$target_dir" -name "$file_pattern" -exec echo "Would remove: {}" \; 2>/dev/null || true
		done
	else

		for dir_pattern in "${TARGET_DIRS[@]}"; do
			find "$target_dir" -type d -name "$dir_pattern" -exec rm -rf {} + 2>/dev/null || true
		done

		for file_pattern in "${TARGET_FILES[@]}"; do
			find "$target_dir" -name "$file_pattern" -exec rm -f {} + 2>/dev/null || true
		done
	fi

	return 0
}

# Clean Node.js files and directories
#
# Inputs:
# - $1, target_dir, directory to clean Node.js files from
# - $2, dry_run, boolean flag for dry-run mode
#
# Side Effects:
# - Removes node_modules directories, package locks, and npm cache
# - In dry-run mode, shows what would be removed without removing
# - Returns 0 on success
clean_node() {
	local target_dir="$1"
	local dry_run="${2:-false}"

	local TARGET_DIRS=("node_modules" ".npm" ".yarn")
	local TARGET_FILES=("package-lock.json" "yarn.lock" ".yarnrc.yml" "npm-debug.log*" "yarn-debug.log*" "yarn-error.log*")

	echo "Cleaning Node.js files."
	if [[ "$dry_run" == "true" ]]; then

		for dir_pattern in "${TARGET_DIRS[@]}"; do
			find "$target_dir" -type d -name "$dir_pattern" -exec echo "Would remove: {}" \; 2>/dev/null || true
		done

		for file_pattern in "${TARGET_FILES[@]}"; do
			find "$target_dir" -name "$file_pattern" -exec echo "Would remove: {}" \; 2>/dev/null || true
		done
	else

		for dir_pattern in "${TARGET_DIRS[@]}"; do
			find "$target_dir" -type d -name "$dir_pattern" -exec rm -rf {} + 2>/dev/null || true
		done

		for file_pattern in "${TARGET_FILES[@]}"; do
			find "$target_dir" -name "$file_pattern" -exec rm -f {} + 2>/dev/null || true
		done
	fi

	return 0
}

# Main entry point for the trilliax cleanup script
#
# Inputs:
# - $1, target_dir, optional directory to clean (default: current directory)
# - $2, dry_run, boolean flag for dry-run mode
# - $3, all_flag, boolean flag for --all option
#
# Side Effects:
# - Performs cleanup operations for selected targets in the specified directory
# - Shows progress messages for each cleanup operation
# - Returns 0 on success, 1 on error
main() {
	echo -e "\n=== Entry: ${BASH_SOURCE[0]:-$0} ===\n"

	# Set target directory (default to current directory)
	local target_dir="${1:-.}"
	local dry_run="${2:-false}"
	local all_flag="${3:-false}"

	# Validate target directory exists
	if [[ ! -d "$target_dir" ]]; then
		echo "Directory '$target_dir' does not exist" >&2
		return 1
	fi

	# Make target directory absolute path
	target_dir="$(cd "$target_dir" && pwd)"

	echo "Cleaning directory: $target_dir"

	# Perform cleanup operations for enabled targets
	local exit_code=0
	local cleanup_count=0

	for target in "${ENABLED_TARGETS[@]}"; do
		case "$target" in
		"cursor")
			if clean_cursor "$target_dir" "$dry_run"; then
				((cleanup_count++))
			else
				echo "Failed to clean .cursor directories" >&2
				exit_code=1
			fi
			;;
		"claude")
			if clean_claude "$target_dir" "$dry_run"; then
				((cleanup_count++))
			else
				echo "Failed to clean Claude files" >&2
				exit_code=1
			fi
			;;
		"python")
			if clean_python "$target_dir" "$dry_run"; then
				((cleanup_count++))
			else
				echo "Failed to clean Python files" >&2
				exit_code=1
			fi
			;;
		"node")
			if clean_node "$target_dir" "$dry_run"; then
				((cleanup_count++))
			else
				echo "Failed to clean Node.js files" >&2
				exit_code=1
			fi
			;;
		esac
	done

	if [[ $cleanup_count -eq 0 ]]; then
		echo "No cleanup operations performed."
	else
		echo "Clean complete. Performed cleanup for $cleanup_count target types."
	fi

	echo -e "\n=== Exit: ${BASH_SOURCE[0]:-$0} ===\n"

	return "$exit_code"
}

# Execute main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	# Set default values
	target_dir="."
	dry_run="${DRY_RUN:-false}"
	targets_string=""
	all_flag="false"

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		-a | --all)
			all_flag="true"
			shift
			;;
		-d | --dir)
			if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
				echo "--dir requires a directory path" >&2
				echo "Use '$(basename "$0") --help' for usage information" >&2
				exit 1
			fi
			target_dir="$2"
			shift 2
			;;
		-t | --targets)
			if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
				echo "--targets requires a comma-separated list of targets" >&2
				echo "Use '$(basename "$0") --help' for usage information" >&2
				exit 1
			fi
			targets_string="$2"
			shift 2
			;;
		-r | --dry-run)
			dry_run="true"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			if [[ -d "$1" ]]; then
				target_dir="$1"
				shift
			else
				echo "Unknown option '$1'" >&2
				echo "Use '$(basename "$0") --help' for usage information" >&2
				exit 1
			fi
			;;
		esac
	done

	if ! validate_targets "$targets_string" "$all_flag"; then
		exit 1
	fi

	main "$target_dir" "$dry_run" "$all_flag"
	exit $?
fi
