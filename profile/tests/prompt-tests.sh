#!/usr/bin/env bats
#
# Unit tests for profile/zsh/prompt.zsh
#

setup_file() {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh"
	export SCRIPT

	return 0
}

@test "prompt:: sources and defines prompt helpers" {
	run zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'PROMPT=%s\n' \"\$PROMPT\"
		type build_prompt
		type _prompt_git_from_head
		type _prompt_git_info
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Fq 'PROMPT=$(build_prompt)'
	echo "${output}" | grep -q 'build_prompt'
	echo "${output}" | grep -q '_prompt_git_from_head'
	echo "${output}" | grep -q '_prompt_git_info'
}
