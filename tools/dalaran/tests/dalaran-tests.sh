#!/usr/bin/env bats
#
# Test suite for dalaran.sh using Bats
#

GIT_ROOT=$(git rev-parse --show-toplevel)
SCRIPT="$GIT_ROOT/tools/dalaran/dalaran.sh"
[[ ! -f "${SCRIPT}" ]] && echo "Could not find dalaran.sh script" >&2 && exit 1

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

create_archive_directory() {
	local archives_dir="$1"
	local timestamp="$2"
	local commands_array_name="$3"
	local -n cmd_array="$commands_array_name"

	local archive_dir="${archives_dir}/${timestamp}"
	local top_commands_file="${archive_dir}/top_commands.txt"

	mkdir -p "${archive_dir}"

	local i
	i=0

	while [[ $i -lt ${#cmd_array[@]} ]]; do
		echo "${cmd_array[$i]}" >>"$top_commands_file"
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
# update_library
########################################################
@test "update_library:: dry run mode returns success" {
	DRY_RUN=true
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "update_library:: no archive files found" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 0 archive top commands files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 0 ]]
}

@test "update_library:: processes single archive file" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands=("git status" "ls -la" "pwd" "git status" "date")
	create_archive_directory "${input_dir}" "20240101" commands

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 1 archive top commands files"
	echo "$output" | grep -q "Added 20240101: 5 commands"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 5 ]]

	local top_command
	top_command=$(head -1 "$output_file")
	[[ "$top_command" == "git status" ]]
}

@test "update_library:: processes multiple archive files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands1=("git status" "ls -la" "pwd")
	local commands2=("git status" "echo hello" "date")
	local commands3=("pwd" "git status" "whoami")

	create_archive_directory "${input_dir}" "20240101" commands1
	create_archive_directory "${input_dir}" "20240102" commands2
	create_archive_directory "${input_dir}" "20240103" commands3

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 3 archive top commands files"
	echo "$output" | grep -q "Updated library with.*total commands from.*archives"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 9 ]]
}

@test "update_library:: concatenates all commands in order" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands1=("cmd1" "cmd2")
	local commands2=("cmd3" "cmd4")
	local commands3=("cmd5")

	create_archive_directory "${input_dir}" "20240101" commands1
	create_archive_directory "${input_dir}" "20240102" commands2
	create_archive_directory "${input_dir}" "20240103" commands3

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 5 ]]

	grep -q "cmd1" "$output_file"
	grep -q "cmd2" "$output_file"
	grep -q "cmd3" "$output_file"
	grep -q "cmd4" "$output_file"
	grep -q "cmd5" "$output_file"
}

@test "update_library:: handles multiple archives" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands1=("cmd1" "cmd2" "cmd3" "cmd4" "cmd5")
	local commands2=("cmd6" "cmd7" "cmd8" "cmd9" "cmd10")

	create_archive_directory "${input_dir}" "20240101" commands1
	create_archive_directory "${input_dir}" "20240102" commands2

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 10 ]]
}

@test "update_library:: ignores non-archive files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local commands=("git status" "ls -la")
	create_archive_directory "${input_dir}" "20240101" commands

	echo "not a library file" >"${input_dir}/other_file.txt"
	echo "another file" >"${input_dir}/data.txt"

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 1 archive top commands files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 2 ]]
}

@test "update_library:: handles empty archive files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	mkdir -p "${input_dir}/20240101"
	touch "${input_dir}/20240101/top_commands.txt"
	mkdir -p "${input_dir}/20240102"
	touch "${input_dir}/20240102/top_commands.txt"

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found 2 archive top commands files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 0 ]]
}

@test "update_library:: creates output file successfully" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file="${DIR}/combined_output.txt"

	local commands=("git status" "ls -la" "pwd" "date")
	create_archive_directory "${input_dir}" "20240101" commands

	run update_library "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Updated library with.*total commands from.*archives"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -gt 0 ]]
}

########################################################
# create_archive
########################################################
@test "create_archive:: dry run mode returns success" {
	DRY_RUN=true
	local archive_file
	local top_commands_file
	archive_file="${DIR}/archive/.zsh_history"
	top_commands_file="${DIR}/archive/top_commands.txt"

	run create_archive "$archive_file" "$top_commands_file" 10
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "create_archive:: creates archive directory" {
	DRY_RUN=false
	local archive_file
	local top_commands_file
	archive_file="${DIR}/archive/test/.zsh_history"
	top_commands_file="${DIR}/archive/test/top_commands.txt"

	run create_archive "$archive_file" "$top_commands_file" 10
	[[ "$status" -eq 0 ]]
	[[ -d "${DIR}/archive/test" ]]
}

@test "create_archive:: copies HISTFILE to archive location" {
	DRY_RUN=false
	local archive_file
	local top_commands_file
	archive_file="${DIR}/archive/test/.zsh_history"
	top_commands_file="${DIR}/archive/test/top_commands.txt"

	run create_archive "$archive_file" "$top_commands_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$archive_file" ]]

	local original_count
	local archive_count
	original_count=$(wc -l <"${HISTFILE}")
	archive_count=$(wc -l <"$archive_file")
	[[ "$original_count" -eq "$archive_count" ]]
}

