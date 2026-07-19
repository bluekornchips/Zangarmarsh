#!/usr/bin/env bash
#
# Platform detection and configuration for Zsh
# Detects macOS and Linux environments

# Detect platform with architecture
#
# Purpose:
# - Detects the operating system platform and architecture
# - Returns platform identifier in format: os_arch (e.g., macos_arm64, linux_x86_64)
#
# Inputs:
# - None (uses OSTYPE and uname)
#
# Side Effects:
# - None (pure function)
#
# Returns:
# - 0 on success
# - Outputs platform string to stdout (e.g., "macos_arm64", "linux_x86_64")
detect_platform() {
	local os_type
	local arch

	if [[ "${OSTYPE}" == "darwin"* ]]; then
		os_type="macos"
	else
		os_type="linux"
	fi
	arch=$(uname -m)
	echo "${os_type}_${arch}"
}

export PLATFORM="${PLATFORM:-$(detect_platform)}"

# OS family for profile helpers that expect macos or linux
case "${PLATFORM}" in
macos*)
	export PLATFORM_OS="${PLATFORM_OS:-macos}"
	;;
*)
	export PLATFORM_OS="${PLATFORM_OS:-linux}"
	;;
esac

case "${PLATFORM}" in
macos_*)
	if [[ -d "/opt/homebrew" ]]; then
		export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"
		export HOMEBREW_PREFIX="/opt/homebrew"
	elif [[ -d "/usr/local/Homebrew" ]] || [[ -d "/usr/local/bin/brew" ]]; then
		export PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
		export HOMEBREW_PREFIX="/usr/local"
	fi

	if command -v brew >/dev/null 2>&1; then
		brew_prefix="$(brew --prefix 2>/dev/null)"
		if [[ -n "${brew_prefix}" && -d "${brew_prefix}/share/zsh/site-functions" ]]; then
			FPATH="${brew_prefix}/share/zsh/site-functions:${FPATH}"
			autoload -Uz compinit
			compinit -u
		fi
	fi

	if command -v gls >/dev/null 2>&1; then
		alias ls='gls --color=auto'
	fi
	;;
linux_*)
	export PATH="/usr/local/bin:/usr/local/sbin:${PATH}"

	if [[ -x /usr/bin/dircolors ]]; then
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
	fi
	;;
esac

[[ "${ZANGARMARSH_VERBOSE}" == "true" ]] && echo "Platform detected: ${PLATFORM}" >&2
