#!/usr/bin/env bats
#
# Test file for other-tools.sh
# Tests the other tools installation functions
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT_DIR="$GIT_ROOT/tools/talent-calculator"
MAIN_SCRIPT="$SCRIPT_DIR/talent-calculator.sh"
BREW_TOOLS="$SCRIPT_DIR/tools/brew-tools.sh"
OTHER_TOOLS="$SCRIPT_DIR/tools/other-tools.sh"
[[ ! -f "$MAIN_SCRIPT" ]] && echo "setup:: Main script not found: $MAIN_SCRIPT" >&2 && exit 1
[[ ! -f "$OTHER_TOOLS" ]] && echo "setup:: Other tools script not found: $OTHER_TOOLS" >&2 && exit 1

source "${SCRIPT_DIR}/tests/fixtures.sh"

setup_file() {
	return 0
}

setup() {
	set +e
	trap - EXIT ERR
	source "$MAIN_SCRIPT"
	source "$BREW_TOOLS"
	source "$OTHER_TOOLS"
	trap - EXIT ERR
	set +e

	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/other-tools-test.XXXXXX")"
	export TEST_DIR

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
# install_with_curl
########################################################
@test "install_with_curl:: fails when tool_name is empty" {
	run install_with_curl "" "https://example.com"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install_with_curl:: tool_name is required"
}

@test "install_with_curl:: fails when url is empty" {
	run install_with_curl "test-tool" ""
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "install_with_curl:: url is required"
}

@test "install_with_curl:: dry-run shows what would be downloaded" {
	DRY_RUN="true"

	run install_with_curl "kubectl" "https://example.com/kubectl"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would download kubectl"
}

########################################################
# install_aws_sso_util
########################################################
@test "install_aws_sso_util:: dry-run shows what would be installed" {
	DRY_RUN="true"

	run install_aws_sso_util
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would install pipx and aws-sso-util"
}

@test "install_aws_sso_util:: installs pipx first" {
	DRY_RUN="true"
	mock_brew_success

	run install_aws_sso_util
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "pipx"
}

########################################################
# install_bun
########################################################
@test "install_bun:: dry-run shows what would be installed" {
	DRY_RUN="true"

	run install_bun
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would run Bun install script"
}

@test "install_bun:: returns 0 on success" {
	DRY_RUN="true"
	mock_curl_success

	run install_bun
	[[ "$status" -eq 0 ]]
}

########################################################
# install_helm
########################################################
@test "install_helm:: dry-run shows what would be installed" {
	DRY_RUN="true"

	run install_helm
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would download and run Helm install script"
}

@test "install_helm:: returns 0 on success" {
	DRY_RUN="true"
	mock_curl_success

	run install_helm
	[[ "$status" -eq 0 ]]
}

########################################################
# install_other_tools
########################################################
@test "install_other_tools:: installs all other tools in order" {
	mock_command_not_installed "aws-sso-util"
	mock_command_not_installed "bun"
	mock_command_not_installed "helm"
	DRY_RUN="true"

	run install_other_tools
	[[ "$status" -eq 0 ]]

	# Verify tools are processed
	echo "$output" | grep -q "aws-sso-util"
	echo "$output" | grep -q "bun"
	echo "$output" | grep -q "helm"
}

@test "install_other_tools:: installs aws-sso-util" {
	mock_command_not_installed "aws-sso-util"
	DRY_RUN="true"

	run install_other_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "aws-sso-util"
}

@test "install_other_tools:: installs bun" {
	mock_command_not_installed "bun"
	DRY_RUN="true"

	run install_other_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "bun"
}

@test "install_other_tools:: installs helm" {
	mock_command_not_installed "helm"
	DRY_RUN="true"

	run install_other_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "helm"
}

@test "install_other_tools:: skips already installed tools" {
	mock_all_other_tools_installed
	DRY_RUN="true"

	run install_other_tools
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "aws-sso-util is already installed"
	echo "$output" | grep -q "bun is already installed"
	echo "$output" | grep -q "helm is already installed"
	echo "$output" | grep -q "docker with colima is already installed and running"
}
