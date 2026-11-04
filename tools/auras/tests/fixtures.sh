#!/usr/bin/env bash
#
# Shared auras fixtures for aura, buff, and debuff tests.
# Requires GIT_ROOT / ZANGARMARSH_ROOT from the calling setup_file.
#

source "${GIT_ROOT}/tests/fixtures.sh" || return 1

# Standard per-test setup: load the auras CLI and isolate HOME
#
# Reads environment:
# - SCRIPT, path to tools/auras/auras.sh
#
# Side Effects:
# - Sources SCRIPT and creates a temporary HOME
#
# Returns:
# - 0 on success
auras_test_setup() {
	source "${SCRIPT}"
	auras_home_setup

	return 0
}

# Create an isolated HOME for one auras test
#
# Side Effects:
# - Sets and exports HOME and AURAS_TEST_HOME
#
# Returns:
# - 0 on success
auras_home_setup() {
	local bats_tmp="${BATS_TMPDIR:-/tmp}"

	AURAS_TEST_HOME="$(mktemp -d "${bats_tmp}/auras_test_home.XXXXXX")"
	AURAS_TEST_HOME="$(cd "${AURAS_TEST_HOME}" && pwd -P)"
	HOME="${AURAS_TEST_HOME}"
	export HOME
	export AURAS_TEST_HOME

	return 0
}

# Remove the isolated auras HOME created by auras_home_setup
#
# Side Effects:
# - Deletes AURAS_TEST_HOME when set
#
# Returns:
# - 0 always
auras_home_teardown() {
	[[ -n "${AURAS_TEST_HOME:-}" && -d "${AURAS_TEST_HOME}" ]] && rm -rf "${AURAS_TEST_HOME}"
	AURAS_TEST_HOME=""

	return 0
}

# Create an empty executable AppImage file
#
# Inputs:
# - $1 parent, directory that will hold the file
# - $2 fname, AppImage basename
#
# Side Effects:
# - Creates parent and writes an executable empty file
#
# Returns:
# - 0 on success
make_appimage() {
	local parent="$1"
	local fname="$2"

	mkdir -p "${parent}"
	: >"${parent}/${fname}"
	chmod +x "${parent}/${fname}"

	return 0
}

# Write a current Auras-managed desktop entry under HOME
#
# Inputs:
# - $1 name, desktop stem and Name=
# - $2 exec_path, optional Exec= target
#
# Side Effects:
# - Writes HOME/.local/share/applications/name.desktop
#
# Returns:
# - 0 on success
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

	return 0
}

# Create a managed bin symlink under HOME
#
# Inputs:
# - $1 name, command name under ~/.local/bin
# - $2 target, symlink target path
#
# Side Effects:
# - Creates HOME/.local/bin/name -> target
#
# Returns:
# - 0 on success
make_managed_bin_link() {
	local name="$1"
	local target="$2"

	mkdir -p "${HOME}/.local/bin"
	ln -sf "${target}" "${HOME}/.local/bin/${name}"

	return 0
}
