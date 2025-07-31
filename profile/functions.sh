#!/bin/bash

nvm() {
	# Set up NVM environment
	export NVM_DIR="$HOME/.nvm"
	nvm_script=""

	# Determine NVM script location based on platform
	case "$PLATFORM" in
	macos)
		nvm_script="/opt/homebrew/opt/nvm/nvm.sh"
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
	# shellcheck disable=SC1090
	if ! source "$nvm_script" 2>/dev/null; then
		echo "Failed to source NVM script" >&2
		return 0
	fi

	# Source bash completion if available
	if [[ -s "$NVM_DIR/bash_completion" ]]; then
		# shellcheck disable=SC1091
		\. "$NVM_DIR/bash_completion" 2>/dev/null || true
	fi

	# Execute nvm with any passed arguments
	if command -v nvm >/dev/null 2>&1; then
		nvm "$@"
	else
		echo "NVM command not available after sourcing" >&2
		return 0
	fi
}

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
		return 0
	fi

	# Show Python version info
	echo "Using Python: $python_version ($(command -v "$python_version"))"
	echo "Version: $("$python_version" --version 2>/dev/null || echo "Version info unavailable")"

	# If venv exists and no force recreate, just activate it
	if [[ -d "$env_name" && "$force_recreate" != true ]]; then
		echo "Virtual environment exists, activating: $env_name"
		# shellcheck disable=SC1091
		if source "$env_name/bin/activate" >/dev/null 2>&1; then
			echo "Activated existing environment: $env_name"
			return 0
		fi
	fi

	# Clean up existing environment if it exists
	if [[ -d "$env_name" ]]; then
		echo "Removing existing virtual environment: $env_name"
		rm -rf "$env_name" 2>/dev/null || {
			echo "Failed to remove existing environment" >&2
			return 0
		}
	fi

	# Clean up cache files
	echo "Cleaning up cache files."
	CACHE_FILES=(
		"__pycache__"
		"*.pyc"
		".mypy_cache"
		".pytest_cache"
	)
	for cache_file in "${CACHE_FILES[@]}"; do
		find . -type d -name "$cache_file" -exec rm -rf {} + 2>/dev/null 2>&1 || true
	done

	# Create virtual environment
	echo "Creating virtual environment with $python_version: $env_name"
	if ! "$python_version" -m venv "$env_name" 2>/dev/null; then
		echo "Failed to create virtual environment" >&2
		echo "Make sure $python_version has venv module installed" >&2
		echo "Try: $python_version -m pip install --user virtualenv" >&2
		return 0
	fi

	# Activate virtual environment
	# shellcheck disable=SC1091
	if ! source "$env_name/bin/activate" >/dev/null 2>&1; then
		echo "Failed to activate virtual environment" >&2
		return 1
	fi

	local dependency_installed=false

	if [[ -f "pyproject.toml" ]]; then
		echo "Found pyproject.toml - installing with pip."
		if pip install -e ".[dev]" 2>/dev/null || pip install -e . 2>/dev/null; then
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

	cat <<EOF

========================================
Virtual environment setup complete!
Python version: $(python --version 2>/dev/null || echo "Version info unavailable")
Pip version: $(pip --version 2>/dev/null || echo "Pip not available")
Environment: $PWD/$env_name
========================================

EOF
}
