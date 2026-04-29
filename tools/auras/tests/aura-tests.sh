#!/usr/bin/env bats
#
# Test file for auras.sh
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
	local path

	name="$1"
	mkdir -p "${HOME}/.local/share/applications"
	path="${HOME}/.local/share/applications/${name}.desktop"
	cat <<EOF >"${path}"
[Desktop Entry]
Type=Application
Name=${name}
Exec="/tmp/${name}.AppImage" %u
Terminal=false
X-Auras-Managed=true
X-Auras-Version=1
EOF
}

########################################################
# applications_dir
########################################################
@test "applications_dir:: echoes applications path under HOME" {

	run applications_dir
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${HOME}/.local/share/applications" ]]
}

@test "applications_dir:: fails when HOME is empty" {
	run bash -c 'HOME=""; export HOME; source "$1"; applications_dir' _ "$SCRIPT"
	[[ "$status" -eq 1 ]]

	grep -q "applications_dir:: HOME is not set" <<<"$output"
}

########################################################
# validate_appimage_path
########################################################
@test "validate_appimage_path:: accepts executable absolute AppImage path" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 0 ]]
}

@test "validate_appimage_path:: rejects relative AppImage path" {

	run validate_appimage_path "archon.AppImage" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "validate_appimage_path:: AppImage path must be absolute" <<<"$output"
}

@test "validate_appimage_path:: rejects non-AppImage extension" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	mkdir -p "${appdir}"
	appimage="${appdir}/archon.bin"
	: >"${appimage}"
	chmod +x "${appimage}"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "validate_appimage_path:: AppImage path must end" <<<"$output"
}

@test "validate_appimage_path:: rejects non-executable AppImage" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	mkdir -p "${appdir}"
	appimage="${appdir}/archon.AppImage"
	: >"${appimage}"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "validate_appimage_path:: AppImage file is not executable" <<<"$output"
}

########################################################
# desktop_entry_is_auras_managed
########################################################
@test "desktop_entry_is_auras_managed:: accepts current marker and version" {
	make_managed_desktop "archon"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 0 ]]
}

@test "desktop_entry_is_auras_managed:: rejects unmarked desktop file" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/archon.desktop"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 1 ]]
}

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
# debuff_appimage
########################################################
@test "debuff_appimage:: removes an Auras-managed desktop file" {
	make_managed_desktop "archon"

	run debuff_appimage "archon"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
}

@test "debuff_appimage:: refuses to remove unmanaged desktop file" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/archon.desktop"

	run debuff_appimage "archon"
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
# buff_appimage
########################################################
@test "buff_appimage:: writes a desktop entry from explicit AppImage and name" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run buff_appimage "${appimage}" "archon"
	[[ "$status" -eq 0 ]]

	grep -q "Exec=\"${appimage}\" %u" "${HOME}/.local/share/applications/archon.desktop"
}

########################################################
# main
########################################################
@test "main:: script handles help option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
	grep -q -- "--buff APPIMAGE NAME" <<<"$output"
}

@test "main:: script handles unknown options" {
	run bash "$SCRIPT" --unknown
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}

@test "main:: buff mode requires AppImage and name" {
	run bash "$SCRIPT" --buff
	[[ "$status" -eq 1 ]]

	grep -q "main:: --buff requires APPIMAGE and NAME" <<<"$output"
}

@test "main:: buff mode writes AppImage launcher" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run bash "$SCRIPT" --buff "${appimage}" "archon"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/archon.desktop" ]]
}

@test "main:: debuff mode removes managed desktop entry" {
	make_managed_desktop "archon"

	run bash "$SCRIPT" --debuff archon
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
}

@test "main:: rejects packages-dir after simplification" {
	run bash "$SCRIPT" --packages-dir "${HOME}" --buff /tmp/x.AppImage archon
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}
