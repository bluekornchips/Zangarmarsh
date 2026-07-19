#!/usr/bin/env bats

# Test file for gw function in profile/functions.sh
# Uses isolated temp git repos only. Never run gw shortcut tests from the real checkout cwd.

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/functions.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

source "$GIT_ROOT/profile/tests/fixtures.sh"

setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/gw-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	source "$SCRIPT"

	export TEST_DIR
}

teardown() {
	if [[ -n "${TEST_DIR}" && -d "${TEST_DIR}" ]]; then
		local git_root
		git_root="$(git -C "${TEST_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
		if [[ -n "${git_root}" ]]; then
			local wt_path
			while IFS= read -r wt_path; do
				[[ -z "${wt_path}" ]] && continue
				[[ "${wt_path}" == "${git_root}" ]] && continue
				git -C "${git_root}" worktree remove --force "${wt_path}" 2>/dev/null || true
			done < <(git -C "${git_root}" worktree list --porcelain 2>/dev/null | awk '/^worktree / { print $2 }')
		fi
		rm -rf "${TEST_DIR}"
	fi
}

@test "gw:: returns 1 when not in a git repository" {
	run gw feature-one
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "gw:: not in a git repository"
}

@test "gw:: passes add through from repository root" {
	local repo_dir="${TEST_DIR}/repo"
	local worktree_dir="${TEST_DIR}/add-root"

	mkdir -p "${repo_dir}"
	create_mock_git_repo "${repo_dir}"
	cd "${repo_dir}" || return 1

	run gw add "${worktree_dir}" HEAD
	[[ "$status" -eq 0 ]]
	[[ -d "${worktree_dir}" ]]
}

@test "gw:: passes add through from subdirectory" {
	local repo_dir="${TEST_DIR}/repo"
	local worktree_dir="${TEST_DIR}/add-subdir"

	mkdir -p "${repo_dir}"
	create_mock_git_repo "${repo_dir}"
	mkdir -p "${repo_dir}/subdir"
	cd "${repo_dir}/subdir" || return 1

	run gw add "${worktree_dir}" HEAD
	[[ "$status" -eq 0 ]]
	[[ -d "${worktree_dir}" ]]
}

@test "gw:: passes remove through to git worktree" {
	local repo_dir="${TEST_DIR}/repo"
	local worktree_dir="${TEST_DIR}/remove-me"

	mkdir -p "${repo_dir}"
	create_mock_git_repo "${repo_dir}"
	git -C "${repo_dir}" worktree add "${worktree_dir}" HEAD >/dev/null 2>&1
	cd "${repo_dir}" || return 1

	run gw remove "${worktree_dir}"
	[[ "$status" -eq 0 ]]
	[[ ! -d "${worktree_dir}" ]]
}

@test "gw:: creates worktree from current branch when base is omitted" {
	local repo_dir="${TEST_DIR}/repo"
	local worktree_dir="${repo_dir}/../feature-one"

	mkdir -p "${repo_dir}"
	create_mock_git_repo "${repo_dir}"
	local current_branch
	current_branch="$(git -C "${repo_dir}" branch --show-current)"
	cd "${repo_dir}" || return 1

	run gw feature-one
	[[ "$status" -eq 0 ]]
	[[ -d "${worktree_dir}" ]]
	[[ "$(git -C "${worktree_dir}" branch --show-current)" == "feature-one" ]]
	[[ "$(git -C "${worktree_dir}" merge-base feature-one "${current_branch}")" == "$(git -C "${repo_dir}" rev-parse "${current_branch}")" ]]
}

@test "gw:: creates worktree from explicit base branch" {
	local repo_dir="${TEST_DIR}/repo"
	local worktree_dir="${repo_dir}/../feature-two"

	mkdir -p "${repo_dir}"
	create_mock_git_repo "${repo_dir}"
	git -C "${repo_dir}" checkout -b base-branch >/dev/null 2>&1
	echo "base content" >"${repo_dir}/base_file"
	git -C "${repo_dir}" add base_file >/dev/null 2>&1
	git -C "${repo_dir}" commit -m "Base commit" >/dev/null 2>&1
	cd "${repo_dir}" || return 1

	run gw feature-two base-branch
	[[ "$status" -eq 0 ]]
	[[ -d "${worktree_dir}" ]]
	[[ -f "${worktree_dir}/base_file" ]]
	[[ "$(git -C "${worktree_dir}" branch --show-current)" == "feature-two" ]]
}

@test "gw:: fails when shortcut receives too many arguments" {
	create_mock_git_repo "${TEST_DIR}"
	cd "${TEST_DIR}" || return 1

	run gw feature-three base-branch extra-arg
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"gw:: shortcut accepts at most two arguments"* ]]
}

@test "gw:: fails when no shortcut name is provided" {
	create_mock_git_repo "${TEST_DIR}"
	cd "${TEST_DIR}" || return 1

	run gw
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"gw:: name is required unless using add or remove"* ]]
}
