# SSH Agent setup
# This script configures and manages SSH agent for key authentication

# Check if SSH setup is enabled
if [[ "${ZANGARMARSH_ENABLE_SSH:-true}" != "true" ]]; then
	[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "SSH setup disabled by configuration" >&2
	# Early return for sourced scripts
	:
else

if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -n "${SSH_AGENT_PID:-}" ]] && [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
	:
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
				break
			fi
		done
	fi

	# start new only if we don't have a socket
	if [[ -z "${SSH_AUTH_SOCK}" ]] && command -v ssh-agent >/dev/null 2>&1; then
		if ! eval "$(ssh-agent -s)" >/dev/null 2>&1; then
			echo "Failed to start SSH agent" >&2
		fi
	fi
fi

# Load SSH keys into the agent
if [[ -n "${SSH_AUTH_SOCK}" ]] && command -v ssh-add >/dev/null 2>&1; then
	if ! ssh-add -l >/dev/null 2>&1; then
		# Only add keys if .ssh directory exists
		if [[ -d "$HOME/.ssh" ]]; then
			# Add keys with timeout to prevent hanging
			if timeout 5s ssh-add >/dev/null 2>&1; then
				ssh_keys=$(ssh-add -l 2>/dev/null || echo "No keys loaded")
			else
				# If default keys failed, try to add all private keys
				for key_file in "$HOME/.ssh"/*; do
					if [[ -f "$key_file" ]] && [[ "$key_file" != *.pub ]] && [[ "$key_file" != *known_hosts* ]]; then
						if timeout 5s ssh-add "$key_file" >/dev/null 2>&1; then
							break
						fi
					fi
				done
			fi
		fi
	fi
fi

if [[ -n "${SSH_AUTH_SOCK}" ]]; then
	:
else
	echo -e "SSH agent not available\nSSH functionality may be limited" >&2
fi

fi