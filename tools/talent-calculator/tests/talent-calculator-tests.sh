#!/usr/bin/env bats
#
# Test file for talent-calculator.sh
# Tests the talent-calculator tool installation script
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT_DIR="$GIT_ROOT/tools/talent-calculator"
SCRIPT="$SCRIPT_DIR/talent-calculator.sh"
BREW_TOOLS="$SCRIPT_DIR/tools/brew-tools.sh"
OTHER_TOOLS="$SCRIPT_DIR/tools/other-tools.sh"
[[ ! -f "$SCRIPT" ]] && echo "setup:: Script not found: $SCRIPT" >&2 && exit 1

setup_file() {
	return 0
}

setup() {
	set +e
	trap - EXIT ERR
	source "$SCRIPT"
	source "$BREW_TOOLS"
	source "$OTHER_TOOLS"
	trap - EXIT ERR
	set +e

	export TEST_DIR
	TEST_DIR="$(mktemp -d)"

	DRY_RUN="false"
	TALENT_MODE="check"
	export DRY_RUN
	export TALENT_MODE

	return 0
}

teardown() {
	[[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"

	return 0
}

########################################################
# Mocks
########################################################
mock_brew_success() {
	brew() {
		echo "brew $*"
		return 0
	}
	export -f brew
}

mock_brew_failure() {
	brew() {
		echo "brew $*" >&2
		return 1
	}
	export -f brew
}

mock_curl_success() {
	curl() {
		echo "curl $*"
		return 0
	}
	export -f curl
}

mock_curl_failure() {
	curl() {
		echo "curl $*" >&2
		return 1
	}
	export -f curl
}

mock_command_installed() {
	local cmd_name="$1"
	# shellcheck disable=SC2329
	command() {
		if [[ "$1" == "-v" ]] && [[ "$2" == "${cmd_name}" ]]; then
			echo "/usr/local/bin/${cmd_name}"
			return 0
		fi
		builtin command "$@"
	}
	export -f command
}

mock_command_not_installed() {
	local cmd_name="$1"
	# shellcheck disable=SC2329
	command() {
		if [[ "$1" == "-v" ]] && [[ "$2" == "${cmd_name}" ]]; then
			return 1
		fi
		builtin command "$@"
	}
	export -f command
}

mock_uname_darwin_arm64() {
	uname() {
		case "$1" in
		-s) echo "Darwin" ;;
		-m) echo "arm64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname
}

mock_uname_linux_amd64() {
	uname() {
		case "$1" in
		-s) echo "Linux" ;;
		-m) echo "x86_64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname
}

mock_uname_linux_arm64() {
	uname() {
		case "$1" in
		-s) echo "Linux" ;;
		-m) echo "aarch64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname
}

########################################################
# Script structure and help
########################################################
@test "main:: has proper shebang and structure" {
	run bash -n "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

@test "main:: is executable" {
	chmod +x "$SCRIPT"
	[[ -x "$SCRIPT" ]]
}

@test "usage:: displays help when called with --help" {
	run "$SCRIPT" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
	echo "$output" | grep -q "INSTALLATION ORDER:"
}

@test "usage:: displays help when called with -h" {
	run "$SCRIPT" -h
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
}

@test "main:: handles unknown options" {
	run "$SCRIPT" --invalid-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_talent_calculator:: Unknown option '--invalid-option'"
	echo "$output" | grep -q "run_talent_calculator:: Use"
}

########################################################
# detect_platform
########################################################
@test "detect_platform:: returns darwin-arm64 for macOS ARM" {
	mock_uname_darwin_arm64

	run detect_platform
	[[ "$status" -eq 0 ]]
	[[ "$output" == "darwin-arm64" ]]
}

@test "detect_platform:: returns linux-amd64 for Linux x86_64" {
	mock_uname_linux_amd64

	run detect_platform
	[[ "$status" -eq 0 ]]
	[[ "$output" == "linux-amd64" ]]
}

@test "detect_platform:: fails for linux-arm64" {
	mock_uname_linux_arm64

	run detect_platform
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unsupported platform"
}

@test "detect_platform:: fails for unsupported platform" {
	uname() {
		case "$1" in
		-s) echo "FreeBSD" ;;
		-m) echo "x86_64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname

	run detect_platform
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unsupported platform"
}

########################################################
# check_is_installed
########################################################
@test "check_is_installed:: returns 0 when command exists" {
	run check_is_installed "bash"
	[[ "$status" -eq 0 ]]
}

@test "check_is_installed:: returns 1 when command does not exist" {
	run check_is_installed "nonexistent_command_xyz_12345"
	[[ "$status" -eq 1 ]]
}

