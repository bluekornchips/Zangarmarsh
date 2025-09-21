# Trilliax Cleanup Tool

## Overview

Trilliax is a powerful cleanup utility that removes generated files and directories from development environments. It intelligently identifies and removes temporary files, cache directories, and build artifacts while preserving important configuration files.

## Install

```bash
# Ensure Zangarmarsh is sourced in your shell profile
source /path/to/zangarmarsh/zangarmarsh.sh

# Trilliax will be available as an alias
```

## Usage

```bash
# Clean current directory
trilliax

# Clean specific directory
trilliax /path/to/project

# Preview what would be cleaned (dry-run mode)
trilliax --dry-run

# Clean only specific targets
trilliax --targets=cursor,python

# Show help
trilliax --help
```