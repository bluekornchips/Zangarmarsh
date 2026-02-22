#!/usr/bin/env bats
#
# Tests for ice-block.sh backup script functionality
#
GIT_ROOT="$(git rev-parse --show-toplevel || echo "")"
SCRIPT="${GIT_ROOT}/tools/ice-block/ice-block.sh"
[[ ! -f "$SCRIPT" ]] && echo "setup:: Script not found: $SCRIPT" >&2 && return 1

setup_file() {
	return 0
}

setup() {
	TEST_DIR="$(mktemp -d -t ice-block-tests.XXXXXX)"
	export TEST_DIR

	export ORIGINAL_HOME="$HOME"
	export HOME="$TEST_DIR"

	mkdir -p "$HOME/.ssh"
	echo "alias foo='bar'" > "$HOME/.aliases"
	echo "export PATH=..." > "$HOME/.bashrc"
	echo "ssh config" > "$HOME/.ssh/config"
	chmod 400 "$HOME/.ssh/config"

	set +e
	trap - EXIT ERR
	# shellcheck disable=SC1091
	source "$SCRIPT"
	trap - EXIT ERR
	set +e

	return 0
}

teardown() {
	[[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
	export HOME="$ORIGINAL_HOME"

	return 0
}

########################################################
# ensure_target_dir
########################################################
@test "ensure_target_dir:: creates the target directory when it does not exist" {
	TARGET_DIR="$TEST_DIR/backup"

	run ensure_target_dir
	[[ "$status" -eq 0 ]]
	[[ -d "$TEST_DIR/backup" ]]
}

@test "ensure_target_dir:: succeeds when target directory already exists" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR"

	run ensure_target_dir
	[[ "$status" -eq 0 ]]
	[[ -d "$TARGET_DIR" ]]
}

########################################################
# copy_source
########################################################
@test "copy_source:: copies a regular file" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR"

	run copy_source "$HOME/.aliases"
	[[ "$status" -eq 0 ]]
	[[ -f "$TARGET_DIR/.aliases" ]]
	grep -q "alias foo='bar'" "$TARGET_DIR/.aliases"
}

@test "copy_source:: copies a directory recursively" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR"

	run copy_source "$HOME/.ssh"
	[[ "$status" -eq 0 ]]
	[[ -d "$TARGET_DIR/.ssh" ]]
	[[ -f "$TARGET_DIR/.ssh/config" ]]
}

@test "copy_source:: overwrites a read-only file in the destination" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR/.ssh"
	echo "old config" > "$TARGET_DIR/.ssh/config"
	chmod 400 "$TARGET_DIR/.ssh/config"

	run copy_source "$HOME/.ssh"
	[[ "$status" -eq 0 ]]
	[[ -f "$TARGET_DIR/.ssh/config" ]]
	grep -q "ssh config" "$TARGET_DIR/.ssh/config"
}

@test "copy_source:: preserves symlinks" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR"
	ln -s "$HOME/.aliases" "$HOME/.aliases_link"

	run copy_source "$HOME/.aliases_link"
	[[ "$status" -eq 0 ]]
	[[ -L "$TARGET_DIR/.aliases_link" ]]
	[[ "$(readlink "$TARGET_DIR/.aliases_link")" == "$HOME/.aliases" ]]
}

@test "copy_source:: skips a non-existent source path" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR"

	run copy_source "$HOME/.non-existent"
	[[ "$status" -eq 0 ]]
	[[ ! -e "$TARGET_DIR/.non-existent" ]]
	echo "$output" | grep -q "Skipping missing path"
}

@test "copy_source:: fails when source argument is empty" {
	TARGET_DIR="$TEST_DIR/backup"
	mkdir -p "$TARGET_DIR"

	run copy_source ""
	[[ "$status" -eq 1 ]]
}

########################################################
# main
########################################################
@test "main:: runs the full backup process and reports success" {
	SOURCES=(
		"$HOME/.aliases"
		"$HOME/.bashrc"
	)
	TARGET_DIR="$TEST_DIR/final_backup"

	run main
	[[ "$status" -eq 0 ]]
	[[ -d "$TARGET_DIR" ]]
	[[ -f "$TARGET_DIR/.aliases" ]]
	[[ -f "$TARGET_DIR/.bashrc" ]]
	echo "$output" | grep -q "All done!"
}

@test "main:: skips missing source files without failing" {
	SOURCES=(
		"$HOME/.aliases"
		"$HOME/.does-not-exist"
	)
	TARGET_DIR="$TEST_DIR/skip_backup"

	run main
	[[ "$status" -eq 0 ]]
	[[ -f "$TARGET_DIR/.aliases" ]]
	[[ ! -e "$TARGET_DIR/.does-not-exist" ]]
	echo "$output" | grep -q "Skipping missing path"
}
