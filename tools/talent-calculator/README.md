# Talent Calculator

Installs and checks CLI tools on a workstation. Supported platforms: `darwin-arm64` and `linux-amd64` only.

## Prerequisites

- Bash 3.2+
- `curl` for Homebrew install
- Homebrew is installed by the script when missing, before other tools

## After sourcing Zangarmarsh

```bash
source /path/to/zangarmarsh/zangarmarsh.sh
# alias
talents
```

## Behavior

- Default with no mode flags: **check only**. Prints what is installed and what is missing. No installs.
- `--spec`: install missing tools.
- `--respec`: remove then reinstall where the installers support that flow.
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

**Core, Homebrew packages**

- `jq`, `yq`, `bats` from package `bats-core`, `kubectl` from package `kubernetes-cli`

**Additional Homebrew**

- `shfmt`, `aws` from package `awscli`, `infracost`, `k9s` from tap `derailed/k9s/k9s`, `localstack` from tap `localstack/tap/localstack-cli`, `minikube`, `stern`, `tfenv`

**Other installers**

- `aws-sso-util`, `bun`, `helm`, `docker` via bundled install helpers in `tools/talent-calculator/tools/`

## Testing

```bash
bats tools/talent-calculator/tests/talent-calculator-tests.sh
```
