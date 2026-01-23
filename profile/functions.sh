#!/usr/bin/env bash

# NVM lazy loading function
# Loads NVM environment when first called, then delegates to the real nvm command
_nvm_load() {
	# Set up NVM environment
	export NVM_DIR="$HOME/.nvm"
	nvm_script=""

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
		return 0
	fi

	# Source NVM

	if ! source "$nvm_script" 2>/dev/null; then
		echo "Failed to source NVM script" >&2
		return 0
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

	if [[ -f "pyproject.toml" ]]; then
		echo "Found pyproject.toml - installing with pip."
		if pip install -e ".[dev]" 2>/dev/null; then
			dependency_installed=true
		elif pip install -e . 2>/dev/null; then
			dependency_installed=true
		else
			echo "pip install failed, you may need to install dependencies manually" >&2
		fi
	elif [[ -f "requirements.txt" ]]; then
		echo "Found requirements.txt - installing dependencies."
		if pip install -r requirements.txt 2>/dev/null; then
			dependency_installed=true
		else
			echo "Failed to install requirements.txt dependencies" >&2
		fi
	fi

	if [[ "$dependency_installed" != true ]]; then
		echo "No dependency files found (pyproject.toml, requirements-dev.txt, requirements.txt)"
	fi

	return 0
}

penv() {
	local env_name=".venv"
	local python_version="python3"
	local force_recreate=false

	# Input validation
	if [[ -z "${env_name}" ]]; then
		echo "penv:: env_name is required" >&2
		return 1
	fi

	# Validate env_name is safe (only .venv allowed)
	if [[ "${env_name}" != ".venv" ]]; then
		echo "penv:: Invalid env_name. Only .venv is allowed for security." >&2
		return 1
	fi

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
			return 0
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

	CACHE_FILES=(
		"__pycache__"
		"*.pyc"
		".mypy_cache"
		".pytest_cache"
	)
	for cache_file in "${CACHE_FILES[@]}"; do
		# Use explicit path and validate results before deletion
		find "${current_dir}" -maxdepth 10 -type d -name "$cache_file" -exec rm -rf {} + 2>/dev/null 2>&1 || true
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

# Smart shfmt wrapper that formats shell files recursively
#
# Inputs:
# - Arguments parsed as flags: -v|--verbose, -d|--depth NUM
#
# Side Effects:
# - Modifies .sh files in place with formatting
shfmt_smart() {
	local depth=4
	local verbose=false

	while [[ $# -gt 0 ]]; do
		case $1 in
		-v | --verbose)
			verbose=true
			shift
			;;
		-d | --depth)
			depth="$2"
			shift 2
			;;
		*)
			if [[ "$1" =~ ^[0-9]+$ ]]; then
				depth="$1"
				shift
			else
				echo "Unknown option: $1" >&2
				return 1
			fi
			;;
		esac
	done

	if ! [[ "$depth" =~ ^[0-9]+$ ]] || ((depth < 1)); then
		echo "depth must be a positive integer" >&2
		return 1
	fi

	if ! command -v shfmt >/dev/null 2>&1; then
		echo "shfmt not found. Please install shfmt first" >&2
		echo "This version is preferred: https://github.com/mvdan/sh" >&2
		return 1
	fi

	[[ "$verbose" == true ]] && echo "Searching for .sh files with max depth: $depth"

	local -a files
	# Mapfile is not available in all shells, so we use bash -c to execute the command
	if ! bash -c "mapfile -t files < <(find . -type f -name '*.sh' -maxdepth '$depth' 2>/dev/null)"; then
		echo "shfmt_smart:: Failed to find shell files" >&2
		return 1
	fi

	if [[ ${#files[@]} -eq 0 ]]; then
		echo "No .sh files found within depth $depth"
		return 0
	fi

	echo "Found ${#files[@]} shell files to format"

	local file
	local shfmt_args=(-w)

	[[ "$verbose" == true ]] && shfmt_args+=(-d)

	for file in "${files[@]}"; do
		if [[ -f "$file" ]]; then
			if [[ "$verbose" == true ]]; then
				echo "Formatting: $file"
			fi
			if ! shfmt "${shfmt_args[@]}" "$file"; then
				echo "Failed to format $file" >&2
			fi
		fi
	done

	return 0
}
