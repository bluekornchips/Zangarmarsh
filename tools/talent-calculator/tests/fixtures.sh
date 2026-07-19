#!/usr/bin/env bash
#
# Shared mocks and helpers for talent-calculator Bats tests
#

mock_curl_success() {
	curl() {
		echo "curl $*"
		return 0
	}
	export -f curl
}

mock_curl_failure() {
	curl() {
		echo "curl $*" >&2
		return 1
	}
	export -f curl
}

mock_command_installed() {
	local cmd_name="$1"
	command() {
		if [[ "$1" == "-v" ]] && [[ "$2" == "${cmd_name}" ]]; then
			echo "/usr/local/bin/${cmd_name}"
			return 0
		fi
		builtin command "$@"
	}
	export -f command
}

mock_command_not_installed() {
	local cmd_name="$1"
	command() {
		if [[ "$1" == "-v" ]] && [[ "$2" == "${cmd_name}" ]]; then
			return 1
		fi
		builtin command "$@"
	}
	export -f command
}

mock_uname_darwin_arm64() {
	uname() {
		case "$1" in
		-s) echo "Darwin" ;;
		-m) echo "arm64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname
}

mock_uname_linux_amd64() {
	uname() {
		case "$1" in
		-s) echo "Linux" ;;
		-m) echo "x86_64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname
}

mock_uname_linux_arm64() {
	uname() {
		case "$1" in
		-s) echo "Linux" ;;
		-m) echo "aarch64" ;;
		*) builtin command uname "$@" ;;
		esac
	}
	export -f uname
}

mock_all_other_tools_installed() {
	check_is_installed() {
		[[ -n "$1" ]] || return 1
		return 0
	}
	export -f check_is_installed
}
