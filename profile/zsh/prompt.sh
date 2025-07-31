#!/usr/bin/env bash

# Zsh prompt configuration
# This script configures the zsh prompt with git branch, kubectl context, and custom formatting

setopt PROMPT_SUBST

GREEN='%{%F{green}%}'
BLUE='%{%F{blue}%}'
CYAN='%{%F{cyan}%}'
YELLOW='%{%F{yellow}%}'
RED='%{%F{red}%}'
RESET='%{%f%}'
#shellcheck disable=SC2148

# Display current git branch or commit information
git_branch() {
	if command -v git >/dev/null 2>&1; then
		local branch
		branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
		[[ -n "$branch" ]] && echo " ($branch)"
	fi
	echo ""
}

# Display current kubectl context if not docker-desktop
kube_context() {
	if command -v kubectl >/dev/null 2>&1; then
		local context
		context=$(kubectl config current-context 2>/dev/null)
		[[ -n "$context" && "$context" != "docker-desktop" ]] && echo "$context"
	fi
	echo ""
}

# Shorten string to specified length
shorten() {
	local input_string="$1"
	local str_length="$2"
	local min_length=1
	[[ $str_length -lt $min_length ]] && str_length=$min_length

	if [[ ${#input_string} -gt $str_length ]]; then
		echo "${input_string:0:$str_length}"
	else
		echo "$input_string"
	fi
}

# Get hostname based on platform
get_hostname() {
	if [[ "$PLATFORM" == "wsl" ]]; then
		echo "${HOSTNAME:-$(hostname 2>/dev/null || echo 'wsl')}"
	else
		echo "${HOSTNAME:-$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo 'localhost')}"
	fi
}

# Build the complete prompt string
build_prompt() {
	local prompt=""
	local kube_ctx
	local username
	local hostname

	kube_ctx="$(kube_context)"
	[[ -n "$kube_ctx" ]] && prompt="${prompt}${CYAN}${kube_ctx}${RESET}"

	# username@hostname, shortened
	username="${USER:-$(whoami 2>/dev/null || echo 'user')}"
	hostname="$(get_hostname)"
	prompt="${prompt} ${BLUE}$(shorten "$username" 1)${RESET}${GREEN}@${RESET}${BLUE}$(shorten "$hostname" 1)${RESET}"

	# git branch
	prompt="${prompt}${GREEN}$(git_branch)${RESET}"

	# current working directory
	prompt="${prompt} ${BLUE}${PWD/#$HOME/~}${RESET}"

	# prompt symbol
	prompt="${prompt} 🌻 "

	echo -e "$prompt"
}

# Set the prompt
PROMPT="\$(build_prompt)"
unset RPROMPT
