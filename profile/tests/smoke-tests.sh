#!/usr/bin/env bats
#
# Test file for zsh session startup smoke checks with Zangarmarsh.
#

setup_file() {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	ZANGARMARSH_SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
	[[ -f "${ZANGARMARSH_SCRIPT}" ]] || {
		echo "setup_file:: script not found: ${ZANGARMARSH_SCRIPT}" >&2
		return 1
	}

	export ZANGARMARSH_SCRIPT

	return 0
}

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/zangarmarsh-smoke.XXXXXX")"

	export TEST_DIR
	HOME="${TEST_DIR}"
	export HOME
	ZDOTDIR="${TEST_DIR}"
	export ZDOTDIR
	ZSH="${TEST_DIR}/.oh-my-zsh"
	export ZSH
	ZANGARMARSH_VERBOSE=false
	export ZANGARMARSH_VERBOSE
	unset ZANGARMARSH_ROOT

	return 0
}

teardown() {
	[[ -n "${TEST_DIR}" && -d "${TEST_DIR}" ]] && rm -rf "${TEST_DIR}"

	return 0
}

teardown_file() {
	return 0
}

measure_warm_zsh_load_ms() {
	rm -f "${HOME}/.zcompdump"
	zsh -i -c 'exit' >/dev/null 2>&1

	local start_ns
	start_ns=$(date +%s%N)

	run zsh -i -c 'exit'
	[[ "${status}" -eq 0 ]] || return 1

	local end_ns
	end_ns=$(date +%s%N)
	local load_ms
	load_ms=$(((end_ns - start_ns) / 1000000))
	echo "${load_ms}"

	return 0
}

@test "smoke:: zsh session startup times" {
	mkdir -p "${ZSH}/plugins/zsh-autosuggestions"
	touch "${ZSH}/oh-my-zsh.sh"
	touch "${ZSH}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
	printf 'source "%s"\n' "${ZANGARMARSH_SCRIPT}" >"${HOME}/.zshrc"
	local zm_ms
	zm_ms="$(measure_warm_zsh_load_ms)" || return 1

	cat >"${HOME}/.zshrc" <<EOF
ZSH="${ZSH}"
export ZSH
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions)
source "\${ZSH}/oh-my-zsh.sh"
autoload -Uz compinit
comp_dump="\${HOME}/.zcompdump"
if [[ -f "\${comp_dump}" && "\${comp_dump}" -nt "\${HOME}/.zshrc" ]]; then
	compinit -C
else
	compinit
fi
EOF
	local omz_ms
	omz_ms="$(measure_warm_zsh_load_ms)" || return 1

	mkdir -p "${ZSH}"
	printf 'source "%s"\n' "${ZANGARMARSH_SCRIPT}" >"${HOME}/.zshrc"
	local zm_no_omz_ms
	zm_no_omz_ms="$(measure_warm_zsh_load_ms)" || return 1

	printf '\n' >"${HOME}/.zshrc"
	local bare_ms
	bare_ms="$(measure_warm_zsh_load_ms)" || return 1

	cat <<EOF >&3
zangarmarsh with omz: ${zm_ms}ms
omz only: ${omz_ms}ms
zangarmarsh without omz: ${zm_no_omz_ms}ms
bare zsh: ${bare_ms}ms
EOF
}
