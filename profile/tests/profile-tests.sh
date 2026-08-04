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
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_DIR="$(mktemp -d "${base}/profile-test.XXXXXX")"
	cd "${TEST_DIR}" || return 1

	export TEST_DIR
	USER="testuser"
	export USER
	HOSTNAME="testhost"
	export HOSTNAME
	HOME="${TEST_DIR}"
	export HOME
	PWD="${TEST_DIR}"
	export PWD
	ZSH="${TEST_DIR}/.oh-my-zsh"
	export ZSH
	ZANGARMARSH_ROOT="$GIT_ROOT"
	export ZANGARMARSH_ROOT
	ZANGARMARSH_VERBOSE=true
	export ZANGARMARSH_VERBOSE

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

@test "profile:: configures zsh session" {
	run zsh -c "
		source '$SCRIPT' || exit 1
		printf 'ZSH=%s\n' \"\$ZSH\"
		printf 'THEME=%s\n' \"\$ZSH_THEME\"
		printf 'PLUGINS=%s\n' \"\${plugins[*]}\"
		printf 'HISTFILE=%s\n' \"\$HISTFILE\"
		printf 'HISTSIZE=%s\n' \"\$HISTSIZE\"
		printf 'SAVEHIST=%s\n' \"\$SAVEHIST\"
		printf 'STYLE=%s\n' \"\$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE\"
		printf 'ROOT=%s\n' \"\$ZANGARMARSH_ROOT\"
		printf 'COMP=%s\n' \"\$_comp_setup\"
	"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "^ZSH=."
	echo "$output" | grep -q "^THEME=robbyrussell$"
	echo "$output" | grep -q "git"
	echo "$output" | grep -q "zsh-autosuggestions"
	echo "$output" | grep -q "\.zsh_history"
	echo "$output" | grep -q "^HISTSIZE=100000$"
	echo "$output" | grep -q "^SAVEHIST=100000$"
	echo "$output" | grep -q "fg=#00ffff,bg=#2d2f40,bold"
	echo "$output" | grep -q "^ROOT=."
	echo "$output" | grep -q "^COMP=1$"
}

@test "profile:: handle missing Oh My Zsh gracefully" {
	rm -rf "$ZSH"
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "Oh My Zsh is not installed"
}

@test "profile:: handle missing zsh-autosuggestions plugin gracefully" {
	rm -rf "$ZSH/plugins/zsh-autosuggestions"
	run zsh -c "source '$SCRIPT'"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "zsh-autosuggestions plugin is not installed"
}
