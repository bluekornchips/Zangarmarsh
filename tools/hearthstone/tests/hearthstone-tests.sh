#!/usr/bin/env bats
#
# Test file for hearthstone.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
	if [[ -z "${GIT_ROOT}" ]]; then
		echo "Failed to get git root" >&2
		return 1
	fi

	SCRIPT="${GIT_ROOT}/tools/hearthstone/hearthstone.sh"
	if [[ ! -f "${SCRIPT}" ]]; then
		echo "Script not found: ${SCRIPT}" >&2
		return 1
	fi

	export GIT_ROOT
	export SCRIPT

	return 0
}

setup() {
	set +e
	trap - EXIT ERR
	source "$SCRIPT"
	trap - EXIT ERR
	set +e

	return 0
}

########################################################
# Mocks
########################################################
mock_commands_success() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local mock_dir

	mock_dir="$(mktemp -d "${base}/hearthstone-mock.XXXXXX")"

	echo '#!/usr/bin/env bash' >"$mock_dir/trilliax.sh"
	echo 'echo "trilliax mocked"' >>"$mock_dir/trilliax.sh"
	chmod +x "$mock_dir/trilliax.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/questlog.sh"
	echo 'echo "questlog mocked"' >>"$mock_dir/questlog.sh"
	chmod +x "$mock_dir/questlog.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"

	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT
}

mock_commands_failure() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local mock_dir

	mock_dir="$(mktemp -d "${base}/hearthstone-mock.XXXXXX")"

	echo '#!/usr/bin/env bash' >"$mock_dir/trilliax.sh"
	echo 'echo "trilliax failed" >&2' >>"$mock_dir/trilliax.sh"
	echo 'exit 1' >>"$mock_dir/trilliax.sh"
	chmod +x "$mock_dir/trilliax.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/questlog.sh"
	echo 'echo "questlog succeeded"' >>"$mock_dir/questlog.sh"
	chmod +x "$mock_dir/questlog.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"

	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT
}

########################################################
# verify_git_repository
########################################################
@test "verify_git_repository:: succeeds with valid directory structure" {
	run verify_git_repository
	[[ "$status" -eq 0 ]]
}

@test "verify_git_repository:: fails when tools directory missing" {
	GIT_ROOT="/nonexistent/path"

	run verify_git_repository
	[[ "$status" -eq 1 ]]

	grep -q "Zangarmarsh root directory not found" <<<"$output"
}

########################################################
# execute_operations
########################################################
@test "execute_operations:: runs all commands successfully without FORCE" {
	mock_commands_success
	FORCE=false
	export FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]

	! grep -q "execute_operations:: Running: trilliax --all" <<<"$output"
	grep -q "execute_operations:: Running: questlog" <<<"$output"
}

@test "execute_operations:: runs all commands including trilliax with FORCE" {
	mock_commands_success
	FORCE=true
	export FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]

	grep -q "execute_operations:: Running: trilliax --all" <<<"$output"
	grep -q "execute_operations:: Running: questlog" <<<"$output"
}

@test "execute_operations:: fails when trilliax fails with FORCE" {
	mock_commands_failure
	FORCE=true
	export FORCE

	run execute_operations
	[[ "$status" -eq 1 ]]

	grep -q "execute_operations:: Failed to execute: trilliax --all" <<<"$output"
}

########################################################
# build_deck
########################################################
@test "build_deck:: succeeds when jq is installed" {
	ensure_jq() {
		echo "ensure_jq:: jq installed"
		return 0
	}
	export -f ensure_jq

	run build_deck
	[[ "$status" -eq 0 ]]
}

@test "build_deck:: succeeds when ensure_jq succeeds after missing PATH check" {
	ensure_jq() {
		echo "ensure_jq:: jq installed"
		return 0
	}
	export -f ensure_jq

	run build_deck
	[[ "$status" -eq 0 ]]
}

@test "build_deck:: fails when jq is missing" {
	ensure_jq() {
		echo "ensure_jq:: jq not found" >&2
		echo "ensure_jq:: Install jq with your OS package manager, then re-run" >&2
		return 1
	}
	export -f ensure_jq

	run build_deck
	[[ "$status" -eq 1 ]]
	grep -q "build_deck:: Failed to ensure jq" <<<"$output"
}

@test "execute_operations:: passes GIT_ROOT to trilliax and questlog" {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
	local mock_dir
	mock_dir="$(mktemp -d "${base}/hearthstone-args.XXXXXX")"

	cat >"$mock_dir/trilliax.sh" <<'EOF'
#!/usr/bin/env bash
printf 'trilliax args:%s\n' "$*"
EOF
	chmod +x "$mock_dir/trilliax.sh"

	cat >"$mock_dir/questlog.sh" <<'EOF'
#!/usr/bin/env bash
printf 'questlog args:%s\n' "$*"
EOF
	chmod +x "$mock_dir/questlog.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"
	FORCE=true
	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]
	grep -Fq "trilliax args:--all ${GIT_ROOT}" <<<"$output"
	grep -Fq "questlog args:${GIT_ROOT}" <<<"$output"
}

########################################################
# main
########################################################
@test "main:: script handles help option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
}

@test "main:: script handles unknown options" {
	run bash "$SCRIPT" --unknown
	[[ "$status" -eq 1 ]]

	grep -q "run_hearthstone:: Unknown option '--unknown'" <<<"$output"
}

@test "main:: script handles yes flag to skip confirmation" {
	mock_commands_success

	run bash "$SCRIPT" --yes
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
}

@test "main:: script cancels when user declines confirmation" {
	confirm_proceed() {
		echo "confirm_proceed:: Operation cancelled by user"
		return 1
	}
	export -f confirm_proceed

	run run_hearthstone
	[[ "$status" -eq 1 ]]

	grep -q "confirm_proceed:: Operation cancelled by user" <<<"$output"
}

@test "main:: script handles force option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "\-f, \-\-force" <<<"$output"
	grep -q "Force operations" <<<"$output"
}

@test "main:: script accepts force flag" {
	mock_commands_success

	run bash "$SCRIPT" --yes --force
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
	grep -q "Hearthstone Complete" <<<"$output"
}

@test "main:: script accepts short force flag" {
	mock_commands_success

	run bash "$SCRIPT" -y -f
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
	grep -q "Hearthstone Complete" <<<"$output"
}
