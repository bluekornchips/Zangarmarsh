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

- `aliases.sh`: short command aliases
- `functions.sh`: `penv`, `gw`, `drun`, `tfp`, `tfa`, plus the `nvm` lazy loader when enabled

Both shells load `tools/lib/platform.sh` so `PLATFORM` and `PLATFORM_OS` are set, and `tools/tools.sh` for `questlog`, `trilliax`, and `auras`. Zsh also loads `profile/zsh/profile.zsh`, which sets PATH and display aliases, and in interactive shells loads Oh My Zsh with `plugins=(git zsh-autosuggestions)`, then `profile/zsh/prompt.zsh` for the customizable prompt with Git branch and kubectl context.

Bash loads `profile/bash/profile.sh` for history and readline options only. It does not load the Zsh prompt. A second `source` of the same checkout is a no-op.

## Install

```bash
git clone https://github.com/bluekornchips/Zangarmarsh.git
cd Zangarmarsh
make install
```

`make install` writes one canonical source line into `~/.zshrc` and `~/.bashrc`, collapses duplicate or alternate source forms for this checkout, removes the official eager NVM block from `~/.bashrc`, and installs the tracked quest-log plugin plus user rules under `~/.cursor/rules`. Pass `--zsh` or `--bash` to `profile/install.sh` to target only one shell rc file.

Dry-run first with:

```bash
profile/install.sh --dry-run
```

Manual source without the installer:

```bash
source /path/to/zangarmarsh/zangarmarsh.sh
```

`make install` installs profile hooks, the local Cursor plugin, and user rules. For `questlog` usage, settings paths, rules sync, and plugin layout, see [tools/quest-log/README.md](tools/quest-log/README.md).

Trilliax can delete generated trees and caches.

## Configuration

Zangarmarsh loads configuration from:

- `profile/`: Shared env defaults, aliases, and functions for Bash and Zsh
- `profile/config.sh`: Shared profile defaults for history, NVM, and prompt
- `profile/bash/`: Bash-only history wiring and options
- `profile/zsh/`: Zsh-only platform PATH, Oh My Zsh load with git and zsh-autosuggestions, and prompt
- `tools/`: Optional CLI utilities documented in the per-tool READMEs under `tools/`

### Environment Variables

Defaults live in `profile/config.sh`. Set a variable before sourcing `zangarmarsh.sh` to override, except `ZANGARMARSH_BASH_HISTFILE` and `ZANGARMARSH_ZSH_HISTFILE`, which always follow `HOME`.

#### Core

- `ZANGARMARSH_ROOT`: Project root directory, set by `zangarmarsh.sh`, usually not set by hand
- `ZANGARMARSH_VERBOSE=true`: Print loader and platform debug lines to stderr
- `ZANGARMARSH_LAZY_LOADING=true`: Lazy-load NVM on first `nvm` call when NVM is enabled, default `true`
- `ZANGARMARSH_ENABLE_NVM=true`: Register NVM loader, default `true`
- `ZANGARMARSH_HISTSIZE=100000`: History size for bash and zsh
- `ZANGARMARSH_HIST_IGNORE`: Colon-separated ignore patterns, shared by bash `HISTIGNORE` and zsh `HISTORY_IGNORE`
- `ZANGARMARSH_BASH_HISTFILE`: Bash history file path, always `${HOME}/.bash_history`
- `ZANGARMARSH_ZSH_HISTFILE`: Zsh history file path, always `${HOME}/.zsh_history`
- `ZANGARMARSH_HISTCONTROL`: Bash `HISTCONTROL`, default `ignoredups:erasedups`

#### Prompt, Zsh only

These apply when `profile/zsh/prompt.zsh` runs:

- `ZANGARMARSH_PROMPT_CACHE_TTL=2`: Prompt cache TTL in seconds, default `2`
- `ZANGARMARSH_GIT_PROMPT=true`: Show git branch in prompt, default `true`
- `ZANGARMARSH_KUBE_PROMPT=true`: Show kubectl context in prompt, default `true`
- `ZANGARMARSH_SHOW_USER=true`: Show username in prompt, default `true`
- `ZANGARMARSH_SHOW_HOST=true`: Show hostname in prompt, default `true`
- `ZANGARMARSH_SHORTEN_NAMES=true`: Shorten user and host to one character, default `true`
- `ZANGARMARSH_PROMPT_SYMBOL=❯`: Trailing symbol, default `❯`
- `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE`: Ghost-text style for zsh-autosuggestions, default `fg=8`

## Tools

`zangarmarsh.sh` must be sourced from an interactive Bash or Zsh session. Non-interactive shells such as `bash -c`, `zsh -c`, scripts, and CI jobs are refused unless `ZANGARMARSH_TEST=1` is set for the bats harness. After a successful source, `questlog`, `trilliax`, and `auras` come from `tools/tools.sh` as shell functions, not aliases, that run the matching script under `ZANGARMARSH_ROOT`. They are not defined in shells that never sourced it. Each script can also run standalone and resolve `ZANGARMARSH_ROOT` from its location.

| Command    | Tool      | Role                                                      |
| ---------- | --------- | --------------------------------------------------------- |
| `questlog` | Quest Log | Install plugin; overwrite host Cursor user settings       |
| `trilliax` | Trilliax  | Cleanup for caches and artifacts                          |
| `auras`    | Auras     | AppImage `.desktop` launchers and `~/.local/bin` commands |

Per-tool docs: [quest-log](tools/quest-log/README.md), [trilliax](tools/trilliax/README.md), [auras](tools/auras/README.md).

## Shell functions

These functions come from `profile/functions.sh` and are defined in both shells:

| Function | Purpose                                                                                                         |
| -------- | --------------------------------------------------------------------------------------------------------------- |
| `gw`     | `gw add\|remove ...` passes through to `git worktree`; `gw NAME [BASE]` adds a sibling worktree on branch NAME  |
| `penv`   | Create and activate `.venv` in the current directory with `uv`; leaves an existing `.venv` alone                |
| `drun`   | Run `docker run -it --rm` on an image with `bash` as the entry command, usage `drun IMAGE [docker run args...]` |
| `tfp`    | Run `terraform plan` and write `.terraform/zangarmarsh.tfplan`                                                  |
| `tfa`    | Apply `.terraform/zangarmarsh.tfplan` from `tfp`                                                                |

## Requirements

- Bash 3.2+ or Zsh 5.0+
- Git for helpers that inspect the repository
- Standard Unix tools such as grep, sed, and awk
- Optional for interactive Zsh: [Oh My Zsh](https://ohmyz.sh/) under `~/.oh-my-zsh`, plus [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) at `$ZSH/plugins/zsh-autosuggestions`

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
