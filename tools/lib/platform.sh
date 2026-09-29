#!/usr/bin/env bash
#
# Shared platform detection for Zangarmarsh profile helpers and tools
#
# Canonical platform ids use uname style names such as darwin-arm64.
# PLATFORM_OS is the profile family: macos or linux.
#

# Detect OS and architecture as a canonical id
#
# Outputs:
# - Prints platform id such as darwin-arm64 or linux-amd64
#
# Returns:
# - 0 on success
# - 1 when OS or arch cannot be mapped
_detect_platform() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local arch
	arch="$(uname -m)"

	case "${arch}" in
	x86_64 | amd64)
		arch="amd64"
		;;
	aarch64 | arm64)
		arch="arm64"
		;;
	*)
		echo "_detect_platform:: Unsupported architecture: ${arch}" >&2
		return 1
		;;
	esac

	case "${os}" in
	darwin | linux)
		echo "${os}-${arch}"
		return 0
		;;
	*)
		echo "_detect_platform:: Unsupported OS: ${os}" >&2
		return 1
		;;
	esac
}

# Map a platform identifier to macos or linux
#
# Inputs:
# - $1 platform_id, canonical id such as darwin-arm64 or linux-amd64
#
# Outputs:
# - Prints macos or linux
#
# Returns:
# - 0 when the id is recognized
# - 1 when the id cannot be mapped
platform_os_from_id() {
	local platform_id="${1:-}"

	if [[ -z "${platform_id}" ]]; then
		echo "platform_os_from_id:: platform id is required" >&2
		return 1
	fi

	case "${platform_id}" in
	darwin*)
		echo "macos"
		return 0
		;;
	linux*)
		echo "linux"
		return 0
		;;
	*)
		echo "platform_os_from_id:: Unsupported platform id: ${platform_id}" >&2
		return 1
		;;
	esac
}

# Export PLATFORM and PLATFORM_OS for the current host
#
# Reads environment:
# - PLATFORM, reused when already set
#
# Side Effects:
# - Exports PLATFORM as a canonical id when unset
# - Exports PLATFORM_OS as the macos or linux projection of PLATFORM
#
# Returns:
# - 0 on success
# - 1 when platform detection fails and PLATFORM is unset
apply_platform_env() {
	if [[ -z "${PLATFORM:-}" ]]; then
		PLATFORM="$(_detect_platform)" || return 1
	fi
	export PLATFORM

	PLATFORM_OS="$(platform_os_from_id "${PLATFORM}")" || return 1
	export PLATFORM_OS

	return 0
}
