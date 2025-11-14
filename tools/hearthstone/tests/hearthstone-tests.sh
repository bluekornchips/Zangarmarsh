#!/usr/bin/env bats
#
# Test file for hearthstone.sh
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="$GIT_ROOT/tools/hearthstone/hearthstone.sh"
[[ ! -f "$SCRIPT" ]] && echo "Script not found: $SCRIPT" >&2 && return 1

setup() {

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

	echo '#!/usr/bin/env bash' >"$mock_dir/questlog.sh"
	echo 'echo "questlog succeeded"' >>"$mock_dir/questlog.sh"
	chmod +x "$mock_dir/questlog.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/gdlf.sh"
	echo 'echo "gdlf succeeded"' >>"$mock_dir/gdlf.sh"
	chmod +x "$mock_dir/gdlf.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"
	GDLF_SCRIPT="$mock_dir/gdlf.sh"

	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT GDLF_SCRIPT
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
# vscodeoverride
########################################################
@test "vscodeoverride::syncs when directory is empty" {
	FORCE=false
	export FORCE

	test_dir="$(mktemp -d)"
	cd "$test_dir" || return 1

	run vscodeoverride
	[[ "$status" -eq 0 ]]

	grep -q "vscodeoverride:: VSCode settings synced" <<<"$output"
	[[ -d "$test_dir/.vscode" ]]

	cd - >/dev/null || return 1
}

@test "vscodeoverride::skips when directory exists and FORCE is false" {
	FORCE=false
	export FORCE

	test_dir="$(mktemp -d)"
	mkdir -p "$test_dir/.vscode"
	echo "existing" >"$test_dir/.vscode/settings.json"
	cd "$test_dir" || return 1

	run vscodeoverride
	[[ "$status" -eq 0 ]]

	grep -q "vscodeoverride:: VSCode settings already exist" <<<"$output"
	grep -q "use --force to replace" <<<"$output"

	cd - >/dev/null || return 1
}

@test "vscodeoverride::replaces when FORCE is true" {
	FORCE=true
	export FORCE

	test_dir="$(mktemp -d)"
	mkdir -p "$test_dir/.vscode"
	echo "existing" >"$test_dir/.vscode/settings.json"
	cd "$test_dir" || return 1

	run vscodeoverride
	[[ "$status" -eq 0 ]]

	grep -q "vscodeoverride:: VSCode settings synced (replaced existing)" <<<"$output"

	cd - >/dev/null || return 1
}

########################################################
# execute_operations
########################################################
@test "execute_operations::runs all commands successfully without FORCE" {
	mock_commands_success
	FORCE=false
	export FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]

	! grep -q "execute_operations:: Running: trilliax --all" <<<"$output"
	grep -q "execute_operations:: Running: questlog" <<<"$output"
	grep -q "execute_operations:: Running: vscodeoverride" <<<"$output"
	grep -q "execute_operations:: Running: gdlf --install" <<<"$output"
}

@test "execute_operations::runs all commands including trilliax with FORCE" {
	mock_commands_success
	FORCE=true
	export FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]

	grep -q "execute_operations:: Running: trilliax --all" <<<"$output"
	grep -q "execute_operations:: Running: questlog" <<<"$output"
	grep -q "execute_operations:: Running: vscodeoverride" <<<"$output"
	grep -q "execute_operations:: Running: gdlf --install" <<<"$output"
}

@test "execute_operations::fails when trilliax fails with FORCE" {
	mock_commands_failure
	FORCE=true
	export FORCE

	run execute_operations
	[[ "$status" -eq 1 ]]

	grep -q "execute_operations:: Failed to execute: trilliax --all" <<<"$output"
}

@test "execute_operations::passes force flag to gdlf when FORCE is true" {
	local mock_dir
	mock_dir="$(mktemp -d)"

	echo '#!/usr/bin/env bash' >"$mock_dir/trilliax.sh"
	echo 'exit 0' >>"$mock_dir/trilliax.sh"
	chmod +x "$mock_dir/trilliax.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/questlog.sh"
	echo 'exit 0' >>"$mock_dir/questlog.sh"
	chmod +x "$mock_dir/questlog.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/gdlf.sh"
	echo 'echo "Args: $@"' >>"$mock_dir/gdlf.sh"
	echo 'exit 0' >>"$mock_dir/gdlf.sh"
	chmod +x "$mock_dir/gdlf.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"
	GDLF_SCRIPT="$mock_dir/gdlf.sh"
	FORCE=true
	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT GDLF_SCRIPT FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]

	grep -q "Args: -i -f" <<<"$output"
}

