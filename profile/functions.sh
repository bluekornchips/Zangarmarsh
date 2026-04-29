#!/usr/bin/env bash

# Load NVM environment when first called (lazy load).
#
# Inputs:
# - None (uses PLATFORM, HOMEBREW_PREFIX, NVM_DIR from environment)
#
# Side Effects:
# - Exports NVM_DIR, sources nvm.sh and optional bash_completion
#
# Returns:
# - 0 on success
# - 1 if NVM script not found or source fails
_nvm_load() {
	# Set up NVM environment
	export NVM_DIR="$HOME/.nvm"
	local nvm_script=""

	# Determine NVM script location based on platform
	case "$PLATFORM" in
	macos)
		# Try Homebrew installation first, then default location
		if [[ -n "$HOMEBREW_PREFIX" && -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
			nvm_script="$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
		else
			nvm_script="$NVM_DIR/nvm.sh"
		fi
		;;
	linux | wsl)
		nvm_script="$NVM_DIR/nvm.sh"
		;;
	*)
		nvm_script="$NVM_DIR/nvm.sh"
		;;
	esac

	# Check if NVM script exists
	if [[ -z "$nvm_script" ]] || [[ ! -s "$nvm_script" ]]; then
		echo "NVM not found at $nvm_script" >&2
		echo "Install NVM from: https://github.com/nvm-sh/nvm" >&2
		return 1
	fi

	# Source NVM
	if ! source "$nvm_script" 2>/dev/null; then
		echo "Failed to source NVM script" >&2
		return 1
	fi

	# Source bash completion if available
	if [[ -s "$NVM_DIR/bash_completion" ]]; then

		\. "$NVM_DIR/bash_completion" 2>/dev/null || true
	fi

	# NVM is now loaded globally, no need to call it again
}

# Install Python dependencies from project files
#
# Inputs:
# - None (reads from current directory)
#
# Side Effects:
# - Installs dependencies using pip if pyproject.toml or requirements.txt found
# - Sets dependency_installed flag
#
# Returns:
# - 0 if dependencies installed or no dependency files found
# - 1 if installation fails
_penv_install_dependencies() {
	local dependency_installed=false
	local install_failed=false

	if [[ -f "pyproject.toml" ]]; then
		echo "Found pyproject.toml. Installing with pip."
		if pip install -e ".[dev]" 2>/dev/null; then
			dependency_installed=true
		elif pip install -e . 2>/dev/null; then
			dependency_installed=true
		else
			echo "pip install failed, you may need to install dependencies manually" >&2
			install_failed=true
		fi
	elif [[ -f "requirements.txt" ]]; then
		echo "Found requirements.txt. Installing dependencies."
		if pip install -r requirements.txt 2>/dev/null; then
			dependency_installed=true
		else
			echo "Failed to install requirements.txt dependencies" >&2
			install_failed=true
		fi
	fi

	if [[ "$dependency_installed" != true ]] && [[ "$install_failed" != true ]]; then
		echo "No dependency files found (pyproject.toml, requirements.txt)"
	fi

	[[ "$install_failed" == true ]] && return 1

	return 0
}

