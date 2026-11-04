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

	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

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

	seed_omz_stub

	return 0
}

teardown() {
	rm -rf "${TEST_DIR}"
	return 0
}

@test "profile:: non-interactive zsh sets history and skips Oh My Zsh" {
	run env -u ZANGARMARSH_TEST HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'HISTSIZE=%s\n' \"\$HISTSIZE\"
		alias ga >/dev/null 2>&1 && printf 'GA=1\n' || printf 'GA=0\n'
		type build_prompt >/dev/null 2>&1 && printf 'PROMPT_FN=1\n' || printf 'PROMPT_FN=0\n'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "^HISTSIZE=100000$"
	echo "${output}" | grep -q "^GA=0$"
	echo "${output}" | grep -q "^PROMPT_FN=0$"
}

@test "profile:: forces HISTFILE over an inherited bash path and sets HISTORY_IGNORE" {
	local shared
	shared="$(bash -c "source '${ZANGARMARSH_ROOT}/profile/config.sh' && printf '%s' \"\$ZANGARMARSH_HIST_IGNORE\"")"
	shared="(${shared//:/|})"

	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		HISTFILE="${HOME}/.bash_history" \
		zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'HISTFILE=%s\n' \"\$HISTFILE\"
		printf 'HISTORY_IGNORE=%s\n' \"\$HISTORY_IGNORE\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "^HISTFILE=${HOME}/.zsh_history$"
	echo "${output}" | grep -Fq "HISTORY_IGNORE=${shared}"
}

@test "platform.zsh:: nested source does not duplicate /usr/local/bin" {
	# Controlled PATH so host duplicates do not mask prepend-once behavior.
	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZSH="${ZSH}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
		PATH="/usr/bin:/bin" \
		zsh -c "
		source '${SCRIPT}' || exit 1
		first=\"\${PATH}\"
		source '${ZANGARMARSH_ROOT}/profile/zsh/platform.zsh' || exit 1
		second=\"\${PATH}\"
		printf 'FIRST=%s\n' \"\${first}\"
		printf 'SECOND=%s\n' \"\${second}\"
	"
	[[ "${status}" -eq 0 ]]
	local first second
	first="$(echo "${output}" | sed -n 's/^FIRST=//p')"
	second="$(echo "${output}" | sed -n 's/^SECOND=//p')"
	[[ "${first}" == "${second}" ]]
	local count
	count="$(echo ":${first}:" | tr ':' '\n' | grep -cx '/usr/local/bin')"
	[[ "${count}" -eq 1 ]]
}

@test "integration:: profile loads Oh My Zsh with git and autosuggestions" {
	run zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'STYLE=%s\n' \"\$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE\"
		printf 'GA=%s\n' \"\$(alias ga 2>/dev/null || true)\"
		printf 'PLUGINS=%s\n' \"\${plugins[*]}\"
		type build_prompt >/dev/null && printf 'PROMPT_FN=1\n'
		zstyle -t ':completion:*:*:*:*:*' menu select && printf 'MENU=1\n'
		bindkey '^[[A' | grep -q up-line-or-beginning-search && printf 'UP_SEARCH=1\n'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "fg=8"
	echo "${output}" | grep -q "^GA=.*git add"
	echo "${output}" | grep -q "git"
	echo "${output}" | grep -q "zsh-autosuggestions"
	echo "${output}" | grep -q "^PROMPT_FN=1$"
	echo "${output}" | grep -q "^MENU=1$"
	echo "${output}" | grep -q "^UP_SEARCH=1$"
}

@test "integration:: history knobs win after Oh My Zsh lib/history.zsh" {
	run zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'HISTFILE=%s\n' \"\$HISTFILE\"
		printf 'HISTSIZE=%s\n' \"\$HISTSIZE\"
		printf 'SAVEHIST=%s\n' \"\$SAVEHIST\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "^HISTFILE=${HOME}/.zsh_history$"
	echo "${output}" | grep -q "^HISTSIZE=100000$"
	echo "${output}" | grep -q "^SAVEHIST=100000$"
}

@test "integration:: profile warns when Oh My Zsh is missing" {
	rm -rf "${ZSH}"
	run zsh -c "source '${SCRIPT}'"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Oh My Zsh is not installed"
}
