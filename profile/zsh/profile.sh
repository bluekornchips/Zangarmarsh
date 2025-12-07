#!/usr/bin/env bash
#
# Zsh profile configuration with Oh My Zsh integration.

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="robbyrussell"

plugins=(git zsh-autosuggestions)

# Check and load Oh My Zsh
if [[ ! -f "$ZSH/oh-my-zsh.sh" ]]; then
	cat <<EOF >&2
Warning: Oh My Zsh is not installed.
To install Oh My Zsh, run:
	sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
Or visit: https://ohmyz.sh/#install
EOF
else

	source "$ZSH/oh-my-zsh.sh"
fi

# Check zsh-autosuggestions plugin
if [[ ! -d "$ZSH/plugins/zsh-autosuggestions" ]]; then
	cat <<EOF >&2
Warning: zsh-autosuggestions plugin is not installed.
To install zsh-autosuggestions, run:
	git clone https://github.com/zsh-users/zsh-autosuggestions \$ZSH/plugins/zsh-autosuggestions
Or visit: https://github.com/zsh-users/zsh-autosuggestions
EOF
fi

# Load zsh-autosuggestions plugin
if [[ -z "$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE" ]] && [[ -f "${ZSH}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then

	source "${ZSH}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
	ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#00ffff,bg=#2d2f40,bold"
fi

# Load custom zsh files
if [[ -z "$ZANGARMARSH_ROOT" ]]; then
	ZANGARMARSH_ROOT="$(cd "$(dirname -- "${0:A}")/../.." 2>/dev/null && pwd)"
	if [[ ! -d "$ZANGARMARSH_ROOT" ]]; then
		# Fallback to current directory if detection fails
		ZANGARMARSH_ROOT="$(pwd)"
	fi
fi

ZSH_FILES=(
	"platform.sh"
	"prompt.sh"
)

for file in "${ZSH_FILES[@]}"; do
	file_path="$ZANGARMARSH_ROOT/profile/zsh/$file"
	if [[ -f "$file_path" ]]; then

		source "$file_path" 2>/dev/null || {
			[[ "$ZANGARMARSH_VERBOSE" == "true" ]] && echo "Failed to source $file_path" >&2
		}
	fi
done

# Configure zsh history
unset HISTFILE HISTSIZE HISTFILESIZE HISTCONTROL HISTIGNORE
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000

[[ "$ZANGARMARSH_VERBOSE" == "true" ]] && echo "Loading zsh history configuration" >&2
[[ "$ZANGARMARSH_VERBOSE" == "true" ]] && echo "Set HISTFILE to: $HISTFILE" >&2

if [[ ! -f "$HISTFILE" ]]; then
	touch "$HISTFILE" 2>/dev/null || {
		[[ "$ZANGARMARSH_VERBOSE" == "true" ]] && echo "Cannot create history file $HISTFILE" >&2
	}
fi

setopt \
	hist_expire_dups_first \
	hist_ignore_dups \
	hist_ignore_space \
	hist_verify \
	share_history \
	extended_history

# Configure zsh completion
if [[ -z "$_comp_setup" ]]; then
	autoload -Uz compinit

	# Use cached completion dump if it's fresh, less than 24 hours old
	comp_dump="$HOME/.zcompdump"
	if [[ -f "$comp_dump" && "$comp_dump" -nt "$HOME/.zshrc" ]]; then
		compinit -C
	else
		compinit
	fi

	_comp_setup=1
fi

setopt PROMPT_SUBST 2>/dev/null || true
