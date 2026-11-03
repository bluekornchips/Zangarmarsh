#!/usr/bin/env bats
#
# Unit and integration tests for profile/zsh/profile.zsh
#

setup_file() {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/zsh/profile.zsh"
	export SCRIPT

	return 0
}

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/profile-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	export TEST_DIR
	USER="testuser"
	export USER
	HOSTNAME="testhost"
	export HOSTNAME
	HOME="${TEST_DIR}"
	export HOME
	ZDOTDIR="${TEST_DIR}"
	export ZDOTDIR
	PWD="${TEST_DIR}"
	export PWD
	ZSH="${TEST_DIR}/.oh-my-zsh"
	export ZSH
	printf '\n' >"${ZDOTDIR}/.zshrc"
	touch "${ZDOTDIR}/.zcompdump"
	export ZANGARMARSH_ROOT
	ZANGARMARSH_VERBOSE=false
	export ZANGARMARSH_VERBOSE

	mkdir -p "${ZSH}/lib" "${ZSH}/plugins/git" "${ZSH}/plugins/zsh-autosuggestions"
	printf 'git_current_branch() { echo main; }\n' >"${ZSH}/lib/git.zsh"
	printf 'alias ga="git add"\n' >"${ZSH}/plugins/git/git.plugin.zsh"
	printf '# autosuggestions stub\n' >"${ZSH}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

	return 0
}

teardown() {
	rm -rf "${TEST_DIR}"

	return 0
}

@test "profile:: non-interactive zsh sets history and skips plugins" {
	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'HISTSIZE=%s\n' \"\$HISTSIZE\"
		printf 'COMP=%s\n' \"\${_zangarmarsh_compinit:-}\"
		type build_prompt >/dev/null 2>&1 && printf 'PROMPT_FN=1\n' || printf 'PROMPT_FN=0\n'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "^HISTSIZE=100000$"
	echo "${output}" | grep -q "^COMP=$"
	echo "${output}" | grep -q "^PROMPT_FN=0$"
}

@test "integration:: profile loads git plugin, autosuggestions, and prompt interactively" {
	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		zsh -i -c "
		source '${SCRIPT}' || exit 1
		printf 'COMP=%s\n' \"\$_zangarmarsh_compinit\"
		printf 'STYLE=%s\n' \"\$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE\"
		printf 'GA=%s\n' \"\$(alias ga 2>/dev/null || true)\"
		type build_prompt >/dev/null && printf 'PROMPT_FN=1\n'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "^COMP=1$"
	echo "${output}" | grep -q "fg=#00ffff,bg=#2d2f40,bold"
	echo "${output}" | grep -q "^GA=.*git add"
	echo "${output}" | grep -q "^PROMPT_FN=1$"
}

@test "integration:: profile warns when git plugin files are missing" {
	rm -rf "${ZSH}"
	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		zsh -i -c "source '${SCRIPT}'"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Oh My Zsh git plugin files are not installed"
}

@test "integration:: profile warns when zsh-autosuggestions is missing" {
	rm -rf "${ZSH}/plugins/zsh-autosuggestions"
	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		zsh -i -c "source '${SCRIPT}'"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "zsh-autosuggestions plugin is not installed"
}
