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

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	TEST_DIR="$(mktemp -d "${base}/prompt-test.XXXXXX")"
	export TEST_DIR

	return 0
}

teardown() {
	rm -rf "${TEST_DIR}"
	return 0
}

@test "prompt:: sources and defines prompt helpers" {
	run zsh -c "
		source '${SCRIPT}' || exit 1
		printf 'PROMPT=%s\n' \"\$PROMPT\"
		type build_prompt
		type _prompt_git_from_head
		type _prompt_git_info
		type _zangarmarsh_precmd_prompt
	"
	[[ "${status}" -eq 0 ]]
	local expected_prompt="PROMPT=\${_prompt_rendered}"
	echo "${output}" | grep -Fq "${expected_prompt}"
	echo "${output}" | grep -q 'build_prompt'
	echo "${output}" | grep -q '_prompt_git_from_head'
	echo "${output}" | grep -q '_prompt_git_info'
	echo "${output}" | grep -q '_zangarmarsh_precmd_prompt'
}

@test "build_prompt:: second call within TTL reuses the kubectl cache" {
	local mock_bin="${TEST_DIR}/bin"
	local call_log="${TEST_DIR}/kubectl-calls"
	mkdir -p "${mock_bin}"
	: >"${call_log}"
	cat >"${mock_bin}/kubectl" <<EOF
#!/usr/bin/env bash
echo "call" >>"${call_log}"
echo "mock-context"
EOF
	chmod +x "${mock_bin}/kubectl"

	run env PATH="${mock_bin}:${PATH}" ZANGARMARSH_PROMPT_CACHE_TTL=60 zsh -c "
		source '${SCRIPT}' || exit 1
		build_prompt >/dev/null
		build_prompt >/dev/null
		wc -l <'${call_log}'
	"
	[[ "${status}" -eq 0 ]]
	[[ "$(echo "${output}" | tr -d '[:space:]')" == "1" ]]
}

@test "_prompt_git_from_head:: nested cwd does not leak git_dir= into stdout" {
	local repo_dir="${TEST_DIR}/repo"
	local worktree_dir="${TEST_DIR}/worktree"
	local nested_dir="${worktree_dir}/a/b/c"
	local branch="prompt-nested-leak"

	mkdir -p "${repo_dir}"
	if ! create_mock_worktree "${repo_dir}" "${worktree_dir}" "${branch}"; then
		return 1
	fi
	mkdir -p "${nested_dir}"

	run zsh -c "
		cd '${nested_dir}' || exit 1
		source '${SCRIPT}' || exit 1
		_prompt_git_info
	"
	[[ "${status}" -eq 0 ]]
	[[ "${output}" != *git_dir=* ]]
	[[ "${output}" != *$'\n'* ]]
	[[ "${output}" == " (${branch})" ]]
}
