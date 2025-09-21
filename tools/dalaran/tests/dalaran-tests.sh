#!/usr/bin/env bats
#
# Test suite for dalaran.sh using Bats
# Tests core functionality and command-line options
# Should never alter real system state
#

GIT_ROOT=$(git rev-parse --show-toplevel)
SCRIPT="$GIT_ROOT/tools/dalaran/dalaran.sh"
[[ ! -f "${SCRIPT}" ]] && echo "Could not find dalaran.sh script" >&2 && exit 1

# Create a test history file with mock data
# Inputs:
# $1 - history_file, path to create the test history file
# $2 - command_count, number of commands to create (default: 20)
create_test_history_file() {
	local history_file="$1"
	local command_count
	command_count="${2:-20}"

	local commands
	commands=(
		"git status"
		"cd /tmp"
		"ls -la"
		"git add ."
		"git commit -m 'test commit'"
		"git status"
		"ls -la"
		"cd /home"
		"git log"
		"git status"
		"echo 'hello world'"
		"cat file.txt"
		"git status"
		"ls -la"
		"git add ."
		"git commit -m 'another commit'"
		"git status"
		"cd /tmp"
		"ls -la"
		"git status"
	)

	local timestamp
	local i
	timestamp=1700000000
	i=0

	while [[ $i -lt $command_count ]]; do
		local cmd_index
		cmd_index=$((i % ${#commands[@]}))
		echo ": ${timestamp}:0;${commands[$cmd_index]}" >>"$history_file"
		timestamp=$((timestamp + 1))
		i=$((i + 1))
	done

	return 0
}

setup() {
	source "$SCRIPT"

	local test_dir
	temp_dir=$(mktemp -d) || return 1
	DIR="${temp_dir}"
	cd "${DIR}" || return 1

	HOME="${DIR}/home"
	mkdir -p "${HOME}"

	HISTFILE="${DIR}/test_zsh_history"
	DALARAN_DIR="${HOME}/.dalaran"
	TOP_COMMANDS_DIR="${HOME}/.dalaran/top_commands"
	BACKUP_FILE="$(mktemp)"


	# Redefine common vars for script
	HOME="${HOME}"
	HISTFILE="${HISTFILE}"

	DRY_RUN=true

	export HOME
	export HISTFILE
	export DALARAN_DIR
	export TOP_COMMANDS_DIR
	export DRY_RUN
}

@test "script exists and is executable" {
	[[ -f "${SCRIPT}" ]]
	[[ -x "${SCRIPT}" ]]
}

@test "script should load successfully" {
	run source "$SCRIPT"
	[[ "$status" -eq 0 ]]
}

########################################################
# usage
########################################################
@test "usage:: display usage when run with -h" {
	run "$SCRIPT" -h
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
}

@test "usage:: display usage when run with --help" {
	run "$SCRIPT" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
}

########################################################
# create_backup
########################################################
@test "create_backup:: source file cannot be empty" {
	run create_backup ""
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Source file cannot be empty"
}

@test "create_backup:: source file not found" {
	run create_backup "/does/not/exist"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Source file not found: /does/not/exist"
}

@test "create_backup:: backup file cannot be empty" {
	run create_backup "${HISTFILE}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Backup file cannot be empty"
}

@test "create_backup:: backup directory not found" {
	DRY_RUN=false
	local hist_file
	hist_file=$(mktemp)
	create_test_history_file "${hist_file}"
	
	run create_backup "${hist_file}" "${BACKUP_FILE}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Failed to copy"
}

@test "create_backup:: dry run is true" {
	run create_backup "${HISTFILE}" "${HISTFILE}.bak"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "create_backup:: copy fails" {
	DRY_RUN=false

	run create_backup "${HISTFILE}" "${BACKUP_FILE}"
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Failed to copy ${HISTFILE} to /does/not/exist"
}

@test "create_backup:: copy succeeds" {
	DRY_RUN=false
	local hist_file
	hist_file=$(mktemp)

	create_test_history_file "${hist_file}"
	local command_count
	command_count=$(wc -l <"${hist_file}")

	run create_backup "${hist_file}" "${hist_file}.bak"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Backed up ${command_count} commands to: $(basename "${hist_file}.bak")"
	[[ -f "${hist_file}.bak" ]]
}
