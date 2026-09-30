#!/usr/bin/env bats
#
# Tests for profile/bash/profile.sh
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"
	SCRIPT="${ZANGARMARSH_ROOT}/profile/bash/profile.sh"
	export SCRIPT

	return 0
}

@test "bash profile:: sets history variables" {
	run bash -c "source '${SCRIPT}' && printf 'SIZE=%s\nFILESIZE=%s\n' \"\$HISTSIZE\" \"\$HISTFILESIZE\""
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "^SIZE=100000$"
	echo "$output" | grep -q "^FILESIZE=100000$"
}
