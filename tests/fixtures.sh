#!/usr/bin/env bash
#
# Shared Bats fixtures for the Zangarmarsh harness.
# Callers must set GIT_ROOT before sourcing this file.
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

	_ZANGARMARSH_SHARED_FIXTURES_LOADED=1
	export _ZANGARMARSH_SHARED_FIXTURES_LOADED

	return 0
}

# Create a mock git repository for testing purposes
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
}

# Tests must set GIT_ROOT before sourcing this file.
if [[ "${_ZANGARMARSH_SHARED_FIXTURES_LOADED:-}" != "1" ]]; then
	load_shared_fixtures || return 1
fi
