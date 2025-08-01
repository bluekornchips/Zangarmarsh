#!/usr/bin/env bats
#
# Test suite for dalaran.sh using Bats
# Tests core functionality and command-line options
# Never alters real system state

setup() {
	export TEST_DIR
	TEST_DIR=$(mktemp -d)
	cd "$TEST_DIR" || exit 1

	# Get absolute path to the dalaran script
	export SCRIPT_DIR
	SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
	export DALARAN_SCRIPT="${SCRIPT_DIR}/dalaran.sh"

	export ORIGINAL_HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
	export TEST_HISTFILE="${TEST_DIR}/test_zsh_history"
	export TEST_HOME="${TEST_DIR}/home"
	export TEST_DALARAN_DIR="${TEST_HOME}/.dalaran"
	export TEST_TOP_COMMANDS_DIR="${TEST_HOME}/.dalaran/top_commands"

	mkdir -p "${TEST_HOME}"

	# Test data: mock zsh history entries
	export MOCK_HISTORY_DATA=": 1700000000:0;git status
: 1700000001:0;cd /tmp
: 1700000002:0;ls -la
: 1700000003:0;git add .
: 1700000004:0;git commit -m 'test commit'
: 1700000005:0;git status
: 1700000006:0;ls -la
: 1700000007:0;cd /home
: 1700000008:0;git log
: 1700000009:0;git status
: 1700000010:0;echo 'hello world'
: 1700000011:0;cat file.txt
: 1700000012:0;git status
: 1700000013:0;ls -la
: 1700000014:0;git add .
: 1700000015:0;git commit -m 'another commit'
: 1700000016:0;git status
: 1700000017:0;cd /tmp
: 1700000018:0;ls -la
: 1700000019:0;git status"

	echo "${MOCK_HISTORY_DATA}" >"${TEST_HISTFILE}"
	echo "Created mock history with $(wc -l <"${TEST_HISTFILE}") entries"

	[[ -d "${TEST_HOME}" ]]
	[[ -f "${TEST_HISTFILE}" ]]
	[[ -f "${DALARAN_SCRIPT}" ]]
}

teardown() {
	if [[ -d "${TEST_DIR}" ]]; then
		rm -rf "${TEST_DIR}"
	fi
}

@test "core::script_does_not_modify_real_histfile" {
	local real_histfile_backup=""
	if [[ -f "${ORIGINAL_HISTFILE}" ]]; then
		real_histfile_backup=$(mktemp)
		cp "${ORIGINAL_HISTFILE}" "${real_histfile_backup}"
	fi

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=true run bash "${DALARAN_SCRIPT}"

	if [[ -f "${ORIGINAL_HISTFILE}" && -f "${real_histfile_backup}" ]]; then
		run diff "${ORIGINAL_HISTFILE}" "${real_histfile_backup}"
		[[ "$status" -eq 0 ]]
	fi

	if [[ -f "${real_histfile_backup}" ]]; then
		rm -f "${real_histfile_backup}"
	fi
}

@test "core::dry_run_mode_functionality" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=true run bash "${DALARAN_SCRIPT}"

	echo "$output" | grep -q "Would execute\|Would create\|Would extract\|Would combine"
}

@test "core::directory_creation" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	[[ -d "${TEST_DALARAN_DIR}" ]]
	[[ -d "${TEST_TOP_COMMANDS_DIR}" ]]
}

@test "core::backup_file_creation" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	local backup_files_count
	backup_files_count=$(find "${TEST_DALARAN_DIR}" -name "library_*.txt" -type f 2>/dev/null | wc -l)
	[ "${backup_files_count}" -gt 0 ]
}

@test "core::top_commands_extraction" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	local combined_file="${TEST_DALARAN_DIR}/top_commands.txt"
	[[ -f "${combined_file}" ]]

	local command_count
	command_count=$(wc -l <"${combined_file}")
	[[ ${command_count} -gt 0 ]]
}

@test "core::working_history_creation" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	local working_history="${TEST_DALARAN_DIR}/active_history"
	[[ -f "${working_history}" ]]

	local history_count
	history_count=$(wc -l <"${working_history}")
	[[ ${history_count} -gt 0 ]]
}

@test "core::script_creates_expected_files_in_normal_mode" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	[[ -d "${TEST_DALARAN_DIR}" ]]
	[[ -d "${TEST_TOP_COMMANDS_DIR}" ]]
	[[ -f "${TEST_DALARAN_DIR}/top_commands.txt" ]]
	[[ -f "${TEST_DALARAN_DIR}/active_history" ]]
}

@test "core::script_creates_expected_files_in_dry_run_mode" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=true run bash "${DALARAN_SCRIPT}"

	[[ ! -d "${TEST_DALARAN_DIR}" ]]
}

@test "core::script_works_normally_without_options" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}"

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "ZSH Dalaran Library"
	echo "$output" | grep -q "Backing up current history"
	echo "$output" | grep -q "Extracting top"
	echo "$output" | grep -q "Combining all historical"
	echo "$output" | grep -q "Dalaran Library Summary"
}

