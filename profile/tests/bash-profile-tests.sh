#!/usr/bin/env bats
#
# Tests for profile/bash/profile.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/bash/profile.sh"
	export SCRIPT

	return 0
}

# Point HOME at a temp directory for each bash profile test
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

@test "bash_profile:: sets history variables" {
	run bash -c "
		ZANGARMARSH_ROOT='${ZANGARMARSH_ROOT}'
		export ZANGARMARSH_ROOT
		source '${SCRIPT}' && printf 'SIZE=%s\nFILESIZE=%s\n' \"\$HISTSIZE\" \"\$HISTFILESIZE\"
	"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "^SIZE=100000$"
	echo "$output" | grep -q "^FILESIZE=100000$"
}

@test "bash_profile:: forces HISTFILE over an inherited zsh path" {
	run bash -c "
		HOME='${HOME}'
		export HOME
		ZANGARMARSH_ROOT='${ZANGARMARSH_ROOT}'
		export ZANGARMARSH_ROOT
		HISTFILE=\"\${HOME}/.zsh_history\"
		export HISTFILE
		source '${SCRIPT}' || exit 1
		printf 'HISTFILE=%s\n' \"\$HISTFILE\"
		printf 'HISTIGNORE=%s\n' \"\$HISTIGNORE\"
	"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "^HISTFILE=${HOME}/.bash_history$"
	echo "$output" | grep -q 'set \*'
}

@test "bash_profile:: HISTIGNORE comes from shared config.sh" {
	local shared
	shared="$(bash -c "source '${ZANGARMARSH_ROOT}/profile/config.sh' && printf '%s' \"\$ZANGARMARSH_HIST_IGNORE\"")"

	run bash -c "
		ZANGARMARSH_ROOT='${ZANGARMARSH_ROOT}'
		export ZANGARMARSH_ROOT
		source '${SCRIPT}' || exit 1
		printf 'HISTIGNORE=%s\n' \"\$HISTIGNORE\"
		printf 'HISTFILE=%s\n' \"\$HISTFILE\"
	"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -Fq "HISTIGNORE=${shared}"
	echo "$output" | grep -q "^HISTFILE=${HOME}/.bash_history$"
}
