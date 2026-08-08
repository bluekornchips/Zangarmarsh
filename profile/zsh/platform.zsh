#!/usr/bin/env zsh
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
	if [[ "${OSTYPE}" == "darwin"* ]]; then
		os_type="macos"
	else
		os_type="linux"
	fi

	local arch
	arch=$(uname -m)
	echo "${os_type}_${arch}"
}

PLATFORM="${PLATFORM:-$(detect_platform)}"
export PLATFORM

# OS family for profile helpers that expect macos or linux
case "${PLATFORM}" in
macos*)
	PLATFORM_OS="${PLATFORM_OS:-macos}"
	export PLATFORM_OS
	;;
*)
	PLATFORM_OS="${PLATFORM_OS:-linux}"
	export PLATFORM_OS
	;;
esac

case "${PLATFORM}" in
macos_*)
	PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
	export PATH

	if command -v gls >/dev/null 2>&1; then
		alias ls='gls --color=auto'
	fi
	;;
linux_*)
	PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
	export PATH

	if [[ -x /usr/bin/dircolors ]]; then
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
	fi
	;;
esac

[[ "${ZANGARMARSH_VERBOSE}" == "true" ]] && echo "Platform detected: ${PLATFORM}" >&2
