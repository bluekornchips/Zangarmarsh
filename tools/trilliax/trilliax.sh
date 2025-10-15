#!/usr/bin/env bash
#
# Trilliax cleanup script
# Removes generated files and directories from development environments
#
set -euo pipefail

ENABLED_TARGETS=()

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
  -t, --targets      Comma-separated list of targets to clean (cursor,claude,python,node)
  -a, --all          Clean all targets (overrides --targets)
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
# - $2, dry_run, boolean flag for dry-run mode
#
# Side Effects:
# - Removes empty directories
# - In dry-run mode, shows what would be removed without removing
# - Returns 0 on success
clean_fs() {
	local target_dir="$1"
	local dry_run="${2:-false}"

	echo "Cleaning empty directories."

	local dirs_to_remove
	dirs_to_remove=$(find "$target_dir" -depth -type d -empty 2>/dev/null)

	if [[ "$dry_run" == "true" ]]; then
		for dir in $dirs_to_remove; do
			[[ -n "$dir" ]] && echo "Would remove: $dir"
		done

		return 0
	fi

	find "$target_dir" -depth -type d -empty -delete 2>/dev/null || true

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

	local dirs_to_remove=""
	for pattern in "${TARGET_DIRS[@]}"; do
		dirs_to_remove="$dirs_to_remove $(find "$target_dir" -maxdepth 10 -type d -name "$pattern" 2>/dev/null)"
	done

	if [[ "$dry_run" == "true" ]]; then
		for dir in $dirs_to_remove; do
			[[ -n "$dir" ]] && echo "Would remove: $dir"
		done

		return 0
	fi

	for dir in $dirs_to_remove; do
		[[ -n "$dir" ]] && rm -rf "$dir" 2>/dev/null || true
	done

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

	local TARGET_FILES=("CLAUDE.md")

	echo "Cleaning Claude files."

	local files_to_remove=""
	for pattern in "${TARGET_FILES[@]}"; do
		files_to_remove="$files_to_remove $(find "$target_dir" -maxdepth 10 -name "$pattern" -type f 2>/dev/null)"
	done

	if [[ "$dry_run" == "true" ]]; then
		for file in $files_to_remove; do
			[[ -n "$file" ]] && echo "Would remove: $file"
		done

		return 0
	fi

	for file in $files_to_remove; do
		[[ -n "$file" ]] && rm -f "$file" 2>/dev/null || true
	done

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

	local items_to_remove=""
	for pattern in "${TARGET_DIRS[@]}"; do
		items_to_remove="$items_to_remove $(find "$target_dir" -maxdepth 10 -type d -name "$pattern" 2>/dev/null)"
	done
	for pattern in "${TARGET_FILES[@]}"; do
		items_to_remove="$items_to_remove $(find "$target_dir" -maxdepth 10 -name "$pattern" 2>/dev/null)"
	done

	if [[ "$dry_run" == "true" ]]; then
		for item in $items_to_remove; do
			[[ -n "$item" ]] && echo "Would remove: $item"
		done

		return 0
	fi

	for item in $items_to_remove; do
		[[ -n "$item" ]] && rm -rf "$item" 2>/dev/null || true
	done

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

	local items_to_remove=""
	for pattern in "${TARGET_DIRS[@]}"; do
		items_to_remove="$items_to_remove $(find "$target_dir" -maxdepth 10 -type d -name "$pattern" 2>/dev/null)"
	done
	for pattern in "${TARGET_FILES[@]}"; do
		items_to_remove="$items_to_remove $(find "$target_dir" -maxdepth 10 -name "$pattern" 2>/dev/null)"
	done

	if [[ "$dry_run" == "true" ]]; then
		for item in $items_to_remove; do
			[[ -n "$item" ]] && echo "Would remove: $item"
		done

		return 0
	fi

	for item in $items_to_remove; do
		[[ -n "$item" ]] && rm -rf "$item" 2>/dev/null || true
	done

	return 0
}

# Validate and parse target selection
validate_targets() {
	local targets_string="$1"
	local all_flag="${2:-false}"

	if [[ "$all_flag" == "true" ]]; then
		ENABLED_TARGETS=("cursor" "claude" "python" "node")
		return 0
	fi

	if [[ -z "$targets_string" ]]; then
		echo "No targets specified. Use --targets to specify targets or --all to clean all." >&2
		return 1
	fi

	IFS=',' read -ra REQUESTED_TARGETS <<<"$targets_string"
	local enabled_targets=()

	for target in "${REQUESTED_TARGETS[@]}"; do
		target=$(echo "$target" | xargs)
		case "$target" in
		cursor | claude | python | node)
			enabled_targets+=("$target")
			;;
		*)
			echo "Invalid target '$target'. Available targets: cursor,claude,python,node" >&2
			return 1
			;;
		esac
	done

	ENABLED_TARGETS=("${enabled_targets[@]}")
	return 0
}

# Main entry point for the trilliax cleanup script
#
# Inputs:
# - $1, target_dir, optional directory to clean (default: current directory)
# - $2, dry_run, boolean flag for dry-run mode
#
# Side Effects:
# - Performs cleanup operations for selected targets in the specified directory
# - Shows progress messages for each cleanup operation
# - Returns 0 on success, 1 on error
main() {
	echo "=== Entry: ${BASH_SOURCE[0]:-$0} ==="

	echo "Apologies for the mess master, I shall tidy up immediately."

	local target_dir="${1:-.}"
	local dry_run="${2:-false}"

	if [[ ! -d "$target_dir" ]]; then
		echo "Directory '$target_dir' does not exist" >&2
		return 1
	fi

	pushd "$target_dir" >/dev/null
	target_dir="$(pwd)"
	popd >/dev/null
	echo "Cleaning directory: $target_dir"

	if [[ ${#ENABLED_TARGETS[@]} -eq 0 ]]; then
		echo "No targets selected for cleanup." >&2
		return 1
	fi

	echo "Filthy, filthy, FILTHY!"
	local cleanup_count=0
	for target in "${ENABLED_TARGETS[@]}"; do
		case "$target" in
		cursor)
			clean_cursor "$target_dir" "$dry_run"
			cleanup_count=$((cleanup_count + 1))
			;;
		claude)
			clean_claude "$target_dir" "$dry_run"
			cleanup_count=$((cleanup_count + 1))
			;;
		python)
			clean_python "$target_dir" "$dry_run"
			cleanup_count=$((cleanup_count + 1))
			;;
		node)
			clean_node "$target_dir" "$dry_run"
			cleanup_count=$((cleanup_count + 1))
			;;
		esac
	done

	echo "Please don't say such things! The master is back, and things need to be kept tidy."

	echo "=== Exit: ${BASH_SOURCE[0]:-$0} ==="
}

# Execute main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	target_dir="."
	dry_run="${DRY_RUN:-false}"
	targets_string=""
	all_flag="false"

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
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
		-a | --all)
			all_flag="true"
			shift
			;;
		-r | --dry-run)
			if [[ "${DRY_RUN:-}" != "false" ]]; then
				dry_run=true
			fi
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

	# Validate targets
	if ! validate_targets "$targets_string" "$all_flag"; then
		exit 1
	fi

	main "$target_dir" "$dry_run"
fi
