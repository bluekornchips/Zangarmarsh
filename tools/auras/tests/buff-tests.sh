#!/usr/bin/env bats
#
# Tests for buff.sh install path functions and buff CLI mode
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

setup_appimage_fixture() {
	local stem="${1:-demoapp}"
	local relative="${2:-false}"

	APPIMAGE_APPDIR="${AURAS_TEST_HOME}/apps"
	make_appimage "${APPIMAGE_APPDIR}" "${stem}.AppImage"
	APPIMAGE_PATH="${APPIMAGE_APPDIR}/${stem}.AppImage"

	if [[ "${relative}" == "true" ]]; then
		APPIMAGE_ARG="apps/${stem}.AppImage"
		APPIMAGE_EXPECTED="${APPIMAGE_PATH}"
	else
		APPIMAGE_ARG="${APPIMAGE_PATH}"
		APPIMAGE_EXPECTED="${APPIMAGE_PATH}"
	fi

	export APPIMAGE_APPDIR APPIMAGE_PATH APPIMAGE_ARG APPIMAGE_EXPECTED
}

########################################################
# ensure_desktop_entry_writable
########################################################
@test "ensure_desktop_entry_writable:: refuses unmanaged existing desktop file" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/demoapp.desktop"

	run ensure_desktop_entry_writable "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file" <<<"$output"
}

########################################################
# write_application_desktop
########################################################
@test "write_application_desktop:: writes managed desktop entry with expected fields" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	grep -q '^Name=demoapp$' "${HOME}/.local/share/applications/demoapp.desktop"
	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
	grep -q '^Terminal=false$' "${HOME}/.local/share/applications/demoapp.desktop"
	grep -q '^X-Auras-Managed=true$' "${HOME}/.local/share/applications/demoapp.desktop"
	grep -q '^X-Auras-Version=1$' "${HOME}/.local/share/applications/demoapp.desktop"
}

@test "write_application_desktop:: rejects relative AppImage path" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="apps/demoapp.AppImage"

	cd "${AURAS_TEST_HOME}"

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: AppImage path must be absolute" <<<"$output"
}

@test "write_application_desktop:: overwrites existing Auras-managed desktop file" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"
	make_managed_desktop "demoapp"

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
}

@test "write_application_desktop:: refuses to overwrite unmanaged desktop file" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/demoapp.desktop"

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file" <<<"$output"
}

@test "write_application_desktop:: rejects stem containing slash" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"

	run write_application_desktop "evil/name" "${appimage}" "Label"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: name must be one segment without slashes" <<<"$output"
}

########################################################
# bin_link_dir
########################################################
@test "bin_link_dir:: echoes bin path under HOME" {

	run bin_link_dir
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${HOME}/.local/bin" ]]
}

########################################################
# write_application_bin_link
########################################################
@test "write_application_bin_link:: creates symlink to AppImage" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"

	run write_application_bin_link "demoapp" "${appimage}"
	[[ "$status" -eq 0 ]]

	[[ -L "${HOME}/.local/bin/demoapp" ]]
	[[ "$(readlink -f "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]
}

@test "write_application_bin_link:: refuses unmanaged existing regular file" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"
	mkdir -p "${HOME}/.local/bin"
	: >"${HOME}/.local/bin/demoapp"

	run write_application_bin_link "demoapp" "${appimage}"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_bin_link_writable:: refusing to overwrite unmanaged bin path" <<<"$output"
}

########################################################
# buff_launcher
########################################################
@test "buff_launcher:: writes desktop entry and bin symlink" {
	setup_appimage_fixture "demoapp"

	run buff_launcher "demoapp" "${APPIMAGE_EXPECTED}"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${APPIMAGE_EXPECTED}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$(readlink -f "${HOME}/.local/bin/demoapp")" == "${APPIMAGE_EXPECTED}" ]]
}

@test "buff_launcher:: writes from relative AppImage path" {
	setup_appimage_fixture "demoapp" true

	cd "${AURAS_TEST_HOME}"

	run buff_launcher "demoapp" "${APPIMAGE_EXPECTED}"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${APPIMAGE_EXPECTED}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$(readlink -f "${HOME}/.local/bin/demoapp")" == "${APPIMAGE_EXPECTED}" ]]
}

@test "buff_launcher:: rolls back desktop when bin link fails" {
	setup_appimage_fixture "demoapp"
	mkdir -p "${HOME}/.local/bin"
	chmod 555 "${HOME}/.local/bin"

	run buff_launcher "demoapp" "${APPIMAGE_EXPECTED}"
	chmod 755 "${HOME}/.local/bin"
	[[ "$status" -eq 1 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	grep -q "buff_launcher:: failed to write bin link" <<<"$output"
}

########################################################
# main
########################################################
@test "main:: buff mode requires name" {
	run bash "$SCRIPT" --buff
	[[ "$status" -eq 1 ]]

	grep -q "main:: --buff requires NAME" <<<"$output"
}

@test "main:: buff mode requires --appimage" {
	run bash "$SCRIPT" --buff demoapp
	[[ "$status" -eq 1 ]]

	grep -q "main:: --buff requires --appimage PATH" <<<"$output"
}

@test "main:: rejects legacy positional buff form" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"

	run bash "$SCRIPT" --buff "${appimage}" demoapp
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}

@test "main:: buff accepts flags in any order" {
	local appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "demoapp.AppImage"
	local appimage="${appdir}/demoapp.AppImage"

	run bash "$SCRIPT" --appimage "${appimage}" --buff demoapp
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ "$(readlink -f "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]
}
