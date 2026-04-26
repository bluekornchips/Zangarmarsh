#!/usr/bin/env bats
#
# Test file for buffs.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
	SCRIPT="$GIT_ROOT/tools/buffs/buffs.sh"
	[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && return 1

	export GIT_ROOT
	export SCRIPT

	return 0
}

setup() {
	source "$SCRIPT"

	local bats_tmp

	bats_tmp="${BATS_TMPDIR:-/tmp}"
	BUFF_TEST_HOME="$(mktemp -d "${bats_tmp}/buffs_test_home.XXXXXX")"
	HOME="${BUFF_TEST_HOME}"

	return 0
}

teardown() {
	[[ -n "${BUFF_TEST_HOME}" && -d "${BUFF_TEST_HOME}" ]] && rm -rf "${BUFF_TEST_HOME}"
	BUFF_TEST_HOME=""
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

seed_packages_dir() {
	local root

	root="$(mktemp -d)"
	mkdir -p "${root}/appA" "${root}/appB" "${root}/empty"
	make_appimage "${root}/appA" "appA-1.0.AppImage"
	make_appimage "${root}/appB" "appB-0.9.AppImage"

	echo "${root}"
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
# find_latest_appimage
########################################################
@test "find_latest_appimage:: returns newest AppImage by mtime" {
	local appdir
	appdir="${BUFF_TEST_HOME}/app"
	mkdir -p "${appdir}"
	make_appimage "${appdir}" "old.AppImage"
	touch -d '2 hours ago' "${appdir}/old.AppImage"
	make_appimage "${appdir}" "new.AppImage"
	touch -d '1 hour ago' "${appdir}/new.AppImage"

	run find_latest_appimage "${appdir}"
	[[ "$status" -eq 0 ]]
	grep -q "new.AppImage" <<<"$output"
}

@test "find_latest_appimage:: returns empty output when no AppImage exists" {
	local emptydir
	emptydir="${HOME}/empty"
	mkdir -p "${emptydir}"

	run find_latest_appimage "${emptydir}"
	[[ "$status" -eq 0 ]]
	[[ -z "$(echo "$output" | tr -d '[:space:]')" ]]
}

@test "find_latest_appimage:: fails when directory does not exist" {
	run find_latest_appimage "/nonexistent/buffs_pkg_$$"
	[[ "$status" -eq 1 ]]

	grep -q "find_latest_appimage:: directory does not exist" <<<"$output"
}

@test "find_latest_appimage:: fails when directory is not readable" {
	local locked
	locked="${HOME}/locked"
	mkdir -p "${locked}"
	chmod 000 "${locked}"

	run find_latest_appimage "${locked}"
	chmod 700 "${locked}"
	[[ "$status" -eq 1 ]]

	grep -q "find_latest_appimage:: directory is not readable" <<<"$output"
}

########################################################
# write_application_desktop
########################################################
@test "write_application_desktop:: writes desktop entry with expected fields" {
	local binfile
	binfile="${HOME}/x.AppImage"
	: >"${binfile}"
	chmod +x "${binfile}"

	run write_application_desktop "myapp" "${binfile}" "My Label"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/myapp.desktop" ]]
	grep -q '^Name=My Label$' "${HOME}/.local/share/applications/myapp.desktop"
	grep -q "Exec=\"${binfile}\" %u" "${HOME}/.local/share/applications/myapp.desktop"
	grep -q '^Terminal=false$' "${HOME}/.local/share/applications/myapp.desktop"
}

@test "write_application_desktop:: fails when app_stem is empty" {
	local binfile
	binfile="${HOME}/x.AppImage"
	: >"${binfile}"
	chmod +x "${binfile}"

	run write_application_desktop "" "${binfile}" "Label"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: app_stem, appimage_path, and display_name are required" <<<"$output"
}

@test "write_application_desktop:: fails when appimage_path is empty" {

	run write_application_desktop "myapp" "" "Label"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: app_stem, appimage_path, and display_name are required" <<<"$output"
}

@test "write_application_desktop:: fails when display_name is empty" {
	local binfile
	binfile="${HOME}/x.AppImage"
	: >"${binfile}"
	chmod +x "${binfile}"

	run write_application_desktop "myapp" "${binfile}" ""
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: app_stem, appimage_path, and display_name are required" <<<"$output"
}

@test "write_application_desktop:: fails when AppImage file does not exist" {

	run write_application_desktop "myapp" "${BUFF_TEST_HOME}/missing.AppImage" "Label"
	[[ "$status" -eq 1 ]]

	grep -q "write_application_desktop:: AppImage file does not exist" <<<"$output"
}

########################################################
# remove_desktop_entry
########################################################
@test "remove_desktop_entry:: removes an existing desktop file" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/foo.desktop"

	run remove_desktop_entry "foo"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/foo.desktop" ]]
}

@test "remove_desktop_entry:: fails when desktop file is missing" {
	mkdir -p "${HOME}/.local/share/applications"

	run remove_desktop_entry "missing"
	[[ "$status" -eq 1 ]]

	grep -q "remove_desktop_entry:: no desktop file" <<<"$output"
}

@test "remove_desktop_entry:: fails when app_stem is empty" {

	run remove_desktop_entry ""
	[[ "$status" -eq 1 ]]

	grep -q "remove_desktop_entry:: app_stem is required" <<<"$output"
}

########################################################
# scan_and_sync_desktops
########################################################
@test "scan_and_sync_desktops:: syncs every subdirectory skipping empty ones" {
	local seed
	seed="$(seed_packages_dir)"

	run scan_and_sync_desktops "${seed}"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/appA.desktop" ]]
	[[ -f "${HOME}/.local/share/applications/appB.desktop" ]]
	[[ ! -f "${HOME}/.local/share/applications/empty.desktop" ]]

	rm -rf "${seed}"
}

@test "scan_and_sync_desktops:: syncs only named subdirectory" {
	local seed
	seed="$(seed_packages_dir)"

	run scan_and_sync_desktops "${seed}" "appA"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/appA.desktop" ]]
	[[ ! -f "${HOME}/.local/share/applications/appB.desktop" ]]

	rm -rf "${seed}"
}

@test "scan_and_sync_desktops:: fails when named subdirectory has no AppImage" {
	local seed
	seed="$(seed_packages_dir)"

	run scan_and_sync_desktops "${seed}" "empty"
	[[ "$status" -eq 1 ]]

	grep -q "scan_and_sync_desktops:: no AppImage in" <<<"$output"

	rm -rf "${seed}"
}

@test "scan_and_sync_desktops:: fails when packages_dir does not exist" {

	run scan_and_sync_desktops "/nonexistent/buffs_packages_$$"
	[[ "$status" -eq 1 ]]

	grep -q "scan_and_sync_desktops:: not a directory" <<<"$output"
}

########################################################
# _handle_input_add_name
########################################################
@test "_handle_input_add_name:: rejects empty string" {
	add_targets=()

	run _handle_input_add_name ""
	[[ "$status" -eq 1 ]]

	grep -q "main:: each NAME after -a must be non-empty" <<<"$output"
}

@test "_handle_input_add_name:: rejects whitespace only" {
	add_targets=()

	run _handle_input_add_name "   "
	[[ "$status" -eq 1 ]]

	grep -q "main:: each NAME after -a must be non-empty" <<<"$output"
}

@test "_handle_input_add_name:: appends non-empty name" {
	add_targets=()

	_handle_input_add_name "appA"
	[[ "${#add_targets[@]}" -eq 1 ]]
	[[ "${add_targets[0]}" == "appA" ]]
}

########################################################
# main
########################################################
@test "main:: script handles help option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
	grep -q "packages-dir" <<<"$output"
}

