#!/usr/bin/env bats
#
# Test suite for dalaran.sh using Bats
# Tests core functionality and command-line options
# Should never alter real system state
#

GIT_ROOT=$(git rev-parse --show-toplevel)
SCRIPT="$GIT_ROOT/tools/dalaran/dalaran.sh"

if [[ ! -f "${SCRIPT}" ]]; then
	echo "Could not find dalaran.sh script at: ${SCRIPT}" >&2
	return 1
fi

# Create a test history file with mock data
# Inputs:
# $1 - history_file, path to create the test history file
# $2 - command_count, number of commands to create (default: 20)
create_test_history_file() {
	local history_file
	history_file="$1"
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
		((timestamp++))
		((i++))
	done

	return 0
}

setup() {
	# Source the script to get function access
	source "$SCRIPT"

	# Create temporary directory for tests
	local temp_dir
	temp_dir=$(mktemp -d) || return 1
	export TEST_DIR="${temp_dir}"
	cd "${temp_dir}" || return 1

	# Set up test environment variables
	export TEST_HOME="${TEST_DIR}/home"
	export TEST_HISTFILE="${TEST_DIR}/test_zsh_history"
	export TEST_DALARAN_DIR="${TEST_HOME}/.dalaran"
	export TEST_TOP_COMMANDS_DIR="${TEST_HOME}/.dalaran/top_commands"

	# Create test home directory
	mkdir -p "${TEST_HOME}"

	# Create test history file with mock data
	if ! create_test_history_file "${TEST_HISTFILE}"; then
		echo "Failed to create test history file" >&2
		return 1
	fi

	# Set global variables for script
	export HOME="${TEST_HOME}"
	export HISTFILE="${TEST_HISTFILE}"
	export DRY_RUN="false"

	return 0
}

teardown() {
	if [[ -d "${TEST_DIR:-}" ]]; then
		rm -rf "${TEST_DIR}"
	fi
}

########################################################
# Main Function Tests
########################################################
@test 'main::script_does_not_modify_real_histfile' {
	local real_histfile_backup=""
	if [[ -f "${ORIGINAL_HISTFILE:-}" ]]; then
		local real_histfile_backup
		real_histfile_backup=$(mktemp)
		cp "${ORIGINAL_HISTFILE}" "${real_histfile_backup}"
	fi

	DRY_RUN=true run main

	if [[ -f "${ORIGINAL_HISTFILE:-}" && -f "${real_histfile_backup}" ]]; then
		run diff "${ORIGINAL_HISTFILE}" "${real_histfile_backup}"
		[[ "$status" -eq 0 ]]
	fi

	if [[ -f "${real_histfile_backup}" ]]; then
		rm -f "${real_histfile_backup}"
	fi
}

@test 'main::dry_run_mode_functionality' {
	# Clean up any existing directories first
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=true run main

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "DRY RUN MODE"
	[[ ! -d "${TEST_DALARAN_DIR:-}" ]]
}

@test 'main::directory_creation' {
	# Use the actual DALARAN_DIR that the script will create
	local actual_dalaran_dir
	actual_dalaran_dir="$HOME/.dalaran"
	local actual_top_commands_dir
	actual_top_commands_dir="$HOME/.dalaran/top_commands"
	rm -rf "${actual_dalaran_dir}"

	DRY_RUN=false run main

	[[ -d "${actual_dalaran_dir}" ]]
	[[ -d "${actual_top_commands_dir}" ]]
}

@test 'main::backup_file_creation' {
	# Use the actual DALARAN_DIR that the script will create
	local actual_dalaran_dir
	actual_dalaran_dir="$HOME/.dalaran"
	rm -rf "${actual_dalaran_dir}"

	DRY_RUN=false run main

	# Check that backup files were created (they're in the main dalaran dir)
	local backup_files_count
	backup_files_count=$(find "${actual_dalaran_dir}" -maxdepth 1 -name "library_*.txt" -type f 2>/dev/null | wc -l)
	[[ "${backup_files_count}" -gt 0 ]]
}

