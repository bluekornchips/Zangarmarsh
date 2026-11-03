#!/usr/bin/env zsh
#
# Zsh profile configuration. Sources the Oh My Zsh git plugin and
# zsh-autosuggestions without loading the Oh My Zsh framework.

ZSH="${ZSH:-${HOME}/.oh-my-zsh}"
export ZSH

if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
	echo "profile.zsh:: ZANGARMARSH_ROOT is required" >&2
	return 1
fi

# Shared PATH and display aliases for every zsh session that sources this file.
ZSH_COMMON_FILES=(
	"platform.zsh"
)

for file in "${ZSH_COMMON_FILES[@]}"; do
	file_path="${ZANGARMARSH_ROOT}/profile/zsh/${file}"
	if [[ ! -f "${file_path}" ]]; then
		echo "profile.zsh:: Required file not found: ${file_path}" >&2
		return 1
	fi

	source "${file_path}" || {
		echo "profile.zsh:: Failed to source ${file_path}" >&2
		return 1
	}
done

if ! source "${ZANGARMARSH_ROOT}/profile/config.sh"; then
	echo "profile.zsh:: Failed to source config.sh" >&2
	return 1
fi

# Configure zsh history for interactive and non-interactive shells.
# Force the zsh history path after unset so an inherited bash HISTFILE cannot stick.
unset HISTFILE HISTSIZE HISTFILESIZE HISTCONTROL HISTIGNORE HISTORY_IGNORE
HISTFILE="${ZANGARMARSH_ZSH_HISTFILE}"
export HISTFILE
HISTSIZE="${ZANGARMARSH_HISTSIZE}"
export HISTSIZE
SAVEHIST="${ZANGARMARSH_HISTSIZE}"
export SAVEHIST
HISTORY_IGNORE="(${ZANGARMARSH_HIST_IGNORE//:/|})"
export HISTORY_IGNORE

[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "profile.zsh:: Loading zsh history configuration" >&2
[[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]] && echo "profile.zsh:: Set HISTFILE to: ${HISTFILE}" >&2

if [[ ! -f "${HISTFILE}" ]]; then
	if ! touch "${HISTFILE}"; then
		echo "profile.zsh:: Cannot create history file ${HISTFILE}" >&2
	elif ! chmod 600 "${HISTFILE}"; then
		echo "profile.zsh:: Cannot set history file mode ${HISTFILE}" >&2
	fi
fi

setopt \
	hist_expire_dups_first \
	hist_ignore_dups \
	hist_ignore_space \
	hist_verify \
	share_history \
	extended_history

# Plugins, completion, and the prompt are interactive-only.
if [[ ! -o interactive ]]; then
	return 0
fi

# Completion must load before the git plugin so its compdef calls work.
# Do not touch _comp_setup; compinit owns that string and every completer evals it.
if [[ -z "${_zangarmarsh_compinit:-}" ]]; then
	autoload -Uz compinit

	# Use cached completion dump when it is newer than ${ZDOTDIR:-$HOME}/.zshrc.
	# -u skips the macOS compaudit prompt on Homebrew's group-writable fpath.
	comp_dump="${ZDOTDIR:-${HOME}}/.zcompdump"
	if [[ -f "${comp_dump}" && "${comp_dump}" -nt "${ZDOTDIR:-${HOME}}/.zshrc" ]]; then
		compinit -u -C -d "${comp_dump}"
	else
		compinit -u -d "${comp_dump}"
	fi

	_zangarmarsh_compinit=1
fi

git_lib="${ZSH}/lib/git.zsh"
git_plugin="${ZSH}/plugins/git/git.plugin.zsh"
if [[ ! -f "${git_lib}" || ! -f "${git_plugin}" ]]; then
	cat <<EOF >&2
Oh My Zsh git plugin files are not installed under ${ZSH}.
Install Oh My Zsh so lib/git.zsh and plugins/git/git.plugin.zsh are present:
	sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
Or visit: https://ohmyz.sh/#install
EOF
else
	source "${git_lib}" || {
		echo "profile.zsh:: Failed to source ${git_lib}" >&2
		return 1
	}

	source "${git_plugin}" || {
		echo "profile.zsh:: Failed to source ${git_plugin}" >&2
		return 1
	}
fi

autosuggestions="${ZSH}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ ! -f "${autosuggestions}" ]]; then
	cat <<EOF >&2
zsh-autosuggestions plugin is not installed.
To install zsh-autosuggestions, run:
	git clone https://github.com/zsh-users/zsh-autosuggestions \$ZSH/plugins/zsh-autosuggestions
Or visit: https://github.com/zsh-users/zsh-autosuggestions
EOF
else
	source "${autosuggestions}" || {
		echo "profile.zsh:: Failed to source ${autosuggestions}" >&2
		return 1
	}
fi

prompt_file="${ZANGARMARSH_ROOT}/profile/zsh/prompt.zsh"
if [[ ! -f "${prompt_file}" ]]; then
	echo "profile.zsh:: Required file not found: ${prompt_file}" >&2
	return 1
fi

source "${prompt_file}" || {
	echo "profile.zsh:: Failed to source ${prompt_file}" >&2
	return 1
}

setopt PROMPT_SUBST 2>/dev/null || true
