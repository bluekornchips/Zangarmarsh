# Quest Log

## Overview

Sync `.vscode/` settings from Zangarmarsh into a target project, printing a
diff and a summary for every file that changes. Cursor rules, commands, and
skills now live in the [familiar](https://github.com/bluekornchips/familiar)
plugin instead of being generated here; Quest Log is scoped to VS Code sync.

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

- Copies `.vscode/settings.json` and `.vscode/extensions.json` from Zangarmarsh into the target project
- Prints a color diff and a Created/Updated/Unchanged summary for each file
- Skips the sync when the target is the Zangarmarsh checkout itself

## Usage

```bash
# Sync .vscode into the current git repository root
questlog

# Sync .vscode for a specific directory tree
questlog /path/to/project

# Show help
questlog --help
```

## Files Created

- `.vscode/settings.json` and `.vscode/extensions.json` in the target project, copied from the Zangarmarsh template

## Testing

Install a Bats package so the `bats` binary is on your `PATH`, then run:

```bash
bats tools/quest-log/tests/quest-log-cli-tests.sh
```

You can also run `bash -n tools/quest-log/quest-log.sh` for a quick syntax check without Bats.

## Verification Steps

- [ ] `.vscode/settings.json` and `.vscode/extensions.json` appear in the target project after `questlog`
- [ ] Running `questlog` again on an unchanged target reports "No changes" for each file
