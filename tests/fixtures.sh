#!/usr/bin/env bash
#
# Shared Bats fixtures for the Zangarmarsh harness.
# Prefer setting GIT_ROOT before sourcing; when unset, zangarmarsh_bats_setup_file resolves it.
#

# Validate GIT_ROOT and align ZANGARMARSH_ROOT for tests
#
# Reads environment:
# - GIT_ROOT, required
# - ZANGARMARSH_ROOT, optional; defaults to GIT_ROOT
#
# Side Effects:
# - Exports GIT_ROOT and ZANGARMARSH_ROOT
#
# Returns:
# - 0 on success
# - 1 when GIT_ROOT is unset
load_shared_fixtures() {
	if [[ -z "${GIT_ROOT:-}" ]]; then
		echo "load_shared_fixtures:: GIT_ROOT is required" >&2
		return 1
	fi

	ZANGARMARSH_ROOT="${ZANGARMARSH_ROOT:-${GIT_ROOT}}"
	export GIT_ROOT
	export ZANGARMARSH_ROOT

	# Opt into non-interactive source for bats. Production shells leave this unset.
	ZANGARMARSH_TEST=1
	export ZANGARMARSH_TEST

	_ZANGARMARSH_SHARED_FIXTURES_LOADED=1
	export _ZANGARMARSH_SHARED_FIXTURES_LOADED

	return 0
}

# Create a mock git repository for testing purposes
#
# Inputs:
# - $1 test_dir, existing empty directory that becomes the repository root
#
# Side Effects:
# - Changes the working directory to test_dir
#
# Returns:
# - 0 on success
# - 1 when test_dir does not exist
create_mock_git_repo() {
	local test_dir="$1"

	cd "$test_dir" || {
		echo "create_mock_git_repo:: test_dir does not exist: ${test_dir}" >&2
		return 1
	}

	git init >/dev/null 2>&1
	git config user.name "Test User" >/dev/null 2>&1
	git config user.email "test@example.test" >/dev/null 2>&1
	echo "test content" >test_file
	git add test_file >/dev/null 2>&1
	git commit -m "Initial commit" >/dev/null 2>&1

	return 0
}

# Create a mock repository and a linked worktree on a new branch
#
# Git-touching tests run inside the linked worktree so they never touch the
# real checkout and still exercise a worktree layout, where .git is a file.
#
# Inputs:
# - $1 repo_dir, existing empty directory for the main repository
# - $2 worktree_dir, path for the linked worktree, must not exist
# - $3 branch, new branch checked out in the worktree
#
# Side Effects:
# - Changes the working directory to repo_dir
#
# Returns:
# - 0 on success
# - 1 when the repository or worktree cannot be created
create_mock_worktree() {
	local repo_dir="$1"
	local worktree_dir="$2"
	local branch="$3"

	if [[ -z "${repo_dir}" || -z "${worktree_dir}" || -z "${branch}" ]]; then
		echo "create_mock_worktree:: repo_dir, worktree_dir, and branch are required" >&2
		return 1
	fi

	create_mock_git_repo "${repo_dir}" || return 1

	if ! git worktree add -q -b "${branch}" "${worktree_dir}" >/dev/null 2>&1; then
		echo "create_mock_worktree:: failed to add worktree: ${worktree_dir}" >&2
		return 1
	fi

	return 0
}

# Seed a stub zsh-autosuggestions install under HOME
#
# Reads environment:
# - HOME
# - ZANGARMARSH_ZSH_AUTOSUGGESTIONS, optional override path
#
# Side Effects:
# - Creates the autosuggestions script at the configured path
#
# Returns:
# - 0 on success
# - 1 when HOME is unset or the parent directory cannot be created
seed_zsh_autosuggestions_stub() {
	if [[ -z "${HOME:-}" ]]; then
		echo "seed_zsh_autosuggestions_stub:: HOME is required" >&2
		return 1
	fi

	local suggest_path="${ZANGARMARSH_ZSH_AUTOSUGGESTIONS:-${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh}"
	local suggest_dir
	suggest_dir="$(dirname "${suggest_path}")"

	mkdir -p "${suggest_dir}" || {
		echo "seed_zsh_autosuggestions_stub:: cannot create ${suggest_dir}" >&2
		return 1
	}

	printf '# autosuggestions stub\n' >"${suggest_path}"

	return 0
}

# Resolve GIT_ROOT from the current worktree and load shared fixtures
#
# Side Effects:
# - Exports GIT_ROOT and ZANGARMARSH_ROOT
#
# Returns:
# - 0 on success
# - 1 when git root cannot be determined
zangarmarsh_bats_setup_file() {
	if [[ -z "${GIT_ROOT:-}" ]]; then
		if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
			echo "zangarmarsh_bats_setup_file:: Failed to get git root" >&2
			return 1
		fi
	fi

	load_shared_fixtures || return 1

	return 0
}

# Source a library during setup without leaving Bats errexit disabled
#
# Inputs:
# - $1, path to source
#
# Side Effects:
# - Sources the file with errexit suspended
# - Restores errexit afterwards
#
# Returns:
# - The sourced file's status
source_for_test() {
	set +e
	# shellcheck disable=SC1090
	source "$1"
	local source_status=$?
	set -e

	return "${source_status}"
}

if [[ "${_ZANGARMARSH_SHARED_FIXTURES_LOADED:-}" != "1" ]]; then
	zangarmarsh_bats_setup_file || return 1
fi