@test 'main::top_commands_extraction' {
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=false run main

	local combined_file
	combined_file="${TEST_DALARAN_DIR}/top_commands.txt"
	[[ -f "${combined_file}" ]]

	local command_count
	command_count=$(wc -l <"${combined_file}")
	[[ ${command_count} -gt 0 ]]
}

@test 'main::working_history_creation' {
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=false run main

	local working_history
	working_history="${TEST_DALARAN_DIR}/active_history"
	[[ -f "${working_history}" ]]

	local history_count
	history_count=$(wc -l <"${working_history}")
	[[ ${history_count} -gt 0 ]]
}

@test 'main::script_creates_expected_files_in_normal_mode' {
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=false run main

	[[ -d "${TEST_DALARAN_DIR}" ]]
	[[ -d "${TEST_TOP_COMMANDS_DIR}" ]]
	[[ -f "${TEST_DALARAN_DIR}/top_commands.txt" ]]
	[[ -f "${TEST_DALARAN_DIR}/active_history" ]]
}

@test 'main::script_creates_expected_files_in_dry_run_mode' {
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=true run main

	[[ ! -d "${TEST_DALARAN_DIR:-}" ]]
}

@test 'main::script_works_normally_without_options' {
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=false run main

	[[ "$status" -eq 0 ]]
	# Remove ANSI escape sequences before grepping
	local clean_output
	clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
	echo "$clean_output" | grep -q "ZSH Dalaran Library"
	echo "$clean_output" | grep -q "Backed up.*commands"
	echo "$clean_output" | grep -q "Extracted.*top commands"
	echo "$clean_output" | grep -q "Found.*historical top command files"
	echo "$clean_output" | grep -q "Dalaran Library Summary:"
}

########################################################
# Error Handling Tests
########################################################
@test 'error::missing_history_file_handling' {
	local non_existent_file
	non_existent_file="${TEST_DIR}/nonexistent_history"

	HISTFILE="${non_existent_file}" DRY_RUN=false run main

	[[ "$status" -ne 0 ]]
}

@test "error::empty_history_file_handling" {
	local empty_file
	empty_file="${TEST_DIR}/empty_history"
	touch "${empty_file}"

	rm -rf "${TEST_DALARAN_DIR:-}"

	HISTFILE="${empty_file}" run main

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Backed up 0 commands"
	echo "$output" | grep -q "Extracted 0 top commands"
}

@test "error::malformed_history_entries_handling" {
	local malformed_file
	malformed_file="${TEST_DIR}/malformed_history"
	cat >"${malformed_file}" <<'EOF'
: 1700000000:0;git status
malformed entry without timestamp
: 1700000001:0;ls -la
another malformed entry
: 1700000002:0;cd /tmp
EOF

	rm -rf "${TEST_DALARAN_DIR:-}"

	HISTFILE="${malformed_file}" DRY_RUN=false run main

	[[ "$status" -eq 0 ]]
	[[ -f "${TEST_DALARAN_DIR}/top_commands.txt" ]]
}

@test "error::invalid_option_shows_error_message" {
	run parse_options --invalid-option

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: Unknown option '--invalid-option'"
	echo "$output" | grep -q "Use --help for usage information"
}

@test "error::multiple_invalid_options_show_error_for_first_one" {
	run parse_options --invalid-option --another-invalid

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: Unknown option '--invalid-option'"
}

