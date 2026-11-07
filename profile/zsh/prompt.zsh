#!/usr/bin/env zsh

# Zsh prompt configuration with git branch, kubectl context, and custom formatting

setopt PROMPT_SUBST
zmodload zsh/datetime 2>/dev/null || true

GREEN='%{%F{green}%}'
BLUE='%{%F{blue}%}'
CYAN='%{%F{cyan}%}'
RESET='%{%f%}'

_prompt_cache=""
_prompt_cache_time=0
_prompt_pwd_cache=""
_prompt_git_cache=""
_prompt_kube_cache=""

PROMPT_CACHE_TTL="${ZANGARMARSH_PROMPT_CACHE_TTL:-2}"
GIT_PROMPT_ENABLED="${ZANGARMARSH_GIT_PROMPT:-true}"
KUBE_PROMPT_ENABLED="${ZANGARMARSH_KUBE_PROMPT:-true}"
SHOW_USER="${ZANGARMARSH_SHOW_USER:-true}"
SHOW_HOST="${ZANGARMARSH_SHOW_HOST:-true}"
SHORTEN_NAMES="${ZANGARMARSH_SHORTEN_NAMES:-true}"
PROMPT_SYMBOL="${ZANGARMARSH_PROMPT_SYMBOL:-❯}"

# Resolve kubectl once at load. Keep empty when the binary is absent.
_prompt_kubectl=""
if [[ "${KUBE_PROMPT_ENABLED}" == "true" ]] && command -v kubectl >/dev/null 2>&1; then
	_prompt_kubectl="$(command -v kubectl)"
fi

