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
alias gdlf="\$HOME/bluekornchips/gandalf/gandalf.sh"

# Zangarmarsh Tools
alias questlog="\$ZANGARMARSH_ROOT/tools/quest-log/quest-log.sh"
alias trilliax="\$ZANGARMARSH_ROOT/tools/trilliax/trilliax.sh"
alias hearthstone="\$ZANGARMARSH_ROOT/tools/hearthstone/hearthstone.sh"
alias talents="\$ZANGARMARSH_ROOT/tools/talent-calculator/talent-calculator.sh"
