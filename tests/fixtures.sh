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

# Seed a minimal Oh My Zsh tree for zsh profile and smoke tests
#
# Inputs:
# - $1 zsh_home, optional install root, defaults to ZSH
#
# Side Effects:
# - Creates oh-my-zsh.sh, lib stubs, and git and zsh-autosuggestions plugin stubs
#
# Returns:
# - 0 on success
# - 1 when no install root is available
seed_omz_stub() {
	local zsh_home="${1:-${ZSH:-}}"

	if [[ -z "${zsh_home}" ]]; then
		echo "seed_omz_stub:: zsh_home or ZSH is required" >&2
		return 1
	fi

	mkdir -p "${zsh_home}/lib" "${zsh_home}/plugins/git" "${zsh_home}/plugins/zsh-autosuggestions"
	cat >"${zsh_home}/oh-my-zsh.sh" <<'EOF'
for _zangarmarsh_lib in "${ZSH}"/lib/*.zsh(N); do
	source "${_zangarmarsh_lib}"
done
unset _zangarmarsh_lib
for _zangarmarsh_plugin in ${plugins}; do
	_zangarmarsh_plugin_file="${ZSH}/plugins/${_zangarmarsh_plugin}/${_zangarmarsh_plugin}.plugin.zsh"
	[[ -f "${_zangarmarsh_plugin_file}" ]] && source "${_zangarmarsh_plugin_file}"
done
unset _zangarmarsh_plugin _zangarmarsh_plugin_file
EOF
	printf 'zstyle ":completion:*:*:*:*:*" menu select\nsetopt auto_menu\n' >"${zsh_home}/lib/completion.zsh"
	cat >"${zsh_home}/lib/key-bindings.zsh" <<'EOF'
autoload -U up-line-or-beginning-search
zle -N up-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
EOF
	# Mimic Oh My Zsh lib/history.zsh overwriting caller history knobs.
	cat >"${zsh_home}/lib/history.zsh" <<'EOF'
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
EOF
	printf 'git_current_branch() { echo main; }\n' >"${zsh_home}/lib/git.zsh"
	printf 'alias ga="git add"\n' >"${zsh_home}/plugins/git/git.plugin.zsh"
	printf '# autosuggestions stub\n' >"${zsh_home}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

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

# Source a library during setup without leaving Bats traps disabled
#
# Inputs:
# - $1, path to source
#
# Side Effects:
# - Sources the file with errexit and the EXIT/ERR traps suspended
# - Restores those traps and errexit afterwards
#
# Returns:
# - The sourced file's status
source_for_test() {
	# Suspend errexit only. Sourced libraries under test do not install EXIT/ERR
	# traps at source time, so clearing and restoring those traps is unnecessary.
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
