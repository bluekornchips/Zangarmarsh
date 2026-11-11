#!/usr/bin/env bats
#
# Tests for profile/config.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/config.sh"
	export SCRIPT

	return 0
}

# Point HOME at a temp directory for each config test
#
# Side Effects:
# - Exports HOME to a new directory under BATS_TEST_TMPDIR
#
# Returns:
# - 0 on success
# - 1 when the temp HOME cannot be created
setup() {
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1
	use_temp_home || return 1
	return 0
}

@test "config:: sets shared history and feature defaults" {
	run bash -c "
		unset ZANGARMARSH_HISTSIZE ZANGARMARSH_HIST_IGNORE
		unset ZANGARMARSH_BASH_HISTFILE ZANGARMARSH_ZSH_HISTFILE
		unset ZANGARMARSH_LAZY_LOADING ZANGARMARSH_ENABLE_NVM
		unset ZANGARMARSH_ZSH_AUTOSUGGESTIONS
		source '${SCRIPT}' || exit 1
		printf 'HISTSIZE=%s\n' \"\$ZANGARMARSH_HISTSIZE\"
		printf 'IGNORE=%s\n' \"\$ZANGARMARSH_HIST_IGNORE\"
		printf 'BASH_HIST=%s\n' \"\$ZANGARMARSH_BASH_HISTFILE\"
		printf 'ZSH_HIST=%s\n' \"\$ZANGARMARSH_ZSH_HISTFILE\"
		printf 'LAZY=%s\n' \"\$ZANGARMARSH_LAZY_LOADING\"
		printf 'NVM=%s\n' \"\$ZANGARMARSH_ENABLE_NVM\"
		printf 'SUGGEST=%s\n' \"\$ZANGARMARSH_ZSH_AUTOSUGGESTIONS\"
	"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q '^HISTSIZE=100000$'
	echo "$output" | grep -Fq 'IGNORE=ls:ll:cd:pwd:clear:history:set *'
	echo "$output" | grep -q "^BASH_HIST=${HOME}/.bash_history$"
	echo "$output" | grep -q "^ZSH_HIST=${HOME}/.zsh_history$"
	echo "$output" | grep -q '^LAZY=true$'
	echo "$output" | grep -q '^NVM=true$'
	echo "$output" | grep -q "^SUGGEST=${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh$"
}

@test "config:: preserves existing overrides" {
	run bash -c "
		ZANGARMARSH_HISTSIZE=12
		export ZANGARMARSH_HISTSIZE
		ZANGARMARSH_HIST_IGNORE='foo'
		export ZANGARMARSH_HIST_IGNORE
		source '${SCRIPT}' || exit 1
		printf 'HISTSIZE=%s\n' \"\$ZANGARMARSH_HISTSIZE\"
		printf 'IGNORE=%s\n' \"\$ZANGARMARSH_HIST_IGNORE\"
	"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q '^HISTSIZE=12$'
	echo "$output" | grep -q '^IGNORE=foo$'
}

@test "config:: histfile paths follow the current HOME" {
	run bash -c "
		ZANGARMARSH_ZSH_HISTFILE='/stale/.zsh_history'
		export ZANGARMARSH_ZSH_HISTFILE
		ZANGARMARSH_BASH_HISTFILE='/stale/.bash_history'
		export ZANGARMARSH_BASH_HISTFILE
		HOME='/tmp/zangarmarsh-config-home'
		export HOME
		source '${SCRIPT}' || exit 1
		printf 'BASH_HIST=%s\n' \"\$ZANGARMARSH_BASH_HISTFILE\"
		printf 'ZSH_HIST=%s\n' \"\$ZANGARMARSH_ZSH_HISTFILE\"
	"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q '^BASH_HIST=/tmp/zangarmarsh-config-home/.bash_history$'
	echo "$output" | grep -q '^ZSH_HIST=/tmp/zangarmarsh-config-home/.zsh_history$'
}