# Run git worktree from the git root
#
# Encapsulates git worktree so it always runs relative to the repository root,
# regardless of the current working directory. When the first argument is not
# add or remove, creates a sibling worktree with a branch of the same name.
#
# Inputs:
# - $1: optional new branch and folder name, or add or remove
# - $2: optional base branch for shortcut creation
# - $@: arguments passed to git worktree when using add or remove
#
# Side Effects:
# - Invokes git worktree in the repository root
# - Creates a sibling worktree when using the shortcut form
#
# Returns:
# - 0 on success
# - 1 if not in a git repository or git worktree fails
gw() {
	local git_root
	local worktree_name
	local base_branch
	local worktree_path

	git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [[ -z "${git_root}" ]]; then
		echo "gw:: not in a git repository" >&2
		return 1
	fi

	case "${1:-}" in
	add | remove)
		# Don't capture output, allow uninterrupted flow
		git -C "${git_root}" worktree "$@"
		return $?
		;;
	esac

	if [[ -z "${1:-}" ]]; then
		echo "gw:: name is required unless using add or remove" >&2
		return 1
	fi

	if (($# > 2)); then
		echo "gw:: shortcut accepts at most two arguments: name and base branch" >&2
		return 1
	fi

	worktree_name="$1"
	base_branch="${2:-}"

	if [[ -z "${base_branch}" ]]; then
		base_branch="$(git -C "${git_root}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
	fi

	if [[ -z "${base_branch}" ]]; then
		base_branch="$(git -C "${git_root}" symbolic-ref --quiet --short HEAD 2>/dev/null)"
	fi

	if [[ -z "${base_branch}" ]]; then
		echo "gw:: unable to determine default base branch" >&2
		return 1
	fi

	worktree_path="${git_root}/../${worktree_name}"

	git -C "${git_root}" worktree add -b "${worktree_name}" "${worktree_path}" "${base_branch}"

	return $?
}

# Create or activate a Python virtual environment in the current directory
#
# Inputs:
# - [-d|--delete]: force recreate the environment
# - [python_version]: Python interpreter to use (default: python3)
#
# Side Effects:
# - Creates/activates .venv in the current directory
# - Removes existing .venv if -d is passed
# - Cleans __pycache__, .mypy_cache, .pytest_cache, and .pyc files
# - Installs dependencies from pyproject.toml or requirements.txt if present
#
# Returns:
# - 0 on success
# - 1 on failure (bad args, missing Python, venv creation/activation failure)
penv() {
	local env_name=".venv"
	local python_version="python3"
	local force_recreate=false

	# Handle flags and Python version specification
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-d | --delete)
			force_recreate=true
			shift
			;;
		-h | --help)
			cat <<EOF
Usage: penv [-d] [python_version]
Options:
	-d, --delete    Force recreate environment
	-h, --help      Show this help
Examples:
	penv                 # Create/activate with default Python
	penv python3.11     # Use specific Python version
	penv -d              # Force recreate
EOF
			return 0
			;;
		python[0-9].[0-9]*)
			python_version="$1"
			shift
			;;
		*)
			echo "Unknown option '$1'" >&2
			echo "Use 'penv --help' for usage information" >&2
			return 1
			;;
		esac
	done

	# Validate Python version
	if ! command -v "$python_version" >/dev/null 2>&1; then
		echo "$python_version not found" >&2
		echo "Available Python versions:" >&2
		find /usr/bin -maxdepth 1 -name "python*" -type f 2>/dev/null | head -5 || echo "No Python versions found in /usr/bin" >&2
		[[ "$PLATFORM" == "macos" ]] && echo "Try installing Python via Homebrew: brew install python" >&2
		return 1
	fi

	# Show Python version info
	echo "Using Python: $python_version ($(command -v "$python_version"))"
	echo "Version: $("$python_version" --version 2>/dev/null || echo "Version info unavailable")"

	# If venv exists and no force recreate, just activate it
	if [[ -d "$env_name" && "$force_recreate" != true ]]; then
		echo "Virtual environment exists, activating: $env_name"

		if source "$env_name/bin/activate" >/dev/null 2>&1; then
			echo "Activated existing environment: $env_name"
			return 0
		fi
	fi

	# Clean up existing environment if it exists
	# Explicit path validation: ensure we're only removing .venv in current directory
	if [[ -d "$env_name" ]] && [[ "$(realpath "$env_name" 2>/dev/null || echo "$env_name")" == "$(realpath "$(pwd)/$env_name" 2>/dev/null || echo "$(pwd)/$env_name")" ]]; then
		echo "Removing existing virtual environment: $env_name"
		rm -rf "$env_name" 2>/dev/null || {
			echo "Failed to remove existing environment" >&2
			return 1
		}
	fi

	# Clean up cache files
	# Explicit path validation: only clean cache files in current directory tree
	echo "Cleaning up cache files."
	local current_dir
	current_dir="$(pwd)"
	if [[ -z "${current_dir}" ]] || [[ ! -d "${current_dir}" ]]; then
		echo "penv:: Invalid current directory" >&2
		return 1
	fi

	local cache_dirs
	cache_dirs=(
		"__pycache__"
		".mypy_cache"
		".pytest_cache"
	)

	local cache_files
	cache_files=("*.pyc")
	for cache_dir in "${cache_dirs[@]}"; do
		find "${current_dir}" -maxdepth 10 -type d -name "${cache_dir}" -exec rm -rf {} + 2>/dev/null || true
	done

	for cache_file in "${cache_files[@]}"; do
		find "${current_dir}" -maxdepth 10 -type f -name "${cache_file}" -exec rm -f {} + 2>/dev/null || true
	done

	# Create virtual environment
	echo "Creating virtual environment with $python_version: $env_name"
	if ! "$python_version" -m venv "$env_name" 2>/dev/null; then
		echo "Failed to create virtual environment" >&2
		echo "Make sure $python_version has venv module installed" >&2
		echo "Try: $python_version -m pip install --user virtualenv" >&2
		return 1
	fi

	# Activate virtual environment
	if ! source "$env_name/bin/activate" >/dev/null 2>&1; then
		echo "Failed to activate virtual environment" >&2
		return 1
	fi

	# Install dependencies if project files are present
	_penv_install_dependencies

	cat <<EOF

