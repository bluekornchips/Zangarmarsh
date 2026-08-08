#!/usr/bin/env bats
#
# Test file for other-tools.sh
# Tests the other tools installation functions
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
	command() {
		if [[ "$1" == "-v" ]] && [[ "$2" == "${cmd_name}" ]]; then
			return 1
		fi
		builtin command "$@"
	}
	export -f command
}

mock_all_other_tools_installed() {
	check_is_installed() {
		[[ -n "$1" ]] || return 1
		return 0
	}
	export -f check_is_installed
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
	echo "$output" | grep -q "Would install aws-sso-util with pipx"
}

@test "install_aws_sso_util:: fails when pipx is missing" {
	mock_command_not_installed "pipx"

	run install_aws_sso_util
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "pipx is required"
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
}
