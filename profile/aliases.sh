########################################################
# Aliases
########################################################
# AWS
alias awsume=". awsume"
alias awsor="aws-sso-util login --force-refresh"

# Shell
alias bats="bats --verbose-run --timing"
alias shfmt="shfmt --ln=bats -w"

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
# Gandalf
alias gdlf="\$HOME/bluekornchips/gandalf/gandalf"

# Zangarmarsh Tools
alias questlog="\$ZANGARMARSH_ROOT/tools/quest-log/quest-log.sh"
alias dalaran="\$ZANGARMARSH_ROOT/tools/dalaran/dalaran.sh"
alias trilliax="\$ZANGARMARSH_ROOT/tools/trilliax/trilliax.sh"

# Copy the contents of the .vscode directory from the Zangarmarsh root to the current directory
alias vscodeoverride="cp -r \$ZANGARMARSH_ROOT/.vscode .vscode"