@test "data::command_frequency_ranking_preserved" {
	local repeated_file
	repeated_file="${TEST_DIR}/repeated_history"
	cat >"${repeated_file}" <<'EOF'
: 1700000000:0;git status
: 1700000001:0;ls -la
: 1700000002:0;git status
: 1700000003:0;cd /tmp
: 1700000004:0;git status
: 1700000005:0;ls -la
: 1700000006:0;git status
EOF

	rm -rf "${TEST_DALARAN_DIR:-}"

	HISTFILE="${repeated_file}" DRY_RUN=false run main

	local combined_file
	combined_file="${TEST_DALARAN_DIR}/top_commands.txt"
	[[ -f "${combined_file}" ]]

	local file_contents
	file_contents=$(cat "${combined_file}")
	echo "$file_contents" | grep -q "git status"
	echo "$file_contents" | grep -q "ls -la"
	echo "$file_contents" | grep -q "cd /tmp"
}

@test "data::boolean_parameter_handling" {
	DRY_RUN=true run main
	local output_true
	output_true="$output"

	DRY_RUN=false run main
	local output_false
	output_false="$output"

	[[ "$output_true" != "$output_false" ]]
}

@test "options::help_shows_usage_information" {
	run parse_options --help

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
	echo "$output" | grep -q "OPTIONS:"
	echo "$output" | grep -q "\\--help"
	echo "$output" | grep -q "top"
	echo "$output" | grep -q "dry-run"
	echo "$output" | grep -q "ENVIRONMENT VARIABLES:"
	echo "$output" | grep -q "EXAMPLES:"
}

@test "options::short_help_shows_same_usage_as_long_help" {
	run parse_options -h

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
	echo "$output" | grep -q "OPTIONS:"
}

@test "options::top_with_valid_number_shows_commands" {
	DRY_RUN=false run main

	run parse_options --top=5

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 5 most used commands from dalaran library:"
}

@test "options::top_with_default_value_shows_10_commands" {
	DRY_RUN=false run main

	run parse_options --top=10

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 10 most used commands from dalaran library:"
}

@test "options::top_with_zero_value_shows_error" {
	run parse_options --top=0

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_with_negative_value_shows_error" {
	run parse_options --top=-5

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_with_non_numeric_value_shows_error" {
	run parse_options --top=abc

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_with_empty_value_shows_error" {
	run parse_options --top=

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_when_no_library_exists_shows_appropriate_message" {
	rm -rf "${TEST_DALARAN_DIR:-}"

	local test_home_clean
	test_home_clean="${TEST_DIR}/clean_home"
	mkdir -p "${test_home_clean}"

	HOME="${test_home_clean}" run parse_options --top=5

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No dalaran library found. Run the script first to create one."
}

@test "options::dry_run_command_line_option_works" {
	# Clean up any existing directories first
	rm -rf "${TEST_DALARAN_DIR:-}"

	run parse_options --dry-run

	[[ "$status" -eq 0 ]]
}

@test "options::dry_run_option_does_not_create_actual_files" {
	rm -rf "${TEST_DALARAN_DIR:-}"

	DRY_RUN=true run main

	[[ "$status" -eq 0 ]]
	[[ ! -d "${TEST_DALARAN_DIR:-}" ]]
}

@test "options::combination_of_valid_options_works" {
	DRY_RUN=false run main

	run parse_options --top=3

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 3 most used commands from dalaran library:"
}

@test "options::dry_run_environment_variable_still_works_with_new_options" {
	DRY_RUN=true run parse_options --top=5

	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "No dalaran library found. Run the script first to create one."
}

@test "functions::show_usage_displays_correct_script_name" {
	run usage

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: dalaran.sh"
}

@test "functions::show_top_commands_formats_output_correctly" {
	DRY_RUN=false run main

	run show_top_commands 3

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 3 most used commands from dalaran library:"
	echo "$output" | grep -q "^[[:space:]]*[0-9][[:space:]]"
}

@test "functions::parse_options_handles_empty_arguments" {
	run parse_options

	[[ "$status" -eq 0 ]]
}

@test "functions::parse_options_handles_multiple_valid_options" {
	DRY_RUN=false run main

	run parse_options --top=2

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 2 most used commands from dalaran library:"
}