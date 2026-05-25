#!/usr/bin/env bats
#
# Tests for debuff.sh removal functions and debuff CLI mode
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
# debuff_appimage
########################################################
@test "debuff_appimage:: removes an Auras-managed desktop file" {
	make_managed_desktop "archon"

	run debuff_appimage "archon"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
}

@test "debuff_appimage:: removes matching managed bin symlink" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"
	make_managed_desktop "archon" "${appimage}"
	make_managed_bin_link "archon" "${appimage}"

	run debuff_appimage "archon"
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
	[[ ! -e "${HOME}/.local/bin/archon" ]]
}

@test "debuff_appimage:: fails when bin symlink target does not match desktop Exec" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"
	make_managed_desktop "archon" "${appimage}"
	make_managed_bin_link "archon" "/tmp/other.AppImage"

	run debuff_appimage "archon"
	[[ "$status" -eq 1 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
	[[ -L "${HOME}/.local/bin/archon" ]]
	grep -q "remove_application_bin_link:: refusing to remove bin symlink" <<<"$output"
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
# main
########################################################
@test "main:: debuff rejects --appimage" {
	run bash "$SCRIPT" --debuff archon --appimage /tmp/x.AppImage
	[[ "$status" -eq 1 ]]

	grep -q "main:: --appimage is only valid with --buff" <<<"$output"
}

@test "main:: debuff mode removes managed desktop entry and bin symlink" {
	local appdir
	local appimage

	appdir="${AURAS_TEST_HOME}/apps"
	make_appimage "${appdir}" "archon.AppImage"
	appimage="${appdir}/archon.AppImage"
	make_managed_desktop "archon" "${appimage}"
	make_managed_bin_link "archon" "${appimage}"

	run bash "$SCRIPT" --debuff archon
	[[ "$status" -eq 0 ]]

	[[ ! -f "${HOME}/.local/share/applications/archon.desktop" ]]
	[[ ! -e "${HOME}/.local/bin/archon" ]]
}
