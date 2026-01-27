#!/usr/bin/env bash
#
# Talent Calculator
# Development tools installation script
# Installs and manages CLI tools for development workstations
#

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077

	cleanup() {
		popd >/dev/null || true
		return 0
	}

	trap cleanup EXIT ERR
fi

CORE_TOOLS=(
	"jq"                               # https://jqlang.org/download/
	"bats --package bats-core"         # https://github.com/bats-core/bats-core#installation
	"kubectl --package kubernetes-cli" # https://kubernetes.io/docs/tasks/tools/
)

BREW_TOOLS=(
	"shfmt"                                              # https://github.com/mvdan/sh
	"aws --package awscli"                               # https://awscli.amazonaws.com/
	"infracost"                                          # https://www.infracost.io/docs/#quick-start
	"k9s --package derailed/k9s/k9s"                     # https://k9scli.io/topics/install/
	"localstack --package localstack/tap/localstack-cli" # https://docs.localstack.cloud/aws/getting-started/installation/
	"minikube"                                           # https://minikube.sigs.k8s.io/docs/start/
	"stern"                                              # https://github.com/stern/stern#installation
	"tfenv"                                              # https://github.com/tfutils/tfenv#installation
)

SCRIPT_TOOLS=(
	"aws-sso-util"
	"bun"
	"helm"
	"docker"
)

ALLOWED_MODES=(
	"check"
	"spec"
	"respec"
)

# Global configuration
DRY_RUN="${DRY_RUN:-false}"
TALENT_MODE="${TALENT_MODE:-check}"

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

OPTIONS:
  -h, --help          Show this help message
  --spec              Install missing tools
  --respec            Remove existing installations before reinstalling
  -r, --dry-run       Show what would be installed without making changes

DESCRIPTION:
  By default, this script checks which tools are installed and which are missing.
  Use --spec to actually install missing tools.

PREREQUISITES:
  curl and brew must be installed before running this script.
  If brew is not installed, this script will attempt to install it.

INSTALLATION ORDER:
  Core tools:
	${CORE_TOOLS[*]}

  Other tools, installed after core:
  ${BREW_TOOLS[*]}

SUPPORTED PLATFORMS:
  - darwin-arm64
  - linux-amd64

EOF

	return 0
}

# Detect the current platform
#
# Outputs:
# - Prints platform identifier: darwin-arm64 or linux-amd64
#
# Returns:
# - 0 on success
# - 1 if platform is unsupported
detect_platform() {
	local os
	local arch
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	arch="$(uname -m)"

	if [[ "${os}" == "darwin" ]] && [[ "${arch}" == "arm64" ]]; then
		echo "darwin-arm64"
		return 0
	fi

	if [[ "${os}" == "linux" ]] && [[ "${arch}" == "x86_64" ]]; then
		echo "linux-amd64"
		return 0
	fi

	echo "detect_platform:: Unsupported platform: ${os}-${arch}" >&2
	echo "detect_platform:: Supported: darwin-arm64, linux-amd64" >&2

	return 1
}

# Check if a command is installed
#
# Inputs:
# - $1, cmd_name, the command to check
#
# Returns:
# - 0 if installed
# - 1 if not installed
check_is_installed() {
	local cmd_name="$1"

	if [[ -z "${cmd_name}" ]]; then
		echo "check_is_installed:: cmd_name is required" >&2
		return 1
	fi

	if command -v "${cmd_name}" >/dev/null 2>&1; then
		return 0
	fi

	return 1
}

# Install Homebrew
#
# https://brew.sh/
#
# Side Effects:
# - Installs Homebrew
#
# Returns:
# - 0 on success
# - 1 on failure
install_brew() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_brew:: Would install Homebrew"
		return 0
	fi

	echo "install_brew:: Installing Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	return 0
}

# Install brew prerequisite
#
# Ensures Homebrew is installed before other tools can be installed.
#
# Returns:
# - 0 on success
# - 1 on failure
install_brew_prerequisite() {
	if check_is_installed "brew"; then
		echo "install_brew_prerequisite:: brew is already installed"
		return 0
	fi

	echo "install_brew_prerequisite:: Installing: brew"
	if ! install_brew; then
		echo "install_brew_prerequisite:: Failed to install brew" >&2
		return 1
	fi

	return 0
}

# Extract command name from tool specification
#
# Inputs:
# - $@, tool_spec, tool specification (e.g., "jq" or "kubectl --package kubernetes-cli")
#
# Outputs:
# - Prints command name
#
# Returns:
# - 0 on success
# - 1 on failure
extract_cmd_name() {
	local cmd_name=""

	# Parse tool specification to extract command name
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--package)
			shift 2
			;;
		*)
			if [[ -z "${cmd_name}" ]]; then
				cmd_name="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "${cmd_name}" ]]; then
		return 1
	fi

	echo "${cmd_name}"
	return 0
}

