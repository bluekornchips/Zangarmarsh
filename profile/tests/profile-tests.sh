#!/usr/bin/env bats
#
# Unit and integration tests for profile/zsh/profile.zsh
#

# Prepare shared paths for profile.zsh tests
#
# Side Effects:
# - Exports SCRIPT
#
# Returns:
# - 0 on success
# - skips when zsh is missing
setup_file() {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/zsh/profile.zsh"
	export SCRIPT

	return 0
}

# Isolate HOME and seed autosuggestions for one profile test
#
# Side Effects:
# - Exports HOME, ZDOTDIR, USER, HOSTNAME, and PWD under a temp HOME
#
# Returns:
# - 0 on success
setup() {
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	use_temp_home || return 1
	cd "${HOME}" || return 1

	USER="testuser"
	export USER
	HOSTNAME="testhost"
	export HOSTNAME
	ZDOTDIR="${HOME}"
	export ZDOTDIR
	PWD="${HOME}"
	export PWD
	printf '\n' >"${ZDOTDIR}/.zshrc"
	touch "${ZDOTDIR}/.zcompdump"
	export ZANGARMARSH_ROOT

	seed_zsh_autosuggestions_stub || return 1

	return 0
}

@test "profile:: forces HISTFILE over an inherited bash path and sets HISTORY_IGNORE" {
	local shared
	shared="$(bash -c "source '${ZANGARMARSH_ROOT}/profile/config.sh' && printf '%s' \"\$ZANGARMARSH_HIST_IGNORE\"")"
	shared="(${shared//:/|})"

	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
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

@test "platform.zsh:: nested source does not duplicate PATH entries" {
	# Controlled PATH so host duplicates do not mask prepend-once behavior.
	run env HOME="${HOME}" ZDOTDIR="${ZDOTDIR}" ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT}" \
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
	local duplicates
	duplicates="$(echo "${second}" | tr ':' '\n' | sort | uniq -d)"
	[[ -z "${duplicates}" ]]
}

@test "integration:: profile loads completion, autosuggestions, and prompt" {
	run zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'STYLE=%s\n' \"\$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE\"
		printf 'SUGGEST=%s\n' \"\$ZANGARMARSH_ZSH_AUTOSUGGESTIONS\"
		type build_prompt >/dev/null && printf 'PROMPT_FN=1\n'
		zstyle -t ':completion:*:*:*:*:*' menu select && printf 'MENU=1\n'
		bindkey '^[[A' | grep -q up-line-or-beginning-search && printf 'UP_SEARCH=1\n'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "fg=8"
	echo "${output}" | grep -q "zsh-autosuggestions"
	echo "${output}" | grep -q "^PROMPT_FN=1$"
	echo "${output}" | grep -q "^MENU=1$"
	echo "${output}" | grep -q "^UP_SEARCH=1$"
}

@test "integration:: history knobs stay at Zangarmarsh defaults" {
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

@test "integration:: profile warns when zsh-autosuggestions is missing" {
	rm -rf "${HOME}/.zsh"
	run zsh -c "source '${SCRIPT}'"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "zsh-autosuggestions not found"
}
