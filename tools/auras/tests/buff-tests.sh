#!/usr/bin/env bats
#
# Tests for buff.sh install path functions and buff CLI mode
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/tools/auras/auras.sh"
	export SCRIPT

	return 0
}

setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	auras_test_setup

	return 0
}

teardown() {
	auras_home_teardown
	return 0
}

setup_appimage_fixture() {
	local stem="${1:-demoapp}"

	APPIMAGE_APPDIR="${AURAS_TEST_HOME}/apps"
	make_appimage "${APPIMAGE_APPDIR}" "${stem}.AppImage"
	APPIMAGE_PATH="${APPIMAGE_APPDIR}/${stem}.AppImage"
	export APPIMAGE_APPDIR APPIMAGE_PATH
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
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
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
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="apps/demoapp.AppImage"

	cd "${AURAS_TEST_HOME}"

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: AppImage path must be absolute" <<<"$output"
}

@test "write_application_desktop:: overwrites existing Auras-managed desktop file" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"
	if ! make_managed_desktop "demoapp"; then
		return 1
	fi

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
}

@test "write_application_desktop:: refuses to overwrite unmanaged desktop file" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/demoapp.desktop"

	run write_application_desktop "demoapp" "${appimage}" "demoapp"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file" <<<"$output"
}

@test "write_application_desktop:: rejects stem containing slash" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run write_application_desktop "evil/name" "${appimage}" "Label"
	[[ "$status" -eq 1 ]]

	grep -q "desktop_path_for_stem:: name must be one segment without slashes" <<<"$output"
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
# ensure_bin_link_writable + _auras_write_bin_link
########################################################
@test "_auras_write_bin_link:: creates symlink to AppImage after ensure" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"
	local link_path
	link_path="$(bin_link_path "demoapp")"

	run ensure_bin_link_writable "${link_path}" "${appimage}" "demoapp"
	[[ "$status" -eq 0 ]]

	run _auras_write_bin_link "demoapp" "${appimage}"
	[[ "$status" -eq 0 ]]

	[[ -L "${HOME}/.local/bin/demoapp" ]]
	[[ "$(resolve_symlink_path "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]
}

@test "ensure_bin_link_writable:: refuses unmanaged existing regular file" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"
	mkdir -p "${HOME}/.local/bin"
	: >"${HOME}/.local/bin/demoapp"
	local link_path
	link_path="$(bin_link_path "demoapp")"

	run ensure_bin_link_writable "${link_path}" "${appimage}" "demoapp"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_bin_link_writable:: refusing to overwrite unmanaged bin path" <<<"$output"
}

########################################################
# buff_launcher
########################################################
@test "buff_launcher:: writes desktop entry and bin symlink" {
	if ! setup_appimage_fixture "demoapp"; then
		return 1
	fi

	run buff_launcher "demoapp" "${APPIMAGE_PATH}"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${APPIMAGE_PATH}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$(resolve_symlink_path "${HOME}/.local/bin/demoapp")" == "${APPIMAGE_PATH}" ]]
}

@test "buff_main:: resolves a relative AppImage path" {
	if ! setup_appimage_fixture "demoapp"; then
		return 1
	fi

	cd "${AURAS_TEST_HOME}"

	run buff_main "demoapp" "apps/demoapp.AppImage"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${APPIMAGE_PATH}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$(resolve_symlink_path "${HOME}/.local/bin/demoapp")" == "${APPIMAGE_PATH}" ]]
}

@test "buff_launcher:: rolls back desktop when bin link fails" {
	if ! setup_appimage_fixture "demoapp"; then
		return 1
	fi
	mkdir -p "${HOME}/.local/bin"
	chmod 555 "${HOME}/.local/bin"

	run buff_launcher "demoapp" "${APPIMAGE_PATH}"
	chmod 755 "${HOME}/.local/bin"
	[[ "$status" -eq 1 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	grep -q "buff_launcher:: failed to write bin link" <<<"$output"
}

@test "buff_launcher:: does not overwrite unmanaged bin file or write desktop" {
	if ! setup_appimage_fixture "demoapp"; then
		return 1
	fi
	mkdir -p "${HOME}/.local/bin"
	printf 'keep-me\n' >"${HOME}/.local/bin/demoapp"

	run buff_launcher "demoapp" "${APPIMAGE_PATH}"
	[[ "$status" -eq 1 ]]

	[[ "$(cat "${HOME}/.local/bin/demoapp")" == "keep-me" ]]
	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	grep -q "ensure_bin_link_writable:: refusing to overwrite unmanaged bin path" <<<"$output"
}

@test "buff_main:: does not overwrite unmanaged bin file or write desktop" {
	if ! setup_appimage_fixture "demoapp"; then
		return 1
	fi
	mkdir -p "${HOME}/.local/bin"
	printf 'keep-me\n' >"${HOME}/.local/bin/demoapp"

	run buff_main "demoapp" "${APPIMAGE_PATH}"
	[[ "$status" -eq 1 ]]

	[[ "$(cat "${HOME}/.local/bin/demoapp")" == "keep-me" ]]
	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	grep -q "ensure_bin_link_writable:: refusing to overwrite unmanaged bin path" <<<"$output"
}

@test "buff_launcher:: restores existing desktop when bin link write fails" {
	if ! setup_appimage_fixture "demoapp"; then
		return 1
	fi
	if ! make_managed_desktop "demoapp" "/tmp/old.AppImage"; then
		return 1
	fi
	local original
	original="$(cat "${HOME}/.local/share/applications/demoapp.desktop")"

	_auras_write_bin_link() {
		return 1
	}

	run buff_launcher "demoapp" "${APPIMAGE_PATH}"
	[[ "$status" -eq 1 ]]

	[[ "$(cat "${HOME}/.local/share/applications/demoapp.desktop")" == "${original}" ]]
	grep -q "buff_launcher:: failed to write bin link" <<<"$output"
}

@test "buff_main:: AppImage path with a space can be buffed and debuffed" {
	local appdir="${AURAS_TEST_HOME}/my apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run buff_main "demoapp" "${appimage}"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$(resolve_symlink_path "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]

	run debuff_appimage "demoapp"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ ! -e "${HOME}/.local/bin/demoapp" ]]
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
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run bash "$SCRIPT" --buff "${appimage}" demoapp
	[[ "$status" -eq 1 ]]

	grep -q "main:: Unknown option" <<<"$output"
}

@test "main:: buff accepts flags in any order" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run bash "$SCRIPT" --appimage "${appimage}" --buff demoapp
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ "$(resolve_symlink_path "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]
}
