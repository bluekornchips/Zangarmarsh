#!/usr/bin/env bash
#
# Platform detection and configuration for Zsh
# Detects macOS, Linux, and WSL environments

# Detect platform with architecture
detect_platform() {
	local os_type="unknown"
	local arch

	if [[ "$OSTYPE" == "darwin"* ]]; then
		os_type="macos"
		arch=$(uname -m)
		echo "${os_type}_${arch}"
	elif [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
		os_type="wsl"
		arch=$(uname -m)
		echo "${os_type}_${arch}"
	else
		os_type="linux"
		arch=$(uname -m)
		echo "${os_type}_${arch}"
	fi
}

# Set platform variable
export PLATFORM="${PLATFORM:-$(detect_platform)}"

# Platform-specific configurations
case "$PLATFORM" in
macos_*)
	# macOS specific settings - support both Apple Silicon and Intel
	if [[ -d "/opt/homebrew" ]]; then
		# Apple Silicon Mac
		export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
		export HOMEBREW_PREFIX="/opt/homebrew"
	elif [[ -d "/usr/local/Homebrew" ]] || [[ -d "/usr/local/bin/brew" ]]; then
		# Intel Mac
		export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
		export HOMEBREW_PREFIX="/usr/local"
	fi

	# Homebrew completion with enhanced detection
	if command -v brew >/dev/null 2>&1; then
		brew_prefix="$(brew --prefix 2>/dev/null)"
		if [[ -n "$brew_prefix" && -d "$brew_prefix/share/zsh/site-functions" ]]; then
			FPATH="$brew_prefix/share/zsh/site-functions:${FPATH}"
			autoload -Uz compinit
			compinit -u
		fi
	fi

	# macOS-specific tools
	if command -v gls >/dev/null 2>&1; then
		alias ls='gls --color=auto'
	fi
	;;
linux_*)
	# Linux specific settings
	export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

	# Enable color support for ls
	if [[ -x /usr/bin/dircolors ]]; then
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
	fi
	;;
wsl_*)
	# WSL specific settings
	export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

	# WSL-specific aliases and functions
	alias explorer="explorer.exe"
	alias code="code.exe"

	# Enable color support
	if [[ -x /usr/bin/dircolors ]]; then
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
	fi

	# WSL2 networking improvements
	if command -v wslview >/dev/null 2>&1; then
		alias open="wslview"
	fi
	;;
esac

# Debug output if verbose mode is enabled
[[ "$ZANGARMARSH_VERBOSE" == "true" ]] && echo "Platform detected: $PLATFORM" >&2
