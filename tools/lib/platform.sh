#!/usr/bin/env bash
#
# Shared platform detection for Zangarmarsh tools
#
# Profile zsh keeps its own detect_platform in profile/zsh/platform.sh
# and uses macos_arm64 style ids. This helper returns darwin-arm64 style
# ids for bash tools such as talent-calculator.
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
