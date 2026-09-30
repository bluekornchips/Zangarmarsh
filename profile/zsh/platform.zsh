#!/usr/bin/env zsh
#
# Zsh-only PATH and display aliases. Detection lives in tools/lib/platform.sh.
# zangarmarsh.sh normally exports PLATFORM_OS first; fall back when profile.zsh
# is sourced on its own.

if [[ -z "${PLATFORM_OS:-}" ]]; then
	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "platform.zsh:: PLATFORM_OS or ZANGARMARSH_ROOT is required" >&2
		return 1
	fi

	source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh"
	apply_platform_env || return 1
fi

case "${PLATFORM_OS}" in
macos)
	PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
	export PATH

	if command -v gls >/dev/null 2>&1; then
		alias ls='gls --color=auto'
	fi
	;;
linux)
	PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
	export PATH

	if [[ -x /usr/bin/dircolors ]]; then
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
	fi
	;;
esac

if [[ "${ZANGARMARSH_VERBOSE:-}" == "true" ]]; then
	echo "Platform detected: ${PLATFORM} os=${PLATFORM_OS}" >&2
fi

return 0
