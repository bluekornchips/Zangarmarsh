# Trilliax Cleanup Tool

## Overview

Trilliax is a powerful cleanup utility that removes generated files and directories from development environments. It intelligently identifies and removes temporary files, cache directories, and build artifacts while preserving important configuration files.

The name [Trilliax](https://www.wowhead.com/npc=104288/trilliax) comes from a World of Warcraft raid boss that was once a proud cleaner servant that now has multiple personalities, all of which are related to cleaning. "Filthy, filthy, FILTHY!" is one my friends and I quote often.

## Features

- Removes temporary files, cache directories, and build artifacts
- Supports multiple cleanup targets (cursor, python, node, fs)
- Preserves important configuration files
- Dry-run mode for safe preview of operations
- Recursive cleanup with smart filtering
- Configurable target selection
- Empty directory cleanup

## Install

```bash
# Ensure script is executable
chmod +x tools/trilliax/trilliax.sh

# Optionally, Zangarmarsh provides a trilliax alias when sourced
source /path/to/zangarmarsh/zangarmarsh.sh
```

## Usage

```bash
# Clean current directory (all targets)
./tools/trilliax/trilliax.sh

# Clean specific directory
./tools/trilliax/trilliax.sh /path/to/project

# Preview what would be cleaned (dry-run mode)
./tools/trilliax/trilliax.sh --dry-run

# Clean only specific targets
./tools/trilliax/trilliax.sh --targets=cursor,python

# Clean all targets explicitly
./tools/trilliax/trilliax.sh --all

# Show help
./tools/trilliax/trilliax.sh --help
```

## Cleanup Targets

### Cursor Target

- `.cursor/` directories (recursively)
- Cursor-related temporary files

### Python Target

- Virtual environments (`venv/`, `.venv/`, `env/`)
- Python cache files (`__pycache__/`, `*.pyc`, `*.pyo`)
- Build directories (`build/`, `dist/`, `*.egg-info/`)
- Pytest cache (`.pytest_cache/`)

### Node Target

- `node_modules/` directories
- Package lock files (`package-lock.json`, `yarn.lock`)
- NPM cache directories

## Environment Variables

- `DRY_RUN=true`: Enable dry-run mode

## Safety Features

- Dry-run mode shows what would be cleaned without making changes
- Intelligent filtering to preserve important files
- Confirmation prompts for destructive operations
- Detailed logging of cleanup operations

## Testing

```bash
# Run trilliax tests
bats tools/trilliax/tests/trilliax-tests.sh
```
