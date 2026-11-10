#!/usr/bin/env zsh
#
# Zsh profile: history, platform PATH, completion, autosuggestions, and prompt.
#

if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
	echo "profile.zsh:: ZANGARMARSH_ROOT is required" >&2
	return 1
fi

# Load config when this file is sourced alone; zangarmarsh.sh already loaded it.
if [[ ! -f "${ZANGARMARSH_ROOT}/profile/config.sh" ]]; then
	echo "profile.zsh:: Required file not found: ${ZANGARMARSH_ROOT}/profile/config.sh" >&2
	return 1
fi

source "${ZANGARMARSH_ROOT}/profile/config.sh" || {
	echo "profile.zsh:: Failed to source ${ZANGARMARSH_ROOT}/profile/config.sh" >&2
	return 1
}

if [[ ! -f "${ZANGARMARSH_ROOT}/profile/zsh/platform.zsh" ]]; then
	echo "profile.zsh:: Required file not found: ${ZANGARMARSH_ROOT}/profile/zsh/platform.zsh" >&2
	return 1
fi

source "${ZANGARMARSH_ROOT}/profile/zsh/platform.zsh" || {
	echo "profile.zsh:: Failed to source ${ZANGARMARSH_ROOT}/profile/zsh/platform.zsh" >&2
	return 1
}

# Apply Zangarmarsh zsh history file, size, and ignore patterns.
#
# Side Effects:
# - Sets and exports HISTFILE, HISTSIZE, SAVEHIST, HISTORY_IGNORE
#
# Returns:
# - 0 on success
# - 1 when a required ZANGARMARSH_* value is missing
zangarmarsh_apply_zsh_history() {
	if [[ -z "${ZANGARMARSH_ZSH_HISTFILE:-}" ]]; then
		echo "zangarmarsh_apply_zsh_history:: ZANGARMARSH_ZSH_HISTFILE is required" >&2
		return 1
	fi

	if [[ -z "${ZANGARMARSH_HISTSIZE:-}" ]]; then
		echo "zangarmarsh_apply_zsh_history:: ZANGARMARSH_HISTSIZE is required" >&2
		return 1
	fi

	if [[ -z "${ZANGARMARSH_HIST_IGNORE:-}" ]]; then
		echo "zangarmarsh_apply_zsh_history:: ZANGARMARSH_HIST_IGNORE is required" >&2
		return 1
	fi

	HISTFILE="${ZANGARMARSH_ZSH_HISTFILE}"
	export HISTFILE
	HISTSIZE="${ZANGARMARSH_HISTSIZE}"
	export HISTSIZE
	SAVEHIST="${ZANGARMARSH_HISTSIZE}"
	export SAVEHIST
	HISTORY_IGNORE="(${ZANGARMARSH_HIST_IGNORE//:/|})"
	export HISTORY_IGNORE

	return 0
}

# Load zsh completion; use a cached dump when it is fresher than 24 hours.
#
# Side Effects:
# - Runs compinit -C against a fresh ${HOME}/.zcompdump, otherwise full compinit
# - Sets completion menu select and auto_menu
#
# Returns:
# - 0 on success
# - 1 when compinit fails
zangarmarsh_init_completions() {
	local zcompdump="${HOME}/.zcompdump"

	# LOCAL_OPTIONS keeps EXTENDED_GLOB from leaking into the caller shell.
	setopt LOCAL_OPTIONS EXTENDED_GLOB

	autoload -Uz compinit || {
		echo "zangarmarsh_init_completions:: failed to autoload compinit" >&2
		return 1
	}

	# Unquoted path so the mh+24 glob qualifier can match an aged dump.
	if [[ -f "${zcompdump}" && -z ${zcompdump}(#qN.mh+24) ]]; then
		compinit -C -d "${zcompdump}" || {
			echo "zangarmarsh_init_completions:: compinit -C failed" >&2
			return 1
		}
	else
		compinit -d "${zcompdump}" || {
			echo "zangarmarsh_init_completions:: compinit failed" >&2
			return 1
		}
	fi

	zstyle ':completion:*:*:*:*:*' menu select
	setopt auto_menu

	return 0
}

# Bind up-arrow to up-line-or-beginning-search for prefix history search.
#
# Side Effects:
# - Registers up-line-or-beginning-search and binds ^[[A and ^[OA
#
# Returns:
# - 0 on success
# - 1 when the widget cannot be loaded
zangarmarsh_bind_history_search() {
	autoload -Uz up-line-or-beginning-search || {
		echo "zangarmarsh_bind_history_search:: failed to autoload up-line-or-beginning-search" >&2
		return 1
	}

	zle -N up-line-or-beginning-search
	bindkey '^[[A' up-line-or-beginning-search
	bindkey '^[OA' up-line-or-beginning-search

	return 0
}

# Source zsh-autosuggestions when the configured path exists.
#
# Side Effects:
# - Sources ZANGARMARSH_ZSH_AUTOSUGGESTIONS
# - Writes an install hint to stderr when the file is missing
#
# Returns:
# - 0 always; missing autosuggestions is non-fatal
zangarmarsh_load_autosuggestions() {
	local suggest_path="${ZANGARMARSH_ZSH_AUTOSUGGESTIONS:-}"

	if [[ -z "${suggest_path}" ]]; then
		echo "zangarmarsh_load_autosuggestions:: ZANGARMARSH_ZSH_AUTOSUGGESTIONS is required" >&2
		return 0
	fi

	if [[ ! -f "${suggest_path}" ]]; then
		cat <<EOF >&2
profile.zsh:: zsh-autosuggestions not found at ${suggest_path}.
Install it:
	git clone https://github.com/zsh-users/zsh-autosuggestions \${HOME}/.zsh/zsh-autosuggestions
EOF
		return 0
	fi

	source "${suggest_path}" || {
		echo "zangarmarsh_load_autosuggestions:: Failed to source ${suggest_path}" >&2
		return 0
	}

	return 0
}

# Configure zsh history for interactive and non-interactive shells.
# Unset first so an inherited bash HISTFILE cannot stick.
unset HISTFILE HISTSIZE HISTFILESIZE HISTCONTROL HISTIGNORE HISTORY_IGNORE
zangarmarsh_apply_zsh_history || return 1

[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "profile.zsh:: Loading zsh history configuration" >&2
[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "profile.zsh:: Set HISTFILE to: ${HISTFILE}" >&2

[[ -f "${HISTFILE}" ]] || {
	touch "${HISTFILE}" && chmod 600 "${HISTFILE}"
} || true

setopt \
	hist_expire_dups_first \
	hist_ignore_dups \
	hist_ignore_space \
	hist_verify \
	share_history \
	extended_history

# Completion, autosuggestions, and the custom prompt are interactive-only.
# ZANGARMARSH_TEST=1 lets bats exercise this path under zsh -c.
if [[ ! -o interactive && -z "${ZANGARMARSH_TEST:-}" ]]; then
	return 0
fi

zangarmarsh_init_completions || return 1
zangarmarsh_bind_history_search || return 1
zangarmarsh_load_autosuggestions

if [[ ! -f "${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" ]]; then
	echo "profile.zsh:: Required file not found: ${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" >&2
	return 1
fi

source "${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" || {
	echo "profile.zsh:: Failed to source ${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" >&2
	return 1
}

setopt PROMPT_SUBST 2>/dev/null || true
