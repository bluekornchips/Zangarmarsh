# Zangarmarsh

> Shell profile setup automation that for Bash & Zsh

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
git clone https://github.com/yourusername/zangarmarsh.git
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

# Available functions after sourcing:
# penv - Python virtual environment helper
# nvm - Node.js version manager
# questlog - Agent instructions tool
# dalaran - Command history library tool
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
| Path deduplication    | Yes  | Yes |
| SSH agent setup       | Yes  | Yes |
| Python venv helpers   | Yes  | Yes |
| Node.js management    | Yes  | Yes |
| Oh My Zsh integration | No   | Yes |
| Advanced completion   | No   | Yes |

## Tools

Zangarmarsh includes several powerful tools for development workflow enhancement:

### Dalaran Library

The `tools/dalaran/` directory contains a ZSH command library script that:

- Analyzes your ZSH history to identify most-used commands
- Creates a growing library of historical command snapshots
- Combines current history with historical top commands
- Generates a working history file with enhanced command prioritization
- Maintains backup files and command frequency rankings
- Supports dry-run mode for safe testing

```bash
# Run dalaran library script
./tools/dalaran/dalaran.sh

# Show top 20 most used commands
./tools/dalaran/dalaran.sh --top=20

# Preview changes without applying
./tools/dalaran/dalaran.sh --dry-run

# Use enhanced history in current session
export HISTFILE="$HOME/.dalaran/.active_history"
fc -R
```

### Quest Log

The `tools/quest-log/` directory contains tools for generating AI assistant rules:

- CLAUDE.md Generation: Creates core development standards for Claude Code
- Cursor Rules: Generates individual rule files for Cursor IDE
- Backup System: Safely backs up existing rules before overwriting
- Template-Based: Uses YAML schema to define rule structure

```bash
# Generate agent rules for current directory
./tools/quest-log/quest-log.sh

# Generate with backup of existing rules
./tools/quest-log/quest-log.sh --backup

# Generate rules in specified directory
./tools/quest-log/quest-log.sh /path/to/project
```

#### Generated Rule Types

- Core Standards: Essential development practices for all languages
- Python Standards: Type hints, testing, security, and async patterns
- Shell Standards: Bash scripting best practices and ShellCheck compliance
- Documentation Standards: Templates for PRs, READMEs, and API docs
- Test Data Standards: Lord of the Rings and World of Warcraft mock data

### Available Functions

After sourcing Zangarmarsh, these functions are available:

- `penv`: Python virtual environment helper
- `nvm`: Node.js version manager
- `questlog`: Quest log tool (alias for quest-log.sh)
- `dalaran`: Command history library tool (alias for dalaran.sh)

### Tool Documentation

Each tool includes comprehensive documentation:

- [Dalaran Library README](tools/dalaran/README.md): Command history analysis and enhancement
- [Quest Log README](tools/quest-log/README.md): AI assistant rule generation

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
bats tools/dalaran/dalaran-tests.sh
```

## Requirements

- Bash 4.0+ or Zsh 5.0+
- Git (for repository detection)
- Standard Unix tools (grep, sed, awk, etc.)
- Optional: Oh My Zsh (for enhanced Zsh features)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
