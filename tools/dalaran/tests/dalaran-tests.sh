#!/usr/bin/env bats
#
# Test suite for dalaran.sh using Bats
#

GIT_ROOT=$(git rev-parse --show-toplevel)
SCRIPT="$GIT_ROOT/tools/dalaran/dalaran.sh"
[[ ! -f "${SCRIPT}" ]] && echo "Could not find dalaran.sh script" >&2 && exit 1

# Create a test history file with zsh format entries
#
# Inputs:
# - $1, history_file, path to the history file to create
# - $@, remaining arguments are the spell commands to add
#
# Side Effects:
# - Creates or appends to the specified history file with timestamped entries
create_test_history_file() {
	local history_file="$1"
	shift

	local timestamp
	local spell
	timestamp=1700000000

	for spell in "$@"; do
		echo ": ${timestamp}:0;${spell}" >>"$history_file"
		timestamp=$((timestamp + 1))
	done

	return 0
}

# Create archive directory with spellbook file from spell data
#
# Inputs:
# - $1, archives_dir, base directory for archives
# - $2, timestamp, timestamp identifier for the archive
# - $@, remaining arguments are the spells to add to spellbook
#
# Side Effects:
# - Creates archive directory structure
# - Creates spellbook.txt file with spell contents
create_archive_directory() {
	local archives_dir="$1"
	local timestamp="$2"
	shift 2

	local archive_dir="${archives_dir}/${timestamp}"
	local spellbook_file="${archive_dir}/spellbook.txt"

	mkdir -p "${archive_dir}"

	local spell
	for spell in "$@"; do
		echo "${spell}" >>"$spellbook_file"
	done

	return 0
}

setup() {
	#shellcheck disable=SC1091
	source "$SCRIPT"

	temp_dir=$(mktemp -d) || return 1
	DIR="${temp_dir}"
	cd "${DIR}" || return 1

	HOME="${DIR}/home"
	mkdir -p "${HOME}"

	HISTFILE="${DIR}/test_zsh_history"
	DALARAN_DIR="${HOME}/.dalaran"

	local default_spells=(
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
	create_test_history_file "${HISTFILE}" "${default_spells[@]}"

	DRY_RUN=true

	export HOME
	export HISTFILE
	export DALARAN_DIR
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
# extract_top_spells
########################################################
@test "extract_top_spells:: input file not found creates empty output" {
	local output_file
	output_file=$(mktemp)

	run extract_top_spells "/does/not/exist" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 0 ]]
}

@test "extract_top_spells:: dry run mode returns success" {
	DRY_RUN=true
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)
	local simple_spells=("echo hello" "pwd" "date" "ls" "whoami")
	create_test_history_file "$input_file" simple_spells

	run extract_top_spells "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "extract_top_spells:: processes zsh format history" {
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

	run extract_top_spells "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted"
	[[ -f "$output_file" ]]

	local top_spell
	top_spell=$(head -1 "$output_file")
	[[ "$top_spell" == "git status" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 3 ]]
}

@test "extract_top_spells:: processes plain format history" {
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

	run extract_top_spells "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted"
	[[ -f "$output_file" ]]

	local top_spell
	top_spell=$(head -1 "$output_file")
	[[ "$top_spell" == "echo hello" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 3 ]]
}

@test "extract_top_spells:: processes mixed format history" {
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

	run extract_top_spells "$input_file" "$output_file" 10
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

@test "extract_top_spells:: respects max spells limit" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	local i
	i=0
	while [[ $i -lt 20 ]]; do
		echo "spell_${i}" >>"$input_file"
		i=$((i + 1))
	done

	run extract_top_spells "$input_file" "$output_file" 5
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 5 ]]
}

@test "extract_top_spells:: handles empty input file" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	run extract_top_spells "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 0 ]]
}

@test "extract_top_spells:: skips empty lines and whitespace" {
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

	run extract_top_spells "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -eq 3 ]]

	grep -q "echo hello" "$output_file"
	grep -q "pwd" "$output_file"
	grep -q "date" "$output_file"
}

