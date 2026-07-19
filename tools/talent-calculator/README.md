# Talent Calculator

Installs and checks CLI tools on a workstation. Supported platforms: `darwin-arm64` and `linux-amd64` only.

## Prerequisites

- Bash 3.2+
- `curl` for script-managed installers

## After sourcing Zangarmarsh

```bash
source /path/to/zangarmarsh/zangarmarsh.sh
# alias
talents
```

## Behavior

- Default with no mode flags: **check only**. Prints what is installed and what is missing. No installs.
- `--spec`: install missing script-managed tools. Core and extra tools are reported only; install those with your OS package manager.
- `--respec`: reinstall script-managed tools.
- `-r` or `--dry-run`: print actions without changing the system. Combine with `--spec` or `--respec` for a preview.

```bash
talents
talents --dry-run
talents --spec --dry-run
talents --spec
talents --respec --dry-run
talents --respec
talents --help
```

## Tool lists

Values match [talent-calculator.sh](talent-calculator.sh).

**Core, checked only**

- `jq`, `yq`, `bats`, `kubectl`

**Extra, checked only**

- `shfmt`, `aws`, `infracost`, `k9s`, `localstack`, `minikube`, `stern`, `tfenv`, `docker`

**Script-managed installers**

- `aws-sso-util` via `pipx`, `bun`, `helm` via helpers in `tools/talent-calculator/tools/`

## Testing

```bash
bats tools/talent-calculator/tests/talent-calculator-tests.sh
bats tools/talent-calculator/tests/other-tools-tests.sh
```
