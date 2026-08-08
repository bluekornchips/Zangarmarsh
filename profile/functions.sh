#!/usr/bin/env bash

# Load NVM environment when first called (lazy load).
#
# Inputs:
# - None (uses NVM_DIR from environment)
#
# Side Effects:
# - Exports NVM_DIR, sources nvm.sh and optional bash_completion
#
# Returns:
# - 0 on success
# - 1 if NVM script not found or source fails
_nvm_load() {
	NVM_DIR="${HOME}/.nvm"
	export NVM_DIR
	local nvm_script="${NVM_DIR}/nvm.sh"

	if [[ ! -s "${nvm_script}" ]]; then
		echo "_nvm_load:: NVM not found at ${nvm_script}" >&2
		echo "_nvm_load:: Install NVM from: https://github.com/nvm-sh/nvm" >&2
		return 1
	fi

	if ! source "${nvm_script}" 2>/dev/null; then
		echo "_nvm_load:: Failed to source NVM script" >&2
		return 1
	fi

	if [[ -s "${NVM_DIR}/bash_completion" ]]; then

		\. "${NVM_DIR}/bash_completion" 2>/dev/null || true
	fi
}

# Install Python dependencies from project files
#
# Inputs:
# - None (reads from current directory)
#
# Side Effects:
# - Requires uv when dependency files are present
# - Sets dependency_installed flag
#
# Returns:
# - 0 if dependencies installed or no dependency files found
# - 1 if installation fails
_penv_install_dependencies() {
	local dependency_installed=false
	local install_failed=false

	if [[ -f "pyproject.toml" ]]; then
		if ! command -v uv >/dev/null 2>&1; then
			echo "_penv_install_dependencies:: uv is required for pyproject.toml" >&2
			return 1
		fi

		echo "Found pyproject.toml. Installing with uv."
		if [[ -f "uv.lock" ]]; then
			if uv sync --active --locked 2>/dev/null; then
				dependency_installed=true
			fi
		elif uv sync --active 2>/dev/null; then
			dependency_installed=true
		fi

	fi

	if [[ "${dependency_installed}" != true && -f "pyproject.toml" ]]; then
		install_failed=true
		echo "_penv_install_dependencies:: Dependency installation failed" >&2
	elif [[ "${dependency_installed}" != true ]]; then
		echo "_penv_install_dependencies:: No pyproject.toml found"
	fi

	[[ "${install_failed}" == true ]] && return 1

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
	git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [[ -z "${git_root}" ]]; then
		echo "gw:: not in a git repository" >&2
		return 1
	fi

	case "${1:-}" in
	add | remove)
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

	local worktree_name="${1}"
	local base_branch="${2:-}"

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

	local worktree_path="${git_root}/../${worktree_name}"

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
# - Installs dependencies from pyproject.toml with uv
#
# Returns:
# - 0 on success
# - 1 on failure (bad args, missing Python, venv creation/activation failure)
penv() {
	local python_version="python3"
	local force_recreate=false
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
			python_version="${1}"
			shift
			;;
		*)
			echo "penv:: Unknown option '${1}'" >&2
			echo "penv:: Use 'penv --help' for usage information" >&2
			return 1
			;;
		esac
	done

	if ! command -v "${python_version}" >/dev/null 2>&1; then
		echo "penv:: ${python_version} not found" >&2
		echo "penv:: Available Python versions:" >&2
		local python_candidate
		local python_count=0
		for python_candidate in /usr/bin/python* /usr/local/bin/python* /opt/homebrew/bin/python*; do
			if [[ -x "${python_candidate}" ]]; then
				echo "${python_candidate}" >&2
				python_count=$((python_count + 1))
				[[ "${python_count}" -ge 5 ]] && break
			fi
		done
		[[ "${python_count}" -eq 0 ]] && echo "penv:: No Python versions found in common paths" >&2
		[[ "${PLATFORM_OS:-${PLATFORM}}" == "macos" ]] && echo "penv:: Try installing Python from https://www.python.org/downloads/" >&2
		return 1
	fi

	echo "Using Python: ${python_version} ($(command -v "${python_version}"))"
	echo "Version: $("${python_version}" --version 2>/dev/null || echo "Version info unavailable")"

	local env_name=".venv"
	if [[ -d "${env_name}" && "${force_recreate}" != true ]]; then
		echo "Virtual environment exists, activating: ${env_name}"

		if source "${env_name}/bin/activate" >/dev/null 2>&1; then
			echo "Activated existing environment: ${env_name}"
			return 0
		fi
	fi

	# Explicit path validation: ensure we're only removing .venv in current directory
	if [[ -d "${env_name}" ]]; then
		echo "Removing existing virtual environment: ${env_name}"
		rm -rf "${env_name}" 2>/dev/null || {
			echo "penv:: Failed to remove existing environment" >&2
			return 1
		}
	fi

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
		find "${current_dir}" -type d -name "${cache_dir}" -prune -exec rm -rf {} + 2>/dev/null || true
	done

	for cache_file in "${cache_files[@]}"; do
		find "${current_dir}" -type f -name "${cache_file}" -exec rm -f {} + 2>/dev/null || true
	done

	echo "Creating virtual environment with ${python_version}: ${env_name}"
	if ! "${python_version}" -m venv "${env_name}" 2>/dev/null; then
		echo "penv:: Failed to create virtual environment" >&2
		echo "penv:: Make sure ${python_version} has venv module installed" >&2
		echo "penv:: Install Python with a working venv module, then retry" >&2
		return 1
	fi

	if ! source "${env_name}/bin/activate" >/dev/null 2>&1; then
		echo "penv:: Failed to activate virtual environment" >&2
		return 1
	fi

	_penv_install_dependencies

	cat <<EOF

========================================
Virtual environment setup complete!
Python version: $(python --version 2>/dev/null || echo "Version info unavailable")
Environment: $PWD/$env_name
========================================

EOF
}

# Set up lazy loading for expensive operations (using configuration)
if [[ "${ZANGARMARSH_LAZY_LOADING:-true}" == "true" ]] && [[ "${ZANGARMARSH_ENABLE_NVM:-true}" == "true" ]]; then
	nvm() {
		unset -f nvm
		_nvm_load
		if command -v nvm >/dev/null 2>&1; then
			nvm "$@"
		else
			echo "nvm:: NVM command not available after loading" >&2
			return 1
		fi
	}
elif [[ "${ZANGARMARSH_ENABLE_NVM:-true}" == "true" ]]; then
	_nvm_load
fi
