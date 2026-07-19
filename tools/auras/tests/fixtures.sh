#!/usr/bin/env bash
#
# Shared fixtures for auras Bats tests
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
	SCRIPT="${GIT_ROOT}/tools/auras/auras.sh"
	if [[ ! -f "${SCRIPT}" ]]; then
		echo "Script not found: ${SCRIPT}" >&2
		return 1
	fi

	export GIT_ROOT
	export SCRIPT

	return 0
}

setup() {
	source "${SCRIPT}"

	local bats_tmp="${BATS_TMPDIR:-/tmp}"
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
	local parent="$1"
	local fname="$2"

	mkdir -p "${parent}"
	: >"${parent}/${fname}"
	chmod +x "${parent}/${fname}"
}

make_managed_desktop() {
	local name="$1"
	local exec_path="${2:-/tmp/${name}.AppImage}"
	local path="${HOME}/.local/share/applications/${name}.desktop"

	mkdir -p "${HOME}/.local/share/applications"
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
	local name="$1"
	local target="$2"

	mkdir -p "${HOME}/.local/bin"
	ln -sf "${target}" "${HOME}/.local/bin/${name}"
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
