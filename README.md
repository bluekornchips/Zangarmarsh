# Zangarmarsh

> Shell profile setup and workstation tools for Bash and Zsh

<div align="center">

![Shell Compatibility](https://img.shields.io/badge/shell-bash%20%7C%20zsh-blue)
![Platform Support](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-green)
![Testing](https://img.shields.io/badge/tests-bats-orange)
![License](https://img.shields.io/badge/license-GPL%203.0-green)

</div>

---

## Why the name 'Zangarmarsh'?

Zangarmarsh is a zone in World of Warcraft overwhelmed by blue ambiance, dampness, glowing foliage, and massive mushrooms. The zone is one I return to whenever I make updates to my user interface or addon packages. When I think of Zangarmarsh I think of relaxtion, creativity, and grounding.

## What it does

After you `source zangarmarsh.sh`, both shells load shared files under `profile/`:

- `aliases.sh` and `functions.sh`: tool aliases, `penv`, `nvm` lazy load when enabled, `gw`, `list_changed_files`, and related helpers

Zsh also loads `profile/zsh/profile.sh`, which pulls in Oh My Zsh, `profile/zsh/platform.sh` for macOS and Linux PATH and aliases, and `profile/zsh/prompt.sh` for the customizable prompt with Git branch and kubectl context.

Bash loads `profile/bash/profile.sh` for history and readline options only. It does not load the Zsh prompt or platform module.

## Install

```bash
git clone https://github.com/bluekornchips/Zangarmarsh.git
cd Zangarmarsh
source zangarmarsh.sh

# Add to your shell profile for permanent setup
echo 'source /path/to/zangarmarsh/zangarmarsh.sh' >> ~/.bashrc
echo 'source /path/to/zangarmarsh/zangarmarsh.sh' >> ~/.zshrc
```

## Generate rules

Quest Log sources live under `tools/quest-log/`. Generated `.cursor/` and `.agent/` trees are gitignored.

```bash
source zangarmarsh.sh
questlog
```

## Notes on destructive tools

- Ice Block copies `~/.ssh` into `~/.ice-block/<hostname>/` when that path exists; protect the backup tree like your SSH directory
- Trilliax and Hearthstone `--force` can delete generated trees and caches
- Talent Calculator `--spec` may run remote upstream installers for script-managed tools such as Bun and Helm

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

| Feature                      | Bash | Zsh |
| ---------------------------- | ---- | --- |
| Shared aliases and tools     | Yes  | Yes |
| Git branch in prompt         | No   | Yes |
| Kubernetes context in prompt | No   | Yes |
| Platform PATH setup          | No   | Yes |
| Python venv helpers          | Yes  | Yes |
| Node.js via NVM              | Yes  | Yes |
| Oh My Zsh integration        | No   | Yes |
| Basic completion             | No   | Yes |

## Tools

After sourcing, aliases map to scripts under `tools/`:

| Alias         | Tool              | Role                                                                  |
| ------------- | ----------------- | --------------------------------------------------------------------- |
| `questlog`    | Quest Log         | Cursor and Agent rules from schema and Markdown                       |
| `trilliax`    | Trilliax          | Cleanup for caches and artifacts                                      |
| `talents`     | Talent Calculator | Check workstation CLIs; install script-managed tools with `--spec`    |
| `hearthstone` | Hearthstone       | Sync VS Code settings and quest log; optional Trilliax with `--force` |
| `iceblock`    | Ice Block         | Dotfile backup to `~/.ice-block/<hostname>/`                          |
| `auras`       | Auras             | AppImage `.desktop` launchers and `~/.local/bin` commands             |

Per-tool docs: [tools/README.md](tools/README.md).

## Requirements

- Bash 3.2+ or Zsh 5.0+
- Git for helpers that inspect the repository
- Standard Unix tools such as grep, sed, and awk
- Optional: Oh My Zsh and zsh-autosuggestions for the full Zsh stack described in [profile/zsh/profile.sh](profile/zsh/profile.sh)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
