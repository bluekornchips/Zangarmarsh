#!/usr/bin/env bats
#
# Tests for shared auras helpers and CLI dispatch in auras.sh
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

@test "resolve_appimage_path:: resolves relative AppImage directory" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="apps/demoapp.AppImage"
	local expected="${appdir}/demoapp.AppImage"

	cd "${AURAS_TEST_HOME}"

	run resolve_appimage_path "${appimage}" "resolve_appimage_path"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${expected}" ]]
}

@test "resolve_appimage_path:: resolves AppImage name in current directory" {
	if ! make_appimage "${AURAS_TEST_HOME}" "demoapp.AppImage"; then
		return 1
	fi
	local expected="${AURAS_TEST_HOME}/demoapp.AppImage"

	cd "${AURAS_TEST_HOME}"

	run resolve_appimage_path "demoapp.AppImage" "resolve_appimage_path"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${expected}" ]]
}

@test "resolve_appimage_path:: rejects missing relative directory" {

	run resolve_appimage_path "missing/demoapp.AppImage" "resolve_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "resolve_appimage_path:: AppImage directory does not exist" <<<"$output"
}

@test "validate_appimage_path:: accepts executable absolute AppImage path" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 0 ]]
}

@test "validate_appimage_path:: rejects relative AppImage path" {

	run validate_appimage_path "demoapp.AppImage" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "validate_appimage_path:: AppImage path must be absolute" <<<"$output"
}

@test "validate_appimage_path:: rejects a quote or percent sign" {
	run validate_appimage_path "/tmp/bad%name.AppImage" "validate_appimage_path"
	[[ "$status" -eq 1 ]]
	grep -q "must not contain a quote or percent sign" <<<"$output"
}

@test "validate_appimage_path:: rejects a dollar sign" {
	local bad_path="/tmp/bad\$name.AppImage"

	run validate_appimage_path "${bad_path}" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "must not contain a dollar sign" <<<"$output"
}

@test "validate_appimage_path:: rejects a backtick" {
	run validate_appimage_path '/tmp/bad`name.AppImage' "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "must not contain a backtick" <<<"$output"
}

@test "validate_appimage_path:: rejects a backslash" {
	run validate_appimage_path '/tmp/bad\name.AppImage' "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "must not contain a backslash" <<<"$output"
}

@test "validate_appimage_path:: accepts a path with a space" {
	local appdir="${AURAS_TEST_HOME}/my apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 0 ]]
}

@test "validate_appimage_path:: rejects non-AppImage extension" {
	local appdir="${AURAS_TEST_HOME}/apps"
	mkdir -p "${appdir}"
	local appimage="${appdir}/demoapp.bin"
	: >"${appimage}"
	chmod +x "${appimage}"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "validate_appimage_path:: AppImage path must end" <<<"$output"
}

@test "validate_appimage_path:: rejects non-executable AppImage" {
	local appdir="${AURAS_TEST_HOME}/apps"
	mkdir -p "${appdir}"
	local appimage="${appdir}/demoapp.AppImage"
	: >"${appimage}"

	run validate_appimage_path "${appimage}" "validate_appimage_path"
	[[ "$status" -eq 1 ]]

	grep -q "validate_appimage_path:: AppImage file is not executable" <<<"$output"
}

@test "prepare_appimage_path:: resolves relative AppImage path" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="apps/demoapp.AppImage"
	local expected="${appdir}/demoapp.AppImage"

	cd "${AURAS_TEST_HOME}"

	run prepare_appimage_path "${appimage}" "prepare_appimage_path"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${expected}" ]]
}

@test "resolve_appimage_path:: rejects an empty path" {
	run resolve_appimage_path "" "resolve_appimage_path"
	[[ "$status" -eq 1 ]]
	grep -q "resolve_appimage_path:: AppImage path is required" <<<"$output"
}

@test "desktop_entry_is_auras_managed:: accepts current marker and version" {
	if ! make_managed_desktop "demoapp"; then
		return 1
	fi

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 0 ]]
}

@test "desktop_entry_is_auras_managed:: rejects unmarked desktop file" {
	mkdir -p "${HOME}/.local/share/applications"
	: >"${HOME}/.local/share/applications/demoapp.desktop"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 1 ]]
}

