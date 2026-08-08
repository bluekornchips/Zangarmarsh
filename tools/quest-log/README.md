# Quest Log

## Overview

Install the tracked plugin tree in this directory under
`~/.cursor/plugins/local/quest-log`, and sync `.vscode/` settings into the
target project. There is no generation step: `plugin/` is the plugin.

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

- Replaces `~/.cursor/plugins/local/quest-log` with a fresh copy of `tools/quest-log/plugin/` on every run, so stale files never survive
- Syncs `.vscode/` from Zangarmarsh into the target project when the target is not this repo

## Usage

```bash
# Install plugin locally, sync .vscode in the current git repository root
questlog

# Same, syncing .vscode for a specific directory tree
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
  rules/*.mdc                  # Cursor rules, loaded in every window
  skills/quest-*/SKILL.md      # quest-* skills
  MCP.md                       # optional MCP setup guidance
```

This tracked plugin is the canonical agent configuration for this repository.
The old ignored `.agent/` directory is not a source tree and should not be
recreated. The plugin follows this repository's GPL-3.0-only license.

| Rule             | Role                                                        |
| ---------------- | ----------------------------------------------------------- |
| `always.mdc`     | Universal assistant behavior, safety, and response quality  |
| `lua.mdc`        | Lua and WoW addon guidance                                  |
| `python.mdc`     | Python typing, errors, imports, tests, and tooling          |
| `shell.mdc`      | Bash and zsh scripting, structure, and Bats testing         |
| `typescript.mdc` | TypeScript and JavaScript typing, modules, async, and tests |

## Skills

| Skill                        | Role                                                              |
| ---------------------------- | ----------------------------------------------------------------- |
| `quest-author`               | Documentation templates for PRs, tickets, README files, and specs |
| `quest-bash-review`          | Bash repository review checklist                                  |
| `quest-lua-review`           | Lua review checklist                                              |
| `quest-python-project-setup` | Python project bootstrap notes                                    |
| `quest-review`               | Strict maintainability review                                     |
| `quest-typescript-review`    | TypeScript review checklist                                       |

To add or change a rule or skill, edit the files under `plugin/` directly and
run `questlog` to install the update.

## Install layout

- `tools/quest-log/plugin/`: tracked plugin source, installed as-is
- `~/.cursor/plugins/local/quest-log/`: live local install refreshed every run

The live install is disposable. Edit the tracked source, validate it with
`make plugin-check`, then run `questlog` to refresh the local copy.

## VS Code settings

`questlog` always syncs `.vscode/` from the Zangarmarsh template into the target project when the target is not the Zangarmarsh repo itself.

## Testing

Install a Bats package so the `bats` binary is on your `PATH`, then run:

```bash
bats tools/quest-log/tests/quest-log-cli-tests.sh
```

You can also run `bash -n tools/quest-log/quest-log.sh` for a quick syntax check without Bats.

## Verification Steps

- [ ] `~/.cursor/plugins/local/quest-log/rules/always.mdc` exists after `questlog`
- [ ] `~/.cursor/plugins/local/quest-log/skills/quest-review/SKILL.md` exists after `questlog`
- [ ] Running `questlog` again on an unchanged tree reports "No changes" for `.vscode` files
- [ ] `.vscode/settings.json` appears in an external target project after `questlog`
- [ ] `questlog --dry-run /path/to/project` makes no file changes