# Read the current branch or short SHA from .git/HEAD with builtins.
#
# Inputs:
# - None, walks from PWD toward the filesystem root
#
# Outputs:
# - Branch name or short SHA on stdout when found
#
# Returns:
# - 0 when a ref is printed
# - 1 when no git directory is found or HEAD cannot be read
_prompt_git_from_head() {
	# Declare once outside the loop. In zsh, repeated local or typeset of an
	# existing name prints its value to stdout unless TYPESET_SILENT is set,
	# and that leak is captured into the prompt via command substitution.
	local dir="${PWD}"
	local git_dir
	local gitdir_line
	local head_file
	local head_content

	while [[ -n "${dir}" ]]; do
		if [[ -f "${dir}/.git" ]]; then
			gitdir_line="$(<"${dir}/.git")" || return 1
			# Worktree pointer: gitdir: /path/to/repo/.git/worktrees/name
			if [[ "${gitdir_line}" == gitdir:* ]]; then
				git_dir="${gitdir_line#gitdir: }"
				git_dir="${git_dir#"${git_dir%%[![:space:]]*}"}"
				git_dir="${git_dir%"${git_dir##*[![:space:]]}"}"
				if [[ "${git_dir}" != /* ]]; then
					git_dir="${dir}/${git_dir}"
				fi
			else
				return 1
			fi
		elif [[ -d "${dir}/.git" ]]; then
			git_dir="${dir}/.git"
		else
			if [[ "${dir}" == "/" ]]; then
				return 1
			fi

			dir="${dir:h}"
			continue
		fi

		head_file="${git_dir}/HEAD"
		if [[ ! -f "${head_file}" ]]; then
			return 1
		fi

		head_content="$(<"${head_file}")" || return 1
		head_content="${head_content%%$'\n'*}"
		if [[ "${head_content}" == ref:\ refs/heads/* ]]; then
			print -r -- "${head_content#ref: refs/heads/}"
			return 0
		fi

		if ((${#head_content} >= 7)); then
			print -r -- "${head_content[1,7]}"
			return 0
		fi

		return 1
	done

	return 1
}

# Resolve git branch suffix for the prompt, HEAD builtins then git fallback.
#
# Outputs:
# - Formatted branch suffix on stdout when a ref is found
#
# Returns:
# - 0 always
_prompt_git_info() {
	local branch
	branch="$(_prompt_git_from_head)" && {
		[[ -n "${branch}" ]] && print -r -- " (${branch})"
		return 0
	}

	if command -v git >/dev/null 2>&1; then
		branch="$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
		[[ -n "${branch}" ]] && print -r -- " (${branch})"
	fi

	return 0
}

# Build the complete prompt string with caching
#
# Outputs:
# - Prompt text on stdout
#
# Returns:
# - 0 always
build_prompt() {
	local current_pwd="${PWD}"

	local current_time
	if [[ -n "${EPOCHSECONDS:-}" ]]; then
		current_time="${EPOCHSECONDS}"
	else
		current_time="$(date +%s)"
	fi

	local cache_expired=0
	local pwd_changed=0

	if ((current_time - _prompt_cache_time > PROMPT_CACHE_TTL)); then
		cache_expired=1
	fi

	if [[ "${current_pwd}" != "${_prompt_pwd_cache}" ]]; then
		pwd_changed=1
	fi

	if ((cache_expired == 0 && pwd_changed == 0)) && [[ -n "${_prompt_cache}" ]]; then
		print -r -- "${_prompt_cache}"
		return 0
	fi

	local prompt=""

	if [[ "${KUBE_PROMPT_ENABLED}" == "true" ]]; then
		local kube_ctx
		if ((cache_expired)); then
			kube_ctx=""
			if [[ -n "${_prompt_kubectl}" ]]; then
				kube_ctx="$("${_prompt_kubectl}" config current-context 2>/dev/null)"
			fi

			_prompt_kube_cache="${kube_ctx}"
		else
			kube_ctx="${_prompt_kube_cache}"
		fi

		[[ -n "${kube_ctx}" ]] && prompt="${prompt}${CYAN}${kube_ctx}${RESET}"
	fi

	if [[ "${SHOW_USER}" == "true" || "${SHOW_HOST}" == "true" ]]; then
		if [[ "${SHOW_USER}" == "true" ]]; then
			local username="${USER:-}"
			if [[ -z "${username}" ]]; then
				username="$(whoami 2>/dev/null || echo 'user')"
			fi

			if [[ "${SHORTEN_NAMES}" == "true" ]]; then
				username="${username:0:1}"
			fi

			prompt="${prompt} ${BLUE}${username}${RESET}"
		fi

		if [[ "${SHOW_USER}" == "true" && "${SHOW_HOST}" == "true" ]]; then
			prompt="${prompt}${GREEN}@${RESET}"
		fi

		if [[ "${SHOW_HOST}" == "true" ]]; then
			local hostname="${HOST:-${HOSTNAME:-}}"
			if [[ -z "${hostname}" ]]; then
				hostname="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo 'localhost')"
			fi

			if [[ "${SHORTEN_NAMES}" == "true" ]]; then
				hostname="${hostname:0:1}"
			fi

			prompt="${prompt}${BLUE}${hostname}${RESET}"
		fi
	fi

	if [[ "${GIT_PROMPT_ENABLED}" == "true" ]]; then
		local git_info
		if ((pwd_changed || cache_expired)); then
			git_info="$(_prompt_git_info)"
			_prompt_git_cache="${git_info}"
		else
			git_info="${_prompt_git_cache}"
		fi

		prompt="${prompt}${GREEN}${git_info}${RESET}"
	fi

	prompt="${prompt} ${BLUE}${PWD/#${HOME}/~}${RESET}"
	prompt="${prompt} ${PROMPT_SYMBOL} "

	_prompt_cache="${prompt}"
	_prompt_cache_time="${current_time}"
	_prompt_pwd_cache="${current_pwd}"

	print -r -- "${prompt}"

	return 0
}

# build_prompt mutates cache globals. A command-substitution PROMPT would
# run it in a subshell, so the cache never persists. Use a precmd hook.
autoload -Uz add-zsh-hook

# Refresh the rendered prompt string in the current shell before each prompt
#
# Side Effects:
# - Sets _prompt_rendered from build_prompt
#
# Returns:
# - 0 always
_zangarmarsh_precmd_prompt() {
	_prompt_rendered="$(build_prompt)"
	return 0
}

_prompt_rendered=""
add-zsh-hook precmd _zangarmarsh_precmd_prompt
PROMPT='${_prompt_rendered}'
unset RPROMPT
