#!/usr/bin/env zsh
#
# Zsh profile: our history and prompt on top of Oh My Zsh with
# plugins=(git zsh-autosuggestions).
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
# Call once for all shells, then again after Oh My Zsh so lib/history.zsh
# cannot leave its defaults in place.
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

# Oh My Zsh and the custom prompt are interactive-only.
# ZANGARMARSH_TEST=1 lets bats exercise this path under zsh -c.
if [[ ! -o interactive && -z "${ZANGARMARSH_TEST:-}" ]]; then
	return 0
fi

ZSH="${ZSH:-${HOME}/.oh-my-zsh}"
export ZSH
omz_init="${ZSH}/oh-my-zsh.sh"

if [[ ! -f "${omz_init}" ]]; then
	cat <<EOF >&2
profile.zsh:: Oh My Zsh is not installed at ${ZSH}.
Install it, then add the zsh-autosuggestions plugin:
	sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH}/plugins/zsh-autosuggestions
EOF
else
	# Empty theme so Oh My Zsh skips its prompt; we load prompt.zsh below.
	ZSH_THEME=""
	plugins=(git zsh-autosuggestions)
	source "${omz_init}" || {
		echo "profile.zsh:: Failed to source ${omz_init}" >&2
		return 1
	}

	# Oh My Zsh lib/history.zsh overwrites these; re-apply our values.
	zangarmarsh_apply_zsh_history || return 1
fi

if [[ ! -f "${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" ]]; then
	echo "profile.zsh:: Required file not found: ${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" >&2
	return 1
fi

source "${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" || {
	echo "profile.zsh:: Failed to source ${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh" >&2
	return 1
}

setopt PROMPT_SUBST 2>/dev/null || true
