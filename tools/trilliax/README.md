# Trilliax Cleanup Tool

## Overview

Trilliax removes generated files and directories from development environments: temporary files, cache directories, and build artifacts selected by target.

The name [Trilliax](https://www.wowhead.com/npc=104288/trilliax) comes from a World of Warcraft raid boss that was once a proud cleaner servant that now has multiple personalities, all of which are related to cleaning. "Filthy, filthy, FILTHY!" is one my friends and I quote often.

## Usage

```bash
# Clean current directory (all targets)
./tools/trilliax/trilliax.sh --all

# Clean specific directory
./tools/trilliax/trilliax.sh --all /path/to/project

# Preview what would be cleaned (dry-run mode)
./tools/trilliax/trilliax.sh --dry-run --all

# Clean only specific targets
./tools/trilliax/trilliax.sh --targets cursor,python

# Show help
./tools/trilliax/trilliax.sh --help
```

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

- `DRY_RUN=true`: Enable dry-run mode
- `MAX_DEPTH`: Maximum `find` depth, default `10`

## Testing

```bash
bats tools/trilliax/tests/trilliax-tests.sh
```
