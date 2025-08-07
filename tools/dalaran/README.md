# ZSH Command Dalaran Library

## Overview

A powerful shell script that builds and maintains a collection of your most-used commands over time. The dalaran library script analyzes your ZSH history, extracts frequently used commands, and creates an enhanced history file that prioritizes your most valuable commands.

## Features

- Historical Analysis: Processes your entire ZSH history to identify command patterns
- Frequency Ranking: Sorts commands by usage frequency to surface the most valuable ones
- Incremental Updates: Maintains a growing library that improves over time
- Backup System: Safely backs up your original history before processing
- ZSH Integration: Creates history files compatible with ZSH's history system
- Dry Run Mode: Preview operations without making changes

## Install

```bash
# Clone or download the script
# Make it executable
chmod +x tools/dalaran/dalaran.sh
```

## Usage

```bash
# Run the dalaran library script
./tools/dalaran/dalaran.sh

# Dry run mode - see what would be done without making changes
DRY_RUN=true ./tools/dalaran/dalaran.sh

# To use the enhanced history in your current session
export HISTFILE="$HOME/.zsh_dalaran_library/.zsh_history_working"
fc -R
```

## Configuration

The script uses these environment variables:

- `TOP_N_COMMANDS`: Number of top commands to extract (default: 1000)
- `HISTFILE`: Path to your ZSH history file (default: `$HOME/.zsh_history`)
- `DRY_RUN`: Set to `true` to preview operations without making changes

```bash
# Example: Extract top 500 commands
TOP_N_COMMANDS=500 ./tools/dalaran/dalaran.sh

# Example: Dry run with custom command limit
DRY_RUN=true TOP_N_COMMANDS=500 ./tools/dalaran/dalaran.sh
```

## How It Works

1. Backup: Creates a timestamped backup of your current history
2. Extraction: Parses ZSH history format and extracts plain commands
3. Analysis: Counts command frequency and ranks by usage
4. Combination: Merges with previous library snapshots
5. Generation: Creates enhanced history with most-used commands prioritized

## Output Files

The script creates several files in `$HOME/.zsh_dalaran_library/`:

- `top_commands.txt`: Combined list of most-used commands
- `.zsh_history_working`: Enhanced history file ready for use
- `top_commands/`: Directory containing historical snapshots
- `.zsh_history_*.txt`: Timestamped backups of original history

## Integration

Add to your `.zshrc` for automatic library usage:

```bash
# Use dalaran library-enhanced history
export HISTFILE="$HOME/.zsh_dalaran_library/.zsh_history_working"

# Reload history on shell startup
fc -R
```

## Maintenance

Run the script periodically to keep your library updated:

```bash
# Add to crontab for weekly updates
0 2 * * 0 /path/to/tools/dalaran/dalaran.sh
```

## Requirements

- ZSH shell
- Standard Unix tools (sed, grep, sort, uniq, wc)
- Write permissions to `$HOME/.zsh_dalaran_library/`

## Testing

The script includes a comprehensive test suite using Bats:

```bash
# Run all tests
bats tools/dalaran/dalaran-tests.sh

# Run specific test
bats tools/dalaran/dalaran-tests.sh -f "test name"
```

The tests are designed to never alter real system state.

## Troubleshooting

### Common Issues

**History file not found**

```bash
# Check your HISTFILE setting
echo $HISTFILE
# Or set it explicitly
export HISTFILE="$HOME/.zsh_history"
```

**Permission denied**

```bash
# Ensure script is executable
chmod +x tools/dalaran/dalaran.sh
```

**No commands extracted**

```bash
# Check if your history file has content
wc -l $HISTFILE
```

## Security

- The script only reads your history file and creates backups
- No external data is transmitted
- All processing happens locally on your machine
- Original history files are preserved as backups