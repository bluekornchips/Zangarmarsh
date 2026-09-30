########################################################
# Aliases
########################################################
# AWS
alias awsume=". awsume"
alias awsor="aws-sso-util login --force-refresh"

# Shell
alias bats="bats --verbose-run --timing"
alias batso="bats --show-output-of-passing-tests"
alias cbats="clear && bats"
alias cbatso="clear && bats --show-output-of-passing-tests"

# Development
alias drun='docker run -it --rm --entrypoint /usr/bin/env bash'
alias k="kubectl"
alias python="python3"

# Git
alias gms='git merge --squash'
alias gco='git checkout'

# Terraform
alias tfi='terraform init'
alias tfp='terraform plan -out temp.plan'
alias tfa='terraform apply temp.plan'

########################################################
# Custom Functions and Tools
########################################################
# Zangarmarsh Tools as functions so short names work in non-interactive shells

# Run one tool script under ZANGARMARSH_ROOT
#
# Inputs:
# - $1 relpath, path under the repository root
# - $@ forwarded to the tool script
#
# Returns:
# - Tool exit status
# - 1 when ZANGARMARSH_ROOT is unset
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

	shift
	"${ZANGARMARSH_ROOT}/${relpath}" "$@"
}

questlog() {
	_zangarmarsh_tool tools/quest-log/quest-log.sh "$@"
}

trilliax() {
	_zangarmarsh_tool tools/trilliax/trilliax.sh "$@"
}

hearthstone() {
	_zangarmarsh_tool tools/hearthstone/hearthstone.sh "$@"
}

auras() {
	_zangarmarsh_tool tools/auras/auras.sh "$@"
}
