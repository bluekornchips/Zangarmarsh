# Quest Log

## Overview

Install the tracked plugin tree in this directory under
`~/.cursor/plugins/local/quest-log` and overwrite host Cursor user settings from
`tools/vscode/settings.json`. There is no generation step: `plugin/` is the
plugin. Quest-log does not write project `.vscode/` files.

## Prerequisites

- Bash 3.2 or greater

## Install

```bash
# Source the main script
source /path/to/zangarmarsh/zangarmarsh.sh

# Quest-log will be available as an alias
questlog
```

## Features

- Replaces `~/.cursor/plugins/local/quest-log` with a fresh copy of
  `tools/quest-log/plugin/` on every run, so stale files never survive
- Overwrites host Cursor `User/settings.json` from `tools/vscode/settings.json`

## Usage

```bash
# Install plugin and overwrite host Cursor user settings
questlog

# Same, using a specific working directory
questlog /path/to/project

# Show help
questlog --help

questlog --dry-run /path/to/project
```

## Plugin source layout

`tools/quest-log/plugin/` is committed, hand-authored, and installed as-is:

```text
plugin/
  .cursor-plugin/plugin.json   # plugin manifest
  rules/*.mdc                  # Cursor rules
  skills/quest-*/SKILL.md      # quest-* skills
```

This tracked plugin is the canonical agent configuration for this repository.
The plugin follows this repository's GPL-3.0-only license.

| Rule             | Role                                                       |
| ---------------- | ---------------------------------------------------------- |
| `always.mdc`     | Universal assistant behavior, safety, and response quality |
| `never.mdc`      | Agent prohibitions, including no Python generation or run  |
| `shell.mdc`      | Shared shell quoting, status, and destructive-path rules   |
| `bash.mdc`       | Bash 3.2, locals, source guards, arrays, and Bats          |
| `zsh.mdc`        | Zsh 5 profile and Zsh-owned module rules                   |
| `python.mdc`     | User-reference Python standards; does not authorize agents |
| `lua.mdc`        | Lua and WoW addon guidance                                 |
| `javascript.mdc` | JavaScript modules, async work, errors, and tests          |
| `typescript.mdc` | TypeScript typing, modules, async work, errors, and tests  |

## Skills

| Skill                        | Role                                        |
| ---------------------------- | ------------------------------------------- |
| `quest-author`               | Current PR and issue delivery documents     |
| `quest-bash-review`          | Bash repository review checklist            |
| `quest-lua-review`           | Lua review checklist                        |
| `quest-python-project-setup` | Python project bootstrap notes for the user |
| `quest-review`               | Strict maintainability review               |
| `quest-typescript-review`    | TypeScript review checklist                 |

To add or change a rule or skill, edit the files under `plugin/` directly and
run `questlog` to install the update.

## Install layout

- `tools/quest-log/plugin/`: tracked plugin source, installed as-is
- `~/.cursor/plugins/local/quest-log/`: live local install refreshed every run

The live install is disposable. Edit the tracked source, then run `questlog` to
refresh the local copy.

## Cursor user settings

Canonical host Cursor settings live in `tools/vscode/settings.json`. Each
`questlog` run copies that file over the host Cursor user settings:

- Linux: `~/.config/Cursor/User/settings.json`
- macOS: `~/Library/Application Support/Cursor/User/settings.json`

There is no project `.vscode/` sync. `tools/vscode/extensions.json` is a
recommended extensions list only.

Edit `tools/vscode/settings.json`, then run `questlog` (or `hearthstone`) to
apply.

## Testing

Install a Bats package so the `bats` binary is on your `PATH`, then run:

```bash
bats tools/quest-log/tests/quest-log-cli-tests.sh
```

You can also run `bash -n tools/quest-log/quest-log.sh` for a quick syntax check
without Bats.

## Verification Steps

- [ ] `~/.cursor/plugins/local/quest-log/rules/always.mdc` exists after `questlog`
- [ ] `~/.cursor/plugins/local/quest-log/skills/quest-review/SKILL.md` exists after `questlog`
- [ ] Running `questlog` again reports "No changes" for Cursor user settings
- [ ] Cursor user settings match `tools/vscode/settings.json` after `questlog`
- [ ] No project `.vscode/` files are created by `questlog`
- [ ] `questlog --dry-run /path/to/project` makes no file changes
