# SSH Agent setup
# This script configures and manages SSH agent for key authentication

# Check if SSH setup is enabled
if [[ "${ZANGARMARSH_ENABLE_SSH:-true}" != "true" ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "SSH setup disabled by configuration" >&2
	return 0
fi

# Helper function to only output debug info if ZANGARMARSH_VERBOSE is true
log_debug() {
	local message="$1"
	[[ "${ZANGARMARSH_VERBOSE:-}" != "true" ]] && return 0
	echo "$message" >&2
}

if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -n "${SSH_AGENT_PID:-}" ]] && [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
	log_debug "Found existing SSH agent socket: $SSH_AUTH_SOCK"
	log_debug "SSH agent pid: $SSH_AGENT_PID"
fi

# 'SSH_AUTH_SOCK' tells calling tools where to find the ssh-agent socket
# If SSH_AUTH_SOCK is set but invalid, clear it
if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ ! -S "${SSH_AUTH_SOCK:-}" ]]; then
	unset SSH_AUTH_SOCK
	unset SSH_AGENT_PID
fi

if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
	ssh_agent_pid=""

	# Check for existing ssh-agent pid
	if command -v pgrep >/dev/null 2>&1; then
		ssh_agent_pid=$(pgrep -u "$USER" ssh-agent 2>/dev/null | head -1 || true)
	fi

	# Finding a pid means we have an existing ssh-agent running, but does not mean we have a socket
	# 'SSH_AGENT_PID' is the pid of the ssh-agent process
	if [[ -n "$ssh_agent_pid" ]]; then
		for sock in /tmp/ssh-*/agent.*; do
			if [[ -S "$sock" ]]; then
				export SSH_AUTH_SOCK="$sock"
				export SSH_AGENT_PID="$ssh_agent_pid"
				log_debug "Found existing SSH agent socket: $SSH_AUTH_SOCK"
				log_debug "SSH agent pid: $SSH_AGENT_PID"
				break
			fi
		done
	fi

	# start new only if we don't have a socket
	if [[ -z "${SSH_AUTH_SOCK}" ]] && command -v ssh-agent >/dev/null 2>&1; then
		if ! eval "$(ssh-agent -s)" >/dev/null 2>&1; then
			echo "Failed to start SSH agent" >&2
		else
			log_debug "Started new SSH agent."
		fi
	fi
fi

# Load SSH keys into the agent
if [[ -n "${SSH_AUTH_SOCK}" ]] && command -v ssh-add >/dev/null 2>&1; then
	if ! ssh-add -l >/dev/null 2>&1; then
		# Only add keys if we're not in a test environment and .ssh directory exists
		if [[ "$ZANGARMARSH_VERBOSE" != "true" ]] && [[ -d "$HOME/.ssh" ]]; then
			# Add keys with timeout to prevent hanging
			if timeout 5s ssh-add >/dev/null 2>&1; then
				ssh_keys=$(ssh-add -l 2>/dev/null || echo "No keys loaded")
				log_debug "SSH keys loaded: $ssh_keys"
			else
				log_debug "Failed to add SSH keys to agent (timeout or no keys)"
			fi
		else
			log_debug "Skipping SSH key loading in test environment or missing .ssh directory"
		fi
	fi
fi

if [[ -n "${SSH_AUTH_SOCK}" ]]; then
	log_debug "SSH agent loaded successfully"
else
	echo -e "SSH agent not available\nSSH functionality may be limited" >&2
fi