@test "extract_top_spells:: sorts by frequency correctly" {
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

	run extract_top_spells "$input_file" "$output_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local first_spell
	local second_spell
	first_spell=$(sed -n '1p' "$output_file")
	second_spell=$(sed -n '2p' "$output_file")

	[[ "$first_spell" == "git status" ]]
	[[ "$second_spell" == "ls -la" ]]
}

@test "extract_top_spells:: creates output file successfully" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file="${DIR}/test_output.txt"
	local mixed_spells=("git status" "echo hello" "ls -la" "pwd" "git add ." "date")
	create_test_history_file "$input_file" mixed_spells

	run extract_top_spells "$input_file" "$output_file" 5
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Extracted.*top spells to: $(basename "$output_file")"
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -gt 0 ]]
}

########################################################
# update_spellbook
########################################################
@test "update_spellbook:: dry run mode returns success" {
	DRY_RUN=true
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "update_spellbook:: no archive files found" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found.*0.*archive spellbook files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 0 ]]
}

@test "update_spellbook:: processes single archive file" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local spells=("git status" "ls -la" "pwd" "git status" "date")
	create_archive_directory "${input_dir}" "20240101" "${spells[@]}"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found.*1.*archive spellbook files"
	echo "$output" | grep -q "Added 20240101:.*5 spells"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 5 ]]

	local top_spell
	top_spell=$(head -1 "$output_file")
	[[ "$top_spell" == "git status" ]]
}

@test "update_spellbook:: processes multiple archive files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local spells1=("git status" "ls -la" "pwd")
	local spells2=("git status" "echo hello" "date")
	local spells3=("pwd" "git status" "whoami")

	create_archive_directory "${input_dir}" "20240101" "${spells1[@]}"
	create_archive_directory "${input_dir}" "20240102" "${spells2[@]}"
	create_archive_directory "${input_dir}" "20240103" "${spells3[@]}"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found.*3.*archive spellbook files"
	echo "$output" | grep -q "Updated spellbook with.*total spells from.*archives"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 9 ]]
}

@test "update_spellbook:: concatenates all spells in order" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local spells1=("spell1" "spell2")
	local spells2=("spell3" "spell4")
	local spells3=("spell5")

	create_archive_directory "${input_dir}" "20240101" "${spells1[@]}"
	create_archive_directory "${input_dir}" "20240102" "${spells2[@]}"
	create_archive_directory "${input_dir}" "20240103" "${spells3[@]}"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 5 ]]

	grep -q "spell1" "$output_file"
	grep -q "spell2" "$output_file"
	grep -q "spell3" "$output_file"
	grep -q "spell4" "$output_file"
	grep -q "spell5" "$output_file"
}

@test "update_spellbook:: handles multiple archives" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local spells1=("spell1" "spell2" "spell3" "spell4" "spell5")
	local spells2=("spell6" "spell7" "spell8" "spell9" "spell10")

	create_archive_directory "${input_dir}" "20240101" "${spells1[@]}"
	create_archive_directory "${input_dir}" "20240102" "${spells2[@]}"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 10 ]]
}

@test "update_spellbook:: ignores non-archive files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	local spells=("git status" "ls -la")
	create_archive_directory "${input_dir}" "20240101" "${spells[@]}"

	echo "not a spellbook file" >"${input_dir}/other_file.txt"
	echo "another file" >"${input_dir}/data.txt"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found.*1.*archive spellbook files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 2 ]]
}

@test "update_spellbook:: handles empty archive files" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file=$(mktemp)

	mkdir -p "${input_dir}/20240101"
	touch "${input_dir}/20240101/spellbook.txt"
	mkdir -p "${input_dir}/20240102"
	touch "${input_dir}/20240102/spellbook.txt"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found.*2.*archive spellbook files"
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 0 ]]
}

