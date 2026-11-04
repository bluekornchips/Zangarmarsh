#!/usr/bin/env bash

# Run one tool script under ZANGARMARSH_ROOT
#
# Inputs:
# - $1 relpath, path under the repository root
# - $@ forwarded to the tool script
#
# Returns:
# - Tool exit status
# - 1 when ZANGARMARSH_ROOT is unset, the path is empty, or the script is missing
_zangarmarsh_tool() {
	local relpath="${1:-}"

	if [[ -z "${ZANGARMARSH_ROOT:-}" ]]; then
		echo "_zangarmarsh_tool:: ZANGARMARSH_ROOT is required" >&2
		return 1
	fi

	if [[ -z "${relpath}" ]]; then
		echo "_zangarmarsh_tool:: tool path is required" >&2
		return 1
	fi

	local tool_path="${ZANGARMARSH_ROOT}/${relpath}"
	if [[ ! -f "${tool_path}" || ! -x "${tool_path}" ]]; then
		echo "_zangarmarsh_tool:: tool not found or not executable: ${tool_path}" >&2
		return 1
	fi

	shift
	"${tool_path}" "$@"

	return $?
}

# Run tools/quest-log/quest-log.sh
#
# Inputs:
# - $@ forwarded to quest-log.sh
#
# Returns:
# - Tool exit status
# - 1 when the tool cannot be resolved
questlog() {
	_zangarmarsh_tool tools/quest-log/quest-log.sh "$@"
	return $?
}

# Run tools/trilliax/trilliax.sh
#
# Inputs:
# - $@ forwarded to trilliax.sh
#
# Returns:
# - Tool exit status
# - 1 when the tool cannot be resolved
trilliax() {
	_zangarmarsh_tool tools/trilliax/trilliax.sh "$@"
	return $?
}

# Run tools/auras/auras.sh
#
# Inputs:
# - $@ forwarded to auras.sh
#
# Returns:
# - Tool exit status
# - 1 when the tool cannot be resolved
auras() {
	_zangarmarsh_tool tools/auras/auras.sh "$@"
	return $?
}