@test "create_archive:: creates top commands file" {
	DRY_RUN=false
	local archive_file
	local top_commands_file
	archive_file="${DIR}/archive/test/.zsh_history"
	top_commands_file="${DIR}/archive/test/top_commands.txt"

	run create_archive "$archive_file" "$top_commands_file" 5
	[[ "$status" -eq 0 ]]
	[[ -f "$top_commands_file" ]]

	local top_count
	top_count=$(wc -l <"$top_commands_file")
	[[ "$top_count" -gt 0 ]]
	[[ "$top_count" -le 5 ]]
}

@test "create_archive:: displays progress messages" {
	DRY_RUN=false
	local archive_file
	local top_commands_file
	archive_file="${DIR}/archive/test/.zsh_history"
	top_commands_file="${DIR}/archive/test/top_commands.txt"

	run create_archive "$archive_file" "$top_commands_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Created archive: test with.*commands"
	echo "$output" | grep -q "Extracted.*top commands to:"
}

@test "create_archive:: fails when HISTFILE missing" {
	DRY_RUN=false
	HISTFILE="/does/not/exist"
	local archive_file
	local top_commands_file
	archive_file="${DIR}/archive/test/.zsh_history"
	top_commands_file="${DIR}/archive/test/top_commands.txt"

	run create_archive "$archive_file" "$top_commands_file" 10
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Failed to create archive"
}

########################################################
# display_summary
########################################################
@test "display_summary:: dry run mode returns success" {
	DRY_RUN=true
	local dalaran_dir
	local archives_dir
	local top_commands_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	top_commands_file="${dalaran_dir}/top_commands.txt"

	run display_summary "$dalaran_dir" "$archives_dir" "$top_commands_file"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "display_summary:: counts archive directories" {
	DRY_RUN=false
	local dalaran_dir
	local archives_dir
	local top_commands_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	top_commands_file="${dalaran_dir}/top_commands.txt"

	mkdir -p "${archives_dir}/20240101"
	mkdir -p "${archives_dir}/20240102"
	echo "git status" >"$top_commands_file"
	echo "ls -la" >>"$top_commands_file"

	run display_summary "$dalaran_dir" "$archives_dir" "$top_commands_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Archive directories: 2"
	echo "$output" | grep -q "Combined top commands: 2"
}

@test "display_summary:: handles missing directories" {
	DRY_RUN=false
	local dalaran_dir
	local archives_dir
	local top_commands_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	top_commands_file="${dalaran_dir}/top_commands.txt"

	run display_summary "$dalaran_dir" "$archives_dir" "$top_commands_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Archive directories: 0"
	echo "$output" | grep -q "Combined top commands: 0"
}

@test "display_summary:: shows file paths" {
	DRY_RUN=false
	local dalaran_dir
	local archives_dir
	local top_commands_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	top_commands_file="${dalaran_dir}/top_commands.txt"

	mkdir -p "$dalaran_dir"
	touch "$top_commands_file"

	run display_summary "$dalaran_dir" "$archives_dir" "$top_commands_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Your dalaran top commands are available at:"
	echo "$output" | grep -q "$top_commands_file"
}

########################################################
# show_top_commands
########################################################
@test "show_top_commands:: library file not found" {
	local fake_home
	fake_home=$(mktemp -d)
	HOME="$fake_home"

	run show_top_commands 10
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No dalaran top commands found"
}

@test "show_top_commands:: displays top commands" {
	local fake_home
	local top_commands_file
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	mkdir -p "${fake_home}/.dalaran"
	top_commands_file="${fake_home}/.dalaran/top_commands.txt"

	cat >"$top_commands_file" <<EOF
git status
ls -la
pwd
date
whoami
EOF

	run show_top_commands 3
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 3 most used commands from dalaran:"
	echo "$output" | grep -q "1.*git status"
	echo "$output" | grep -q "2.*ls -la"
	echo "$output" | grep -q "3.*pwd"
}

@test "show_top_commands:: respects count limit" {
	local fake_home
	local top_commands_file
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	mkdir -p "${fake_home}/.dalaran"
	top_commands_file="${fake_home}/.dalaran/top_commands.txt"

	cat >"$top_commands_file" <<EOF
git status
ls -la
pwd
date
whoami
echo hello
cat file
mkdir test
EOF

	run show_top_commands 5
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 5 most used commands from dalaran:"

	local line_count
	line_count=$(echo "$output" | grep -c "^[[:space:]]*[0-9]")
	[[ "$line_count" -eq 5 ]]
}

########################################################
# main
########################################################
@test "main:: unknown option returns error" {
	run "$SCRIPT" --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "Unknown option"
}

@test "main:: top option with invalid value" {
	run "$SCRIPT" --top=abc
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "must be a positive integer"
}

@test "main:: top option with zero value" {
	run "$SCRIPT" --top=0
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "must be a positive integer"
}

@test "main:: top option shows commands" {
	local fake_home
	local top_commands_file
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	mkdir -p "${fake_home}/.dalaran"
	top_commands_file="${fake_home}/.dalaran/top_commands.txt"

	cat >"$top_commands_file" <<EOF
git status
ls -la
pwd
EOF

	run "$SCRIPT" --top=2
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 2 most used commands"
}

@test "main:: dry run option sets environment" {
	run "$SCRIPT" --dry-run --help
	[[ "$status" -eq 0 ]]
}

@test "main:: missing history file error" {
	DRY_RUN=false
	HISTFILE="/does/not/exist"

	run "$SCRIPT"
	[[ "$status" -ne 0 ]]
	echo "$output" | grep -q "History file not found"
}