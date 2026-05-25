#!/usr/bin/env bats
#
# Tests for shared auras helpers and CLI dispatch in auras.sh
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

make_managed_bin_link() {
	local name
	local target

	name="$1"
	target="$2"
	mkdir -p "${HOME}/.local/bin"
	ln -sf "${target}" "${HOME}/.local/bin/${name}"
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
# resolve_appimage_path
########################################################
@test "resolve_appimage_path:: resolves relative AppImage directory" {
	local appdir
	local appimage
	local expected

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="apps/archon.AppImage"
	expected="${appdir}/archon.AppImage"

	cd "${AURAS_TEST_HOME}"

	run resolve_appimage_path "${appimage}" "resolve_appimage_path"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${expected}" ]]
}

@test "resolve_appimage_path:: resolves AppImage name in current directory" {
	local expected

	make_appimage "${AURAS_TEST_HOME}" "archon.AppImage"
	expected="${AURAS_TEST_HOME}/archon.AppImage"

	cd "${AURAS_TEST_HOME}"

	run resolve_appimage_path "archon.AppImage" "resolve_appimage_path"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${expected}" ]]
}

@test "resolve_appimage_path:: rejects missing relative directory" {

	run resolve_appimage_path "missing/archon.AppImage" "resolve_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "resolve_appimage_path:: AppImage directory does not exist" <<<"$output"
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
# prepare_appimage_path
########################################################
@test "prepare_appimage_path:: resolves relative AppImage path" {
	local appdir
	local appimage
	local expected

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="apps/archon.AppImage"
	expected="${appdir}/archon.AppImage"

	cd "${AURAS_TEST_HOME}"

	run prepare_appimage_path "${appimage}" "prepare_appimage_path"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${expected}" ]]
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

@test "desktop_entry_is_auras_managed:: rejects desktop with only managed marker" {
	mkdir -p "${HOME}/.local/share/applications"
	printf '%s\n' "X-Auras-Managed=true" >"${HOME}/.local/share/applications/archon.desktop"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 1 ]]
}

@test "desktop_entry_is_auras_managed:: rejects desktop with only version marker" {
	mkdir -p "${HOME}/.local/share/applications"
	printf '%s\n' "X-Auras-Version=${AURAS_DESKTOP_VERSION}" >"${HOME}/.local/share/applications/archon.desktop"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 1 ]]
}

########################################################
# desktop_entry_exec_path
########################################################
@test "desktop_entry_exec_path:: parses quoted Exec with field code" {
	make_managed_desktop "archon" "/tmp/archon.AppImage"

	run desktop_entry_exec_path "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "/tmp/archon.AppImage" ]]
}

@test "desktop_entry_exec_path:: rejects unparseable Exec line" {
	mkdir -p "${HOME}/.local/share/applications"
	printf '%s\n' 'Exec=broken line' >"${HOME}/.local/share/applications/archon.desktop"

	run desktop_entry_exec_path "${HOME}/.local/share/applications/archon.desktop"
	[[ "$status" -eq 1 ]]

	grep -q "desktop_entry_exec_path:: could not parse Exec=" <<<"$output"
}

########################################################
# main
########################################################
@test "main:: script handles help option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
	grep -q -- "--buff NAME" <<<"$output"
	grep -q -- "--appimage PATH" <<<"$output"
}

@test "main:: script handles unknown options" {
	run bash "$SCRIPT" --unknown
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}

@test "main:: accepts short mode flags -b and -d" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"

	run bash "$SCRIPT" -b archon -a "${appimage}"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/archon.desktop" ]]
	[[ "$(readlink -f "${HOME}/.local/bin/archon")" == "${appimage}" ]]

	make_managed_desktop "curseforge" "${appimage}"
	make_managed_bin_link "curseforge" "${appimage}"

	run bash "$SCRIPT" -d curseforge
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/curseforge.desktop" ]]
}

@test "main:: rejects packages-dir after simplification" {
	run bash "$SCRIPT" --packages-dir "${HOME}" --buff archon --appimage /tmp/x.AppImage
	[[ "$status" -eq 1 ]]

	grep -q "main:: unknown option" <<<"$output"
}