@test "core::script_maintains_backward_compatibility" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	[[ "$status" -eq 0 ]]
	[[ -d "${TEST_DALARAN_DIR}" ]]
	[[ -d "${TEST_TOP_COMMANDS_DIR}" ]]
	[[ -f "${TEST_DALARAN_DIR}/top_commands.txt" ]]
	[[ -f "${TEST_DALARAN_DIR}/active_history" ]]
}

@test "error::missing_history_file_handling" {
	local non_existent_file="${TEST_DIR}/nonexistent_history"

	HOME="${TEST_HOME}" HISTFILE="${non_existent_file}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	[[ "$status" -ne 0 ]]
}

@test "error::empty_history_file_handling" {
	local empty_file="${TEST_DIR}/empty_history"
	touch "${empty_file}"

	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${empty_file}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	[[ "$status" -eq 0 ]]
}

@test "error::malformed_history_entries_handling" {
	local malformed_file="${TEST_DIR}/malformed_history"
	cat >"${malformed_file}" <<'EOF'
: 1700000000:0;git status
malformed entry without timestamp
: 1700000001:0;ls -la
another malformed entry
: 1700000002:0;cd /tmp
EOF

	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${malformed_file}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	[[ "$status" -eq 0 ]]
	[[ -f "${TEST_DALARAN_DIR}/top_commands.txt" ]]
}

@test "error::invalid_option_shows_error_message" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --invalid-option

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: Unknown option '--invalid-option'"
	echo "$output" | grep -q "Use --help for usage information"
}

@test "error::multiple_invalid_options_show_error_for_first_one" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --invalid-option --another-invalid

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: Unknown option '--invalid-option'"
}

@test "data::command_frequency_ranking_preserved" {
	local repeated_file="${TEST_DIR}/repeated_history"
	cat >"${repeated_file}" <<'EOF'
: 1700000000:0;git status
: 1700000001:0;ls -la
: 1700000002:0;git status
: 1700000003:0;cd /tmp
: 1700000004:0;git status
: 1700000005:0;ls -la
: 1700000006:0;git status
EOF

	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${repeated_file}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	local combined_file="${TEST_DALARAN_DIR}/top_commands.txt"
	[[ -f "${combined_file}" ]]

	local file_contents
	file_contents=$(cat "${combined_file}")
	echo "$file_contents" | grep -q "git status"
	echo "$file_contents" | grep -q "ls -la"
	echo "$file_contents" | grep -q "cd /tmp"
}

@test "data::boolean_parameter_handling" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=true run bash "${DALARAN_SCRIPT}"
	local output_true="$output"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"
	local output_false="$output"

	[[ "$output_true" != "$output_false" ]]
}

@test "options::help_shows_usage_information" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --help

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
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" -h

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage:"
	echo "$output" | grep -q "OPTIONS:"
}

@test "options::top_with_valid_number_shows_commands" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=5

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 5 most used commands from dalaran library:"
}

@test "options::top_with_default_value_shows_10_commands" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=10

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 10 most used commands from dalaran library:"
}

@test "options::top_with_zero_value_shows_error" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=0

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_with_negative_value_shows_error" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=-5

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_with_non_numeric_value_shows_error" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=abc

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_with_empty_value_shows_error" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Error: --top value must be a positive integer"
}

@test "options::top_when_no_library_exists_shows_appropriate_message" {
	rm -rf "${TEST_DALARAN_DIR}"

	local test_home_clean="${TEST_DIR}/clean_home"
	mkdir -p "${test_home_clean}"

	HOME="${test_home_clean}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=5

	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No dalaran library found. Run the script first to create one."
}

@test "options::dry_run_command_line_option_works" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --dry-run

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Would execute\|Would create\|Would extract\|Would combine"
	echo "$output" | grep -q "ZSH Dalaran Library \[DRY RUN\]"
}

@test "options::dry_run_option_does_not_create_actual_files" {
	rm -rf "${TEST_DALARAN_DIR}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --dry-run

	[[ "$status" -eq 0 ]]
	[[ ! -d "${TEST_DALARAN_DIR}" ]]
}

@test "options::combination_of_valid_options_works" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=3 --dry-run

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 3 most used commands from dalaran library:"
}

@test "options::dry_run_environment_variable_still_works_with_new_options" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=true run bash "${DALARAN_SCRIPT}" --top=5

	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "No dalaran library found. Run the script first to create one."
}

@test "functions::show_usage_displays_correct_script_name" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --help

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Usage: dalaran.sh"
}

@test "functions::show_top_commands_formats_output_correctly" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=3

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 3 most used commands from dalaran library:"
	echo "$output" | grep -q "^[[:space:]]*[0-9][[:space:]]"
}

@test "functions::parse_options_handles_empty_arguments" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}"

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "ZSH Dalaran Library"
}

@test "functions::parse_options_handles_multiple_valid_options" {
	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" DRY_RUN=false run bash "${DALARAN_SCRIPT}"

	HOME="${TEST_HOME}" HISTFILE="${TEST_HISTFILE}" run bash "${DALARAN_SCRIPT}" --top=2 --dry-run

	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 2 most used commands from dalaran library:"
}
