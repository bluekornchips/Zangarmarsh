#!/usr/bin/env bats
#
# Test file for zsh session startup smoke checks with Zangarmarsh.
#

setup_file() {
	command -v zsh >/dev/null 2>&1 || exit 0

	GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
	ZANGARMARSH_SCRIPT="${GIT_ROOT}/zangarmarsh.sh"
	[[ -f "${ZANGARMARSH_SCRIPT}" ]] || {
		echo "setup_file:: script not found: ${ZANGARMARSH_SCRIPT}" >&2
		return 1
	}

	export GIT_ROOT ZANGARMARSH_SCRIPT

	return 0
}

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/zangarmarsh-smoke.XXXXXX")"

	export TEST_DIR
	export HOME="${TEST_DIR}"
	export ZDOTDIR="${TEST_DIR}"
	export ZSH="${TEST_DIR}/.oh-my-zsh"
	export ZANGARMARSH_VERBOSE=false
	unset ZANGARMARSH_ROOT

	mkdir -p "${ZSH}/plugins/zsh-autosuggestions"
	touch "${ZSH}/oh-my-zsh.sh"
	touch "${ZSH}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
	printf 'source "%s"\n' "${ZANGARMARSH_SCRIPT}" >"${HOME}/.zshrc"

	return 0
}

teardown() {
	[[ -n "${TEST_DIR}" && -d "${TEST_DIR}" ]] && rm -rf "${TEST_DIR}"
	return 0
}

@test "smoke:: zsh session startup time with zangarmarsh" {
	local start_ns
	local end_ns
	local load_ms

	start_ns=$(date +%s%N)

	run zsh -i -c 'exit'
	[[ "${status}" -eq 0 ]]

	end_ns=$(date +%s%N)
	load_ms=$(((end_ns - start_ns) / 1000000))

	echo -e "\nzsh session load time: ${load_ms}ms\n" >&0
}
