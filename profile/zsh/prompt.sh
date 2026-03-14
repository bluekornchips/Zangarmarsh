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

# Prompt caching variables
_prompt_cache=""
_prompt_cache_time=0
_prompt_pwd_cache=""
_prompt_git_cache=""
_prompt_kube_cache=""

# Cache TTL from configuration (default 2 seconds)
PROMPT_CACHE_TTL="${ZANGARMARSH_PROMPT_CACHE_TTL:-2}"

# Feature flags from configuration
GIT_PROMPT_ENABLED="${ZANGARMARSH_GIT_PROMPT:-true}"
KUBE_PROMPT_ENABLED="${ZANGARMARSH_KUBE_PROMPT:-true}"
SHOW_USER="${ZANGARMARSH_SHOW_USER:-true}"
SHOW_HOST="${ZANGARMARSH_SHOW_HOST:-true}"
SHORTEN_NAMES="${ZANGARMARSH_SHORTEN_NAMES:-true}"
PROMPT_SYMBOL="${ZANGARMARSH_PROMPT_SYMBOL:-🌻}"

# Display current git branch or commit information with caching
git_branch() {
	if command -v git >/dev/null 2>&1; then
		local branch
		# Use faster git branch --show-current for performance
		branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
		[[ -n "$branch" ]] && echo " ($branch)"
	fi
}

# Display current kubectl context if not docker-desktop with caching
kube_context() {
	if command -v kubectl >/dev/null 2>&1; then
		local context
		context=$(kubectl config current-context 2>/dev/null)
		[[ -n "$context" && "$context" != "docker-desktop" ]] && echo "$context"
	fi
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

# Build the complete prompt string with caching
build_prompt() {
	local current_time
	local current_pwd="$PWD"

	# Get current time (use date +%s for compatibility)
	current_time=$(date +%s)

	# Check if we need to regenerate the cache
	local cache_expired=false
	local pwd_changed=false

	if ((current_time - _prompt_cache_time > PROMPT_CACHE_TTL)); then
		cache_expired=true
	fi

	if [[ "$current_pwd" != "$_prompt_pwd_cache" ]]; then
		pwd_changed=true
	fi

	# Return cached prompt if still valid
	if [[ "$cache_expired" == "false" && "$pwd_changed" == "false" && -n "$_prompt_cache" ]]; then
		echo -e "$_prompt_cache"
		return
	fi

	# Generate new prompt
	local prompt=""
	local kube_ctx
	local username
	local hostname
	local git_info

	# Only check kube context if enabled and cache expired (expensive operation)
	if [[ "$KUBE_PROMPT_ENABLED" == "true" ]]; then
		if [[ "$cache_expired" == "true" ]]; then
			kube_ctx="$(kube_context)"
			_prompt_kube_cache="$kube_ctx"
		else
			kube_ctx="$_prompt_kube_cache"
		fi
		[[ -n "$kube_ctx" ]] && prompt="${prompt}${CYAN}${kube_ctx}${RESET}"
	fi

	# username@hostname, with configuration options
	if [[ "$SHOW_USER" == "true" || "$SHOW_HOST" == "true" ]]; then
		if [[ "$SHOW_USER" == "true" ]]; then
			username="${USER:-$(whoami 2>/dev/null || echo 'user')}"
			if [[ "$SHORTEN_NAMES" == "true" ]]; then
				username="$(shorten "$username" 1)"
			fi
			prompt="${prompt} ${BLUE}${username}${RESET}"
		fi

		if [[ "$SHOW_USER" == "true" && "$SHOW_HOST" == "true" ]]; then
			prompt="${prompt}${GREEN}@${RESET}"
		fi

		if [[ "$SHOW_HOST" == "true" ]]; then
			hostname="$(get_hostname)"
			if [[ "$SHORTEN_NAMES" == "true" ]]; then
				hostname="$(shorten "$hostname" 1)"
			fi
			prompt="${prompt}${BLUE}${hostname}${RESET}"
		fi
	fi

	# git branch (check on pwd change or cache expiry) - only if enabled
	if [[ "$GIT_PROMPT_ENABLED" == "true" ]]; then
		if [[ "$pwd_changed" == "true" || "$cache_expired" == "true" ]]; then
			git_info="$(git_branch)"
			_prompt_git_cache="$git_info"
		else
			git_info="$_prompt_git_cache"
		fi
		prompt="${prompt}${GREEN}${git_info}${RESET}"
	fi

	# current working directory
	prompt="${prompt} ${BLUE}${PWD/#$HOME/~}${RESET}"

	# configurable prompt symbol
	prompt="${prompt} ${PROMPT_SYMBOL} "

	# Update cache
	_prompt_cache="$prompt"
	_prompt_cache_time="$current_time"
	_prompt_pwd_cache="$current_pwd"

	echo -e "$prompt"
}

# Set the prompt
PROMPT="\$(build_prompt)"
unset RPROMPT
