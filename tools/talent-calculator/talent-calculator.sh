#!/usr/bin/env bash
#
# Talent Calculator
# Development tools installation script
# Installs and manages CLI tools for development workstations
#

_TC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_TC_DIR}/../lib/platform.sh"

CORE_TOOLS=(
	"jq"      # https://jqlang.org/download/
	"yq"      # https://github.com/mikefarah/yq
	"bats"    # https://github.com/bats-core/bats-core#installation
	"kubectl" # https://kubernetes.io/docs/tasks/tools/
)

EXTRA_TOOLS=(
	"shfmt"      # https://github.com/mvdan/sh
	"aws"        # https://awscli.amazonaws.com/
	"infracost"  # https://www.infracost.io/docs/#quick-start
	"k9s"        # https://k9scli.io/topics/install/
	"localstack" # https://docs.localstack.cloud/aws/getting-started/installation/
	"minikube"   # https://minikube.sigs.k8s.io/docs/start/
	"stern"      # https://github.com/stern/stern#installation
	"tfenv"      # https://github.com/tfutils/tfenv#installation
	"docker"     # https://docs.docker.com/engine/install/
)

SCRIPT_TOOLS=(
	"aws-sso-util"
	"bun"
	"helm"
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
  --health-check      Validate curl availability
  --spec              Install missing script-managed tools
  --respec            Reinstall script-managed tools
  -r, --dry-run       Show what would be installed without making changes

DESCRIPTION:
  By default, this script checks which tools are installed and which are missing.
  Use --spec to install script-managed tools. Core and extra tools are checked
  only; install those with your OS package manager when missing.

PREREQUISITES:
  curl must be installed before running this script.

INSTALLATION ORDER:
  Core tools, checked only:
	${CORE_TOOLS[*]}

  Extra tools, checked only:
	${EXTRA_TOOLS[*]}

  Script-managed tools, installed after checks:
	${SCRIPT_TOOLS[*]}

SUPPORTED PLATFORMS:
  - darwin-arm64
  - linux-amd64

EOF

	return 0
}

# Detect the current platform
#
# Uses _detect_platform from tools/lib/platform.sh, then restricts to
# platforms this installer supports.
#
# Outputs:
# - Prints platform identifier: darwin-arm64 or linux-amd64
#
# Returns:
# - 0 on success
# - 1 if platform is unsupported
detect_platform() {
	local platform
	local os
	local arch

	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	arch="$(uname -m)"

	platform="$(_detect_platform)" || {
		echo "detect_platform:: Unsupported platform: ${os}-${arch}" >&2
		echo "detect_platform:: Supported: darwin-arm64, linux-amd64" >&2
		return 1
	}

	case "${platform}" in
	darwin-arm64 | linux-amd64)
		echo "${platform}"
		return 0
		;;
	*)
		echo "detect_platform:: Unsupported platform: ${platform}" >&2
		echo "detect_platform:: Supported: darwin-arm64, linux-amd64" >&2
		return 1
		;;
	esac
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
	echo "check_tools_status:: Checking tool installation status"

	local installed_count=0
	local missing_count=0
	local missing_tools=()

	echo "check_tools_status:: Core tools:"
	local cmd_name
	for cmd_name in "${CORE_TOOLS[@]}"; do
		if check_tool_status "${cmd_name}"; then
			((installed_count++)) || true
		else
			((missing_count++)) || true
			missing_tools+=("${cmd_name}")
		fi
	done

	echo "check_tools_status:: Extra tools:"
	for cmd_name in "${EXTRA_TOOLS[@]}"; do
		if check_tool_status "${cmd_name}"; then
			((installed_count++)) || true
		else
			((missing_count++)) || true
			missing_tools+=("${cmd_name}")
		fi
	done

	echo "check_tools_status:: Script tools:"
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
		echo "check_tools_status:: Run with --spec to install script-managed tools"
		return 1
	fi

	return 0
}

# Report package-managed tools that are missing
#
# Side Effects:
# - Prints install hints for missing core and extra tools
#
# Returns:
# - 0 always
report_missing_package_tools() {
	local cmd_name

	for cmd_name in "${CORE_TOOLS[@]}" "${EXTRA_TOOLS[@]}"; do
		if ! check_is_installed "${cmd_name}"; then
			echo "report_missing_package_tools:: ${cmd_name} is missing"
			echo "report_missing_package_tools:: Install ${cmd_name} with your OS package manager"
		fi
	done

	return 0
}

# Validate prerequisites without installing tools
#
# Returns:
# - 0 when curl is available
# - 1 when a required dependency is missing
health_check() {
	local errors=0

	if ! command -v curl >/dev/null 2>&1; then
		echo "health_check:: curl is not installed" >&2
		errors=$((errors + 1))
	fi

	if [[ "${errors}" -eq 0 ]]; then
		echo "health_check:: passed"
		return 0
	fi

	echo "health_check:: failed with ${errors} error(s)" >&2

	return 1
}

run_talent_calculator() {
	# Parse arguments
	local dry_run="false"
	local talent_mode="check"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			return 0
			;;
		--health-check)
			health_check
			return $?
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
			echo "run_talent_calculator:: Unknown option '${1}'" >&2
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

	report_missing_package_tools

	if ! install_other_tools; then
		return 1
	fi

	echo "run_talent_calculator:: Installation complete"
	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077
	run_talent_calculator "$@"
	exit $?
fi
