# Quest Log

## Overview

Generate AI assistant rules for Cursor from JSON metadata and Markdown quest templates in this directory. Rules are written under the target project.

## Prerequisites

- Bash 3.2 or greater
- `jq` for JSON parsing

## Install

```bash
# Source the main script
source /path/to/zangarmarsh/zangarmarsh.sh

# Quest-log will be available as an alias
questlog
```

## Features

- Creates Cursor rules under `.cursor/rules/user/`
- Creates Agent rules under `.agent/rules/`
- Generates Cursor commands from `tools/quest-log/commands/` into `.cursor/commands/user/`
- Generates Agent workflows into `.agent/workflows/`
- Template-based rule generation driven by `schema.json`

## Usage

```bash
# Generate rules in the current git repository root
questlog

# Generate rules for a specific directory tree
questlog /path/to/project

# Show help
questlog --help
```

## Configuration

The tool reads [tools/quest-log/schema.json](schema.json) and Markdown bodies from [tools/quest-log/quests/](quests/). Each quest file uses `Purpose`, `Priority`, `Standards`, `Usage`, and optional `Example` headings, with `Allowed` and `Denied` nested under `Usage`.

| Template        | Role                                                        |
| --------------- | ----------------------------------------------------------- |
| `always.md`     | Universal assistant behavior, safety, and response quality  |
| `python.md`     | Python typing, errors, imports, tests, and tooling          |
| `shell.md`      | Bash and zsh scripting, structure, and Bats testing         |
| `typescript.md` | TypeScript and JavaScript typing, modules, async, and tests |

## Daily Quests

Quest Log copies Markdown from `tools/quest-log/commands/` into `.cursor/commands/user/`. In Cursor chat you can invoke them with `/` plus the file stem, for example `/bash-review`.

See the [Cursor Commands documentation](https://cursor.com/docs/agent/chat/commands) for how commands work in the product.

### Available Daily Quests

- `bash-review.md`: Bash repository review checklist
- `author.md`: Documentation templates for PRs, tickets, README files, and specs
- `python-project-setup.md`: Python project bootstrap notes
- `typescript-review.md`: TypeScript review checklist

## Files Created

- `.cursor/rules/user/`: Cursor rule files named `rules-<quest>.mdc`
- `.agent/rules/`: Agent rule files named `rules-<quest>.md`
- `.cursor/commands/user/`: Cursor command Markdown from `commands/*.md`
- `.agent/workflows/`: Agent workflow Markdown derived from the same command sources

## Schema Format

Each object in `schema.json` defines:

- `name`: stem for output filenames
- `file`: Markdown template under `quests/`
- `icon`: leading acknowledgement line in generated rules
- `description` and `keywords`: Cursor metadata for rule selection
- `cursor.alwaysApply` and `cursor.globs`: Cursor application mode

## Testing

Install a Bats package so the `bats` binary is on your `PATH`, then run:

```bash
bats tools/quest-log/tests/quest-log-tests.sh
```

You can also run `bash -n tools/quest-log/quest-log.sh` and `jq empty tools/quest-log/schema.json` for quick checks without Bats.

## Verification Steps

- [ ] Rules appear under `.cursor/rules/user/` after `questlog`
- [ ] Commands appear under `.cursor/commands/user/` when `commands/` exists
- [ ] All schema entries generate matching Cursor and Agent rule files
