#!/usr/bin/env bats

# Test file for zsh profile functionality in profile/zsh/profile.sh

if ! command -v zsh >/dev/null 2>&1; then
	echo "zsh not available, skipping profile tests" >&2
	exit 0
fi

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/zsh/profile.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

source "$GIT_ROOT/profile/tests/fixtures.sh"

# Setup test environment for zsh profile testing
setup() {
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1

	export TEST_DIR="$test_dir"
	export USER="frodo"
	export HOSTNAME="bag-end"
	export HOME="$test_dir"
	export PWD="$test_dir"
	export ZSH="$test_dir/.oh-my-zsh"
	export ZANGARMARSH_ROOT="$GIT_ROOT"
	export ZANGARMARSH_VERBOSE=true

	# Create mock Oh My Zsh structure
	mkdir -p "$ZSH"
	touch "$ZSH/oh-my-zsh.sh"
	mkdir -p "$ZSH/plugins/zsh-autosuggestions"
	touch "$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
}

# Clean up test environment
teardown() {
	rm -rf "$TEST_DIR"
}

# Core loading tests
@test "profile should load successfully in zsh" {
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "profile should set ZSH environment variable" {
	run zsh -c "source '$SCRIPT' && echo \$ZSH"
	[ "$status" -eq 0 ]
	[[ -n "$output" ]]
}

@test "profile should set ZSH_THEME variable" {
	run zsh -c "source '$SCRIPT' && echo \$ZSH_THEME"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "robbyrussell"
}

@test "profile should set plugins array" {
	run zsh -c "source '$SCRIPT' && echo \${plugins[@]}"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "git"
	echo "$output" | grep -q "zsh-autosuggestions"
}

@test "profile should set HISTFILE variable" {
	run zsh -c "source '$SCRIPT' && echo \$HISTFILE"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q ".zsh_history"
}

@test "profile should set HISTSIZE variable" {
	run zsh -c "source '$SCRIPT' && echo \$HISTSIZE"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "100000"
}

@test "profile should set SAVEHIST variable" {
	run zsh -c "source '$SCRIPT' && echo \$SAVEHIST"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "100000"
}

@test "profile should handle missing Oh My Zsh gracefully" {
	rm -rf "$ZSH"
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "Oh My Zsh is not installed"
}

@test "profile should handle missing zsh-autosuggestions plugin gracefully" {
	rm -rf "$ZSH/plugins/zsh-autosuggestions"
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "zsh-autosuggestions plugin is not installed"
}

@test "profile should set ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when plugin is available" {
	run zsh -c "source '$SCRIPT' && echo \$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "fg=#00ffff,bg=#2d2f40,bold"
}

@test "profile should load custom zsh files" {
	run zsh -c "source '$SCRIPT' && echo \$ZANGARMARSH_ROOT"
	[ "$status" -eq 0 ]
	[[ -n "$output" ]]
}

@test "profile should set _comp_setup variable after completion setup" {
	run zsh -c "source '$SCRIPT' && echo \$_comp_setup"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "1"
}