# Check status of a single tool
#
# Inputs:
# - $1, cmd_name, command name to check
#
# Outputs:
# - Prints status line to stdout
#
# Returns:
# - 0 if installed
# - 1 if missing
check_tool_status() {
	local cmd_name="$1"

	if [[ -z "${cmd_name}" ]]; then
		echo "check_tool_status:: cmd_name is required" >&2
		return 1
	fi

	if check_is_installed "${cmd_name}"; then
		echo "check_tools_status:: [OK] ${cmd_name}"
		return 0
	else
		echo "check_tools_status:: [MISSING] ${cmd_name}"
		return 1
	fi
}

# Check status of all tools
#
# Checks which tools are installed and which are missing.
#
# Returns:
# - 0 if all tools are installed
# - 1 if any tools are missing
check_tools_status() {
	local installed_count=0
	local missing_count=0
	local missing_tools=()
	local cmd_name=""
	local tool=""

	echo "check_tools_status:: Checking tool installation status"

	# Check core tools
	echo "check_tools_status:: Core tools:"
	for tool in "${CORE_TOOLS[@]}"; do
		cmd_name=$(extract_cmd_name ${tool})
		if check_tool_status "${cmd_name}"; then
			((installed_count++)) || true
		else
			((missing_count++)) || true
			missing_tools+=("${cmd_name}")
		fi
	done

	# Check brew tools
	echo "check_tools_status:: Brew tools:"
	for tool in "${BREW_TOOLS[@]}"; do
		cmd_name=$(extract_cmd_name ${tool})
		if check_tool_status "${cmd_name}"; then
			((installed_count++)) || true
		else
			((missing_count++)) || true
			missing_tools+=("${cmd_name}")
		fi
	done

	# Check other tools
	echo "check_tools_status:: Other tools:"
	for cmd_name in "${SCRIPT_TOOLS[@]}"; do
		if check_tool_status "${cmd_name}"; then
			((installed_count++)) || true
		else
			((missing_count++)) || true
			missing_tools+=("${cmd_name}")
		fi
	done

	echo "check_tools_status:: Summary: ${installed_count} installed, ${missing_count} missing"

	if [[ ${missing_count} -gt 0 ]]; then
		echo "check_tools_status:: Missing tools: ${missing_tools[*]}"
		echo "check_tools_status:: Run with --spec to install missing tools"

		return 1
	fi

	return 0
}

# Install core tools
#
# Core tools are essential development tools:
# - jq (JSON processor)
# - bats-core (Bash Automated Testing System)
# - kubectl (Kubernetes command-line tool)
#
# Returns:
# - 0 always
install_core_tools() {
	for tool in "${CORE_TOOLS[@]}"; do
		install_brew_package ${tool}
	done

	return 0
}

run_talent_calculator() {
	local dry_run="false"
	local talent_mode="check"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		-r | --dry-run)
			dry_run="true"
			shift
			;;
		--respec)
			talent_mode="respec"
			shift
			;;
		--spec)
			talent_mode="spec"
			shift
			;;
		*)
			echo "run_talent_calculator:: Unknown option '$1'" >&2
			echo "run_talent_calculator:: Use '$(basename "$0") --help' for usage information" >&2
			return 1
			;;
		esac
	done

	DRY_RUN="${dry_run}"
	TALENT_MODE="${talent_mode}"

	export DRY_RUN
	export TALENT_MODE

	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	source "${SCRIPT_DIR}/tools/brew-tools.sh"
	source "${SCRIPT_DIR}/tools/other-tools.sh"

	# Change to HOME directory
	pushd "${HOME}" >/dev/null || {
		echo "run_talent_calculator:: Failed to change to HOME directory" >&2
		return 1
	}

	# Default behavior: check status only
	if [[ "${TALENT_MODE}" == "check" ]]; then
		check_tools_status
		return $?
	fi

	# Installation mode
	echo "run_talent_calculator:: Starting tool installation"

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "run_talent_calculator:: Dry-run mode enabled"
	fi

	if [[ "${TALENT_MODE}" == "respec" ]]; then
		echo "run_talent_calculator:: Respec mode enabled"
	fi

	# Check curl is installed
	if ! check_is_installed "curl"; then
		echo "run_talent_calculator:: curl is required but not installed" >&2
		echo "run_talent_calculator:: Install curl manually before running this script" >&2
		return 1
	fi

	# Install brew prerequisite
	if ! install_brew_prerequisite; then
		echo "run_talent_calculator:: brew is required but failed to install" >&2
		return 1
	fi

	if ! install_core_tools; then
		return 1
	fi

	if ! install_other_tools; then
		return 1
	fi

	for tool in "${BREW_TOOLS[@]}"; do
		install_brew_package ${tool}
	done

	echo "run_talent_calculator:: Installation complete"

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	run_talent_calculator "$@"
	exit $?
fi