@test "execute_operations::does not pass force flag to gdlf when FORCE is false" {
	local mock_dir
	mock_dir="$(mktemp -d)"

	echo '#!/usr/bin/env bash' >"$mock_dir/trilliax.sh"
	echo 'exit 0' >>"$mock_dir/trilliax.sh"
	chmod +x "$mock_dir/trilliax.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/questlog.sh"
	echo 'exit 0' >>"$mock_dir/questlog.sh"
	chmod +x "$mock_dir/questlog.sh"

	echo '#!/usr/bin/env bash' >"$mock_dir/gdlf.sh"
	echo 'echo "Args: $@"' >>"$mock_dir/gdlf.sh"
	echo 'exit 0' >>"$mock_dir/gdlf.sh"
	chmod +x "$mock_dir/gdlf.sh"

	TRILLIAX_SCRIPT="$mock_dir/trilliax.sh"
	QUESTLOG_SCRIPT="$mock_dir/questlog.sh"
	GDLF_SCRIPT="$mock_dir/gdlf.sh"
	FORCE=false
	export TRILLIAX_SCRIPT QUESTLOG_SCRIPT GDLF_SCRIPT FORCE

	run execute_operations
	[[ "$status" -eq 0 ]]

	grep -q "Args: -i" <<<"$output"
	! grep -q "Args: -i -f" <<<"$output"
}

########################################################
# build_deck
########################################################
@test "build_deck::succeeds when jq is installed" {
	install_jq() {
		echo "install_jq:: jq installed"
		return 0
	}
	export -f install_jq

	run build_deck
	[[ "$status" -eq 0 ]]
}

@test "build_deck::succeeds when jq needs installation but succeeds" {
	command() {
		case "$2" in
		"jq") return 1 ;;
		*) builtin command "$@" ;;
		esac
	}
	export -f command

	install_jq() {
		echo "install_jq:: jq installed"
		return 0
	}
	export -f install_jq

	run build_deck
	[[ "$status" -eq 0 ]]
}

@test "build_deck::fails when jq installation fails" {
	command() {
		case "$2" in
		"jq" | "apt-get" | "brew" | "pacman") return 1 ;;
		*) builtin command "$@" ;;
		esac
	}
	export -f command

	install_jq() {
		echo "install_jq:: jq not found, attempting to install."
		echo "install_jq:: No supported package manager found. Please install jq manually for your system." >&2
		return 1
	}
	export -f install_jq

	run build_deck
	[[ "$status" -eq 1 ]]
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

	grep -q "main:: Unknown option '--unknown'" <<<"$output"
}

@test "main::script handles yes flag to skip confirmation" {
	mock_commands_success

	run bash "$SCRIPT" --yes
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
}

@test "main::script cancels when user declines confirmation" {
	confirm_proceed() {
		echo "confirm_proceed:: Operation cancelled by user"
		return 1
	}
	export -f confirm_proceed

	run main
	[[ "$status" -eq 1 ]]

	grep -q "confirm_proceed:: Operation cancelled by user" <<<"$output"
}

@test "main::script handles force option" {
	run bash "$SCRIPT" --help
	[[ "$status" -eq 0 ]]

	grep -q "\-f, \-\-force" <<<"$output"
	grep -q "Force operations" <<<"$output"
}

@test "main::script accepts force flag" {
	mock_commands_success

	run bash "$SCRIPT" --yes --force
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
	grep -q "Hearthstone Complete" <<<"$output"
}

@test "main::script accepts short force flag" {
	mock_commands_success

	run bash "$SCRIPT" -y -f
	[[ "$status" -eq 0 ]]

	grep -q "Running Hearthstone" <<<"$output"
	grep -q "Hearthstone Complete" <<<"$output"
}
