#!/usr/bin/env bash
#
# Bash-specific configuration and history setup

if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
	echo "profile.sh:: ZANGARMARSH_ROOT is required" >&2
	return 1
fi

source "${ZANGARMARSH_ROOT}/profile/config.sh" || {
	echo "profile.sh:: Failed to source ${ZANGARMARSH_ROOT}/profile/config.sh" >&2
	return 1
}

# Force the bash history path. An inherited HISTFILE from zsh would point at
# ~/.zsh_history and pull extended_history lines into bash.
HISTFILE="${ZANGARMARSH_BASH_HISTFILE}"
export HISTFILE
HISTSIZE="${ZANGARMARSH_HISTSIZE}"
export HISTSIZE
HISTFILESIZE="${ZANGARMARSH_HISTSIZE}"
export HISTFILESIZE
HISTCONTROL="${ZANGARMARSH_HISTCONTROL}"
export HISTCONTROL
HISTIGNORE="${ZANGARMARSH_HIST_IGNORE}"
export HISTIGNORE

shopt -s histappend
shopt -s checkwinsize

bind 'set horizontal-scroll-mode off' 2>/dev/null || true
bind 'set completion-ignore-case on' 2>/dev/null || true

if [[ ! -f "${HISTFILE}" ]]; then
	(umask 077 && : >>"${HISTFILE}") || true
fi