@test "desktop_entry_is_auras_managed:: rejects desktop with only managed marker" {
	mkdir -p "${HOME}/.local/share/applications"
	printf '%s\n' "X-Auras-Managed=true" >"${HOME}/.local/share/applications/demoapp.desktop"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 1 ]]
}

@test "desktop_entry_is_auras_managed:: rejects desktop with only version marker" {
	mkdir -p "${HOME}/.local/share/applications"
	printf '%s\n' "X-Auras-Version=${AURAS_DESKTOP_VERSION}" >"${HOME}/.local/share/applications/demoapp.desktop"

	run desktop_entry_is_auras_managed "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 1 ]]
}

@test "desktop_entry_exec_path:: parses quoted Exec with field code" {
	if ! make_managed_desktop "demoapp" "/tmp/demoapp.AppImage"; then
		return 1
	fi

	run desktop_entry_exec_path "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "/tmp/demoapp.AppImage" ]]
}

@test "desktop_entry_exec_path:: parses quoted Exec with spaces in path" {
	if ! make_managed_desktop "demoapp" "/tmp/my apps/demoapp.AppImage"; then
		return 1
	fi

	run desktop_entry_exec_path "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "/tmp/my apps/demoapp.AppImage" ]]
}

@test "desktop_entry_exec_path:: rejects Exec path containing a tab" {
	mkdir -p "${HOME}/.local/share/applications"
	printf 'Exec="/tmp/bad\tpath.AppImage" %%u\n' >"${HOME}/.local/share/applications/demoapp.desktop"

	run desktop_entry_exec_path "${HOME}/.local/share/applications/demoapp.desktop"
	[[ "$status" -eq 1 ]]

	grep -q "desktop_entry_exec_path:: could not parse Exec=" <<<"$output"
}

@test "main:: script handles help option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
	grep -q -- "--buff NAME" <<<"$output"
	grep -q -- "--appimage PATH" <<<"$output"
}

@test "main:: --help mentions --ready-check" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q -- "--ready-check DIR" <<<"$output"
}

@test "main:: --help works when ZANGARMARSH_ROOT points at a missing tree" {
	run env ZANGARMARSH_ROOT=/nonexistent bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
}

@test "main:: ignores an inherited ZANGARMARSH_ROOT from another checkout" {
	local other_root="${AURAS_TEST_HOME}/other-root"
	mkdir -p "${other_root}"
	printf '# decoy\n' >"${other_root}/zangarmarsh.sh"

	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run env HOME="${HOME}" ZANGARMARSH_ROOT="${other_root}" \
		bash "$SCRIPT" --buff demoapp --appimage "${appimage}"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ "$(readlink "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]
}

@test "main:: script handles unknown options" {
	run bash "$SCRIPT" --unknown
	[[ "$status" -eq 1 ]]

	grep -q "main:: Unknown option" <<<"$output"
}

@test "main:: accepts short mode flags -b and -d" {
	local appdir="${AURAS_TEST_HOME}/apps"
	if ! make_appimage "${appdir}" "demoapp.AppImage"; then
		return 1
	fi
	local appimage="${appdir}/demoapp.AppImage"

	run bash "$SCRIPT" -b demoapp -a "${appimage}"
	[[ "$status" -eq 0 ]]

	[[ -f "${HOME}/.local/share/applications/demoapp.desktop" ]]
	[[ "$(readlink "${HOME}/.local/bin/demoapp")" == "${appimage}" ]]

	if ! make_managed_desktop "curseforge" "${appimage}"; then
		return 1
	fi
	if ! make_managed_bin_link "curseforge" "${appimage}"; then
		return 1
	fi

	run bash "$SCRIPT" -d curseforge
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/curseforge.desktop" ]]
}

@test "main:: rejects --buff combined with --debuff" {
	run main --buff demoapp --debuff demoapp
	[[ "$status" -eq 1 ]]

	grep -q "main:: use only one of --buff, --ready-check, or --debuff" <<<"$output"
}

@test "main:: rejects unknown --packages-dir" {
	run bash "$SCRIPT" --packages-dir "${HOME}" --buff demoapp --appimage /tmp/x.AppImage
	[[ "$status" -eq 1 ]]

	grep -q "main:: Unknown option" <<<"$output"
}
