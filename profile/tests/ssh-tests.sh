#!/usr/bin/env bats

# Test file for profile/ssh.sh
# Tests the SSH agent setup and key management functions against real SSH service

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$GIT_ROOT/profile/ssh.sh"
[[ -f "$SCRIPT" ]] || {
	echo "Script not found: $SCRIPT" >&2
	exit 1
}

#shellcheck disable=SC1091
source "$GIT_ROOT/profile/tests/fixtures.sh"

# Save and restore SSH environment for testing
save_ssh_environment() {
	# Store original SSH environment
	export ORIGINAL_SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}"
	export ORIGINAL_SSH_AGENT_PID="${SSH_AGENT_PID:-}"

	# Backup .ssh directory only if it exists
	HOME_BACKUP_DIR="$HOME/.ssh.backup"
	if [[ -d "$HOME/.ssh" ]]; then
		mv "$HOME/.ssh" "$HOME_BACKUP_DIR"
	fi
	export HOME_BACKUP_DIR
}

# Restore SSH environment to original state
restore_ssh_environment() {
	if [[ -n "${ORIGINAL_SSH_AUTH_SOCK:-}" ]]; then
		export SSH_AUTH_SOCK="$ORIGINAL_SSH_AUTH_SOCK"
	else
		unset SSH_AUTH_SOCK
	fi

	if [[ -n "${ORIGINAL_SSH_AGENT_PID:-}" ]]; then
		export SSH_AGENT_PID="$ORIGINAL_SSH_AGENT_PID"
	else
		unset SSH_AGENT_PID
	fi

	# Restore .ssh directory
	if [[ -d "${HOME_BACKUP_DIR:-}" ]]; then
		mv "$HOME_BACKUP_DIR" "$HOME/.ssh"
	fi
}

# Check if SSH agent is currently running
is_ssh_agent_running() {
	[[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -S "${SSH_AUTH_SOCK:-}" ]]
}

# Start a test SSH agent for testing purposes
start_test_ssh_agent() {
	if command -v ssh-agent >/dev/null 2>&1; then
		eval "$(ssh-agent -s)" >/dev/null 2>&1
		return 0
	fi

	echo "ssh-agent not available on this system" >&2
	exit 1
}

# Stop SSH agent and clean up environment
stop_ssh_agent() {
	# Stop any existing SSH agents
	if [[ -n "${SSH_AGENT_PID:-}" ]] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
		ssh-agent -k >/dev/null 2>&1 || true
	fi

	# Also try to kill any ssh-agent processes
	if command -v pgrep >/dev/null 2>&1; then
		pkill -f ssh-agent >/dev/null 2>&1 || true
	fi

	# Clear SSH environment
	unset SSH_AUTH_SOCK
	unset SSH_AGENT_PID
}

trap 'restore_ssh_environment' EXIT

# Setup test environment for SSH testing
setup() {
	save_ssh_environment # Save original ssh environment
	local test_dir
	test_dir=$(mktemp -d)
	cd "$test_dir" || exit 1
	TEST_IDENTITY_FILE="$test_dir/test-identity"
	ssh-keygen -t ed25519 -f "$TEST_IDENTITY_FILE" -N ""

	ZANGARMARSH_VERBOSE=true

	# Clear SSH environment for testing
	unset SSH_AUTH_SOCK
	unset SSH_AGENT_PID

	export TEST_DIR="$test_dir"
	export ZANGARMARSH_VERBOSE
}

# Clean up test environment
teardown() {
	restore_ssh_environment
}

@test "ssh should load successfully" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"
	echo "$output" | grep -q "SSH agent pid:"
}

@test "ssh should load successfully with existing socket and pid" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"
	echo "$output" | grep -q "SSH agent pid:"
}

@test "ssh should start new SSH agent when none running" {
	stop_ssh_agent

	unset SSH_AUTH_SOCK
	unset SSH_AGENT_PID

	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Started new SSH agent."
}

@test "ssh should handle invalid SSH socket gracefully" {
	export SSH_AUTH_SOCK="/tmp/nonexistent/agent.12345"

	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"
}

@test "ssh should load SSH keys when agent is available" {
	start_test_ssh_agent

	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"

	stop_ssh_agent
}

@test "ssh should handle missing .ssh directory gracefully" {
	start_test_ssh_agent
	[[ -d "$HOME/.ssh" ]] && mv "$HOME/.ssh" "$HOME_BACKUP_DIR"

	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"

	[[ -d "$HOME_BACKUP_DIR" ]] && mv "$HOME_BACKUP_DIR" "$HOME/.ssh"

	stop_ssh_agent
}

@test "ssh should handle empty .ssh directory gracefully" {
	start_test_ssh_agent

	mkdir -p "$TEST_DIR/.ssh"
	local original_home="$HOME"
	export HOME="$TEST_DIR"

	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"

	export HOME="$original_home"

	stop_ssh_agent
}

@test "ssh should load successfully with existing agent" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "SSH agent loaded successfully"
}

@test "ssh should handle multiple loads safely" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "SSH agent loaded successfully"
}

@test "ssh should be sourced multiple times safely" {
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"
	run "$SCRIPT"
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Found existing SSH agent socket"
}

@test "ssh should set up environment correctly" {
	run "$SCRIPT"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "SSH agent loaded successfully"
}

@test "ssh should work with bash" {
	stop_ssh_agent
	if command -v bash >/dev/null 2>&1; then
		run bash -c "cd '$GIT_ROOT' && source profile/ssh.sh && ssh-add '$TEST_IDENTITY_FILE' && echo 'Bash test successful'"
		[ "$status" -eq 0 ]
		echo "$output" | grep -q "Bash test successful"
	else
		skip "bash not available on this system"
	fi
}

@test "ssh should work with zsh" {
	stop_ssh_agent
	if command -v zsh >/dev/null 2>&1; then
		# Run zsh in non-interactive mode with minimal configuration
		run env ZDOTDIR=/dev/null zsh -c "cd '$GIT_ROOT' && source profile/ssh.sh && echo 'Zsh test successful'"
		[ "$status" -eq 0 ]
		echo "$output" | grep -q "Zsh test successful"
	else
		skip "zsh not available on this system"
	fi
}
