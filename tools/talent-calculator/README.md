# Talent Calculator

## Overview

Development tools installation script for managing CLI tools on development workstations. Talent Calculator automates the installation of essential development tools via Homebrew and other installation methods, supporting both macOS and Linux platforms.

## Prerequisites

- Bash 3.2 or greater
- `curl` (required for downloads)
- `brew` (Homebrew, will be installed automatically if missing)

## Install

```bash
# Source the main script
source /path/to/zangarmarsh/zangarmarsh.sh

# Talent Calculator will be available as an alias
talents
```

## Features

- Automated installation of core development tools
- Platform detection (darwin-arm64, linux-amd64)
- Dry-run mode for previewing changes
- Reset mode for clean reinstallation
- Modular tool installation system
- Comprehensive error handling

## Usage

```bash
# Install all tools
talents

# Preview what would be installed (dry-run)
talents --dry-run

# Reset and reinstall all tools
talents --reset-talents

# Show help
talents --help
```

## Installation Order

### Core Tools

Installed first, essential for development:

- `jq` - JSON processor
- `yq` - YAML processor
- `bats-core` - Bash Automated Testing System
- `kubectl` - Kubernetes command-line tool

### Brew Tools

Installed via Homebrew after core tools:

- `shfmt` - Shell formatter
- `awscli` - AWS Command Line Interface
- `infracost` - Cloud cost estimation
- `k9s` - Kubernetes cluster management
- `localstack` - Local AWS cloud stack
- `minikube` - Local Kubernetes cluster
- `stern` - Multi pod log tailing
- `tfenv` - Terraform version manager

### Other Tools

Installed via non-brew methods:

- `aws-sso-util` - AWS SSO utilities (via pipx)
- `bun` - JavaScript runtime (via install script)
- `helm` - Kubernetes package manager (via install script)
- `docker` + `colima` - Container runtime (via brew, colima started automatically)
