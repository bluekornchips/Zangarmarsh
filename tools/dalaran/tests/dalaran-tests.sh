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
# $2 - commands_array_name, name of the array variable containing commands
create_test_history_file() {
	local history_file="$1"
	local commands_array_name="$2"
	local -n commands="$commands_array_name"

	local timestamp
	local i
	timestamp=1700000000
	i=0

	while [[ $i -lt ${#commands[@]} ]]; do
		echo ": ${timestamp}:0;${commands[$i]}" >>"$history_file"
		timestamp=$((timestamp + 1))
		i=$((i + 1))
	done

	return 0
}

# Create a library file with commands for combine_historical_files testing
# Inputs:
# $1 - library_file, path to create the library file
# $2 - commands_array_name, name of the array variable containing commands
create_library_file() {
	local library_file="$1"
	local commands_array_name="$2"
	local -n cmd_array="$commands_array_name"

	local i
	i=0

	while [[ $i -lt ${#cmd_array[@]} ]]; do
		echo "${cmd_array[$i]}" >>"$library_file"
		i=$((i + 1))
	done

	return 0
}

setup() {
	source "$SCRIPT"

	temp_dir=$(mktemp -d) || return 1
	DIR="${temp_dir}"
	cd "${DIR}" || return 1

	HOME="${DIR}/home"
	mkdir -p "${HOME}"

	HISTFILE="${DIR}/test_zsh_history"
	DALARAN_DIR="${HOME}/.dalaran"
	TOP_COMMANDS_DIR="${HOME}/.dalaran/top_commands"
	BACKUP_HIST_FILE="$(mktemp)"

	# Create test history file for tests
	local default_commands=(
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
	create_test_history_file "${HISTFILE}" default_commands

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
# extract_top_commands
########################################################
@test "extract_top_commands:: input file not found creates empty output" {
	local output_file
	output_file=$(mktemp)

	run extract_top_commands "/does/not/exist" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 0 ]]
}

@test "extract_top_commands:: dry run mode returns success" {
	DRY_RUN=true
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)
	local simple_commands=("echo hello" "pwd" "date" "ls" "whoami")
	create_test_history_file "$input_file" simple_commands

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "extract_top_commands:: processes zsh format history" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	cat >"$input_file" <<EOF
: 1700000001:0;git status
: 1700000002:0;ls -la
: 1700000003:0;git status
: 1700000004:0;cd /tmp
: 1700000005:0;git status
EOF

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted"
	[[ -f "$output_file" ]]

	local top_command
	top_command=$(head -1 "$output_file")
	[[ "$top_command" == "git status" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 3 ]]
}

@test "extract_top_commands:: processes plain format history" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	cat >"$input_file" <<EOF
echo hello
pwd
echo hello
date
echo hello
EOF

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted"
	[[ -f "$output_file" ]]

	local top_command
	top_command=$(head -1 "$output_file")
	[[ "$top_command" == "echo hello" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 3 ]]
}

@test "extract_top_commands:: processes mixed format history" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	cat >"$input_file" <<EOF
: 1700000001:0;git status
echo hello
: 1700000002:0;ls -la
pwd
: 1700000003:0;git status
echo hello
date
: 1700000004:0;git add .
pwd
: 1700000005:0;git status
EOF

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted"
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -gt 0 ]]

	grep -q "git status" "$output_file"
	grep -q "echo hello" "$output_file"
	grep -q "pwd" "$output_file"
}

@test "extract_top_commands:: respects max commands limit" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	local i
	i=0
	while [[ $i -lt 20 ]]; do
		echo "command_${i}" >>"$input_file"
		i=$((i + 1))
	done

	run extract_top_commands "$input_file" "$output_file" 5
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 5 ]]
}

@test "extract_top_commands:: handles empty input file" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 0 ]]
}

@test "extract_top_commands:: skips empty lines and whitespace" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	cat >"$input_file" <<EOF

   
echo hello

pwd
   
date

EOF

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 3 ]]

	grep -q "echo hello" "$output_file"
	grep -q "pwd" "$output_file"
	grep -q "date" "$output_file"
}

