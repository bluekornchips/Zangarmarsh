#!/usr/bin/env bats
#
# Unit and integration tests for zangarmarsh.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
	export SCRIPT

	return 0
}

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	source "${GIT_ROOT}/tests/fixtures.sh"

	TEST_DIR="$(mktemp -d "${base}/zangarmarsh-test.XXXXXX")"
	TEST_DIR="$(cd "${TEST_DIR}" && pwd)"
	export TEST_DIR
	unset ZANGARMARSH_LOADED_ROOT

	return 0
}

teardown() {
	rm -rf "${TEST_DIR}"

	return 0
}

@test "zangarmarsh:: refuses execution" {
	run bash "${SCRIPT}"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "zangarmarsh:: source this file instead of executing it"
}

@test "zangarmarsh:: sets ZANGARMARSH_ROOT and leaves VERBOSE unset by default" {
	unset ZANGARMARSH_VERBOSE
	source "${SCRIPT}"
	[[ -n "${ZANGARMARSH_ROOT}" ]]
	[[ -z "${ZANGARMARSH_VERBOSE:-}" ]]
}

@test "zangarmarsh:: preserves an existing ZANGARMARSH_VERBOSE value" {
	ZANGARMARSH_VERBOSE=true
	export ZANGARMARSH_VERBOSE
	source "${SCRIPT}"
	[[ "${ZANGARMARSH_VERBOSE}" == "true" ]]
}

@test "zangarmarsh:: second source of the same root is a no-op" {
	source "${SCRIPT}"
	local first_root="${ZANGARMARSH_ROOT}"
	[[ "${ZANGARMARSH_LOADED_ROOT}" == "${first_root}" ]]

	source "${SCRIPT}"
	[[ "${ZANGARMARSH_ROOT}" == "${first_root}" ]]
	[[ "${ZANGARMARSH_LOADED_ROOT}" == "${first_root}" ]]
}

@test "zangarmarsh:: does not export the loaded-root guard" {
	source "${SCRIPT}"
	[[ "${ZANGARMARSH_LOADED_ROOT}" == "${ZANGARMARSH_ROOT}" ]]

	run bash -c 'printf "%s\n" "${ZANGARMARSH_LOADED_ROOT:-}"'
	[[ "${status}" -eq 0 ]]
	[[ -z "${output}" ]]
}

@test "zangarmarsh:: root follows the sourced script directory" {
	local origin
	origin="$(cd "$(dirname "${SCRIPT}")" && pwd)"
	ln -s "${origin}/profile" "${TEST_DIR}/profile"
	ln -s "${origin}/tools" "${TEST_DIR}/tools"
	cp "${SCRIPT}" "${TEST_DIR}/zangarmarsh.sh"

	source "${TEST_DIR}/zangarmarsh.sh"
	[[ "${ZANGARMARSH_ROOT}" == "${TEST_DIR}" ]]
}

@test "zangarmarsh:: keeps script-dir root when CWD is another git repo" {
	local other_repo
	other_repo="$(mktemp -d "${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}/other-git.XXXXXX")"
	local expected_root
	expected_root="$(cd "$(dirname "${SCRIPT}")" && pwd)"
	create_mock_git_repo "${other_repo}"
	cd "${other_repo}" || return 1

	run bash -c "unset ZANGARMARSH_VERBOSE; source '${SCRIPT}' && printf '%s\n' \"\${ZANGARMARSH_ROOT}\""
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${expected_root}" ]]

	cd - >/dev/null || return 1
	rm -rf "${other_repo}"
}

@test "integration:: bash parent still allows a child zsh to load the prompt" {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local home
	home="$(mktemp -d "${base}/zsh-from-bash.XXXXXX")" || return 1
	printf 'source "%s"\n' "${SCRIPT}" >"${home}/.zshrc"
	touch "${home}/.zcompdump"
	mkdir -p "${home}/.oh-my-zsh/lib" "${home}/.oh-my-zsh/plugins/git" \
		"${home}/.oh-my-zsh/plugins/zsh-autosuggestions"
	printf 'git_current_branch() { echo main; }\n' >"${home}/.oh-my-zsh/lib/git.zsh"
	printf 'alias ga="git add"\n' >"${home}/.oh-my-zsh/plugins/git/git.plugin.zsh"
	printf '# autosuggestions stub\n' >"${home}/.oh-my-zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

	source "${SCRIPT}"

	run env HOME="${home}" ZDOTDIR="${home}" ZSH="${home}/.oh-my-zsh" \
		zsh -i -c 'print -r -- "${PROMPT}"; type build_prompt'
	local cmd_status="${status}"
	rm -rf "${home}"
	[[ "${cmd_status}" -eq 0 ]]
	echo "${output}" | grep -Fq '$(build_prompt)'
	echo "${output}" | grep -q 'build_prompt is a shell function'
}
