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

#### Core Configuration

- `ZANGARMARSH_ROOT`: Project root directory (auto-detected, usually not needed)
- `ZANGARMARSH_VERBOSE=true`: Enable debug output for troubleshooting
- `ZANGARMARSH_LAZY_LOADING=true`: Enable lazy loading for expensive operations like NVM (default: `true`)
- `ZANGARMARSH_ENABLE_NVM=true`: Enable NVM lazy loading (default: `true`)
- `ZANGARMARSH_ENABLE_SSH=true`: Enable SSH agent setup (default: `true`)

#### Prompt Configuration

- `ZANGARMARSH_PROMPT_CACHE_TTL=2`: Prompt cache time-to-live in seconds (default: `2`)
- `ZANGARMARSH_GIT_PROMPT=true`: Show git branch in prompt (default: `true`)
- `ZANGARMARSH_KUBE_PROMPT=true`: Show kubectl context in prompt (default: `true`)
- `ZANGARMARSH_SHOW_USER=true`: Show username in prompt (default: `true`)
- `ZANGARMARSH_SHOW_HOST=true`: Show hostname in prompt (default: `true`)
- `ZANGARMARSH_SHORTEN_NAMES=true`: Shorten username/hostname to single character (default: `true`)
- `ZANGARMARSH_PROMPT_SYMBOL=🌻`: Custom prompt symbol (default: `🌻`)

## Features

| Feature                | Bash | Zsh |
| ---------------------- | ---- | --- |
| Git branch display     | Yes  | Yes |
| Kubernetes context     | Yes  | Yes |
| Platform detection     | Yes  | Yes |
| Platform-specific PATH | Yes  | Yes |
| SSH agent setup        | Yes  | Yes |
| Python venv helpers    | Yes  | Yes |
| Node.js management     | Yes  | Yes |
| Oh My Zsh integration  | No   | Yes |
| Basic completion       | No   | Yes |

## Tools

Development utilities in `tools/`:

- Quest Log: AI assistant rules generator for Cursor from JSON schema
- Trilliax: Development environment cleanup tool that removes generated files and build artifacts

See `tools/README.md` for detailed documentation and usage examples.

## Development

### Quick Commands

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
bats tools/trilliax/tests/trilliax-tests.sh
```

## Requirements

- Bash 4.0+ or Zsh 5.0+
- Git (for repository detection)
- Standard Unix tools (grep, sed, awk, etc.)
- Optional: Oh My Zsh (for enhanced Zsh features)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