@test "extract_top_commands:: sorts by frequency correctly" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	cat >"$input_file" <<EOF
git status
ls -la
git status
cd /tmp
git status
ls -la
date
EOF

	run extract_top_commands "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local first_command
	local second_command
	first_command=$(sed -n '1p' "$output_file")
	second_command=$(sed -n '2p' "$output_file")

	[[ "$first_command" == "git status" ]]
	[[ "$second_command" == "ls -la" ]]
}

@test "extract_top_commands:: creates output file successfully" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file="${DIR}/test_output.txt"
	local mixed_commands=("git status" "echo hello" "ls -la" "pwd" "git add ." "date")
	create_test_history_file "$input_file" mixed_commands

	run extract_top_commands "$input_file" "$output_file" 5
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted.*top commands to: $(basename "$output_file")"
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -gt 0 ]]
}



########################################################
# combine_historical_files
########################################################

@test "combine_historical_files:: dry run mode returns success" {
	DRY_RUN=true
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "combine_historical_files:: no library files found" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 0 historical top command files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 0 ]]
}

@test "combine_historical_files:: processes single library file" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands=("git status" "ls -la" "pwd" "git status" "date")
	create_library_file "${input_dir}/library_20240101.txt" commands

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 1 historical top command files"
	echo "$output" | grep -q "Processed library_20240101.txt: 5 commands"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 4 ]]

	local top_command
	top_command=$(head -1 "$output_file")
	[[ "$top_command" == "git status" ]]
}

@test "combine_historical_files:: processes multiple library files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands1=("git status" "ls -la" "pwd")
	local commands2=("git status" "echo hello" "date")
	local commands3=("pwd" "git status" "whoami")

	create_library_file "${input_dir}/library_20240101.txt" commands1
	create_library_file "${input_dir}/library_20240102.txt" commands2
	create_library_file "${input_dir}/library_20240103.txt" commands3

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 3 historical top command files"
	echo "$output" | grep -q "Combined.*total commands into.*unique top commands"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 6 ]]

	local top_command
	top_command=$(head -1 "$output_file")
	[[ "$top_command" == "git status" ]]
}

@test "combine_historical_files:: sorts by frequency correctly" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands1=("git status" "git status" "git status" "ls -la")
	local commands2=("pwd" "pwd" "echo hello")
	local commands3=("ls -la" "date")

	create_library_file "${input_dir}/library_20240101.txt" commands1
	create_library_file "${input_dir}/library_20240102.txt" commands2
	create_library_file "${input_dir}/library_20240103.txt" commands3

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local first_command
	local second_command
	local third_command
	first_command=$(sed -n '1p' "$output_file")
	second_command=$(sed -n '2p' "$output_file")
	third_command=$(sed -n '3p' "$output_file")

	[[ "$first_command" == "git status" ]]
	[[ "$second_command" == "pwd" ]]
	[[ "$third_command" == "ls -la" ]]
}

@test "combine_historical_files:: respects max commands limit" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands1=("cmd1" "cmd2" "cmd3" "cmd4" "cmd5")
	local commands2=("cmd6" "cmd7" "cmd8" "cmd9" "cmd10")

	create_library_file "${input_dir}/library_20240101.txt" commands1
	create_library_file "${input_dir}/library_20240102.txt" commands2

	run combine_historical_files "$input_dir" "$output_file" 3
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 3 ]]
}

@test "combine_historical_files:: ignores non-library files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands=("git status" "ls -la")
	create_library_file "${input_dir}/library_20240101.txt" commands

	echo "not a library file" >"${input_dir}/other_file.txt"
	echo "another file" >"${input_dir}/data.txt"

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 1 historical top command files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 2 ]]
}

@test "combine_historical_files:: handles empty library files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	touch "${input_dir}/library_20240101.txt"
	touch "${input_dir}/library_20240102.txt"

	run combine_historical_files "$input_dir" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 2 historical top command files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 0 ]]
}

@test "combine_historical_files:: creates output file successfully" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file="${DIR}/combined_output.txt"

	local commands=("git status" "ls -la" "pwd" "date")
	create_library_file "${input_dir}/library_20240101.txt" commands

	run combine_historical_files "$input_dir" "$output_file" 5
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Combined.*total commands into.*unique top commands"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -gt 0 ]]
}
