#!/usr/bin/env bash
#
# Platform detection and configuration for Zsh
# Detects macOS, Linux, and WSL environments

# Detect platform
detect_platform() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		echo "macos"
	elif [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
		echo "wsl"
	else
		echo "linux"
	fi
}

# Set platform variable
export PLATFORM="${PLATFORM:-$(detect_platform)}"

# Platform-specific configurations
case "$PLATFORM" in
macos)
	# macOS specific settings
	export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

	# Homebrew completion
	if command -v brew >/dev/null 2>&1; then
		FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
		autoload -Uz compinit
		compinit -u
	fi
	;;
linux)
	# Linux specific settings
	export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
	;;
wsl)
	# WSL specific settings
	export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

	# WSL-specific aliases and functions
	alias explorer="explorer.exe"
	alias code="code.exe"
	;;
esac

# Debug output if verbose mode is enabled
[[ "$ZANGARMARSH_VERBOSE" == "true" ]] && echo "Platform detected: $PLATFORM" >&2
