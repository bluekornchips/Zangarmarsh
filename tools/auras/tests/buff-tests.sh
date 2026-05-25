#!/usr/bin/env bats
#
# Tests for buff.sh install path functions and buff CLI mode
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
	SCRIPT="$GIT_ROOT/tools/auras/auras.sh"
	[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && return 1

	export GIT_ROOT
	export SCRIPT

	return 0
}

setup() {
	source "$SCRIPT"

	local bats_tmp

	bats_tmp="${BATS_TMPDIR:-/tmp}"
	AURAS_TEST_HOME="$(mktemp -d "${bats_tmp}/auras_test_home.XXXXXX")"
	HOME="${AURAS_TEST_HOME}"

	return 0
}

teardown() {
	[[ -n "${AURAS_TEST_HOME}" && -d "${AURAS_TEST_HOME}" ]] && rm -rf "${AURAS_TEST_HOME}"
	AURAS_TEST_HOME=""
	return 0
}

make_appimage() {
	local parent
	local fname

	parent="$1"
	fname="$2"

	mkdir -p "${parent}"
	: >"${parent}/${fname}"
	chmod +x "${parent}/${fname}"
}

make_managed_desktop() {
	local name
	local exec_path
	local path

	name="$1"
	exec_path="${2:-/tmp/${name}.AppImage}"
	mkdir -p "${HOME}/.local/share/applications"
	path="${HOME}/.local/share/applications/${name}.desktop"
	cat <<EOF >"${path}"
[Desktop Entry]
Type=Application
Name=${name}
Exec="${exec_path}" %u
Terminal=false
X-Auras-Managed=true
X-Auras-Version=${AURAS_DESKTOP_VERSION}
EOF
}

setup_appimage_fixture() {
	local stem
	local relative

	stem="${1:-archon}"
	relative="${2:-false}"

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
	: >"${HOME}/.local/share/applications/archon.desktop"

	run ensure_desktop_entry_writable "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file" <<<"$output"
}

########################################################
# write_application_desktop
########################################################
@test "write_application_desktop:: writes managed desktop entry with expected fields" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run write_application_desktop "archon" "${appimage}" "archon"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/archon.desktop" ]]
	grep -q '^Name=archon$' "${HOME}/.local/share/applications/archon.desktop"
	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/archon.desktop"
	grep -q '^Terminal=false$' "${HOME}/.local/share/applications/archon.desktop"
	grep -q '^X-Auras-Managed=true$' "${HOME}/.local/share/applications/archon.desktop"
	grep -q '^X-Auras-Version=1$' "${HOME}/.local/share/applications/archon.desktop"
}

@test "write_application_desktop:: rejects relative AppImage path" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="apps/archon.AppImage"

	cd "${AURAS_TEST_HOME}"

	run write_application_desktop "archon" "${appimage}" "archon"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: AppImage path must be absolute" <<<"$output"
}

@test "write_application_desktop:: overwrites existing Auras-managed desktop file" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"
	make_managed_desktop "archon"

	run write_application_desktop "archon" "${appimage}" "archon"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/archon.desktop"
}

@test "write_application_desktop:: refuses to overwrite unmanaged desktop file" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/archon.desktop"

	run write_application_desktop "archon" "${appimage}" "archon"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_desktop_entry_writable:: refusing to overwrite unmanaged desktop file" <<<"$output"
}

@test "write_application_desktop:: rejects stem containing slash" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

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
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run write_application_bin_link "archon" "${appimage}"
	[[ "$status" -eq 0 ]]

	[[ -L "${HOME}/.local/bin/archon" ]]
	[[ "$(readlink -f "${HOME}/.local/bin/archon")" == "${appimage}" ]]
}

@test "write_application_bin_link:: refuses unmanaged existing regular file" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"
	mkdir -p "${HOME}/.local/bin"
	: >"${HOME}/.local/bin/archon"

	run write_application_bin_link "archon" "${appimage}"
	[[ "$status" -eq 1 ]]

	grep -q "ensure_bin_link_writable:: refusing to overwrite unmanaged bin path" <<<"$output"
}

########################################################
# buff_launcher
########################################################
@test "buff_launcher:: writes desktop entry and bin symlink" {
	setup_appimage_fixture "archon"

	run buff_launcher "archon" "${APPIMAGE_EXPECTED}"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${APPIMAGE_EXPECTED}\" %u" "${HOME}/.local/share/applications/archon.desktop"
	[[ "$(readlink -f "${HOME}/.local/bin/archon")" == "${APPIMAGE_EXPECTED}" ]]
}

@test "buff_launcher:: writes from relative AppImage path" {
	setup_appimage_fixture "archon" true

	cd "${AURAS_TEST_HOME}"

	run buff_launcher "archon" "${APPIMAGE_EXPECTED}"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${APPIMAGE_EXPECTED}\" %u" "${HOME}/.local/share/applications/archon.desktop"
	[[ "$(readlink -f "${HOME}/.local/bin/archon")" == "${APPIMAGE_EXPECTED}" ]]
}

@test "buff_launcher:: rolls back desktop when bin link fails" {
	setup_appimage_fixture "archon"
	mkdir -p "${HOME}/.local/bin"
	chmod 555 "${HOME}/.local/bin"

	run buff_launcher "archon" "${APPIMAGE_EXPECTED}"
	chmod 755 "${HOME}/.local/bin"
	[[ "$status" -eq 1 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
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
	run bash "$SCRIPT" --buff archon
	[[ "$status" -eq 1 ]]

	grep -q "main:: --buff requires --appimage PATH" <<<"$output"
}

@test "main:: rejects legacy positional buff form" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run bash "$SCRIPT" --buff "${appimage}" archon
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}

@test "main:: buff accepts flags in any order" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run bash "$SCRIPT" --appimage "${appimage}" --buff archon
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/archon.desktop" ]]
	[[ "$(readlink -f "${HOME}/.local/bin/archon")" == "${appimage}" ]]
}
