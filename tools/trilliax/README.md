# Trilliax Cleanup Tool

## Overview

Trilliax removes generated files and directories from development environments: temporary files, cache directories, and build artifacts selected by target.

The name [Trilliax](https://www.wowhead.com/npc=104288/trilliax) comes from a World of Warcraft raid boss that was once a proud cleaner servant that now has multiple personalities, all of which are related to cleaning. "Filthy, filthy, FILTHY!" is one my friends and I quote often.

## Usage

```bash
# Clean current directory (all targets)
./tools/trilliax/trilliax.sh --all

# Clean specific directory, positional or with -d/--dir
./tools/trilliax/trilliax.sh --all /path/to/project
./tools/trilliax/trilliax.sh --all --dir /path/to/project

# Preview what would be cleaned (dry-run mode)
./tools/trilliax/trilliax.sh --dry-run --all

# Clean only specific targets
./tools/trilliax/trilliax.sh --targets cursor,python

# Show help
./tools/trilliax/trilliax.sh --help
```

## Options

| Flag                | Meaning                                                       |
| ------------------- | ------------------------------------------------------------- |
| `-d`, `--dir PATH`  | Directory to clean, default is the current directory          |
| `-t`, `--targets L` | Comma-separated targets from `cursor`, `python`, `node`, `fs` |
| `-a`, `--all`       | Clean every target; overrides `--targets`                     |
| `-r`, `--dry-run`   | Print what would be removed without changing anything         |
| `-h`, `--help`      | Show usage                                                    |

A positional `DIRECTORY` is the same as `--dir`. Either `--all` or `--targets` is required.

## Cleanup Targets

### Cursor Target

- `.cursor/` directories (recursively)

### Python Target

- Virtual environments (`venv/`, `.venv/`)
- Python cache files (`__pycache__/`, `*.pyc`, `*.pyo`)

### Node Target

- `node_modules/` directories
- NPM cache directories (`.npm/`)
- NPM and Yarn debug logs

### Filesystem Target

- Empty directories up to 10 levels deep

## Environment Variables

- `DRY_RUN=true`: Enable dry-run mode, same as `--dry-run`. Any other value means a live run
- `MAX_DEPTH`: Maximum `find` depth, default `10`. Must be a non-negative integer or the run fails

## Behavior

- Targets run in the order given. A failing target is counted and the remaining targets still run, then the exit status is 1.
- Only paths below the directory being cleaned are removed. The directory itself is never removed, even when it matches a target name such as `.cursor`.
- Unknown flags, a missing value for `--dir` or `--targets`, an unknown target name, a missing directory, or no targets at all fail with exit status 1 before anything is deleted.
- Dry-run lists nested empty directories for the filesystem target even though the parent only becomes empty after its children go.
- `--dir` is resolved to an absolute path before cleaning, so directory names with spaces work.

## Testing

```bash
bats tools/trilliax/tests/trilliax-tests.sh
```
