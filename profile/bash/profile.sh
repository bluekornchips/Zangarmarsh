#!/usr/bin/env bash
#
# Bash-specific configuration and history setup

# Bash history configuration
[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Loading bash history configuration" >&2
export HISTFILE="${HISTFILE:-$HOME/.bash_history}"
export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTCONTROL=ignoredups:erasedups
export HISTIGNORE='ls:ll:cd:pwd:clear:history'

# Set bash options efficiently
shopt -s histappend
shopt -s checkwinsize

# Ensure proper line wrapping and backspace handling
bind 'set horizontal-scroll-mode off' 2>/dev/null || true
bind 'set completion-ignore-case on' 2>/dev/null || true

# Ensure history file exists and is writable
if [[ ! -f "$HISTFILE" ]]; then
	touch "$HISTFILE" 2>/dev/null || {
		[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "Cannot create history file $HISTFILE" >&2
	}
fi
