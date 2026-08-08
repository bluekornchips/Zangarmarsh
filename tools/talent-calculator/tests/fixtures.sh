#!/usr/bin/env bash
#
# Shared talent-calculator fixtures for calculator and other-tools tests.
# Source from setup so helpers exist in each Bats test shell.
#

talent_test_home_setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/talent-calculator-test.XXXXXX")"
	DRY_RUN="false"
	TALENT_MODE="check"
	export TEST_DIR
	export DRY_RUN
	export TALENT_MODE

	return 0
}

talent_test_home_teardown() {
	[[ -n "${TEST_DIR:-}" && -d "${TEST_DIR}" ]] && rm -rf "${TEST_DIR}"
	TEST_DIR=""

	return 0
}