@test "update_spellbook:: creates output file successfully" {
	DRY_RUN=false
	local input_dir
	local output_file
	input_dir=$(mktemp -d)
	output_file="${DIR}/combined_output.txt"

	local spells=("git status" "ls -la" "pwd" "date")
	create_archive_directory "${input_dir}" "20240101" "${spells[@]}"

	run update_spellbook "$input_dir" "$output_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Updated spellbook with.*total spells from.*archives"
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
	local spellbook_file
	archive_file="${DIR}/archive/.zsh_history"
	spellbook_file="${DIR}/archive/spellbook.txt"

	run create_archive "$archive_file" "$spellbook_file" 10
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "create_archive:: creates archive directory" {
	DRY_RUN=false
	local archive_file
	local spellbook_file
	archive_file="${DIR}/archive/test/.zsh_history"
	spellbook_file="${DIR}/archive/test/spellbook.txt"

	run create_archive "$archive_file" "$spellbook_file" 10
	[[ "$status" -eq 0 ]]
	[[ -d "${DIR}/archive/test" ]]
}

@test "create_archive:: copies HISTFILE to archive location" {
	DRY_RUN=false
	local archive_file
	local spellbook_file
	archive_file="${DIR}/archive/test/.zsh_history"
	spellbook_file="${DIR}/archive/test/spellbook.txt"

	run create_archive "$archive_file" "$spellbook_file" 10
	[[ "$status" -eq 0 ]]
	[[ -f "$archive_file" ]]

	local original_count
	local archive_count
	original_count=$(wc -l <"${HISTFILE}")
	archive_count=$(wc -l <"$archive_file")
	[[ "$original_count" -eq "$archive_count" ]]
}

@test "create_archive:: creates spellbook file" {
	DRY_RUN=false
	local archive_file
	local spellbook_file
	archive_file="${DIR}/archive/test/.zsh_history"
	spellbook_file="${DIR}/archive/test/spellbook.txt"

	run create_archive "$archive_file" "$spellbook_file" 5
	[[ "$status" -eq 0 ]]
	[[ -f "$spellbook_file" ]]

	local spell_count
	spell_count=$(wc -l <"$spellbook_file")
	[[ "$spell_count" -gt 0 ]]
	[[ "$spell_count" -le 5 ]]
}

@test "create_archive:: displays progress messages" {
	DRY_RUN=false
	local archive_file
	local spellbook_file
	archive_file="${DIR}/archive/test/.zsh_history"
	spellbook_file="${DIR}/archive/test/spellbook.txt"

	run create_archive "$archive_file" "$spellbook_file" 10
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Created archive: test (.*commands)"
	echo "$output" | grep -q "Extracted.*top spells to:"
}

@test "create_archive:: fails when HISTFILE missing" {
	DRY_RUN=false
	HISTFILE="/does/not/exist"
	local archive_file
	local spellbook_file
	archive_file="${DIR}/archive/test/.zsh_history"
	spellbook_file="${DIR}/archive/test/spellbook.txt"

	run create_archive "$archive_file" "$spellbook_file" 10
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
	local spellbook_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	spellbook_file="${dalaran_dir}/spellbook.txt"

	run display_summary "$dalaran_dir" "$archives_dir" "$spellbook_file"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "display_summary:: counts archive directories" {
	DRY_RUN=false
	local dalaran_dir
	local archives_dir
	local spellbook_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	spellbook_file="${dalaran_dir}/spellbook.txt"

	mkdir -p "${archives_dir}/20240101"
	mkdir -p "${archives_dir}/20240102"
	echo "git status" >"$spellbook_file"
	echo "ls -la" >>"$spellbook_file"

	run display_summary "$dalaran_dir" "$archives_dir" "$spellbook_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Archive directories:.*2"
	echo "$output" | grep -q "Combined spellbook entries: 2"
}

@test "display_summary:: handles missing directories" {
	DRY_RUN=false
	local dalaran_dir
	local archives_dir
	local spellbook_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	spellbook_file="${dalaran_dir}/spellbook.txt"

	run display_summary "$dalaran_dir" "$archives_dir" "$spellbook_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Archive directories:.*0"
	echo "$output" | grep -q "Combined spellbook entries: 0"
}

@test "display_summary:: shows file paths" {
	DRY_RUN=false
	local dalaran_dir
	local archives_dir
	local spellbook_file
	dalaran_dir="${DIR}/.dalaran"
	archives_dir="${dalaran_dir}/archives"
	spellbook_file="${dalaran_dir}/spellbook.txt"

	mkdir -p "$dalaran_dir"
	touch "$spellbook_file"

	run display_summary "$dalaran_dir" "$archives_dir" "$spellbook_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Your dalaran spellbook is available at:"
	echo "$output" | grep -q "$spellbook_file"
}

########################################################
# show_top_spells
########################################################
@test "show_top_spells:: spellbook file not found" {
	local fake_home
	fake_home=$(mktemp -d)
	HOME="$fake_home"

	run show_top_spells 10
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "No dalaran spellbook found"
}

@test "show_top_spells:: displays top spells" {
	local fake_home
	local spellbook_file
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	mkdir -p "${fake_home}/.dalaran"
	spellbook_file="${fake_home}/.dalaran/spellbook.txt"

	cat >"$spellbook_file" <<EOF
git status
ls -la
pwd
date
whoami
EOF

	run show_top_spells 3
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 3 most used spells from dalaran spellbook:"
	echo "$output" | grep -q "1.*git status"
	echo "$output" | grep -q "2.*ls -la"
	echo "$output" | grep -q "3.*pwd"
}

@test "show_top_spells:: respects count limit" {
	local fake_home
	local spellbook_file
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	mkdir -p "${fake_home}/.dalaran"
	spellbook_file="${fake_home}/.dalaran/spellbook.txt"

	cat >"$spellbook_file" <<EOF
git status
ls -la
pwd
date
whoami
echo hello
cat file
mkdir test
EOF

	run show_top_spells 5
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 5 most used spells from dalaran spellbook:"

	local line_count
	line_count=$(echo "$output" | grep -c "^[[:space:]]*[0-9]")
	[[ "$line_count" -eq 5 ]]
}

########################################################
# update_silenced_spells
########################################################
@test "update_silenced_spells:: dry run mode returns success" {
	DRY_RUN=true
	local silenced_file
	silenced_file="${DIR}/.dalaran/silenced.txt"

	run update_silenced_spells "$silenced_file" "ls,pwd,date"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "update_silenced_spells:: creates silenced file" {
	DRY_RUN=false
	local silenced_file
	silenced_file="${DIR}/.dalaran/silenced.txt"

	run update_silenced_spells "$silenced_file" "ls -la,pwd"
	[[ "$status" -eq 0 ]]
	[[ -f "$silenced_file" ]]

	grep -q "ls -la" "$silenced_file"
	grep -q "pwd" "$silenced_file"
}

@test "update_silenced_spells:: handles complex spells" {
	DRY_RUN=false
	local silenced_file
	silenced_file="${DIR}/.dalaran/silenced.txt"

	run update_silenced_spells "$silenced_file" "kubectl get pods && grep \"some value\" -A 10,docker ps | grep running"
	[[ "$status" -eq 0 ]]
	[[ -f "$silenced_file" ]]

	grep -Fq 'kubectl get pods && grep "some value" -A 10' "$silenced_file"
	grep -Fq "docker ps | grep running" "$silenced_file"
}

@test "update_silenced_spells:: avoids duplicates" {
	DRY_RUN=false
	local silenced_file
	silenced_file="${DIR}/.dalaran/silenced.txt"

	mkdir -p "${DIR}/.dalaran"
	echo "ls -la" >"$silenced_file"

	run update_silenced_spells "$silenced_file" "ls -la,pwd,ls -la"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Already silenced: ls -la"
	echo "$output" | grep -q "Silenced spell: pwd"

	local ls_count
	ls_count=$(grep -c "ls -la" "$silenced_file")
	[[ "$ls_count" -eq 1 ]]
}

@test "update_silenced_spells:: trims whitespace" {
	DRY_RUN=false
	local silenced_file
	silenced_file="${DIR}/.dalaran/silenced.txt"

	run update_silenced_spells "$silenced_file" "  ls -la  , pwd  ,  date  "
	[[ "$status" -eq 0 ]]
	[[ -f "$silenced_file" ]]

	grep -q "ls -la" "$silenced_file"
	grep -q "pwd" "$silenced_file"
	grep -q "date" "$silenced_file"
}

@test "update_silenced_spells:: skips empty spells" {
	DRY_RUN=false
	local silenced_file
	silenced_file="${DIR}/.dalaran/silenced.txt"

	run update_silenced_spells "$silenced_file" "ls,,,pwd,,"
	[[ "$status" -eq 0 ]]
	[[ -f "$silenced_file" ]]

	local line_count
	line_count=$(wc -l <"$silenced_file")
	[[ "$line_count" -eq 2 ]]
}

@test "update_silenced_spells:: creates directory structure" {
	DRY_RUN=false
	local silenced_file
	silenced_file="${DIR}/deep/nested/path/silenced.txt"

	run update_silenced_spells "$silenced_file" "test spell"
	[[ "$status" -eq 0 ]]
	[[ -f "$silenced_file" ]]
	[[ -d "${DIR}/deep/nested/path" ]]
}

########################################################
# extract_top_spells with silenced
########################################################
@test "extract_top_spells:: filters spells using silenced file" {
	DRY_RUN=false
	local input_file
	local output_file
	local silenced_file
	input_file=$(mktemp)
	output_file=$(mktemp)
	silenced_file=$(mktemp)

	cat >"$input_file" <<EOF
git status
ls -la
git status
pwd
git status
ls -la
date
EOF

	echo "ls -la" >"$silenced_file"
	echo "pwd" >>"$silenced_file"

	run extract_top_spells "$input_file" "$output_file" 10 "$silenced_file"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Silenced.*spell(s) from spellbook"
	[[ -f "$output_file" ]]

	grep -q "git status" "$output_file"
	grep -q "date" "$output_file"
	! grep -q "ls -la" "$output_file" || false
	! grep -q "pwd" "$output_file" || false
}

@test "extract_top_spells:: works without silenced file" {
	DRY_RUN=false
	local input_file
	local output_file
	input_file=$(mktemp)
	output_file=$(mktemp)

	cat >"$input_file" <<EOF
git status
ls -la
git status
pwd
EOF

	run extract_top_spells "$input_file" "$output_file" 10 "/does/not/exist"
	[[ "$status" -eq 0 ]]
	! echo "$output" | grep -q "Silenced" || true
	[[ -f "$output_file" ]]

	grep -q "git status" "$output_file"
	grep -q "ls -la" "$output_file"
	grep -q "pwd" "$output_file"
}

@test "extract_top_spells:: handles empty silenced file" {
	DRY_RUN=false
	local input_file
	local output_file
	local silenced_file
	input_file=$(mktemp)
	output_file=$(mktemp)
	silenced_file=$(mktemp)

	cat >"$input_file" <<EOF
git status
ls -la
pwd
EOF

	run extract_top_spells "$input_file" "$output_file" 10 "$silenced_file"
	[[ "$status" -eq 0 ]]
	! echo "$output" | grep -q "Silenced" || true
	[[ -f "$output_file" ]]

	local output_count
	output_count=$(wc -l <"$output_file")
	[[ "$output_count" -eq 3 ]]
}

########################################################
# main with silenced
########################################################
@test "main:: silenced option with simple spells" {
	local fake_home
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	DRY_RUN=false

	run "$SCRIPT" --silence="ls,pwd"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Silenced spell: ls"
	echo "$output" | grep -q "Silenced spell: pwd"
	echo "$output" | grep -q "Silenced spells updated"

	local silenced_file
	silenced_file="${fake_home}/.dalaran/silenced.txt"
	[[ -f "$silenced_file" ]]
	grep -q "ls" "$silenced_file"
	grep -q "pwd" "$silenced_file"
}

@test "main:: silenced option with complex spells" {
	local fake_home
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	DRY_RUN=false

	complex_spells=(
		"kubectl get pods && grep \"test\" -A 5"
		"docker ps | grep running"
		"SOME_VAR=\"test\" && \
		export SOME_VAR && \
		echo \"\$SOME_VAR\""
	)

	run "$SCRIPT" --silence="${complex_spells[*]}"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Silenced spell:"

	local silenced_file
	silenced_file="${fake_home}/.dalaran/silenced.txt"
	[[ -f "$silenced_file" ]]
	for spell in "${complex_spells[@]}"; do
		grep -Fq "$spell" "$silenced_file"
	done
}

@test "main:: silenced option with empty value" {
	run "$SCRIPT" --silence=""
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "requires a comma-separated list"
}

@test "main:: silenced option dry run" {
	local fake_home
	fake_home=$(mktemp -d)
	HOME="$fake_home"

	run "$SCRIPT" --dry-run --silence="ls,pwd"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Silenced spells updated"

	local silenced_file
	silenced_file="${fake_home}/.dalaran/silenced.txt"
	[[ ! -f "$silenced_file" ]]
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

@test "main:: top option shows spells" {
	local fake_home
	local spellbook_file
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	mkdir -p "${fake_home}/.dalaran"
	spellbook_file="${fake_home}/.dalaran/spellbook.txt"

	cat >"$spellbook_file" <<EOF
git status
ls -la
pwd
EOF

	run "$SCRIPT" --top=2
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Top 2 most used spells"
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

########################################################
# Real world live tests with actual history
########################################################
@test "LIVE:: extract_top_spells can process actual zsh history file" {
	local history_file="/home/tristan/.zsh_history"

	[[ ! -f "$history_file" ]] && skip "No zsh history file found"

	DRY_RUN=false
	local output_file
	output_file=$(mktemp)

	run extract_top_spells "$history_file" "$output_file" 100
	[[ "$status" -eq 0 ]]
	[[ -f "$output_file" ]]

	local extracted_count
	extracted_count=$(wc -l <"$output_file")
	[[ "$extracted_count" -gt 0 ]]
}

@test "LIVE:: create_archive processes actual history successfully" {
	local history_file="/home/tristan/.zsh_history"

	[[ ! -f "$history_file" ]] && skip "No zsh history file found"

	DRY_RUN=false
	local temp_histfile
	local archive_file
	local spellbook_file
	temp_histfile=$(mktemp)
	archive_file="${DIR}/live_test/.zsh_history"
	spellbook_file="${DIR}/live_test/spellbook.txt"

	cp "$history_file" "$temp_histfile"
	HISTFILE="$temp_histfile"

	run create_archive "$archive_file" "$spellbook_file" 50
	[[ "$status" -eq 0 ]]
	[[ -f "$archive_file" ]]
	[[ -f "$spellbook_file" ]]

	local archive_count
	local spellbook_count
	archive_count=$(wc -l <"$archive_file")
	spellbook_count=$(wc -l <"$spellbook_file")

	[[ "$archive_count" -gt 0 ]]
	[[ "$spellbook_count" -gt 0 ]]

	rm -f "$temp_histfile"
}

@test "LIVE:: main full workflow with actual history" {
	local history_file="/home/tristan/.zsh_history"

	[[ ! -f "$history_file" ]] && skip "No zsh history file found"

	local fake_home
	fake_home=$(mktemp -d)
	HOME="$fake_home"
	DRY_RUN=false

	local temp_histfile
	temp_histfile=$(mktemp)
	cp "$history_file" "$temp_histfile"
	HISTFILE="$temp_histfile"

	echo "Processing history file: $history_file" >&3
	echo "Total commands in history file: $(wc -l <"$history_file")" >&3

	run "$SCRIPT"
	[[ "$status" -eq 0 ]]

	local spellbook_file="${fake_home}/.dalaran/spellbook.txt"
	[[ -f "$spellbook_file" ]]

	local spellbook_count
	spellbook_count=$(wc -l <"$spellbook_file")
	[[ "$spellbook_count" -gt 0 ]]
	echo "Total commands in spellbook file: $spellbook_count" >&3

	rm -f "$temp_histfile"
}
