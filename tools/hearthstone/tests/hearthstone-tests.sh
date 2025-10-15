#!/usr/bin/env bats
#
# Test file for hearthstone.sh
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="$GIT_ROOT/tools/hearthstone/hearthstone.sh"
[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && return 1

setup() {
	#shellcheck disable=SC1090
	source "$SCRIPT"

	return 0
}

########################################################
# Mocks
########################################################
mock_commands_success() {
	local mock_dir
	mock_dir="$(mktemp -d)"

	echo '#!/usr/bin/env bash' >"$mock_dir/trilliax.sh"
	echo 'echo "trilliax mocked"' >>"$mock_dir/trilliax.sh"
	chmod +x "$mock_dir/trilliax.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/questlog.sh"
	echo 'echo "questlog mocked"' >>"$mock_dir/questlog.sh"
	chmod +x "$mock_dir/questlog.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/gdlf.sh"
	echo 'echo "gdlf mocked"' >>"$mock_dir/gdlf.sh"
	chmod +x "$mock_dir/gdlf.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"
	GDLF_SCRIPT="$mock_dir/gdlf.sh"

	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT GDLF_SCRIPT
}

mock_commands_failure() {
	local mock_dir
	mock_dir="$(mktemp -d)"

	echo '#!/usr/bin/env bash' >"$mock_dir/trilliax.sh"
	echo 'echo "trilliax failed" >&2' >>"$mock_dir/trilliax.sh"
	echo 'exit 1' >>"$mock_dir/trilliax.sh"
	chmod +x "$mock_dir/trilliax.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"

	export TRILLIAX_SCRIPT
}

mock_user_confirmation_yes() {
	confirm_proceed() {
		return 0
	}

	export -f confirm_proceed
}

mock_user_confirmation_no() {
	confirm_proceed() {
		echo "Operation cancelled by user"
		return 1
	}

	export -f confirm_proceed
}

########################################################
# confirm_proceed
########################################################
@test "confirm_proceed::accepts y as confirmation" {
	run bash -c "source '$SCRIPT' && echo 'y' | confirm_proceed"
	[[ "$status" -eq 0 ]]
}

@test "confirm_proceed::accepts yes as confirmation" {
	run bash -c "source '$SCRIPT' && echo 'yes' | confirm_proceed"
	[[ "$status" -eq 0 ]]
}

@test "confirm_proceed::accepts Y as confirmation" {
	run bash -c "source '$SCRIPT' && echo 'Y' | confirm_proceed"
	[[ "$status" -eq 0 ]]
}

@test "confirm_proceed::rejects n as confirmation" {
	run bash -c "source '$SCRIPT' && echo 'n' | confirm_proceed"
	[[ "$status" -eq 1 ]]

	grep -q "Operation cancelled by user" <<<"$output"
}

@test "confirm_proceed::rejects empty input as confirmation" {
	run bash -c "source '$SCRIPT' && echo '' | confirm_proceed"
	[[ "$status" -eq 1 ]]

	grep -q "Operation cancelled by user" <<<"$output"
}

########################################################
# verify_git_repository
########################################################
@test "verify_git_repository::succeeds with valid directory structure" {
	run verify_git_repository
	[[ "$status" -eq 0 ]]
}

@test "verify_git_repository::fails when tools directory missing" {
	GIT_ROOT="/nonexistent/path"

	run verify_git_repository
	[[ "$status" -eq 1 ]]

	grep -q "Zangarmarsh root directory not found" <<<"$output"
}

########################################################
# execute_operations
########################################################
@test "execute_operations::runs all commands successfully" {
	mock_commands_success

	run execute_operations
	[[ "$status" -eq 0 ]]

	grep -q "Running: trilliax --all" <<<"$output"
	grep -q "Running: questlog" <<<"$output"
	grep -q "Running: vscodeoverride" <<<"$output"
	grep -q "Running: gdlf --install" <<<"$output"
}

@test "execute_operations::fails when command fails" {
	mock_commands_failure

	run execute_operations
	[[ "$status" -eq 1 ]]

	grep -q "Failed to execute: trilliax --all" <<<"$output"
}

########################################################
# main
########################################################
@test "main::script handles help option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "Usage:" <<<"$output"
}

@test "main::script handles unknown options" {
	run bash "$SCRIPT" --unknown
	[[ "$status" -eq 1 ]]

	grep -q "Unknown option '--unknown'" <<<"$output"
}

@test "main::script handles yes flag to skip confirmation" {
	mock_commands_success

	run bash "$SCRIPT" --yes
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
}

@test "main::script cancels when user declines confirmation" {
	mock_user_confirmation_no

	run bash -c "source '$SCRIPT' && main"
	[[ "$status" -eq 1 ]]

	grep -q "Operation cancelled by user" <<<"$output"
}
