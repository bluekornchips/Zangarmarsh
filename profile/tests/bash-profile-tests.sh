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

setup() {
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

@test "bash_profile:: fails when required history config is empty" {
	local stub_root
	stub_root="$(mktemp -d "${TMPDIR:-/tmp}/zangarmarsh-bash-profile.XXXXXX")" || return 1
	mkdir -p "${stub_root}/profile" || return 1
	cat >"${stub_root}/profile/config.sh" <<'EOF'
ZANGARMARSH_BASH_HISTFILE=""
export ZANGARMARSH_BASH_HISTFILE
ZANGARMARSH_HISTSIZE=""
export ZANGARMARSH_HISTSIZE
ZANGARMARSH_HISTCONTROL=""
export ZANGARMARSH_HISTCONTROL
ZANGARMARSH_HIST_IGNORE=""
export ZANGARMARSH_HIST_IGNORE
EOF

	run bash -c "
		ZANGARMARSH_ROOT='${stub_root}'
		export ZANGARMARSH_ROOT
		source '${SCRIPT}'
	"
	rm -rf "${stub_root}"

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "ZANGARMARSH_BASH_HISTFILE is required"
}
