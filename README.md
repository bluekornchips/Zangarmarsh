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

- `aliases.sh` and `functions.sh`: tool aliases, `penv`, `nvm` lazy load when enabled, `gw`, and related helpers

Zsh also loads `profile/zsh/profile.zsh`, which pulls in Oh My Zsh, `profile/zsh/platform.zsh` for macOS and Linux PATH and aliases, and `profile/zsh/prompt.zsh` for the customizable prompt with Git branch and kubectl context.

Bash loads `profile/bash/profile.sh` for history and readline options only. It does not load the Zsh prompt or platform module.

## Install

```bash
git clone https://github.com/bluekornchips/Zangarmarsh.git
cd Zangarmarsh
make install
```

`make install` appends a source line to `~/.zshrc` and `~/.bashrc` and installs
the tracked quest-log plugin. Pass `--zsh` or `--bash` to target only one shell
rc file.

Dry-run first with:

```bash
profile/install.sh --dry-run
```

Manual source without the installer:

```bash
source /path/to/zangarmarsh/zangarmarsh.sh
```

## Install the quest-log plugin

The quest-log Cursor plugin lives under `tools/quest-log/plugin/` as tracked files and is the canonical agent configuration for this repository. Each `questlog` run installs that tree into `~/.cursor/plugins/local/quest-log` and syncs `.vscode/` into the target project.

```bash
source zangarmarsh.sh
questlog

questlog --dry-run /path/to/project
```

## Notes on destructive tools

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

These apply when `profile/zsh/prompt.zsh` runs:

- `ZANGARMARSH_PROMPT_CACHE_TTL=2`: Prompt cache TTL in seconds, default `2`
- `ZANGARMARSH_GIT_PROMPT=true`: Show git branch in prompt, default `true`
- `ZANGARMARSH_KUBE_PROMPT=true`: Show kubectl context in prompt, default `true`
- `ZANGARMARSH_SHOW_USER=true`: Show username in prompt, default `true`
- `ZANGARMARSH_SHOW_HOST=true`: Show hostname in prompt, default `true`
- `ZANGARMARSH_SHORTEN_NAMES=true`: Shorten user and host to one character, default `true`
- `ZANGARMARSH_PROMPT_SYMBOL=❯`: Trailing symbol, default `❯`

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
| `questlog`    | Quest Log         | Install the local quest-log plugin; sync `.vscode`                    |
| `trilliax`    | Trilliax          | Cleanup for caches and artifacts                                      |
| `talents`     | Talent Calculator | Check workstation CLIs; install script-managed tools with `--spec`    |
| `hearthstone` | Hearthstone       | Sync VS Code settings and quest log; optional Trilliax with `--force` |
| `auras`       | Auras             | AppImage `.desktop` launchers and `~/.local/bin` commands             |

Per-tool docs: [tools/README.md](tools/README.md).

## Requirements

- Bash 3.2+ or Zsh 5.0+
- Git for helpers that inspect the repository
- Standard Unix tools such as grep, sed, and awk
- Optional: Oh My Zsh and zsh-autosuggestions for the full Zsh stack described in [profile/zsh/profile.zsh](profile/zsh/profile.zsh)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
