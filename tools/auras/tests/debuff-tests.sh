#!/usr/bin/env bats
#
# Tests for debuff.sh removal functions and debuff CLI mode
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"

	SCRIPT="${ZANGARMARSH_ROOT}/tools/auras/auras.sh"
	[[ -f "${SCRIPT}" ]] || {
		echo "setup_file:: Script not found: ${SCRIPT}" >&2
		return 1
	}
	export SCRIPT

	return 0
}

setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	source "${SCRIPT}"
	source "${ZANGARMARSH_ROOT}/tools/auras/buff.sh"
	source "${ZANGARMARSH_ROOT}/tools/auras/debuff.sh"
	auras_home_setup

	return 0
}

teardown() {
	auras_home_teardown

	return 0
}

teardown_file() {
	return 0
}

########################################################
# debuff_appimage
########################################################
@test "debuff_appimage:: removes an Auras-managed desktop file" {
	make_managed_desktop "demoapp"

	run debuff_appimage "demoapp"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
}

@test "debuff_appimage:: removes matching managed bin symlink" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"
	make_managed_desktop "demoapp" "${appimage}"
	make_managed_bin_link "demoapp" "${appimage}"

	run debuff_appimage "demoapp"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ ! -e "${HOME}/.local/bin/demoapp" ]]
}

@test "debuff_appimage:: fails when bin symlink target does not match desktop Exec" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"
	make_managed_desktop "demoapp" "${appimage}"
	make_managed_bin_link "demoapp" "/tmp/other.AppImage"

	run debuff_appimage "demoapp"
	[[ "$status" -eq 1 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ -L "${HOME}/.local/bin/demoapp" ]]
	grep -q "remove_application_bin_link:: refusing to remove bin symlink" <<<"$output"
}

@test "debuff_appimage:: refuses to remove unmanaged desktop file" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/demoapp.desktop"

	run debuff_appimage "demoapp"
	[[ "$status" -eq 1 ]]

	grep -q "debuff_appimage:: refusing to remove unmanaged desktop file" <<<"$output"
}

@test "debuff_appimage:: fails when desktop file is missing" {
	mkdir -p "${HOME}/.local/share/applications"

	run debuff_appimage "missing"
	[[ "$status" -eq 1 ]]

	grep -q "debuff_appimage:: no desktop file" <<<"$output"
}

########################################################
# main
########################################################
@test "main:: debuff rejects --appimage" {
	run bash "$SCRIPT" --debuff demoapp --appimage /tmp/x.AppImage
	[[ "$status" -eq 1 ]]

	grep -q "main:: --appimage is only valid with --buff" <<<"$output"
}

@test "main:: debuff mode removes managed desktop entry and bin symlink" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"
	make_managed_desktop "demoapp" "${appimage}"
	make_managed_bin_link "demoapp" "${appimage}"

	run bash "$SCRIPT" --debuff demoapp
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ ! -e "${HOME}/.local/bin/demoapp" ]]
}
