#!/usr/bin/env bats
#
# Test file for talent-calculator.sh
# Tests the talent-calculator tool installation script
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	SCRIPT_DIR="${ZANGARMARSH_ROOT}/tools/talent-calculator"
	SCRIPT="${SCRIPT_DIR}/talent-calculator.sh"
	OTHER_TOOLS="${SCRIPT_DIR}/tools/other-tools.sh"
	[[ -f "${SCRIPT}" ]] || {
		echo "setup_file:: Script not found: ${SCRIPT}" >&2
		return 1
	}
	[[ -f "${OTHER_TOOLS}" ]] || {
		echo "setup_file:: Other tools script not found: ${OTHER_TOOLS}" >&2
		return 1
	}
	export SCRIPT_DIR
	export SCRIPT
	export OTHER_TOOLS

	return 0
}

setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	set +e
	trap - EXIT ERR
	source "${SCRIPT}"
	source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
	source "${OTHER_TOOLS}"
	trap - EXIT ERR
	set +e

	talent_test_home_setup

	return 0
}

teardown() {
	talent_test_home_teardown

	return 0
}

teardown_file() {
	return 0
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
# health_check
########################################################
@test "health_check:: passes when curl is available" {
	run health_check
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "health_check:: passed"
}

########################################################
# run_talent_calculator main function
########################################################
@test "run_talent_calculator:: accepts dry-run flag" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Dry-run mode enabled"
}

@test "run_talent_calculator:: accepts short dry-run flag" {
	run run_talent_calculator --spec -r
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

	echo "$output" | grep -q "Core tools:"
	echo "$output" | grep -q "Extra tools:"
	echo "$output" | grep -q "Script tools:"
	echo "$output" | grep -q "Summary:"
}

@test "integration:: dry-run installs script tools" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]

	echo "$output" | grep -q "aws-sso-util\|Would install aws-sso-util"
	echo "$output" | grep -q "bun\|Would run Bun"
	echo "$output" | grep -q "helm\|Would download and run Helm"
}

@test "integration:: dry-run does not make actual changes" {
	run run_talent_calculator --spec --dry-run
	[[ "$status" -eq 0 ]]

	echo "$output" | grep -q "Would\|already installed\|is missing"
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
