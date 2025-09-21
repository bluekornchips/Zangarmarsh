# ZSH Command Dalaran Library

## Overview

A powerful shell script that builds and maintains a collection of your most-used commands over time. The dalaran library script analyzes your ZSH history, extracts frequently used commands, and creates an enhanced history file that prioritizes your most valuable commands.

## Install

```bash
# Clone or download the script
# Make it executable
chmod +x tools/dalaran/dalaran.sh
```

## Usage

```bash
# Run the dalaran spellbook script
./tools/dalaran/dalaran.sh

# Show top 20 most used commands from spellbook
./tools/dalaran/dalaran.sh --top=20

# Dry run mode, preview operations without making changes
./tools/dalaran/dalaran.sh --dry-run

# Add commands to silence list, exclude from analysis
./tools/dalaran/dalaran.sh --silence="ls,pwd,cd"

# Alternative environment variable for dry run
DRY_RUN=true ./tools/dalaran/dalaran.sh
```