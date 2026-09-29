#!/usr/bin/env zsh
#
# Zsh-only PATH and display aliases. Detection runs once in zangarmarsh.sh.

if [[ -z "${PLATFORM_OS:-}" ]]; then
	echo "platform.zsh:: PLATFORM_OS is required; source zangarmarsh.sh first" >&2
	return 1
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