@test "main:: script handles unknown options" {
	run bash "$SCRIPT" --unknown
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}

@test "main:: add mode fails without packages directory flag" {
	run bash "$SCRIPT" -a
	[[ "$status" -eq 1 ]]

	grep -q "main:: -a requires -p DIR" <<<"$output"
}

@test "main:: rejects empty NAME after add" {
	run bash "$SCRIPT" -a "" -p /tmp
	[[ "$status" -eq 1 ]]

	grep -q "main:: each NAME after -a must be non-empty" <<<"$output"
}

@test "main:: rejects whitespace only NAME after add" {
	run bash "$SCRIPT" -a "  " -p /tmp
	[[ "$status" -eq 1 ]]

	grep -q "main:: each NAME after -a must be non-empty" <<<"$output"
}

@test "main:: add mode syncs AppImages under packages directory" {
	local seed
	seed="$(seed_packages_dir)"

	run bash "$SCRIPT" -a -p "${seed}"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/appA.desktop" ]]
	[[ -f "${HOME}/.local/share/applications/appB.desktop" ]]

	rm -rf "${seed}"
}

@test "main:: remove mode deletes desktop entry" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/foo.desktop"

	run bash "$SCRIPT" -r foo
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/foo.desktop" ]]
}

@test "main:: rejects packages-dir with remove mode" {

	run bash "$SCRIPT" -p "${HOME}" -r foo
	[[ "$status" -eq 1 ]]

	grep -q "main:: -p is only valid with -a" <<<"$output"
}
