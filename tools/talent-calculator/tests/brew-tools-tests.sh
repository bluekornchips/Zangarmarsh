#!/usr/bin/env bats
#
# Test file for brew-tools.sh
# Tests the brew tools installation functions
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT_DIR="$GIT_ROOT/tools/talent-calculator"
TALENT_CALC_SCRIPT="$SCRIPT_DIR/talent-calculator.sh"
BREW_TOOLS_SCRIPT="$SCRIPT_DIR/tools/brew-tools.sh"
[[ ! -f "$TALENT_CALC_SCRIPT" ]] && echo "setup:: Main script not found: $TALENT_CALC_SCRIPT" >&2 && exit 1
[[ ! -f "$BREW_TOOLS_SCRIPT" ]] && echo "setup:: Brew tools script not found: $BREW_TOOLS_SCRIPT" >&2 && exit 1

source "$TALENT_CALC_SCRIPT"
source "$BREW_TOOLS_SCRIPT"

# Export functions for run subshell
export -f install_with_brew
export -f uninstall_with_brew
export -f install_brew_package
export -f check_is_installed

setup_file() {
	return 0
}

setup() {
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

########################################################
# install_with_brew
########################################################
@test "install_with_brew:: calls brew install with package name" {
	mock_brew_success

	run install_with_brew "jq"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Installing jq"
}

@test "install_with_brew:: dry-run shows what would be installed" {
	DRY_RUN="true"

	run install_with_brew "stern"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would install: brew install stern"
}

@test "install_with_brew:: fails when package_name is empty" {
	run install_with_brew ""
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install_with_brew:: package_name is required"
}

########################################################
# uninstall_with_brew
########################################################
@test "uninstall_with_brew:: dry-run shows what would be uninstalled" {
	DRY_RUN="true"

	run uninstall_with_brew "jq"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would uninstall jq"
}

@test "uninstall_with_brew:: returns 0 for empty package_name" {
	run uninstall_with_brew ""
	[[ "$status" -eq 0 ]]
}

########################################################
# install_brew_package
########################################################
@test "install_brew_package:: returns 0 when cmd_name is empty" {
	run install_brew_package ""
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "install_brew_package:: cmd_name is required"
}

@test "install_brew_package:: skips when command is already installed" {
	run install_brew_package "bash"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "bash is already installed"
}

@test "install_brew_package:: uses cmd_name as package_name by default" {
	mock_command_not_installed "testtool"
	DRY_RUN="true"

	run install_brew_package "testtool"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would install: brew install testtool"
}

@test "install_brew_package:: uses --package flag for custom package_name" {
	mock_command_not_installed "k9s"
	DRY_RUN="true"

	run install_brew_package "k9s" --package "derailed/k9s/k9s"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would install: brew install derailed/k9s/k9s"
}

@test "install_brew_package:: calls uninstall on respec" {
	mock_brew_success
	TALENT_MODE="respec"
	DRY_RUN="true"

	run install_brew_package "stern"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Reset requested for stern"
}
