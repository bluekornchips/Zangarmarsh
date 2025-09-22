# Zangarmarsh

> Shell profile setup automation that works for Bash & Zsh

<div align="center">

![Shell Compatibility](https://img.shields.io/badge/shell-bash%20%7C%20zsh-blue)
![Platform Support](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-green)
![Testing](https://img.shields.io/badge/tests-bats-orange)
![License](https://img.shields.io/badge/license-GPL%203.0-green)

</div>

---

## Why the name 'Zangarmarsh'?

Zangarmarsh is a zone in World of Warcraft overwhelmed by blue ambiance, dampness, glowing foliage, and massive mushrooms. The zone is one I return to whenever I make updates to my user interface or addon packages. When I think of Zangarmarsh I think of relaxtion, creativity, and grounding.

## What it does

Zangarmarsh automatically configures your shell environment with:

- Cross-shell compatibility for Bash & Zsh
- Prompts with Git branch & Kubernetes context
- Platform detection for macOS/Linux/WSL
- Path management with deduplication
- Development tools (Homebrew, NVM, SSH agent, VS Code)
- SSH key management and agent setup
- Python virtual environment helpers (`penv`)
- Node.js version management (`nvm`)

## Install

```bash
# Clone the repository
git clone https://github.com/bluekornchips/zangarmarsh.git
cd zangarmarsh

# Source the main script
source zangarmarsh.sh

# Add to your shell profile for permanent setup
echo 'source /path/to/zangarmarsh/zangarmarsh.sh' >> ~/.bashrc
echo 'source /path/to/zangarmarsh/zangarmarsh.sh' >> ~/.zshrc
```

## Quick Start

```bash
# Test all components
make test-all

# Reload configuration
source ~/.bashrc  # or ~/.zshrc

# Quick reload alias (available after sourcing)
zngr
```

## Configuration

Zangarmarsh loads configuration from:

- `profile/`: Shared functionality and shell components
- `profile/zsh/`: Zsh-specific settings
- `tools/`: Additional utilities and tools

### Environment Variables

- `ZANGARMARSH_VERBOSE=true`: Enable debug output
- `ZANGARMARSH_ROOT`: Project root (auto-detected)

## Features

| Feature               | Bash | Zsh |
| --------------------- | ---- | --- |
| Git branch display    | Yes  | Yes |
| Kubernetes context    | Yes  | Yes |
| Platform detection    | Yes  | Yes |
| Platform-specific PATH| Yes  | Yes |
| SSH agent setup       | Yes  | Yes |
| Python venv helpers   | Yes  | Yes |
| Node.js management    | Yes  | Yes |
| Oh My Zsh integration | No   | Yes |
| Basic completion      | No   | Yes |

## Tools

### Dalaran Library

The `tools/dalaran/` directory contains a ZSH command library script that:

- Analyzes your command history to find most-used commands
- Creates an enhanced history file prioritizing valuable commands
- Maintains a growing library that improves over time
- Supports dry-run mode for safe testing

```bash
# Run dalaran library script
./tools/dalaran/dalaran.sh

# Preview changes without applying
DRY_RUN=true ./tools/dalaran/dalaran.sh
```

### Quest Log

The `tools/quest-log/` directory contains tools for generating AI assistant rules:

```bash
# Generate agent rules for current directory
./tools/quest-log/quest-log.sh

# Generate with backup of existing rules
./tools/quest-log/quest-log.sh --backup
```

### Trilliax

The `tools/trilliax/` directory contains cleanup and maintenance utilities:

```bash
# Run trilliax cleanup script
./tools/trilliax/trilliax.sh
```

## Development

```bash
# Run all tests
make test-all

# Format shell scripts
make format

# Check shell scripts
make lint

# Run comprehensive checks
make check

# Run specific test suites
bats profile/tests/
bats tools/dalaran/tests/dalaran-tests.sh
bats tools/trilliax/tests/trilliax-tests.sh
```

## Requirements

- Bash 4.0+ or Zsh 5.0+
- Git (for repository detection)
- Standard Unix tools (grep, sed, awk, etc.)
- Optional: Oh My Zsh (for enhanced Zsh features)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
