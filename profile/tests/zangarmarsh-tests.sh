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

@test "zangarmarsh:: refuses a non-interactive bash source" {
	run env -u ZANGARMARSH_TEST bash --noprofile --norc -c "source '${SCRIPT}'"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "zangarmarsh:: interactive shell required"
}

@test "zangarmarsh:: refuses a non-interactive zsh source" {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	run env -u ZANGARMARSH_TEST zsh -c "source '${SCRIPT}'"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "zangarmarsh:: interactive shell required"
}

@test "zangarmarsh:: sets ZANGARMARSH_ROOT and leaves VERBOSE unset by default" {
	run env -u ZANGARMARSH_VERBOSE bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		printf 'ROOT=%s\n' \"\${ZANGARMARSH_ROOT}\"
		printf 'VERBOSE=%s\n' \"\${ZANGARMARSH_VERBOSE-__unset__}\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q '^ROOT=.'
	echo "${output}" | grep -q '^VERBOSE=__unset__$'
}

@test "zangarmarsh:: preserves an existing ZANGARMARSH_VERBOSE value" {
	run env ZANGARMARSH_VERBOSE=true bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		printf '%s\n' \"\${ZANGARMARSH_VERBOSE}\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -qx 'true'
}

@test "zangarmarsh:: second source of the same root is a no-op" {
	run bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		first_root=\"\${ZANGARMARSH_ROOT}\"
		[[ \"\${ZANGARMARSH_LOADED_ROOT}\" == \"\${first_root}\" ]] || exit 2
		source '${SCRIPT}' || exit 1
		[[ \"\${ZANGARMARSH_ROOT}\" == \"\${first_root}\" ]] || exit 3
		[[ \"\${ZANGARMARSH_LOADED_ROOT}\" == \"\${first_root}\" ]] || exit 4
		printf 'ROOT=%s\n' \"\${first_root}\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q '^ROOT=.'
}

@test "zangarmarsh:: does not export the loaded-root guard" {
	run bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		[[ \"\${ZANGARMARSH_LOADED_ROOT}\" == \"\${ZANGARMARSH_ROOT}\" ]] || exit 2
		bash --noprofile --norc -c 'printf \"CHILD=%s\\n\" \"\${ZANGARMARSH_LOADED_ROOT:-}\"'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -qx 'CHILD='
}

@test "zangarmarsh:: root follows the sourced script directory" {
	local origin
	origin="$(cd "$(dirname "${SCRIPT}")" && pwd)"
	ln -s "${origin}/profile" "${TEST_DIR}/profile"
	ln -s "${origin}/tools" "${TEST_DIR}/tools"
	cp "${SCRIPT}" "${TEST_DIR}/zangarmarsh.sh"

	run bash --noprofile --norc -c "
		source '${TEST_DIR}/zangarmarsh.sh' || exit 1
		printf 'ROOT=%s\n' \"\${ZANGARMARSH_ROOT}\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -qx "ROOT=${TEST_DIR}"
}

@test "zangarmarsh:: keeps script-dir root when CWD is another git worktree" {
	local other_repo="${TEST_DIR}/other-repo"
	local other_worktree="${TEST_DIR}/other-worktree"
	local expected_root
	expected_root="$(cd "$(dirname "${SCRIPT}")" && pwd)"

	mkdir -p "${other_repo}"
	if ! create_mock_worktree "${other_repo}" "${other_worktree}" "other-branch"; then
		return 1
	fi

	run bash --noprofile --norc -c "
		cd '${other_worktree}' || exit 1
		unset ZANGARMARSH_VERBOSE
		source '${SCRIPT}' || exit 1
		printf 'ROOT=%s\n' \"\${ZANGARMARSH_ROOT}\"
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -qx "ROOT=${expected_root}"
}

@test "integration:: bash parent still allows a child zsh to load the prompt" {
	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local home
	home="$(mktemp -d "${base}/zsh-from-bash.XXXXXX")" || return 1
	printf 'source "%s"\n' "${SCRIPT}" >"${home}/.zshrc"
	touch "${home}/.zcompdump"
	HOME="${home}" seed_zsh_autosuggestions_stub || return 1

	run env HOME="${home}" ZDOTDIR="${home}" zsh -c "
		source '${home}/.zshrc' || exit 1
		print -r -- \"\${PROMPT}\"
		type build_prompt
	"
	local cmd_status="${status}"
	rm -rf "${home}"
	[[ "${cmd_status}" -eq 0 ]]
	local expected_prompt="\${_prompt_rendered}"
	echo "${output}" | grep -Fq "${expected_prompt}"
	echo "${output}" | grep -q 'build_prompt is a shell function'
}
