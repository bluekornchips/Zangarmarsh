#!/usr/bin/env bats
#
# Tests for ready-check discovery and install helpers
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

########################################################
# appimage_version_from_name
########################################################
@test "appimage_version_from_name:: extracts dotted version from basename" {
	run appimage_version_from_name "DemoApp-1.2.3.AppImage"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "1.2.3" ]]
}

@test "appimage_version_from_name:: strips arch suffix after version" {
	run appimage_version_from_name "DemoApp-1.2.3-x86_64.AppImage"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "1.2.3" ]]
}

@test "appimage_version_from_name:: accepts leading v" {
	run appimage_version_from_name "demoapp-v2.0.AppImage"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "2.0" ]]
}

@test "appimage_version_from_name:: empty for unversioned names" {
	run appimage_version_from_name "DemoApp.AppImage"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

########################################################
# pick_latest_appimage
########################################################
@test "pick_latest_appimage:: prefers higher version over newer mtime" {
	local appdir="${AURAS_TEST_HOME}/Apps/DemoApp"
	if ! make_appimage "${appdir}" "DemoApp-1.0.0.AppImage"; then
		return 1
	fi
	if ! make_appimage "${appdir}" "DemoApp-1.2.0.AppImage"; then
		return 1
	fi
	touch -t 203001010101 "${appdir}/DemoApp-1.0.0.AppImage"
	touch -t 200001010101 "${appdir}/DemoApp-1.2.0.AppImage"

	run pick_latest_appimage "${appdir}"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${appdir}/DemoApp-1.2.0.AppImage" ]]
}

@test "pick_latest_appimage:: uses newest mtime when unversioned" {
	local appdir="${AURAS_TEST_HOME}/Apps/SampleApp"
	if ! make_appimage "${appdir}" "SampleApp-old.AppImage"; then
		return 1
	fi
	if ! make_appimage "${appdir}" "SampleApp-new.AppImage"; then
		return 1
	fi
	touch -t 200001010101 "${appdir}/SampleApp-old.AppImage"
	touch -t 203001010101 "${appdir}/SampleApp-new.AppImage"

	run pick_latest_appimage "${appdir}"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${appdir}/SampleApp-new.AppImage" ]]
}

@test "pick_latest_appimage:: newer mtime wins when versions tie" {
	local appdir="${AURAS_TEST_HOME}/Apps/DemoApp"
	if ! make_appimage "${appdir}" "DemoApp-1.0.0-old.AppImage"; then
		return 1
	fi
	if ! make_appimage "${appdir}" "DemoApp-1.0.0-new.AppImage"; then
		return 1
	fi
	touch -t 200001010101 "${appdir}/DemoApp-1.0.0-old.AppImage"
	touch -t 203001010101 "${appdir}/DemoApp-1.0.0-new.AppImage"

	run pick_latest_appimage "${appdir}"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "${appdir}/DemoApp-1.0.0-new.AppImage" ]]
}

@test "pick_latest_appimage:: fails when directory has no AppImages" {
	local appdir="${AURAS_TEST_HOME}/Apps/EmptyApp"
	mkdir -p "${appdir}"

	run pick_latest_appimage "${appdir}"
	[[ "$status" -eq 1 ]]

	grep -q "pick_latest_appimage:: no AppImage files" <<<"$output"
}

########################################################
# ready_check_main
########################################################
@test "ready_check_main:: buffs multiple child apps" {
	local root="${AURAS_TEST_HOME}/Apps"
	if ! make_appimage "${root}/DemoApp" "DemoApp-1.0.0.AppImage"; then
		return 1
	fi
	if ! make_appimage "${root}/DemoApp" "DemoApp-2.0.0.AppImage"; then
		return 1
	fi
	if ! make_appimage "${root}/SampleApp" "SampleApp.AppImage"; then
		return 1
	fi
	local demo_winner="${root}/DemoApp/DemoApp-2.0.0.AppImage"
	local sample_winner="${root}/SampleApp/SampleApp.AppImage"

	run ready_check_main "${root}"
	[[ "$status" -eq 0 ]]

	[[ "$(resolve_symlink_path "${HOME}/.local/bin/DemoApp")" == "${demo_winner}" ]]
	[[ "$(resolve_symlink_path "${HOME}/.local/bin/SampleApp")" == "${sample_winner}" ]]
	grep -q "Exec=\"${demo_winner}\" %u" "${HOME}/.local/share/applications/DemoApp.desktop"
	grep -q "Exec=\"${sample_winner}\" %u" "${HOME}/.local/share/applications/SampleApp.desktop"
}

@test "ready_check_main:: continues and fails when one child has no AppImage" {
	local root="${AURAS_TEST_HOME}/Apps"
	if ! make_appimage "${root}/DemoApp" "DemoApp-1.0.0.AppImage"; then
		return 1
	fi
	mkdir -p "${root}/EmptyApp"

	run ready_check_main "${root}"
	[[ "$status" -eq 1 ]]

	grep -q "ready_check_main:: no AppImage found for EmptyApp" <<<"$output"
	[[ -f "${HOME}/.local/share/applications/DemoApp.desktop" ]]
}

@test "ready_check_main:: succeeds with message when packages dir has no children" {
	local root="${AURAS_TEST_HOME}/Apps"
	mkdir -p "${root}"

	run ready_check_main "${root}"
	[[ "$status" -eq 0 ]]

	grep -q "ready_check_main:: no application directories under" <<<"$output"
}

@test "ready_check_main:: fails when packages directory is missing" {
	run ready_check_main "${AURAS_TEST_HOME}/missing-apps"
	[[ "$status" -eq 1 ]]

	grep -q "ready_check_main:: packages directory does not exist" <<<"$output"
}

########################################################
# main CLI
########################################################
@test "main:: --ready-check installs latest AppImages under DIR" {
	local root="${AURAS_TEST_HOME}/Apps"
	if ! make_appimage "${root}/DemoApp" "DemoApp-1.0.0.AppImage"; then
		return 1
	fi
	if ! make_appimage "${root}/DemoApp" "DemoApp-1.5.0.AppImage"; then
		return 1
	fi
	local winner="${root}/DemoApp/DemoApp-1.5.0.AppImage"

	run bash "$SCRIPT" --ready-check "${root}"
	[[ "$status" -eq 0 ]]

	[[ "$(resolve_symlink_path "${HOME}/.local/bin/DemoApp")" == "${winner}" ]]
}

@test "main:: --ready-check rejects --appimage" {
	run bash "$SCRIPT" --ready-check "${AURAS_TEST_HOME}" --appimage /tmp/x.AppImage
	[[ "$status" -eq 1 ]]

	grep -q "main:: --appimage is only valid with --buff" <<<"$output"
}

@test "main:: rejects --buff combined with --ready-check" {
	run bash "$SCRIPT" --buff demoapp --ready-check "${AURAS_TEST_HOME}"
	[[ "$status" -eq 1 ]]

	grep -q "main:: use only one of --buff, --ready-check, or --debuff" <<<"$output"
}
