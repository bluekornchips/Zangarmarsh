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

After you `source zangarmarsh.sh`, both shells load shared files under `profile/`:

- `aliases.sh` and `functions.sh`: tool aliases, `penv`, `nvm` lazy load when enabled, `gw`, `list_changed_files`, `runint`, and related helpers

Zsh also loads `profile/zsh/profile.sh`, which pulls in Oh My Zsh, `profile/zsh/platform.sh` for macOS, Linux, and WSL PATH and aliases, and `profile/zsh/prompt.sh` for the customizable prompt with Git branch and kubectl context.

Bash loads `profile/bash/profile.sh` for history and readline options only. It does not load the Zsh prompt or platform module.

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
# Run all Bats tests
make test

# Reload configuration after editing profile files
source zangarmarsh.sh
```

## Configuration

Zangarmarsh loads configuration from:

- `profile/`: Shared aliases and functions for Bash and Zsh
- `profile/bash/`: Bash-only history and options
- `profile/zsh/`: Zsh-only Oh My Zsh, platform PATH, prompt, completion
- `tools/`: Optional CLI utilities documented in [tools/README.md](tools/README.md)

### Environment Variables

#### Core

- `ZANGARMARSH_ROOT`: Project root directory, set by `zangarmarsh.sh`, usually not set by hand
- `ZANGARMARSH_VERBOSE=true`: Print loader and platform debug lines to stderr
- `ZANGARMARSH_LAZY_LOADING=true`: Lazy-load NVM on first `nvm` call when NVM is enabled, default `true`
- `ZANGARMARSH_ENABLE_NVM=true`: Register NVM loader, default `true`

#### Prompt, Zsh only

These apply when `profile/zsh/prompt.sh` runs:

- `ZANGARMARSH_PROMPT_CACHE_TTL=2`: Prompt cache TTL in seconds, default `2`
- `ZANGARMARSH_GIT_PROMPT=true`: Show git branch in prompt, default `true`
- `ZANGARMARSH_KUBE_PROMPT=true`: Show kubectl context in prompt, default `true`
- `ZANGARMARSH_SHOW_USER=true`: Show username in prompt, default `true`
- `ZANGARMARSH_SHOW_HOST=true`: Show hostname in prompt, default `true`
- `ZANGARMARSH_SHORTEN_NAMES=true`: Shorten user and host to one character, default `true`
- `ZANGARMARSH_PROMPT_SYMBOL=🌻`: Trailing symbol, default sunflower

## Features

| Feature                            | Bash | Zsh |
| ---------------------------------- | ---- | --- |
| Shared aliases and tools           | Yes  | Yes |
| Git branch in prompt               | No   | Yes |
| Kubernetes context in prompt       | No   | Yes |
| Platform PATH and brew integration | No   | Yes |
| Python venv helpers                | Yes  | Yes |
| Node.js via NVM                    | Yes  | Yes |
| Oh My Zsh integration              | No   | Yes |
| Basic completion                   | No   | Yes |

## Tools

Scripts under `tools/` with per-tool README files:

- Quest Log: Cursor rules from JSON schema, see [tools/quest-log/README.md](tools/quest-log/README.md)
- Trilliax: cleanup for caches and artifacts, see [tools/trilliax/README.md](tools/trilliax/README.md)
- Talent Calculator: workstation CLI installs, see [tools/talent-calculator/README.md](tools/talent-calculator/README.md)
- Hearthstone: sync VS Code settings, quest log, Gandalf, optional Trilliax, see [tools/hearthstone/README.md](tools/hearthstone/README.md)
- Ice Block: dotfile backup to `~/.ice-block/<hostname>/`, see [tools/ice-block/README.md](tools/ice-block/README.md)
- Auras: AppImage `.desktop` launchers, see [tools/auras/README.md](tools/auras/README.md)

Index and one-line commands: [tools/README.md](tools/README.md).

## Development

```bash
make test
bats profile/tests/
bats tools/trilliax/tests/trilliax-tests.sh
```

## Requirements

- Bash 4.0+ or Zsh 5.0+
- Git for helpers that inspect the repository
- Standard Unix tools such as grep, sed, and awk
- Optional: Oh My Zsh and zsh-autosuggestions for the full Zsh stack described in [profile/zsh/profile.sh](profile/zsh/profile.sh)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
