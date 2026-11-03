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

- `aliases.sh` and `functions.sh`: tool commands as functions, `penv`, `nvm` lazy load when enabled, `gw`, and related helpers

Both shells load `tools/lib/platform.sh` so `PLATFORM` and `PLATFORM_OS` are set. Zsh also loads `profile/zsh/profile.zsh`, which sets PATH and display aliases, and in interactive shells sources the Oh My Zsh git plugin files, zsh-autosuggestions, and `profile/zsh/prompt.zsh` for the customizable prompt with Git branch and kubectl context.

Bash loads `profile/bash/profile.sh` for history and readline options only. It does not load the Zsh prompt. A second `source` of the same checkout is a no-op.

## Install

```bash
git clone https://github.com/bluekornchips/Zangarmarsh.git
cd Zangarmarsh
make install
```

`make install` writes one canonical source line into `~/.zshrc` and `~/.bashrc`,
collapses duplicate or alternate source forms for this checkout, removes the
official eager NVM block from `~/.bashrc`, and installs the tracked quest-log
plugin. Pass `--zsh` or `--bash` to `profile/install.sh` to target only one shell rc file.

Dry-run first with:

```bash
profile/install.sh --dry-run
```

Manual source without the installer:

```bash
source /path/to/zangarmarsh/zangarmarsh.sh
```

## Install the quest-log plugin

`make install` installs the tracked quest-log plugin. For `questlog` usage, settings paths, and plugin layout, see [tools/quest-log/README.md](tools/quest-log/README.md).

## Notes on destructive tools

- Trilliax can delete generated trees and caches

## Configuration

Zangarmarsh loads configuration from:

- `profile/`: Shared aliases and functions for Bash and Zsh
- `profile/bash/`: Bash-only history and options
- `profile/zsh/`: Zsh-only git plugin and autosuggestions load, platform PATH, prompt, completion
- `tools/`: Optional CLI utilities documented in the per-tool READMEs under `tools/`

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

| Feature                       | Bash | Zsh |
| ----------------------------- | ---- | --- |
| Shared aliases and tools      | Yes  | Yes |
| Git branch in prompt          | No   | Yes |
| Kubernetes context in prompt  | No   | Yes |
| Platform PATH setup           | No   | Yes |
| Shared PLATFORM / PLATFORM_OS | Yes  | Yes |
| Python venv helpers           | Yes  | Yes |
| Node.js via NVM               | Yes  | Yes |
| Oh My Zsh git plugin aliases  | No   | Yes |
| Case-insensitive readline     | Yes  | No  |
| Programmable completion       | No   | Yes |

## Tools

After sourcing, functions map to scripts under `tools/` and work in interactive and non-interactive shells. Each script can also run standalone and resolve `ZANGARMARSH_ROOT` from its location.

| Command    | Tool      | Role                                                      |
| ---------- | --------- | --------------------------------------------------------- |
| `questlog` | Quest Log | Install plugin; overwrite host Cursor user settings       |
| `trilliax` | Trilliax  | Cleanup for caches and artifacts                          |
| `auras`    | Auras     | AppImage `.desktop` launchers and `~/.local/bin` commands |

Per-tool docs: [quest-log](tools/quest-log/README.md), [trilliax](tools/trilliax/README.md), [auras](tools/auras/README.md).

## Requirements

- Bash 3.2+ or Zsh 5.0+
- Git for helpers that inspect the repository
- Standard Unix tools such as grep, sed, and awk
- Optional: Oh My Zsh plugin files under `~/.oh-my-zsh` (`lib/git.zsh`, `plugins/git`, `plugins/zsh-autosuggestions`) for the full interactive Zsh stack described in [profile/zsh/profile.zsh](profile/zsh/profile.zsh)

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
