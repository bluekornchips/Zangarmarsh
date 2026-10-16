#!/usr/bin/env bats
#
# Test file for zsh session startup smoke checks with Zangarmarsh.
#

setup_file() {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1
	ZANGARMARSH_SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
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

# Build one completion dump for the warm timings below.
#
# Reads environment:
# - HOME
#
# Side Effects:
# - Writes ${HOME}/.zcompdump through compinit
# - Writes failure messages to stderr
#
# Returns:
# - 0 when ${HOME}/.zcompdump exists and is non-empty
# - 1 when compinit fails or writes no dump
seed_zcompdump() {
	zsh -c 'autoload -Uz compinit; compinit -u' >/dev/null 2>&1 || {
		echo "seed_zcompdump:: compinit failed" >&2
		return 1
	}
	if [[ ! -s "${HOME}/.zcompdump" ]]; then
		echo "seed_zcompdump:: dump was not written" >&2
		return 1
	fi

	return 0
}

# Milliseconds since the epoch, on GNU and BSD date
#
# Outputs:
# - Integer milliseconds on stdout
#
# Returns:
# - 0 when a timestamp is printed
# - 1 when no clock command succeeds
now_ms() {
	local raw
	raw="$(date +%s%N 2>/dev/null || true)"
	if [[ "${raw}" =~ ^[0-9]+$ ]]; then
		echo $((raw / 1000000))
		return 0
	fi

	if command -v python3 >/dev/null 2>&1; then
		python3 -c 'import time; print(int(time.time() * 1000))'
		return 0
	fi

	raw="$(date +%s 2>/dev/null || true)"
	if [[ "${raw}" =~ ^[0-9]+$ ]]; then
		echo $((raw * 1000))
		return 0
	fi

	echo "now_ms:: no usable clock" >&2
	return 1
}

# Time one interactive zsh startup.
#
# Reads environment:
# - HOME
#
# Outputs:
# - Load time in milliseconds on stdout
#
# Side Effects:
# - Updates the mtime of ${HOME}/.zcompdump so it stays newer than .zshrc
# - Starts an interactive zsh
# - Writes failure messages to stderr
#
# Returns:
# - 0 when the timing is printed
# - 1 when the completion dump is missing, touch fails, or zsh exits nonzero
measure_warm_zsh_load_ms() {
	if [[ ! -s "${HOME}/.zcompdump" ]]; then
		echo "measure_warm_zsh_load_ms:: completion dump is missing" >&2
		return 1
	fi

	# .zshrc was just rewritten. A newer dump keeps startup on compinit -C.
	touch "${HOME}/.zcompdump" || return 1

	local start_ms
	local end_ms
	local load_ms
	start_ms="$(now_ms)" || return 1

	# Do not use bats run here; this helper is called from command substitution.
	if ! zsh -i -c 'exit' >/dev/null 2>&1; then
		echo "measure_warm_zsh_load_ms:: zsh -i exited nonzero" >&2
		return 1
	fi

	end_ms="$(now_ms)" || return 1
	load_ms=$((end_ms - start_ms))
	echo "${load_ms}"

	return 0
}

@test "smoke:: zsh session startup times" {
	seed_zcompdump || return 1

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
	compinit -u -C
else
	compinit -u
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
