#!/usr/bin/env bash
#
# Shared auras fixtures for aura, buff, and debuff tests.
# Requires GIT_ROOT / ZANGARMARSH_ROOT from the calling setup_file.
#

auras_home_setup() {
	local bats_tmp="${BATS_TMPDIR:-/tmp}"

	AURAS_TEST_HOME="$(mktemp -d "${bats_tmp}/auras_test_home.XXXXXX")"
	HOME="${AURAS_TEST_HOME}"
	export HOME
	export AURAS_TEST_HOME

	return 0
}

auras_home_teardown() {
	[[ -n "${AURAS_TEST_HOME:-}" && -d "${AURAS_TEST_HOME}" ]] && rm -rf "${AURAS_TEST_HOME}"
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