========================================
Virtual environment setup complete!
Python version: $(python --version 2>/dev/null || echo "Version info unavailable")
Pip version: $(pip --version 2>/dev/null || echo "Pip not available")
Environment: $PWD/$env_name
========================================

EOF
}

# Set up lazy loading for expensive operations (using configuration)
if [[ "${ZANGARMARSH_LAZY_LOADING:-true}" == "true" ]] && [[ "${ZANGARMARSH_ENABLE_NVM:-true}" == "true" ]]; then
	# Create lazy-loaded nvm function that will load the real NVM when first called
	nvm() {
		unset -f nvm
		_nvm_load
		if command -v nvm >/dev/null 2>&1; then
			nvm "$@"
		else
			echo "NVM command not available after loading" >&2
			return 1
		fi
	}
elif [[ "${ZANGARMARSH_ENABLE_NVM:-true}" == "true" ]]; then
	# Load NVM immediately if lazy loading is disabled but NVM is enabled
	_nvm_load
fi

# List changed files between origin_branch and HEAD (added, copied, modified, renamed).
#
# Inputs:
# - origin_branch: branch or ref to compare against (required positional argument)
#
# Side Effects:
# - Reads git state from current repository
#
# Outputs:
# - Full paths of changed files, one per line, to stdout
#
# Returns:
# - 0 on success
# - 1 if origin_branch missing, not in a git repo, or unknown option
list_changed_files() {
	local origin_branch
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-*)
			echo "list_changed_files:: unknown option $1" >&2
			return 1
			;;
		*)
			[[ -z "${origin_branch}" ]] && origin_branch="$1"
			shift
			;;
		esac
	done

	if [[ -z "${origin_branch}" ]]; then
		echo "list_changed_files:: origin_branch is required" >&2
		return 1
	fi

	local git_root
	git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [[ -z "${git_root}" ]]; then
		echo "list_changed_files:: not in a git repository" >&2
		return 1
	fi

	local to_format=()
	local f
	while IFS= read -r f; do
		[[ -n "${f}" ]] && [[ -f "${git_root}/${f}" ]] && to_format+=("${git_root}/${f}")
	done < <(git -C "${git_root}" diff "${origin_branch}" --name-only --diff-filter=ACMR 2>/dev/null)

	printf '%s\n' "${to_format[@]}"

	return 0
}

# Run a command with integration tests enabled
#
# Inputs:
# - $@: command and arguments to execute
#
# Side Effects:
# - Sets RUN_INTEGRATION_TESTS=true in a subshell before executing the command
#
# Returns:
# - Exit code of the executed command
runint() {
	(
		RUN_INTEGRATION_TESTS="true"
		export RUN_INTEGRATION_TESTS
		"$@"
	)
}
