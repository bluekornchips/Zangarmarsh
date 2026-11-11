#!/usr/bin/env zsh
#
# Zsh-only PATH and display aliases. Detection lives in tools/lib/platform.sh.
#

if [[ -z "${PLATFORM_OS:-}" ]]; then
	source "${ZANGARMARSH_ROOT}/tools/lib/platform.sh" || return 1
	apply_platform_env || return 1
fi

# Prepend each existing bin directory that is not already on PATH. The last
# directory in the list ends up first, so Homebrew wins over /usr/local.
for path_dir in /usr/local/sbin /usr/local/bin /opt/homebrew/bin; do
	if [[ -d "${path_dir}" && ":${PATH}:" != *":${path_dir}:"* ]]; then
		PATH="${path_dir}:${PATH}"
	fi
done

case "${PLATFORM_OS}" in
macos)
	if command -v gls >/dev/null 2>&1; then
		alias ls='gls --color=auto'
	fi
	;;
linux)
	if [[ -x /usr/bin/dircolors ]]; then
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
	fi
	;;
esac

return 0