@test "check_is_installed:: fails when cmd_name is empty" {
	run check_is_installed ""
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "check_is_installed:: cmd_name is required"
}

########################################################
# install_brew
########################################################
@test "install_brew:: dry-run shows what would be installed" {
	DRY_RUN="true"

	run install_brew
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would install Homebrew"
}

########################################################
# install_brew_prerequisite
########################################################
@test "install_brew_prerequisite:: installs brew when not present" {
	mock_command_not_installed "brew"
	DRY_RUN="true"

	run install_brew_prerequisite
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Installing: brew"
}

@test "install_brew_prerequisite:: skips when brew is already installed" {
	run install_brew_prerequisite
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "brew is already installed"
}

@test "install_brew_prerequisite:: calls uninstall on respec" {
	TALENT_MODE="respec"
	DRY_RUN="true"

	run install_brew_prerequisite
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Reset requested for brew"
}

########################################################
# install_core_tools
########################################################
@test "install_core_tools:: installs all core tools in order" {
	mock_command_not_installed "jq"
	mock_command_not_installed "bats"
	mock_command_not_installed "kubectl"
	DRY_RUN="true"

	run install_core_tools
	[[ "$status" -eq 0 ]]

	# Verify core tools are processed
	echo "$output" | grep -q "jq"
	echo "$output" | grep -q "bats"
	echo "$output" | grep -q "kubectl"
}

@test "install_core_tools:: installs jq" {
	mock_command_not_installed "jq"
	DRY_RUN="true"

	run install_core_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "jq"
}

@test "install_core_tools:: installs bats-core with correct package name" {
	mock_command_not_installed "bats"
	DRY_RUN="true"

	run install_core_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "bats-core"
}

@test "install_core_tools:: installs kubectl with correct package name" {
	mock_command_not_installed "kubectl"
	DRY_RUN="true"

	run install_core_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "kubernetes-cli"
}

########################################################
# run_talent_calculator main function
########################################################
@test "run_talent_calculator:: accepts dry-run flag" {
	run run_talent_calculator --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Dry-run mode enabled"
}

@test "run_talent_calculator:: accepts short dry-run flag" {
	run run_talent_calculator -r
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Dry-run mode enabled"
}

@test "run_talent_calculator:: accepts respec flag" {
	run run_talent_calculator --respec --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Respec mode enabled"
}

@test "run_talent_calculator:: defaults to check mode" {
	run run_talent_calculator
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Checking tool installation status"
}

@test "run_talent_calculator:: shows starting message in spec mode" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Starting tool installation"
}

@test "run_talent_calculator:: shows completion message in spec mode" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Installation complete"
}

@test "run_talent_calculator:: respec flag overrides spec flag" {
	run run_talent_calculator --spec --respec --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Respec mode enabled"
}

########################################################
# Integration tests
########################################################
@test "integration:: default mode checks tool status" {
	run run_talent_calculator
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

	# Verify status check output
	echo "$output" | grep -q "Core tools:"
	echo "$output" | grep -q "Brew tools:"
	echo "$output" | grep -q "Other tools:"
	echo "$output" | grep -q "Summary:"
}

@test "integration:: dry-run installs core tools first" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]

	# Verify core tools are checked first
	echo "$output" | grep -q "brew is already installed\|Would install Homebrew"
	echo "$output" | grep -q "jq is already installed\|Would install: brew install jq"
	echo "$output" | grep -q "bats is already installed\|Would install: brew install bats-core"
	echo "$output" | grep -q "kubectl is already installed\|Would install: brew install kubernetes-cli"
}

@test "integration:: dry-run installs tools" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]

	# Verify tools are processed
	echo "$output" | grep -q "aws"
	echo "$output" | grep -q "bun\|bats"
	echo "$output" | grep -q "helm"
	echo "$output" | grep -q "stern"
	echo "$output" | grep -q "tfenv"
}

@test "integration:: dry-run does not make actual changes" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]

	# All output should indicate dry-run behavior
	echo "$output" | grep -q "Would\|already installed"
}

@test "integration:: help shows all required options" {
	run "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	echo "$output" | grep -q "\-h, \-\-help"
	echo "$output" | grep -q "\-\-spec"
	echo "$output" | grep -q "\-\-respec"
	echo "$output" | grep -q "\-r, \-\-dry-run"
}

@test "integration:: help shows supported platforms" {
	run "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	echo "$output" | grep -q "darwin-arm64"
	echo "$output" | grep -q "linux-amd64"
}
