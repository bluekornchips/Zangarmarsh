# ZSH Command Dalaran Library

## Overview

A powerful shell script that builds and maintains a collection of your most-used commands over time. Dalaran analyzes your ZSH history, extracts frequently used commands, and creates an enhanced history file that prioritizes your most valuable commands.

I chose the name [Dalaran](https://www.wowhead.com/zone=7502/dalaran) because it is the main city hub for knowledge in Warcraft, and has a cool library.

## Features

- Analyzes command frequency from ZSH history
- Creates enhanced history prioritizing valuable commands
- Maintains growing library that improves over time
- Configurable silence list for excluding common/noise commands
- Archive functionality for command history backup
- Dry-run mode for safe testing
- Supports custom history file locations

## Install

```bash
# Ensure the script is executable
chmod +x tools/dalaran/dalaran.sh
```

## Usage

```bash
# Run the dalaran spellbook script with default settings
./tools/dalaran/dalaran.sh

# Show top 20 most used commands from spellbook
./tools/dalaran/dalaran.sh --top=20

# Dry run mode - preview operations without making changes
./tools/dalaran/dalaran.sh --dry-run

# Add commands to silence list to exclude from analysis
./tools/dalaran/dalaran.sh --silence="ls,pwd,cd"

# Create archive of current history
./tools/dalaran/dalaran.sh --archive=true

# Alternative dry run using environment variable
DRY_RUN=true ./tools/dalaran/dalaran.sh
```

## Environment Variables

- `DRY_RUN=true`: Enable dry run mode
- `TOP_N_SPELLS=N`: Number of top spells to extract (default: 1000)
- `HISTFILE=path`: Path to zsh history file (default: ~/.zsh_history)

## Files Created

- `~/.dalaran_spellbook`: Enhanced history file with your most-used commands
- `~/.dalaran_silenced.txt`: List of commands to exclude from analysis
- `~/.dalaran_archive_*`: Archived copies of your command history

## Testing

```bash
# Run dalaran tests
bats tools/dalaran/tests/dalaran-tests.sh
```
